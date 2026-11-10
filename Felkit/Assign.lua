local addon,S=...
-- Raid assignments (original Felkit code): who curses what, who controls
-- which raid mark, and who soulstones whom.
--
-- The leader or an assistant (the party leader in a party) fills in the
-- window and presses Sync. Every warlock running Felkit gets theirs as a
-- small panel over the orb: a button for the curse, the control spell (with
-- its mark) and the soulstone, each one click to cast. Warlocks without the
-- addon get the list in chat with Announce.
--
-- The newest sync wins. Someone joining or reloading asks the group, and the
-- one who synced answers. Assignments are saved per character and cleared on
-- leaving the group. The panel's buttons cast (secure), so they only change
-- out of combat: a sync received mid-fight lands when the fight ends.
local AS={}; S.Assign=AS
local A=S.API
local PREFIX='Felkit'
local MEDIA='Interface\\AddOns\\'..addon..'\\Media\\'

AS.CURSES={'elements','recklessness','weakness','tongues','exhaustion','havoc'}
AS.CONTROLS={'banish','fear','enslave','howl','seduce'}
AS.CONTROL_IDS={banish={18647,710},fear={6215,6213,5782},enslave={11726,11725,1098},howl={17928,5484},seduce={6358}}
AS.SOULSTONES={16896,16895,16893,16892,5232}
local SHORT={elements='E',recklessness='R',weakness='W',tongues='T',exhaustion='X',havoc='H',
    banish='b',fear='f',enslave='e',howl='h',seduce='s'}
local LONG={}; for k,v in pairs(SHORT) do LONG[v]=k end

function AS.settings(old)
    old=type(old)=='table' and old or {}
    local N=S.Model.number
    return {panel=old.panel~=false,size=old.size=='full' and 'full' or 'small',
        x=N(old.x,-400,400,0),y=N(old.y,-200,400,0),announce=old.announce~=false}
end
local function store()
    FelkitCharDB=type(FelkitCharDB)=='table' and FelkitCharDB or {}
    local a=FelkitCharDB.assign
    if type(a)~='table' or type(a.entries)~='table' then a={entries={}}; FelkitCharDB.assign=a end
    return a
end

-- Names and spells --------------------------------------------------------------------
local function short(name)
    name=A.public(name)
    if type(name)~='string' or name=='' then return nil end
    if Ambiguate then local ok,n=pcall(Ambiguate,name,'none'); if ok and type(n)=='string' then return n end end
    return (name:gsub('%-.*$',''))
end
AS.short=short
local function me() return short(A.call(UnitName,'player')) end
local function familyIds(key) return AS.CONTROL_IDS[key] or (S.KitData.families[key]) end
function AS.label(key)
    if not key then return S.L.assignNone end
    local ids=familyIds(key)
    local name=ids and A.spell(ids[#ids])
    return (type(name)=='string' and name~='' and name:sub(1,1)~='#') and name or key
end
function AS.icon(key)
    local ids=familyIds(key)
    return ids and select(2,A.spell(ids[#ids])) or nil
end
local function best(key)
    local ids=familyIds(key); if not ids then return end
    for _,id in ipairs(ids) do if S.Kit.isKnown(id) then return id end end
    return S.Kit.best(key)
end
local function markTexture(i) return 'Interface\\TargetingFrame\\UI-RaidTargetingIcon_'..i end

-- Group --------------------------------------------------------------------------------
function AS.roster()
    local list,warlocks={},{}
    local raid=A.call(IsInRaid)==true
    local n=A.num(A.call(GetNumGroupMembers)) or 0
    local function add(unit)
        local name=short(A.call(UnitName,unit))
        if not name then return end
        list[#list+1]=name
        local ok,_,token=pcall(UnitClass,unit)
        if ok and A.public(token)=='WARLOCK' then warlocks[#warlocks+1]=name end
    end
    if n==0 then add('player')
    elseif raid then for i=1,n do add('raid'..i) end
    else add('player'); for i=1,n-1 do add('party'..i) end end
    table.sort(list); table.sort(warlocks)
    return warlocks,list
end
function AS.canEdit()
    if A.call(IsInGroup)~=true then return true end
    if A.call(UnitIsGroupLeader,'player')==true then return true end
    return A.call(IsInRaid)==true and A.call(UnitIsGroupAssistant,'player')==true
end
local function senderAllowed(sender)
    local name=short(sender)
    if not name then return false end
    if name==me() then return true end
    if A.call(UnitIsGroupLeader,name)==true then return true end
    return A.call(IsInRaid)==true and A.call(UnitIsGroupAssistant,name)==true
end
local function channel()
    if LE_PARTY_CATEGORY_INSTANCE and A.call(IsInGroup,LE_PARTY_CATEGORY_INSTANCE)==true then return 'INSTANCE_CHAT' end
    if A.call(IsInRaid)==true then return 'RAID' end
    if A.call(IsInGroup)==true then return 'PARTY' end
end

-- Sync ---------------------------------------------------------------------------------
-- One entry: name,curse,control,mark,soulstone. Names never hold , or ;.
local function encode(entries)
    local parts={}
    for name,e in pairs(entries) do
        parts[#parts+1]=table.concat({name,SHORT[e.curse] or '',SHORT[e.control] or '',tostring(e.mark or 0),e.ss or ''},',')
    end
    table.sort(parts)
    return table.concat(parts,';')
end
local function decode(text)
    local entries={}
    for part in (text or ''):gmatch('[^;]+') do
        local name,c,k,m,ss=part:match('^([^,]+),([^,]*),([^,]*),(%d*),([^,]*)$')
        if name then
            entries[name]={curse=LONG[c],control=LONG[k],mark=tonumber(m) ~= 0 and tonumber(m) or nil,ss=ss~='' and ss or nil}
        end
    end
    return entries
end
local function send(msg)
    local ch=channel(); if not ch or not C_ChatInfo then return false end
    return pcall(C_ChatInfo.SendAddonMessage,PREFIX,msg,ch)
end
function AS.sync()
    local a=store()
    if not AS.canEdit() then S.print(S.L.assignNotLeader); return end
    a.from=me(); a.at=time()
    local id=tostring(math.random(100000,999999))
    local text=encode(a.entries)
    local chunks={}
    if text=='' then chunks[1]='' end
    for i=1,#text,200 do chunks[#chunks+1]=text:sub(i,i+199) end
    if not channel() then AS.apply(); S.print(S.L.assignSoloSaved); return end
    for i,chunk in ipairs(chunks) do send('S|'..id..'|'..i..'|'..#chunks..'|'..chunk) end
    S.print(S.L.assignSynced)
    AS.apply()
end
local incoming={}
local function onMessage(prefix,text,_,sender)
    if prefix~=PREFIX then return end
    text=A.public(text); sender=A.public(sender)
    if type(text)~='string' or type(sender)~='string' then return end
    local kind=text:sub(1,1)
    if kind=='Q' then
        local a=store()
        if a.from==me() and short(sender)~=me() and AS.canEdit() then
            C_Timer.After(math.random()*2,function() AS.sync() end)
        end
        return
    end
    if kind~='S' or not senderAllowed(sender) then return end
    local id,i,n,chunk=text:match('^S|(%d+)|(%d+)|(%d+)|(.*)$')
    i,n=tonumber(i),tonumber(n)
    if not id or not i or not n or n>40 then return end
    local key=sender..id
    local buf=incoming[key] or {parts={},got=0}; incoming[key]=buf
    if not buf.parts[i] then buf.parts[i]=chunk; buf.got=buf.got+1 end
    if buf.got<n then return end
    incoming[key]=nil
    local a=store()
    a.entries=decode(table.concat(buf.parts,'',1,n)); a.from=short(sender); a.at=time()
    if short(sender)~=me() then
        local mine=a.entries[me()]
        S.print(string.format(S.L.assignReceived,short(sender))..(mine and '' or (' '..S.L.assignNothingForYou)))
        if A.combat() then S.print(S.L.assignAfterCombat) end
    end
    AS.apply()
end

-- Chat announcement, for warlocks without the addon ------------------------------------
function AS.announce()
    local ch=channel()
    local a=store()
    local names={}; for name in pairs(a.entries) do names[#names+1]=name end
    table.sort(names)
    if #names==0 then S.print(S.L.assignEmpty); return end
    local lines={S.L.assignChatTitle}
    for _,name in ipairs(names) do
        local e=a.entries[name]; local bits={}
        if e.curse then bits[#bits+1]=AS.label(e.curse) end
        if e.control then bits[#bits+1]=AS.label(e.control)..(e.mark and (' {rt'..e.mark..'}') or '') end
        if e.ss then bits[#bits+1]=S.L.assignSoulstoneShort..' > '..e.ss end
        if #bits>0 then lines[#lines+1]=name..': '..table.concat(bits,' | ') end
    end
    for _,line in ipairs(lines) do
        if ch then pcall(SendChatMessage,line,ch) else S.print(line) end
    end
end

-- Personal panel over the orb ------------------------------------------------------------
local function secureButton(parent)
    local b=CreateFrame('Button',nil,parent,'SecureActionButtonTemplate')
    b:RegisterForClicks('AnyUp'); b:SetAttribute('useOnKeyDown',false)
    b.icon=b:CreateTexture(nil,'ARTWORK'); b.icon:SetAllPoints(); b.icon:SetTexCoord(.08,.92,.08,.92)
    b.mask=b:CreateMaskTexture(); b.mask:SetTexture(MEDIA..'fk_mask','CLAMPTOBLACKADDITIVE','CLAMPTOBLACKADDITIVE')
    b.mask:SetAllPoints(b); b.icon:AddMaskTexture(b.mask)
    b.ring=b:CreateTexture(nil,'OVERLAY'); b.ring:SetTexture(MEDIA..'fk_ring_n'); b.ring:SetPoint('CENTER')
    b.mark=b:CreateTexture(nil,'OVERLAY',nil,2); b.mark:SetPoint('TOPRIGHT',4,4)
    b.text=b:CreateFontString(nil,'OVERLAY'); b.text:SetFont(STANDARD_TEXT_FONT or 'Fonts\\FRIZQT__.TTF',10,'OUTLINE')
    b.text:SetPoint('TOP',b,'BOTTOM',0,-2)
    local hl=b:CreateTexture(nil,'HIGHLIGHT'); hl:SetTexture(MEDIA..'fk_glow_fel'); hl:SetBlendMode('ADD'); hl:SetPoint('CENTER')
    b.hl=hl
    b:SetScript('OnEnter',function(self)
        GameTooltip:SetOwner(self,'ANCHOR_TOP'); GameTooltip:SetText(self.title or '')
        if self.sub then GameTooltip:AddLine(self.sub,1,1,1,true) end
        GameTooltip:AddLine(S.L.assignPanelHelp,.8,.65,1,true); GameTooltip:Show()
    end)
    b:SetScript('OnLeave',function() GameTooltip:Hide() end)
    return b
end
function AS.createPanel()
    local p=CreateFrame('Frame','FelkitAssignPanel',S.UI.counter); AS.panel=p
    p:SetSize(1,1); p.buttons={}
    for i,key in ipairs({'curse','control','ss'}) do p.buttons[key]=secureButton(p) end
    p.title=p:CreateFontString(nil,'OVERLAY'); p.title:SetFont(STANDARD_TEXT_FONT or 'Fonts\\FRIZQT__.TTF',10,'OUTLINE')
    p.title:SetTextColor(.66,.42,1); p.title:SetText(S.L.assignPanelTitle)
    p:Hide()
end
-- Out of combat only: the buttons cast.
function AS.apply()
    if not AS.panel then return end
    if A.combat() then AS.pending=true; return end
    AS.pending=nil
    local a=store(); local e=a.entries[me() or '']
    local cfg=S.db.raid
    local size=cfg.size=='full' and S.db.kit.size or math.floor(S.db.kit.size*0.7+0.5)
    local p=AS.panel
    local shown={}
    local function setup(key,b)
        b:SetAttribute('type',nil); b:SetAttribute('spell',nil); b:SetAttribute('macrotext',nil); b:SetAttribute('unit',nil)
        b.mark:Hide(); b.text:SetText(''); b.title=nil; b.sub=nil
        if not e then return false end
        if key=='curse' and e.curse then
            b:SetAttribute('type','spell'); b:SetAttribute('spell',best(e.curse) or familyIds(e.curse)[1])
            b.icon:SetTexture(AS.icon(e.curse)); b.title=AS.label(e.curse); b.sub=S.L.assignYourCurse
            return true
        elseif key=='control' and e.control then
            if e.control=='seduce' then
                b:SetAttribute('type','macro'); b:SetAttribute('macrotext','/cast '..AS.label('seduce'))
            else
                b:SetAttribute('type','spell'); b:SetAttribute('spell',best(e.control) or familyIds(e.control)[1])
            end
            b.icon:SetTexture(AS.icon(e.control)); b.title=AS.label(e.control); b.sub=S.L.assignYourControl
            if e.mark then b.mark:SetTexture(markTexture(e.mark)); b.mark:SetSize(size*0.5,size*0.5); b.mark:Show() end
            return true
        elseif key=='ss' and e.ss then
            local lines={}
            for _,id in ipairs(AS.SOULSTONES) do lines[#lines+1]='/use [@'..e.ss..'] item:'..id end
            b:SetAttribute('type','macro'); b:SetAttribute('macrotext',table.concat(lines,'\n'))
            b.icon:SetTexture(C_Item and A.call(C_Item.GetItemIconByID,AS.SOULSTONES[1]) or 'Interface\\Icons\\Spell_Shadow_SoulGem')
            b.title=S.L.assignSoulstoneShort..' > '..e.ss; b.sub=S.L.assignYourSoulstone; b.text:SetText(e.ss)
            return true
        end
        return false
    end
    for _,key in ipairs({'curse','control','ss'}) do
        local b=p.buttons[key]
        if setup(key,b) then shown[#shown+1]=b; b:Show() else b:Hide() end
    end
    local ring=S.Orb.color(S.db.kit.ringColor,'purple')
    local gap=size+10
    for i,b in ipairs(shown) do
        b:SetSize(size,size); b.ring:SetSize(size*1.18,size*1.18); b.ring:SetVertexColor(ring[1],ring[2],ring[3])
        b.hl:SetSize(size*1.5,size*1.5)
        b:ClearAllPoints(); b:SetPoint('CENTER',p,'CENTER',(i-(#shown+1)/2)*gap,0)
    end
    -- Over the kit: above the orb's arc.
    local kit=S.db.kit
    local lift=(kit.orbSize or 58)/2+kit.size*kit.scale+(kit.orbGap or 7)+size/2+24
    p:ClearAllPoints(); p:SetPoint('CENTER',S.UI.counter,'CENTER',cfg.x,lift+cfg.y)
    p:SetSize(math.max(1,#shown*gap),size)
    p.title:ClearAllPoints(); p.title:SetPoint('BOTTOM',p,'TOP',0,4)
    p:SetShown(S.db.enabled and cfg.panel and #shown>0)
    if AS.window and AS.window:IsShown() then AS.render() end
end

-- Assignment window -------------------------------------------------------------------
local T
local function menu()
    if AS.menu then return AS.menu end
    local m=CreateFrame('Frame',nil,UIParent); m:SetFrameStrata('FULLSCREEN_DIALOG'); m:EnableMouse(true)
    T.skin(m,T.c.side,T.c.accentDim); m.items={}; m:Hide()
    m:SetScript('OnHide',function() m.owner=nil end)
    AS.menu=m; return m
end
-- options: {{value=,label=,icon=}}; onPick(value)
local function openMenu(owner,options,onPick)
    local m=menu()
    if m:IsShown() and m.owner==owner then m:Hide(); return end
    m.owner=owner
    for _,it in ipairs(m.items) do it:Hide() end
    for i,o in ipairs(options) do
        local it=m.items[i]
        if not it then
            it=CreateFrame('Button',nil,m); it:SetSize(180,22)
            it.hl=it:CreateTexture(nil,'HIGHLIGHT'); it.hl:SetAllPoints(); it.hl:SetColorTexture(T.rgb(T.c.raised))
            it.icon=it:CreateTexture(nil,'ARTWORK'); it.icon:SetSize(16,16); it.icon:SetPoint('LEFT',4,0)
            it.text=T.text(it,12,T.c.text); it.text:SetPoint('LEFT',24,0); it.text:SetJustifyH('LEFT')
            m.items[i]=it
        end
        it:SetPoint('TOPLEFT',4,-4-(i-1)*22)
        it.text:SetText(o.label); it.icon:SetTexture(o.icon); it.icon:SetShown(o.icon~=nil)
        if o.coords then it.icon:SetTexCoord(unpack(o.coords)) else it.icon:SetTexCoord(.08,.92,.08,.92) end
        it:SetScript('OnClick',function() m:Hide(); onPick(o.value) end)
        it:Show()
    end
    m:SetSize(188,#options*22+8)
    m:ClearAllPoints(); m:SetPoint('TOPLEFT',owner,'BOTTOMLEFT',0,-2); m:Show()
end
local function curseOptions()
    local o={{value=false,label=S.L.assignNone}}
    for _,k in ipairs(AS.CURSES) do o[#o+1]={value=k,label=AS.label(k),icon=AS.icon(k)} end
    return o
end
local function controlOptions()
    local o={{value=false,label=S.L.assignNone}}
    for _,k in ipairs(AS.CONTROLS) do o[#o+1]={value=k,label=AS.label(k),icon=AS.icon(k)} end
    return o
end
local function markOptions()
    local o={{value=false,label=S.L.assignNoMark}}
    for i=1,8 do o[#o+1]={value=i,label=S.L['mark'..i],icon=markTexture(i),coords={0,1,0,1}} end
    return o
end
local function ssOptions(members)
    local o={{value=false,label=S.L.assignNone}}
    for _,n in ipairs(members) do o[#o+1]={value=n,label=n} end
    return o
end
local ROW_H=34
function AS.createWindow()
    T=S.Theme
    local f=T.window('FelkitAssign',720,470,S.L.assignTitle,'assign'); AS.window=f; f:Hide()
    f.help=T.text(f,11,T.c.muted); f.help:SetPoint('TOPLEFT',16,-46); f.help:SetWidth(688); f.help:SetWordWrap(true)
    f.help:SetText(S.L.assignWindowHelp)
    local cols={{S.L.assignColWarlock,16},{S.L.assignColCurse,170},{S.L.assignColControl,330},{S.L.assignColMark,490},{S.L.assignColSoulstone,580}}
    for _,c in ipairs(cols) do
        local t=T.text(f,11,T.c.gold); t:SetPoint('TOPLEFT',c[2],-82); t:SetText(c[1])
    end
    f.rows={}
    for i=1,10 do
        local r=CreateFrame('Frame',nil,f); r:SetSize(688,ROW_H-4); r:SetPoint('TOPLEFT',16,-100-(i-1)*ROW_H)
        r.bg=r:CreateTexture(nil,'BACKGROUND'); r.bg:SetAllPoints(); r.bg:SetColorTexture(T.rgb(T.c.card))
        r.name=T.text(r,12,T.c.accent); r.name:SetPoint('LEFT',6,0); r.name:SetWidth(140); r.name:SetJustifyH('LEFT')
        local function picker(x,w,field,options)
            local b=T.button(r,'',w,24,nil,'secondary'); b:SetPoint('LEFT',x-16,0)
            b:SetScript('OnClick',function(self)
                if not AS.canEdit() then return end
                openMenu(self,options(),function(v)
                    local a=store(); local e=a.entries[r.who] or {}; a.entries[r.who]=e
                    e[field]=v or nil
                    if not (e.curse or e.control or e.ss) then a.entries[r.who]=nil end
                    AS.render()
                end)
            end)
            return b
        end
        r.curse=picker(170,150,'curse',curseOptions)
        r.control=picker(330,150,'control',controlOptions)
        r.mark=picker(490,80,'mark',markOptions)
        r.ss=picker(580,120,'ss',function() local _,members=AS.roster(); return ssOptions(members) end)
        f.rows[i]=r
    end
    f.empty=T.text(f,12,T.c.muted); f.empty:SetPoint('TOP',0,-140); f.empty:SetText(S.L.assignNoWarlocks)
    f.status=T.text(f,11,T.c.faint); f.status:SetPoint('BOTTOMLEFT',16,52); f.status:SetWidth(688); f.status:SetJustifyH('LEFT')
    local x=16
    for _,def in ipairs({{S.L.assignSync,function() AS.sync() end,'primary'},{S.L.assignAnnounce,function() AS.announce() end},
        {S.L.assignClear,function() if AS.canEdit() then store().entries={}; AS.render() end end},
        {S.L.assignRefresh,function() AS.render() end}}) do
        local b=T.button(f,def[1],150,28,def[2],def[3]); b:SetPoint('BOTTOMLEFT',x,14); x=x+162
        f[def[1]]=b
    end
    f:SetScript('OnShow',function() AS.render() end)
    f:SetScript('OnHide',function() if AS.menu then AS.menu:Hide() end end)
end
function AS.render()
    local f=AS.window; if not f or not f:IsShown() then return end
    local a=store(); local warlocks=AS.roster()
    -- Assigned people who left keep their row until cleared.
    local seen={}; for _,n in ipairs(warlocks) do seen[n]=true end
    for n in pairs(a.entries) do if not seen[n] then warlocks[#warlocks+1]=n end end
    local edit=AS.canEdit()
    for i,r in ipairs(f.rows) do
        local who=warlocks[i]
        r:SetShown(who~=nil); r.who=who
        if who then
            local e=a.entries[who] or {}
            r.name:SetText(who..(seen[who] and '' or (' '..S.L.assignGone)))
            r.curse.label:SetText(e.curse and AS.label(e.curse) or S.L.assignNone)
            r.control.label:SetText(e.control and AS.label(e.control) or S.L.assignNone)
            r.mark.label:SetText(e.mark and ('|T'..markTexture(e.mark)..':14|t '..S.L['mark'..e.mark]) or '-')
            r.ss.label:SetText(e.ss or S.L.assignNone)
            for _,b in ipairs({r.curse,r.control,r.mark,r.ss}) do b:SetAlpha(edit and 1 or .6) end
        end
    end
    f.empty:SetShown(#warlocks==0)
    f.status:SetText((a.from and string.format(S.L.assignLast,a.from,date('%H:%M',a.at or time())) or S.L.assignNever)
        ..'   '..(edit and S.L.assignYouEdit or S.L.assignReadOnly))
end
function AS.toggle()
    if not AS.window then return end
    if AS.window:IsShown() then AS.window:Hide() else AS.window:Show() end
end

function AS.create()
    store()
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then pcall(C_ChatInfo.RegisterAddonMessagePrefix,PREFIX) end
    AS.createPanel(); AS.createWindow()
    local f=CreateFrame('Frame'); AS.events=f
    for _,ev in ipairs({'CHAT_MSG_ADDON','GROUP_ROSTER_UPDATE','GROUP_LEFT','GROUP_JOINED','PLAYER_REGEN_ENABLED','PLAYER_ENTERING_WORLD'}) do
        pcall(f.RegisterEvent,f,ev)
    end
    f:SetScript('OnEvent',function(_,event,...)
        if event=='CHAT_MSG_ADDON' then onMessage(...); return end
        if event=='GROUP_LEFT' or (event=='GROUP_ROSTER_UPDATE' and A.call(IsInGroup)~=true) then
            local a=store()
            if next(a.entries) and a.from and a.from~=me() then a.entries={}; a.from=nil; AS.apply() end
        end
        if event=='GROUP_JOINED' or (event=='PLAYER_ENTERING_WORLD' and A.call(IsInGroup)==true) then
            C_Timer.After(3,function() send('Q') end)
        end
        if event=='PLAYER_REGEN_ENABLED' and AS.pending then AS.apply() end
        if event=='GROUP_ROSTER_UPDATE' then AS.render() end
    end)
    AS.apply()
end
