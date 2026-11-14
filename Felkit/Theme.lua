-- Warlock All-in-One visual language: one palette, one icon catalogue and a small widget
-- kit shared by the settings window, the first-launch assistant and the
-- in-world frames. Plain textures only: no BackdropTemplate callbacks, so the
-- same helpers are safe next to geometry owned by native aura containers.
local addon,S=...
local T={}; S.Theme=T
local WHITE='Interface\\Buttons\\WHITE8X8'
T.white=WHITE
T.c={
    bg={0.039,0.031,0.059,0.97},      -- window
    side={0.055,0.043,0.082,1},       -- sidebar
    card={0.075,0.059,0.106,0.98},    -- card surface
    raised={0.110,0.086,0.153,1},     -- hover / selected surface
    socket={0.027,0.020,0.043,1},     -- icon socket
    line={0.200,0.157,0.275,1},       -- hairlines
    lineSoft={0.145,0.114,0.200,1},
    accent={0.643,0.400,0.988,1},     -- fel-violet accent
    accentDim={0.333,0.192,0.529,1},
    fel={0.475,0.878,0.388,1},        -- "on" / success
    gold={1,0.812,0.384,1},
    danger={0.957,0.392,0.333,1},
    text={0.945,0.925,0.984,1},
    muted={0.682,0.655,0.765,1},
    faint={0.451,0.424,0.525,1},
    track={0.160,0.129,0.212,1},
}
-- Icon catalogue. A string is a client texture path; {spell=id} borrows the
-- game's own icon for that spell, so warlock concepts show warlock art.
local function I(name) return 'Interface\\Icons\\'..name end
T.I={
    warlock=I'ClassIcon_Warlock', -- the game's warlock class icon (minimap, title bars)
    soul=I'Spell_Shadow_SoulGem', dots=I'Spell_Shadow_AbominationExplosion', kit=I'INV_Stone_04',
    shards=I'INV_Misc_Gem_Amethyst_02', nightfall=I'Spell_Shadow_Twilight', grimoire=I'INV_Misc_Book_06',
    channels=I'Spell_Shadow_LifeDrain02', general=I'INV_Misc_Gear_01',
    eye={spell=126},            -- Eye of Kilrogg: previews and test bars
    reveal={spell=132},         -- Detect Invisibility: which enemies are listed
    target=I'Ability_Hunter_SniperShot', pet={spell=688}, crowd={spell=5740},
    style={spell=706},          -- Demon Armor: card skin
    timer=I'Spell_Nature_TimeStop', clock=I'INV_Misc_PocketWatch_01', ticks=I'Spell_Nature_Lightning',
    warning={spell=603},        -- Curse of Doom: the end of a countdown
    tracked={spell=980}, drain={spell=689}, health={spell=755}, tongues={spell=1714},
    move=I'Ability_Hunter_Pathfinding', size=I'INV_Misc_Spyglass_03', lock=I'INV_Misc_Key_03',
    engine=I'Trade_Engineering', note=I'INV_Misc_Note_01', help=I'INV_Misc_QuestionMark', book=I'INV_Misc_Book_09',
    sound=I'Ability_Warrior_BattleShout', proc={spell=17941}, map=I'INV_Misc_Map_01', opacity=I'Spell_Shadow_Shadowform',
    reset=I'Spell_Nature_Reincarnation', bag=I'INV_Misc_Bag_10', burn={spell=17877}, summon={spell=698},
    search=I'INV_Misc_Spyglass_02',
}
function T.font() return S.font and S.font() or STANDARD_TEXT_FONT or 'Fonts\\FRIZQT__.TTF' end
function T.rgb(c,a) return c[1],c[2],c[3],a or c[4] or 1 end
function T.text(parent,size,color,flags)
    local f=parent:CreateFontString(nil,'OVERLAY','GameFontNormal')
    -- A missing alphabet font falls back to the client font rather than no font.
    if f:SetFont(T.font(),size or 12,flags or '')==false then f:SetFont(STANDARD_TEXT_FONT or 'Fonts\\FRIZQT__.TTF',size or 12,flags or '') end
    f:SetTextColor(T.rgb(color or T.c.text)); f:SetJustifyH('LEFT')
    return f
end
-- Background + 1px border built from textures; recolor with T.paint.
function T.skin(f,bg,border,layer)
    if not f.sfBg then
        f.sfBg=f:CreateTexture(nil,layer or 'BACKGROUND'); f.sfBg:SetAllPoints()
        f.sfEdges={}
        for i,pts in ipairs({{'TOPLEFT','TOPRIGHT'},{'BOTTOMLEFT','BOTTOMRIGHT'},{'TOPLEFT','BOTTOMLEFT'},{'TOPRIGHT','BOTTOMRIGHT'}}) do
            local t=f:CreateTexture(nil,'BORDER')
            t:SetPoint(pts[1],f,pts[1],0,0); t:SetPoint(pts[2],f,pts[2],0,0)
            if i<3 then t:SetHeight(1) else t:SetWidth(1) end
            f.sfEdges[i]=t
        end
    end
    T.paint(f,bg,border); return f
end
function T.paint(f,bg,border)
    if bg and f.sfBg then f.sfBg:SetColorTexture(T.rgb(bg)) end
    if border and f.sfEdges then for _,t in ipairs(f.sfEdges) do t:SetColorTexture(T.rgb(border)) end end
end
function T.rule(parent,width,color)
    local t=parent:CreateTexture(nil,'ARTWORK'); t:SetSize(width or 100,1)
    t:SetColorTexture(T.rgb(color or T.c.lineSoft)); return t
end
-- Soft vertical sheen (gradient when available, flat tint otherwise).
local function sheen(t,alpha)
    t:SetColorTexture(1,1,1,1)
    if not (CreateColor and pcall(t.SetGradient,t,'VERTICAL',CreateColor(1,1,1,0),CreateColor(1,1,1,alpha))) then
        t:SetColorTexture(1,1,1,alpha*0.5)
    end
end
function T.resolveIcon(spec)
    if type(spec)=='table' and spec.spell then return select(2,S.API.spell(spec.spell)) end
    return spec
end
-- A missing file falls back to the question mark instead of an empty square.
function T.setIcon(t,spec)
    local texture=T.resolveIcon(spec)
    if texture==nil or t:SetTexture(texture)==false then t:SetTexture(134400) end
    -- The seal is round art with its own rim: shown whole, never cropped like game icons.
    if texture==T.LOGO or texture==T.LOGO_SMALL then t:SetTexCoord(0,1,0,1) end
end
function T.icon(parent,spec,size)
    local t=parent:CreateTexture(nil,'ARTWORK'); t:SetSize(size,size)
    t:SetTexCoord(0.08,0.92,0.08,0.92); T.setIcon(t,spec or 134400); return t
end
-- The add-on's seal (Media/logo*.tga): round art with its own rim, shown whole.
T.LOGO='Interface\\AddOns\\'..addon..'\\Media\\logo'
T.LOGO_SMALL='Interface\\AddOns\\'..addon..'\\Media\\logo-small'
T.I.seal=T.LOGO -- the add-on's seal: home menu, home header and home card
function T.logo(parent,size)
    local f=CreateFrame('Frame',nil,parent); f:SetSize(size,size)
    f.icon=f:CreateTexture(nil,'ARTWORK'); f.icon:SetAllPoints()
    f.icon:SetTexture(size<=32 and T.LOGO_SMALL or T.LOGO)
    return f
end
-- Icon set in a dark socket with a thin rim. SetLit(false) greys it out.
function T.badge(parent,spec,size)
    local b=CreateFrame('Frame',nil,parent); b:SetSize(size,size)
    T.skin(b,T.c.socket,T.c.accentDim)
    local inset=size>=28 and 2 or 1
    b.icon=b:CreateTexture(nil,'ARTWORK'); b.icon:SetPoint('TOPLEFT',inset,-inset); b.icon:SetPoint('BOTTOMRIGHT',-inset,inset)
    b.icon:SetTexCoord(0.08,0.92,0.08,0.92); T.setIcon(b.icon,spec)
    b.sheen=b:CreateTexture(nil,'OVERLAY'); b.sheen:SetPoint('TOPLEFT',inset,-inset); b.sheen:SetPoint('TOPRIGHT',-inset,-inset)
    b.sheen:SetHeight(math.max(2,math.floor(size*0.4))); sheen(b.sheen,0.10)
    function b:SetIcon(s) T.setIcon(self.icon,s) end
    function b:SetLit(on)
        on=on~=false
        T.paint(self,nil,on and T.c.accent or T.c.lineSoft)
        self.icon:SetDesaturated(not on); self.icon:SetAlpha(on and 1 or 0.55)
    end
    return b
end
local function tooltip(owner,title,body)
    if not title then return end
    owner:SetScript('OnEnter',function(self)
        if self.sfHover then self.sfHover(self,true) end
        GameTooltip:SetOwner(self,'ANCHOR_RIGHT'); GameTooltip:SetText(title)
        if body then GameTooltip:AddLine(body,0.85,0.82,0.92,true) end
        GameTooltip:Show()
    end)
    owner:SetScript('OnLeave',function(self)
        if self.sfHover then self.sfHover(self,false) end
        GameTooltip:Hide()
    end)
end
T.tooltip=tooltip
-- kind: 'primary' | 'secondary' | 'ghost' | 'danger'. Optional leading icon.
function T.button(parent,label,w,h,onClick,kind,icon)
    local b=CreateFrame('Button',nil,parent); b:SetSize(w or 140,h or 26)
    kind=kind or 'secondary'; b.kind=kind
    T.skin(b)
    b.label=T.text(b,12); b.label:SetJustifyH('CENTER'); b.label:SetText(label or '')
    if icon then
        local size=math.max(12,math.min(18,(h or 26)-10))
        b.label:SetPoint('CENTER',math.floor((size+6)/2),0)
        b.icon=T.icon(b,icon,size); b.icon:SetPoint('RIGHT',b.label,'LEFT',-6,0)
    else b.label:SetPoint('CENTER',0,0) end
    if kind=='primary' then
        b.sheen=b:CreateTexture(nil,'ARTWORK'); b.sheen:SetPoint('TOPLEFT',1,-1); b.sheen:SetPoint('TOPRIGHT',-1,-1)
        b.sheen:SetHeight(math.floor((h or 26)/2)); sheen(b.sheen,0.08)
    end
    function b:Refresh()
        local c=T.c; local on=self.enabled~=false; local hot=self.hot and on
        if self.kind=='primary' then
            T.paint(self,hot and {0.42,0.25,0.66,1} or c.accentDim,c.accent)
            self.label:SetTextColor(T.rgb(on and c.text or c.faint))
        elseif self.kind=='danger' then
            T.paint(self,hot and {0.30,0.10,0.10,1} or {0.18,0.07,0.08,1},c.danger)
            self.label:SetTextColor(T.rgb(on and {1,0.8,0.78,1} or c.faint))
        elseif self.kind=='ghost' then
            T.paint(self,hot and c.raised or {0,0,0,0},hot and c.line or {0,0,0,0})
            self.label:SetTextColor(T.rgb(on and (hot and c.text or c.muted) or c.faint))
        else
            T.paint(self,hot and c.raised or c.card,hot and c.accent or c.line)
            self.label:SetTextColor(T.rgb(on and c.text or c.faint))
        end
        if self.icon then self.icon:SetDesaturated(not on); self.icon:SetAlpha(on and 1 or 0.5) end
    end
    b.sfHover=function(self,hot) self.hot=hot; self:Refresh() end
    b:SetScript('OnEnter',function(self) self.sfHover(self,true) end)
    b:SetScript('OnLeave',function(self) self.sfHover(self,false) end)
    b:SetScript('OnClick',function(_,...) if b.enabled~=false and onClick then onClick(b,...) end end)
    function b:SetLabel(text) self.label:SetText(text) end
    function b:SetActive(on) self.enabled=on~=false; self:Refresh() end
    b:Refresh(); return b
end
-- Pill switch. get/set operate on any value; the switch reads get() on Sync.
function T.switch(parent,get,set)
    local s=CreateFrame('Button',nil,parent); s:SetSize(40,20)
    T.skin(s,T.c.track,T.c.line,'ARTWORK')
    s.knob=s:CreateTexture(nil,'OVERLAY'); s.knob:SetSize(14,14)
    function s:Sync()
        local on=get()==true; local c=T.c; self.on=on
        T.paint(self,on and c.accentDim or c.track,on and c.accent or c.line)
        self.knob:SetColorTexture(T.rgb(on and c.text or c.faint))
        self.knob:ClearAllPoints(); self.knob:SetPoint(on and 'RIGHT' or 'LEFT',self,on and 'RIGHT' or 'LEFT',on and -3 or 3,0)
        self:SetAlpha(self.enabled==false and 0.4 or 1)
    end
    s:SetScript('OnClick',function() if s.enabled~=false then set(not s.on); s:Sync() end end)
    function s:SetActive(on) self.enabled=on~=false; self:Sync() end
    s:Sync(); return s
end
-- Full-width row: optional icon, title, optional help line, switch on the
-- right. The whole row toggles and lights up under the cursor; the icon is in
-- colour while the option is on.
function T.toggleRow(parent,width,title,help,get,set,icon)
    local r=CreateFrame('Button',nil,parent); r:SetWidth(width)
    r.hl=r:CreateTexture(nil,'BACKGROUND'); r.hl:SetPoint('TOPLEFT',-6,3); r.hl:SetPoint('BOTTOMRIGHT',6,-3)
    r.hl:SetColorTexture(T.rgb(T.c.raised,0.6)); r.hl:Hide()
    local x=0
    if icon then r.icon=T.badge(r,icon,24); r.icon:SetPoint('TOPLEFT',0,0); x=34 end
    r.title=T.text(r,12); r.title:SetPoint('TOPLEFT',x,-3); r.title:SetWidth(width-56-x); r.title:SetText(title)
    local h=r.title:GetStringHeight()+6
    if help then
        r.help=T.text(r,11,T.c.muted); r.help:SetPoint('TOPLEFT',x,-h); r.help:SetWidth(width-56-x); r.help:SetText(help)
        r.help:SetWordWrap(true)
        h=h+r.help:GetStringHeight()+4
    end
    r:SetHeight(math.max(icon and 26 or 24,h+4))
    r.switch=T.switch(r,get,set); r.switch:SetPoint('TOPRIGHT',0,-2)
    r:SetScript('OnClick',function() r.switch:Click() end)
    r.sfHover=function(self,hot) self.hl:SetShown(hot==true and self.switch.enabled~=false) end
    r:SetScript('OnEnter',function(self) self.sfHover(self,true) end)
    r:SetScript('OnLeave',function(self) self.sfHover(self,false) end)
    function r:Sync()
        self.switch:Sync(); local on=self.switch.enabled~=false
        self.title:SetTextColor(T.rgb(on and T.c.text or T.c.faint))
        if self.icon then self.icon:SetLit(on and self.switch.on) end
    end
    function r:SetActive(on) self.switch:SetActive(on); self:Sync() end
    return r
end
-- Small drawn pictograms for visual choices: rectangles {x,y,w,h} in an 18x13 box.
T.GLYPHS={
    bars={{0,0,18,3},{0,-5,14,3},{0,-10,9,3}},
    icons={{0,-1,5,5},{6,-1,5,5},{12,-1,5,5},{0,-7,5,5},{6,-7,5,5}},
    cards={{0,0,18,1},{0,-12,18,1},{0,0,1,13},{17,0,1,13},{3,-3,12,2},{3,-7,8,2}},
    compact={{0,-1,18,3},{0,-5,18,3},{0,-9,18,3}},
    clean={{0,-3,18,1},{0,-7,14,1},{0,-11,10,1}},
    same={{0,-2,18,3},{0,-8,18,3}},
    proportional={{0,-2,18,3},{0,-8,10,3}},
    circle={{6,0,6,3},{0,-5,3,3},{15,-5,3,3},{6,-10,6,3}},
    horizontal={{0,-5,4,4},{5,-5,4,4},{10,-5,4,4},{15,-5,3,4}},
    vertical={{7,0,4,3},{7,-5,4,3},{7,-10,4,3}},
    grid={{2,-1,6,5},{10,-1,6,5},{2,-7,6,5},{10,-7,6,5}},
    free={{0,0,4,4},{12,-2,4,4},{5,-9,4,4}},
}
function T.glyph(parent,name)
    local g=CreateFrame('Frame',nil,parent); g:SetSize(18,13); g.parts={}
    for _,r in ipairs(T.GLYPHS[name] or {}) do
        local t=g:CreateTexture(nil,'ARTWORK'); t:SetPoint('TOPLEFT',r[1],r[2]); t:SetSize(r[3],r[4])
        g.parts[#g.parts+1]=t
    end
    function g:Paint(c,a) for _,t in ipairs(self.parts) do t:SetColorTexture(T.rgb(c,a)) end end
    g:Paint(T.c.muted); return g
end
-- Segmented control. options={{value=..,label=..,tip=..,icon=..|glyph=..|swatch={r,g,b}},...}
-- Visuals sit before the label; the selected choice gets an accent underline.
function T.segmented(parent,width,options,get,set,height)
    local g=CreateFrame('Frame',nil,parent); g:SetSize(width,height or 28)
    T.skin(g,T.c.bg,T.c.line)
    g.items={}
    local w=(width-2)/#options
    for i,o in ipairs(options) do
        local b=CreateFrame('Button',nil,g); b:SetSize(w,(height or 28)-2)
        b:SetPoint('TOPLEFT',1+(i-1)*w,-1)
        b.bg=b:CreateTexture(nil,'ARTWORK'); b.bg:SetAllPoints()
        b.under=b:CreateTexture(nil,'OVERLAY'); b.under:SetPoint('BOTTOMLEFT',0,0); b.under:SetPoint('BOTTOMRIGHT',0,0); b.under:SetHeight(2)
        b.under:SetColorTexture(T.rgb(T.c.accent))
        b.label=T.text(b,11); b.label:SetJustifyH('CENTER'); b.label:SetText(o.label)
        local vis,vw
        if o.icon then vis=T.icon(b,o.icon,16); vw=16
        elseif o.glyph then vis=T.glyph(b,o.glyph); b.glyph=vis; vw=18
        elseif o.swatch then
            vis=CreateFrame('Frame',nil,b); vis:SetSize(12,12); T.skin(vis,{o.swatch[1],o.swatch[2],o.swatch[3],1},{0,0,0,1}); vw=12
        end
        if vis then
            b.label:SetPoint('CENTER',math.floor((vw+6)/2),0); vis:SetPoint('RIGHT',b.label,'LEFT',-6,0); b.vis=vis
        else b.label:SetPoint('CENTER') end
        b.value=o.value
        b:SetScript('OnClick',function() if g.enabled~=false then set(o.value); g:Sync() end end)
        tooltip(b,o.tip and o.label,o.tip)
        b.sfHover=function(self,hot) self.hot=hot; g:Sync() end
        if not o.tip then
            b:SetScript('OnEnter',function(self) self.sfHover(self,true) end)
            b:SetScript('OnLeave',function(self) self.sfHover(self,false) end)
        end
        g.items[i]=b
    end
    function g:Sync()
        local v=get()
        for _,b in ipairs(self.items) do
            local on=b.value==v
            b.bg:SetColorTexture(T.rgb(on and T.c.accentDim or (b.hot and T.c.raised or {0,0,0,0})))
            b.label:SetTextColor(T.rgb(on and T.c.text or T.c.muted))
            b.under:SetShown(on)
            if b.glyph then b.glyph:Paint(on and T.c.text or T.c.muted) end
            if b.vis then b.vis:SetAlpha((on or b.hot) and 1 or 0.65) end
        end
        self:SetAlpha(self.enabled==false and 0.45 or 1)
    end
    function g:SetActive(on) self.enabled=on~=false; self:Sync() end
    g:Sync(); return g
end
-- Labelled slider with live value, minus/plus nudges, a flat track and an
-- optional icon before the title.
function T.slider(parent,width,title,lo,hi,step,get,set,format,icon)
    local r=CreateFrame('Frame',nil,parent); r:SetSize(width,46)
    local x=0
    if icon then r.icon=T.icon(r,icon,16); r.icon:SetPoint('TOPLEFT',0,0); x=22 end
    r.title=T.text(r,12); r.title:SetPoint('TOPLEFT',x,-2); r.title:SetWidth(width-80-x); r.title:SetText(title)
    -- The value doubles as a precise numeric entry (Enter applies, Escape cancels).
    local e=CreateFrame('EditBox',nil,r); r.value=e
    e:SetSize(76,18); e:SetPoint('TOPRIGHT',0,0); e:SetAutoFocus(false); e:SetMaxLetters(9); e:EnableMouse(true)
    e:SetFont(T.font(),12,''); e:SetJustifyH('RIGHT'); e:SetTextColor(T.rgb(T.c.gold))
    local s=CreateFrame('Slider',nil,r); r.slider=s
    s:SetOrientation('HORIZONTAL'); s:SetPoint('TOPLEFT',22,-24); s:SetSize(width-44,14)
    s:SetMinMaxValues(lo,hi); s:SetValueStep(step); s:SetObeyStepOnDrag(true)
    s.track=s:CreateTexture(nil,'BACKGROUND'); s.track:SetPoint('LEFT'); s.track:SetPoint('RIGHT'); s.track:SetHeight(4)
    s.track:SetColorTexture(T.rgb(T.c.track))
    s:SetThumbTexture(WHITE)
    local thumb=s:GetThumbTexture()
    if thumb then thumb:SetSize(10,14); thumb:SetVertexColor(T.rgb(T.c.accent)) end
    local function fmt(v) if format then return format(v) end; return tostring(v) end
    local function clamp(v) v=math.max(lo,math.min(hi,lo+math.floor((v-lo)/step+0.5)*step)); return v end
    s:SetScript('OnValueChanged',function(_,v)
        if r.syncing then return end
        v=clamp(v); if not r.value.editing then r.value:SetText(fmt(v)) end
        set(v)
    end)
    local function commit(self)
        local n=tonumber((self:GetText() or ''):match('%-?%d+%.?%d*'))
        self.editing=false
        -- Typed values are kept exactly (between slider steps), within bounds.
        if n and n>=lo and n<=hi and r.enabled~=false then set(n) end
        r:Sync()
    end
    e:SetScript('OnEditFocusGained',function(self) self.editing=true; self:HighlightText() end)
    e:SetScript('OnEnterPressed',function(self) commit(self); self:ClearFocus() end)
    e:SetScript('OnEditFocusLost',function(self) if self.editing then commit(self) end end)
    e:SetScript('OnEscapePressed',function(self) self.editing=false; r:Sync(); self:ClearFocus() end)
    -- No mouse wheel: scrolling the settings must never change a value by accident.
    r.minus=CreateFrame('Button',nil,r); r.minus:SetSize(16,16); r.minus:SetPoint('RIGHT',s,'LEFT',-4,0)
    r.plus=CreateFrame('Button',nil,r); r.plus:SetSize(16,16); r.plus:SetPoint('LEFT',s,'RIGHT',4,0)
    -- Drawn bars, not text: the game fonts have no minus sign.
    for _,pair in ipairs({{r.minus,false,-1},{r.plus,true,1}}) do
        local b=pair[1]
        b.h=b:CreateTexture(nil,'ARTWORK'); b.h:SetSize(8,2); b.h:SetPoint('CENTER'); b.h:SetColorTexture(T.rgb(T.c.muted))
        if pair[2] then b.v=b:CreateTexture(nil,'ARTWORK'); b.v:SetSize(2,8); b.v:SetPoint('CENTER'); b.v:SetColorTexture(T.rgb(T.c.muted)) end
        b:SetScript('OnClick',function() if r.enabled~=false then s:SetValue(clamp(get()+pair[3]*step)) end end)
    end
    function r:Sync()
        self.syncing=true; local v=get(); s:SetValue(v)
        if not self.value.editing then self.value:SetText(fmt(v)) end
        self.minus.atLimit=v<=lo; self.plus.atLimit=v>=hi
        self.minus:SetAlpha(v<=lo and 0.3 or 1); self.plus:SetAlpha(v>=hi and 0.3 or 1)
        self.syncing=false
        self:SetAlpha(self.enabled==false and 0.4 or 1); s:EnableMouse(self.enabled~=false)
    end
    function r:SetActive(on) self.enabled=on~=false; self:Sync() end
    r:Sync(); return r
end
-- Card with optional icon badge, title and subtitle. Content is stacked with
-- card:Add(widget,h); a hairline separates the header from the first control.
function T.card(parent,width,title,subtitle,icon)
    local c=CreateFrame('Frame',nil,parent); c:SetWidth(width)
    T.skin(c,T.c.card,T.c.lineSoft)
    c.stripe=c:CreateTexture(nil,'ARTWORK'); c.stripe:SetPoint('TOPLEFT',1,-1); c.stripe:SetPoint('BOTTOMLEFT',1,1); c.stripe:SetWidth(2)
    c.stripe:SetColorTexture(T.rgb(T.c.accentDim))
    c.inner=width-28; c.y=-14
    local x=14
    if icon and (title or subtitle) then c.badge=T.badge(c,icon,30); c.badge:SetPoint('TOPLEFT',14,-14); x=54 end
    local tw=width-x-14
    if title then
        c.heading=T.text(c,13,T.c.text); c.heading:SetPoint('TOPLEFT',x,c.y-((c.badge and not subtitle) and 7 or 0)); c.heading:SetWidth(tw); c.heading:SetText(title)
        c.y=c.y-c.heading:GetStringHeight()-3
    end
    if subtitle then
        c.sub=T.text(c,11,T.c.muted); c.sub:SetPoint('TOPLEFT',x,c.y); c.sub:SetWidth(tw); c.sub:SetText(subtitle)
        c.sub:SetWordWrap(true)
        c.y=c.y-c.sub:GetStringHeight()-3
    end
    if c.badge then c.y=math.min(c.y,-14-30) end
    if title or subtitle then c.y=c.y-8; c.pendingRule=true end
    local function rule(self)
        if not self.pendingRule then return end
        self.pendingRule=false
        self.rule=T.rule(self,self.inner,T.c.lineSoft); self.rule:SetPoint('TOPLEFT',14,self.y); self.y=self.y-12
    end
    function c:Add(widget,h,gap,x2)
        rule(self)
        widget:ClearAllPoints(); widget:SetPoint('TOPLEFT',self,'TOPLEFT',14+(x2 or 0),self.y)
        self.y=self.y-(h or widget:GetHeight())-(gap or 10)
        self:SetHeight(-self.y+4); return widget
    end
    function c:Note(text,color)
        local f=T.text(self,11,color or T.c.muted); f:SetWidth(self.inner); f:SetWordWrap(true); f:SetText(text)
        return self:Add(f,f:GetStringHeight(),10)
    end
    c:SetHeight(-c.y+6)
    return c
end
-- Vertical page stacker for cards.
function T.stack(parent,width,top)
    local s={parent=parent,width=width,y=top or 0}
    function s:Add(widget,gap)
        widget:ClearAllPoints(); widget:SetPoint('TOPLEFT',self.parent,'TOPLEFT',0,self.y)
        self.y=self.y-widget:GetHeight()-(gap or 12); return widget
    end
    function s:Height() return -self.y end
    return s
end
-- Thin custom scroll area with wheel support. Returns scroll frame and child.
function T.scroll(parent,width,height)
    local sf=CreateFrame('ScrollFrame',nil,parent); sf:SetSize(width,height)
    local child=CreateFrame('Frame',nil,sf); child:SetSize(width-10,height); sf:SetScrollChild(child)
    sf.child=child
    sf.track=sf:CreateTexture(nil,'ARTWORK'); sf.track:SetPoint('TOPRIGHT'); sf.track:SetPoint('BOTTOMRIGHT'); sf.track:SetWidth(3)
    sf.track:SetColorTexture(T.rgb(T.c.lineSoft,0.6))
    sf.bar=sf:CreateTexture(nil,'OVERLAY'); sf.bar:SetWidth(3); sf.bar:SetColorTexture(T.rgb(T.c.accentDim))
    function sf:Range() return math.max(0,(self.contentHeight or 0)-self:GetHeight()) end
    function sf:UpdateBar()
        local range=self:Range(); local h=self:GetHeight()
        self.bar:SetShown(range>0); self.track:SetShown(range>0)
        if range>0 then
            local size=math.max(24,h*h/(h+range))
            local offset=(h-size)*((self.offset or 0)/range)
            self.bar:ClearAllPoints(); self.bar:SetPoint('TOPRIGHT',self,'TOPRIGHT',0,-offset); self.bar:SetHeight(size)
        end
    end
    function sf:SetContentHeight(h)
        self.contentHeight=h; child:SetHeight(math.max(h,1))
        self.offset=math.min(self.offset or 0,self:Range()); self:SetVerticalScroll(self.offset); self:UpdateBar()
    end
    function sf:ScrollTo(v) self.offset=math.max(0,math.min(self:Range(),v)); self:SetVerticalScroll(self.offset); self:UpdateBar() end
    sf:EnableMouseWheel(true)
    sf:SetScript('OnMouseWheel',function(self,delta) self:ScrollTo((self.offset or 0)-delta*48) end)
    return sf,child
end
-- A grip in the bottom-right corner that resizes the window. The size is saved
-- next to its position. live runs while dragging, done once it is let go.
function T.resizable(f,key,w,h,minW,minH,live,done)
    if f.SetResizable then f:SetResizable(true) end
    local function bounds()
        local maxW=math.max(minW,math.floor(UIParent:GetWidth()-20))
        local maxH=math.max(minH,math.floor(UIParent:GetHeight()-20))
        return maxW,maxH
    end
    local maxW,maxH=bounds()
    if f.SetResizeBounds then f:SetResizeBounds(minW,minH,maxW,maxH)
    else
        if f.SetMinResize then f:SetMinResize(minW,minH) end
        if f.SetMaxResize then f:SetMaxResize(maxW,maxH) end
    end
    local saved=S.db and S.db.positions[key..'Size']
    if saved then f:SetSize(math.max(minW,math.min(maxW,saved.x)),math.max(minH,math.min(maxH,saved.y))) end
    local g=CreateFrame('Button',nil,f); g:SetSize(16,16); g:SetPoint('BOTTOMRIGHT',-3,3)
    g:SetFrameLevel(f:GetFrameLevel()+20); f.grip=g
    g:SetNormalTexture('Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up')
    g:SetPushedTexture('Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down')
    g:SetHighlightTexture('Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight')
    g:RegisterForClicks('RightButtonUp')
    local function finish()
        S.db.positions[key..'Size']={x=math.floor(f:GetWidth()+.5),y=math.floor(f:GetHeight()+.5)}
        f.savePlace()
        if done then done() end
    end
    g:SetScript('OnMouseDown',function(_,button)
        if button~='LeftButton' then return end
        f.sizing=true; f:StartSizing('BOTTOMRIGHT')
    end)
    g:SetScript('OnMouseUp',function(_,button)
        if button~='LeftButton' or not f.sizing then return end
        f.sizing=false; f:StopMovingOrSizing(); finish()
    end)
    g:SetScript('OnClick',function() f:SetSize(w,h); finish() end)
    g:SetScript('OnEnter',function(self)
        GameTooltip:SetOwner(self,'ANCHOR_RIGHT'); GameTooltip:SetText(S.L.resizeHint or '',1,1,1,1,true); GameTooltip:Show()
    end)
    g:SetScript('OnLeave',function() GameTooltip:Hide() end)
    f:HookScript('OnSizeChanged',function() if live then live() end end)
end
-- Draggable window chrome with title bar and close button.
function T.window(name,w,h,title,key)
    local f=CreateFrame('Frame',name,UIParent); f:SetSize(w,h); f:SetClampedToScreen(true)
    f:SetFrameStrata('DIALOG'); f:EnableMouse(true); f:SetMovable(true); f:SetToplevel(true)
    T.skin(f,T.c.bg,T.c.line)
    f.titleBar=CreateFrame('Frame',nil,f); f.titleBar:SetPoint('TOPLEFT',1,-1); f.titleBar:SetPoint('TOPRIGHT',-1,-1); f.titleBar:SetHeight(34)
    f.titleBar.bg=f.titleBar:CreateTexture(nil,'BACKGROUND'); f.titleBar.bg:SetAllPoints(); f.titleBar.bg:SetColorTexture(T.rgb(T.c.side))
    f.titleBar.rule=f.titleBar:CreateTexture(nil,'ARTWORK'); f.titleBar.rule:SetPoint('BOTTOMLEFT'); f.titleBar.rule:SetPoint('BOTTOMRIGHT'); f.titleBar.rule:SetHeight(1)
    f.titleBar.rule:SetColorTexture(T.rgb(T.c.line))
    -- Accent glow along the top edge.
    f.titleBar.glow=f.titleBar:CreateTexture(nil,'ARTWORK'); f.titleBar.glow:SetPoint('TOPLEFT'); f.titleBar.glow:SetPoint('TOPRIGHT'); f.titleBar.glow:SetHeight(2)
    f.titleBar.glow:SetColorTexture(T.rgb(T.c.accentDim))
    f.logo=T.badge(f.titleBar,T.I.warlock,22); f.logo:SetPoint('LEFT',8,0)
    f.title=T.text(f.titleBar,14,T.c.text); f.title:SetPoint('LEFT',f.logo,'RIGHT',8,0); f.title:SetText(title or '')
    f.close=T.button(f.titleBar,'×',26,22,function() f:Hide() end,'ghost'); f.close:SetPoint('RIGHT',-6,0)
    f.close.label:SetFont(T.font(),16,'')
    f.titleBar:EnableMouse(true); f.titleBar:RegisterForDrag('LeftButton')
    f.titleBar:SetScript('OnDragStart',function() if not InCombatLockdown() then f:StartMoving() end end)
    function f.savePlace()
        if not key or not S.db then return end
        local x,y=f:GetCenter(); local px,py=UIParent:GetCenter()
        local ratio=f:GetEffectiveScale()/UIParent:GetEffectiveScale()
        S.db.positions[key]={x=x-px/ratio,y=y-py/ratio}
        f:ClearAllPoints(); f:SetPoint('CENTER',UIParent,'CENTER',S.db.positions[key].x,S.db.positions[key].y)
    end
    f.titleBar:SetScript('OnDragStop',function() f:StopMovingOrSizing(); f.savePlace() end)
    if key and S.db and S.db.positions[key] then
        local p=S.db.positions[key]; f:SetPoint('CENTER',UIParent,'CENTER',p.x,p.y)
    else f:SetPoint('CENTER') end
    if UISpecialFrames and name then table.insert(UISpecialFrames,name) end
    return f
end
-- Language picker: game language plus every bundled translation. Each native
-- name is drawn with the font of its own alphabet. get/set work on codes
-- ('auto', 'en', 'fr'...). Labels follow S.L at every Sync.
-- Tiles to pick one value: an icon or a preview image, a name and an optional
-- line below. options = {{value,label,sub,icon,image={path,coords,tint}}}.
function T.choiceGrid(parent,width,options,get,set,cols,tileH)
    cols=cols or 3; tileH=tileH or 40
    local gap=6
    local g=CreateFrame('Frame',nil,parent)
    local tileW=math.floor((width-(cols-1)*gap)/cols)
    local rows=math.ceil(#options/cols)
    g:SetSize(width,rows*tileH+(rows-1)*gap)
    g.items={}
    for i,o in ipairs(options) do
        local b=CreateFrame('Button',nil,g); b:SetSize(tileW,tileH)
        b:SetPoint('TOPLEFT',((i-1)%cols)*(tileW+gap),-math.floor((i-1)/cols)*(tileH+gap))
        T.skin(b,T.c.card,T.c.lineSoft)
        local chip=tileH-10
        if o.image then
            local frame=CreateFrame('Frame',nil,b); frame:SetSize(math.floor(chip*(o.image[4] or 1)),chip); T.skin(frame,{0.03,0.02,0.06,1},T.c.lineSoft)
            frame:SetPoint('LEFT',5,0)
            local t=frame:CreateTexture(nil,'ARTWORK'); t:SetPoint('TOPLEFT',2,-2); t:SetPoint('BOTTOMRIGHT',-2,2)
            t:SetTexture(o.image[1]); if o.image[2] then t:SetTexCoord(unpack(o.image[2])) end
            if o.image[3] then t:SetVertexColor(unpack(o.image[3])) end
            if t.SetBlendMode then pcall(t.SetBlendMode,t,'ADD') end
            b.vis=frame
        else
            b.vis=T.icon(b,o.icon,chip); b.vis:SetPoint('LEFT',5,0)
        end
        local left=(o.image and math.floor(chip*(o.image[4] or 1)) or chip)+11
        b.name=T.text(b,12); b.name:SetWidth(tileW-left-5); b.name:SetText(o.label)
        if o.sub then
            b.name:SetPoint('TOPLEFT',left,-math.floor(tileH/2)+12)
            b.sub=T.text(b,10,T.c.muted); b.sub:SetPoint('TOPLEFT',left,-math.floor(tileH/2)-1)
            b.sub:SetWidth(tileW-left-5); b.sub:SetText(o.sub)
        else b.name:SetPoint('LEFT',left,0) end
        b.value=o.value
        b:SetScript('OnClick',function() if g.enabled~=false then set(o.value); g:Sync() end end)
        b:SetScript('OnEnter',function(self) self.hot=true; g:Sync() end)
        b:SetScript('OnLeave',function(self) self.hot=false; g:Sync() end)
        g.items[i]=b
    end
    function g:Sync()
        local v=get()
        for _,b in ipairs(self.items) do
            local on=b.value==v
            T.paint(b,on and T.c.raised or (b.hot and T.c.card or T.c.bg),on and T.c.accent or T.c.lineSoft)
            b.name:SetTextColor(T.rgb(on and T.c.text or T.c.muted))
            b.vis:SetAlpha((on or b.hot) and 1 or 0.7)
        end
        self:SetAlpha(self.enabled==false and 0.45 or 1)
    end
    function g:SetActive(on) self.enabled=on~=false; self:Sync() end
    g:Sync(); return g
end
function T.languageGrid(parent,width,get,set,cols,tileH)
    cols=cols or 3; tileH=tileH or 48
    local gap=8
    local g=CreateFrame('Frame',nil,parent)
    local list={{code='auto'}}
    for _,l in ipairs(S.LANGUAGES) do list[#list+1]=l end
    local tileW=math.floor((width-(cols-1)*gap)/cols)
    local rows=math.ceil(#list/cols)
    g:SetSize(width,rows*tileH+(rows-1)*gap)
    g.items={}
    local function setFont(f,code,size)
        if f:SetFont(S.fontFor(code),size,'')==false then f:SetFont(T.font(),size,'') end
    end
    for i,l in ipairs(list) do
        local b=CreateFrame('Button',nil,g); b:SetSize(tileW,tileH)
        b:SetPoint('TOPLEFT',((i-1)%cols)*(tileW+gap),-math.floor((i-1)/cols)*(tileH+gap))
        T.skin(b,T.c.card,T.c.lineSoft)
        local chip=tileH-16
        if l.code=='auto' then b.badge=T.badge(b,T.I.tongues,chip)
        else
            b.badge=CreateFrame('Frame',nil,b); b.badge:SetSize(chip,chip); T.skin(b.badge,T.c.socket,T.c.accentDim)
            b.chip=T.text(b.badge,l.code=='zh' and 15 or 12,T.c.gold); b.chip:SetPoint('CENTER',0,0)
            setFont(b.chip,l.code,l.code=='zh' and 15 or 12); b.chip:SetText(l.chip)
        end
        b.badge:SetPoint('LEFT',8,0)
        b.name=T.text(b,12); b.name:SetPoint('TOPLEFT',chip+16,-math.floor(tileH/2)+13); b.name:SetWidth(tileW-chip-24)
        b.sub=T.text(b,10,T.c.muted); b.sub:SetPoint('TOPLEFT',chip+16,-math.floor(tileH/2)-1); b.sub:SetWidth(tileW-chip-24)
        if l.code~='auto' then setFont(b.name,l.code,12); b.name:SetText(l.native) end
        b.code=l.code
        b:SetScript('OnClick',function() if g.enabled~=false then set(l.code); g:Sync() end end)
        b:SetScript('OnEnter',function(self) self.hot=true; g:Sync() end)
        b:SetScript('OnLeave',function(self) self.hot=false; g:Sync() end)
        g.items[i]=b
    end
    function g:Sync()
        local v=get() or 'auto'
        local client=S.languageInfo[S.clientLanguage()]
        for _,b in ipairs(self.items) do
            local on=b.code==v
            T.paint(b,on and T.c.raised or (b.hot and T.c.card or T.c.bg),on and T.c.accent or T.c.lineSoft)
            if b.code=='auto' then
                b.name:SetText(S.L.languageAuto)
                b.sub:SetText(string.format(S.L.languageAutoHelp,S.L['lang_'..client.code] or client.native))
                b.badge:SetLit(on or b.hot)
            else
                b.sub:SetText(S.L['lang_'..b.code])
                b.badge:SetAlpha((on or b.hot) and 1 or 0.7)
            end
            b.name:SetTextColor(T.rgb(on and T.c.text or T.c.muted))
        end
        self:SetAlpha(self.enabled==false and 0.45 or 1)
    end
    function g:SetActive(on) self.enabled=on~=false; self:Sync() end
    g:Sync(); return g
end
