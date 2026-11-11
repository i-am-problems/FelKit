local addon,S=...
-- Proc timers (original FelKit code): Decimation and Nightfall (Shadow Trance)
-- as a bar or an icon with a countdown, placed anywhere.
--
-- Forever hides the player's buffs from addon code in combat, so the timer
-- never reads them: each look is a slot in the game's own AuraContainer on
-- the player, filtered on the proc's buff IDs. The game shows the slot while
-- the buff is on and drains its bar and countdown. FelKit only builds and
-- places it, out of combat and outside aura restrictions; a change made in a
-- fight waits for the fight to end. The countdown text is never touched once
-- the game owns it, so each look (bar, icon) has its own slot.
local P={procs={}}; S.Procs=P
local A=S.API
local MEDIA='Interface\\AddOns\\'..addon..'\\Media\\'

P.DEFS={
    {key='decimation',ids={440873},icon=440873,color={1.0,0.45,0.12},default=true},
    {key='nightfall',ids={17941},icon=17941,color={0.66,0.36,1.0},default=false},
}
local STYLES={bar=true,icon=true}

function P.settings(old)
    old=type(old)=='table' and old or {}
    local N=S.Model.number
    local d={}
    for i,def in ipairs(P.DEFS) do
        local o=type(old[def.key])=='table' and old[def.key] or {}
        local t={}
        if type(o.enabled)=='boolean' then t.enabled=o.enabled else t.enabled=def.default end
        t.style=STYLES[o.style] and o.style or 'bar'
        t.width=N(o.width,80,400,180); t.height=N(o.height,10,40,20); t.iconSize=N(o.iconSize,20,96,44)
        t.showName=o.showName~=false; t.alpha=N(o.alpha,0.2,1,1)
        t.x=N(o.x,-3000,3000,0); t.y=N(o.y,-3000,3000,-140-(i-1)*34)
        t.buffId=N(o.buffId,1,99999999)
        d[def.key]=t
    end
    return d
end
local function cfg(key) return S.db.procs[key] end
local function idsOf(def)
    local c=cfg(def.key)
    if c.buffId then return {[c.buffId]=true} end
    local t={}; for _,id in ipairs(def.ids) do t[id]=true end; return t
end
local function restricted()
    return A.combat() or (C_Secrets and C_Secrets.ShouldAurasBeSecret and A.call(C_Secrets.ShouldAurasBeSecret)==true)
end
local function font(t,size)
    t:SetFont(S.font(),size,S.fontOutline())
end

-- Visual pieces, shared by the native slots and the public test frame --------------
local function edges(parent,anchor,r,g,b)
    local e={}
    for i=1,4 do e[i]=parent:CreateTexture(nil,'OVERLAY'); e[i]:SetColorTexture(r,g,b,1) end
    e[1]:SetPoint('TOPLEFT',anchor,'TOPLEFT',-1,1); e[1]:SetPoint('TOPRIGHT',anchor,'TOPRIGHT',1,1); e[1]:SetHeight(1)
    e[2]:SetPoint('BOTTOMLEFT',anchor,'BOTTOMLEFT',-1,-1); e[2]:SetPoint('BOTTOMRIGHT',anchor,'BOTTOMRIGHT',1,-1); e[2]:SetHeight(1)
    e[3]:SetPoint('TOPLEFT',anchor,'TOPLEFT',-1,1); e[3]:SetPoint('BOTTOMLEFT',anchor,'BOTTOMLEFT',-1,-1); e[3]:SetWidth(1)
    e[4]:SetPoint('TOPRIGHT',anchor,'TOPRIGHT',1,1); e[4]:SetPoint('BOTTOMRIGHT',anchor,'BOTTOMRIGHT',1,-1); e[4]:SetWidth(1)
    return e
end
-- A bar: round icon in a ring, then a dark bar with the proc's colour, name and time.
local function buildBar(f,def)
    local v={}
    v.icon=f:CreateTexture(nil,'ARTWORK'); v.icon:SetTexCoord(.08,.92,.08,.92)
    v.icon:SetTexture(select(2,A.spell(def.icon)))
    v.mask=f:CreateMaskTexture(); v.mask:SetTexture(MEDIA..'fk_mask','CLAMPTOBLACKADDITIVE','CLAMPTOBLACKADDITIVE')
    v.mask:SetAllPoints(v.icon); v.icon:AddMaskTexture(v.mask)
    v.bar=CreateFrame('StatusBar',nil,f); v.bar:SetStatusBarTexture(MEDIA..'fk_bar'); v.bar:SetMinMaxValues(0,1); v.bar:SetValue(1)
    v.bar:SetStatusBarColor(def.color[1],def.color[2],def.color[3],.95)
    v.bg=v.bar:CreateTexture(nil,'BACKGROUND'); v.bg:SetAllPoints(v.bar); v.bg:SetColorTexture(.04,.025,.06,.9)
    local over=CreateFrame('Frame',nil,f); over:SetAllPoints(f); over:SetFrameLevel(v.bar:GetFrameLevel()+2); v.over=over
    v.edges=edges(over,v.bar,.66,.42,1)
    v.ring=over:CreateTexture(nil,'OVERLAY',nil,2); v.ring:SetTexture(MEDIA..'fk_ring_n'); v.ring:SetVertexColor(.66,.42,1)
    v.ring:SetPoint('CENTER',v.icon,'CENTER')
    v.name=over:CreateFontString(nil,'OVERLAY'); font(v.name,11); v.name:SetJustifyH('LEFT')
    v.name:SetText(A.spell(def.icon) or def.key)
    v.time=over:CreateFontString(nil,'OVERLAY'); font(v.time,11); v.time:SetJustifyH('RIGHT')
    -- Anchored once: the game owns the countdown text once it is bound.
    v.time:SetPoint('RIGHT',v.bar,'RIGHT',-5,0)
    return v
end
local function layoutBar(v,c)
    local h=c.height
    v.icon:ClearAllPoints(); v.icon:SetPoint('LEFT',v.bar:GetParent(),'LEFT',0,0); v.icon:SetSize(h+4,h+4)
    v.ring:SetSize((h+4)*1.24,(h+4)*1.24)
    v.bar:ClearAllPoints(); v.bar:SetPoint('LEFT',v.icon,'RIGHT',4,0); v.bar:SetSize(math.max(20,c.width-h-8),h)
    v.name:ClearAllPoints(); v.name:SetPoint('LEFT',v.bar,'LEFT',5,0); v.name:SetWidth(math.max(10,c.width-h-60))
    v.name:SetShown(c.showName)
end
-- An icon: the spell icon in a ring with the countdown in the middle.
local function buildIcon(f,def)
    local v={}
    v.icon=f:CreateTexture(nil,'ARTWORK'); v.icon:SetTexCoord(.08,.92,.08,.92); v.icon:SetAllPoints(f)
    v.icon:SetTexture(select(2,A.spell(def.icon)))
    v.mask=f:CreateMaskTexture(); v.mask:SetTexture(MEDIA..'fk_mask','CLAMPTOBLACKADDITIVE','CLAMPTOBLACKADDITIVE')
    v.mask:SetAllPoints(f); v.icon:AddMaskTexture(v.mask)
    v.cooldown=CreateFrame('Cooldown',nil,f,'CooldownFrameTemplate'); v.cooldown:SetAllPoints(f)
    v.cooldown:SetDrawEdge(false); v.cooldown:SetReverse(true); v.cooldown:SetHideCountdownNumbers(true)
    if v.cooldown.SetSwipeTexture then pcall(v.cooldown.SetSwipeTexture,v.cooldown,MEDIA..'fk_mask') end
    local over=CreateFrame('Frame',nil,f); over:SetAllPoints(f); over:SetFrameLevel(v.cooldown:GetFrameLevel()+2); v.over=over
    v.ring=over:CreateTexture(nil,'OVERLAY'); v.ring:SetTexture(MEDIA..'fk_ring_n'); v.ring:SetPoint('CENTER')
    v.ring:SetVertexColor(def.color[1],def.color[2],def.color[3])
    v.time=over:CreateFontString(nil,'OVERLAY'); font(v.time,16); v.time:SetPoint('CENTER',0,0)
    return v
end
local function layoutIcon(v,c)
    v.ring:SetSize(c.iconSize*1.2,c.iconSize*1.2)
end
local function sizeOf(c)
    if c.style=='icon' then return c.iconSize,c.iconSize end
    return c.width,c.height+4
end

-- Native slots ------------------------------------------------------------------------
local function buildNative(p,style)
    local def=p.def
    local host=CreateFrame('Frame',nil,p.anchor); host:SetAllPoints(p.anchor); host:EnableMouse(false)
    local container=CreateFrame('AuraContainer',nil,host,'CustomAuraContainerTemplate')
    container:SetAllPoints(host); container:EnableMouse(false)
    container:SetUnit('player')
    local entry={host=host,container=container}
    container:AddAuraSlot(def.key..style,'HELPFUL',{candidateFilters={includeSpellIDs=idsOf(def)},initializeFrame=function(slot)
        slot:SetAllPoints(container); slot:EnableMouse(false)
        local v=style=='icon' and buildIcon(slot,def) or buildBar(slot,def)
        local direction=Enum and Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.RemainingTime or 1
        if v.bar then slot:SetDurationBar(v.bar,{direction=direction,interpolation=0}) end
        if v.cooldown and slot.SetDurationCooldown then slot:SetDurationCooldown(v.cooldown) end
        slot:SetDurationText(v.time,{})
        entry.visuals=v; entry.slot=slot
    end})
    assert(entry.visuals,'proc slot initialization did not run')
    return entry
end
local function ensureNative(p)
    if p.native then return true end
    if p.failed then return false end
    local ok,err=pcall(function()
        if C_AddOns and not C_AddOns.IsAddOnLoaded('Blizzard_AuraContainer') then pcall(C_AddOns.LoadAddOn,'Blizzard_AuraContainer') end
        p.native={bar=buildNative(p,'bar'),icon=buildNative(p,'icon')}
    end)
    if not ok then
        p.failed=true; p.error=tostring(A.public(err) or 'restricted error'):sub(1,200)
        if p.native then for _,e in pairs(p.native) do e.host:Hide() end end
        p.native=nil
    end
    return ok
end

-- Placement and the test bar -------------------------------------------------------
local function place(p)
    local c=cfg(p.def.key)
    local w,h=sizeOf(c)
    p.anchor:ClearAllPoints(); p.anchor:SetPoint('CENTER',UIParent,'CENTER',c.x,c.y); p.anchor:SetSize(w,h)
    p.anchor:SetAlpha(c.alpha)
end
local function savePosition(p)
    local x,y=p.anchor:GetCenter(); local px,py=UIParent:GetCenter()
    local ratio=p.anchor:GetEffectiveScale()/UIParent:GetEffectiveScale()
    local c=cfg(p.def.key); c.x=x-px/ratio; c.y=y-py/ratio
    place(p)
end
local function buildTest(p)
    local t=CreateFrame('Frame',nil,p.anchor); t:SetAllPoints(p.anchor); t:SetFrameStrata('HIGH')
    t.bar=CreateFrame('Frame',nil,t); t.bar:SetAllPoints(t); t.barV=buildBar(t.bar,p.def)
    t.icon=CreateFrame('Frame',nil,t); t.icon:SetAllPoints(t); t.iconV=buildIcon(t.icon,p.def)
    t.frame=t:CreateTexture(nil,'BACKGROUND'); t.frame:SetPoint('TOPLEFT',-4,4); t.frame:SetPoint('BOTTOMRIGHT',4,-4)
    t.frame:SetColorTexture(0.25,0.9,1,0.18)
    t:EnableMouse(true); t:RegisterForDrag('LeftButton')
    t:SetScript('OnDragStart',function() if not A.combat() then p.anchor:StartMoving() end end)
    t:SetScript('OnDragStop',function() p.anchor:StopMovingOrSizing(); savePosition(p) end)
    t:SetScript('OnMouseUp',function(_,b) if b=='RightButton' then P.setTest(false) end end)
    t:SetScript('OnEnter',function(self)
        GameTooltip:SetOwner(self,'ANCHOR_TOP'); GameTooltip:SetText(S.L['proc_'..p.def.key])
        GameTooltip:AddLine(S.L.procDragHelp,1,1,1,true); GameTooltip:Show()
    end)
    t:SetScript('OnLeave',function() GameTooltip:Hide() end)
    t:SetScript('OnUpdate',function(self)
        local duration=10; local left=duration-(GetTime()%duration)
        self.barV.bar:SetValue(left/duration); self.barV.time:SetText(string.format('%.1f',left))
        self.iconV.time:SetText(tostring(math.ceil(left)))
        if not self.cdAt or GetTime()-self.cdAt>=duration then
            self.cdAt=GetTime()-(duration-left); self.iconV.cooldown:SetCooldown(self.cdAt,duration)
        end
    end)
    t:Hide(); p.test=t
end
function P.setTest(on)
    if on and A.combat() then S.print(S.L.previewOnly); return end
    P.testing=on==true
    P.refresh()
    if P.testing then S.print(S.L.procTestOn) end
end

function P.create()
    for _,def in ipairs(P.DEFS) do
        local p={def=def}
        p.anchor=CreateFrame('Frame','FelkitProc_'..def.key,UIParent); p.anchor:SetMovable(true); p.anchor:SetClampedToScreen(true)
        buildTest(p)
        P.procs[def.key]=p
    end
    local f=CreateFrame('Frame'); P.events=f
    f:RegisterEvent('PLAYER_REGEN_ENABLED'); f:RegisterEvent('PLAYER_ENTERING_WORLD')
    f:SetScript('OnEvent',function() if P.pending then P.refresh() end end)
end
-- Out of combat and outside restrictions: build, size and show the chosen look.
function P.refresh()
    if not P.events or not S.db then return end
    if restricted() then P.pending=true; if A.combat() then P.testing=false end
        for _,p in pairs(P.procs) do p.test:Hide() end
        return
    end
    P.pending=nil
    for key,p in pairs(P.procs) do
        local c=cfg(key)
        local on=S.db.enabled and S.db.procTimers and c.enabled
        place(p)
        p.test:SetShown(P.testing==true and on)
        if p.test:IsShown() then
            p.test.bar:SetShown(c.style=='bar'); p.test.icon:SetShown(c.style=='icon')
            layoutBar(p.test.barV,c); layoutIcon(p.test.iconV,c)
        end
        local signature=table.concat({tostring(c.buffId)},':')
        if p.native and p.signature~=signature then
            -- A new buff ID: the filters are fixed at creation, so start over.
            for _,e in pairs(p.native) do pcall(e.container.SetUnit,e.container,'none'); e.host:Hide() end
            p.native=nil; p.failed=nil
        end
        if on and ensureNative(p) then
            p.signature=signature
            for style,e in pairs(p.native) do
                local show=c.style==style and not P.testing
                pcall(function()
                    if style=='bar' then layoutBar(e.visuals,c) else layoutIcon(e.visuals,c) end
                end)
                e.host:SetShown(show)
            end
        elseif p.native then
            for _,e in pairs(p.native) do e.host:Hide() end
        end
    end
end
-- /fk procs ...
function P.slash(rest)
    rest=(rest or ''):match('^%s*(.-)%s*$')
    if rest=='test' or rest=='move' then P.setTest(not P.testing); return end
    if rest=='lock' then P.setTest(false); return end
    if rest=='reset' then
        local fresh=P.settings({})
        for key,c in pairs(S.db.procs) do c.x,c.y,c.buffId=fresh[key].x,fresh[key].y,nil end
        P.refresh(); S.print(S.L.procReset); return
    end
    local key,id=rest:match('^(%a+)%s+(%d+)$')
    if key and S.db.procs[key] then
        S.db.procs[key].buffId=tonumber(id); P.refresh()
        S.print(string.format(S.L.procIdSet,S.L['proc_'..key],id)); return
    end
    local lines={}
    for _,def in ipairs(P.DEFS) do
        local p=P.procs[def.key]; local c=cfg(def.key)
        lines[#lines+1]=S.L['proc_'..def.key]..': '..(c.enabled and 'on' or 'off')..', buff '..(c.buffId or table.concat(def.ids,','))
            ..(p.failed and (' | error: '..tostring(p.error)) or p.native and ' | ready' or '')
    end
    S.print(table.concat(lines,'  '))
    S.print(S.L.procHelp)
end
