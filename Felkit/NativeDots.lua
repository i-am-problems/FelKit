-- Enemy DoTs rendered by Blizzard's secure AuraContainer, one per enemy card.
--
-- Geometry rules (0.4.38 failed on the first engaged enemy because a card and
-- its container were anchored to each other, a cycle WoW rejects):
--   head(n)       -> anchored below the previous card (public offsets)
--   container(n)  -> anchored below head(n); sized by the engine (secret)
--   root(n)       -> card background from head(n) down to container(n)
-- Nothing anchors back up that chain, every frame anchored to a container uses
-- DisableUntrustedLayoutScriptsTemplate, and no geometry is ever read back.
--
-- Profiles: a DoT's tick count and total duration are known from the catalogue
-- for each spell ID. When ticks, expiry warnings or proportional widths are on,
-- DoTs go to one native group per profile, so every slot knows its spell's
-- timing without reading the aura:
--   * tick marks at i/N of the bar (exact for any remaining time);
--   * an expiry zone clipped to warning/duration of the bar, laid over the fill:
--     once fewer seconds than the threshold remain, the whole fill is in it;
--   * a width proportional to the total duration;
--   * a flash at the fill's edge looping every duration/N seconds from the
--     aura's assignment, i.e. exactly when the edge crosses a tick mark.
-- Sorting by expiration applies within each profile group.
-- 0.5.2's duration-text colour curve is gone: combat display failed with it.
local addon,S=...
local N={rows={},bound=0,failures=0}; S.NativeDots=N
local A,L=S.API,S.L
local layoutTemplate='DisableUntrustedLayoutScriptsTemplate'
local white='Interface\\Buttons\\WHITE8X8'
local PAD=6
-- One native allocation batch (CustomAuraContainerConstants.FrameCreationBatchSize).
local MAX_SLOTS=10
local MIN_SHARE=0.35 -- shortest proportional bar, as a share of the full width
local FLASH=0.35
local function C() return S.Theme and S.Theme.c or {} end
local function rgb(c,a) return c[1],c[2],c[3],a or c[4] or 1 end
local function font() return STANDARD_TEXT_FONT or 'Fonts\\FRIZQT__.TTF' end
local function frame(kind,parent) return CreateFrame(kind,nil,parent,layoutTemplate) end
local function edges(parent,size)
    local list={}
    for _,points in ipairs({{'TOPLEFT','TOPRIGHT'},{'BOTTOMLEFT','BOTTOMRIGHT'},
        {'TOPLEFT','BOTTOMLEFT'},{'TOPRIGHT','BOTTOMRIGHT'}}) do
        local t=parent:CreateTexture(nil,'OVERLAY')
        t:SetPoint(points[1],parent,points[1],0,0); t:SetPoint(points[2],parent,points[2],0,0)
        if #list<2 then t:SetHeight(size) else t:SetWidth(size) end
        list[#list+1]=t
    end
    return list
end
local function colorEdges(list,r,g,b,a) for _,t in ipairs(list) do t:SetColorTexture(r,g,b,a) end end
local function text(parent,size)
    local f=parent:CreateFontString(nil,'OVERLAY','GameFontNormal')
    f:SetFont(font(),size,'OUTLINE')
    f:SetWordWrap(false); f:SetNonSpaceWrap(false); f:SetMaxLines(1)
    f:SetTextColor(0.94,0.92,1); return f
end
local function status(parent)
    local b=frame('StatusBar',parent)
    b:SetStatusBarTexture(white); b:SetMinMaxValues(0,1); b:SetValue(0)
    b.bg=b:CreateTexture(nil,'BACKGROUND'); b.bg:SetAllPoints(); b.bg:SetColorTexture(0.12,0.11,0.16,0.8)
    return b
end
local function secretAuras() return C_Secrets and A.call(C_Secrets.ShouldAurasBeSecret)==true end
local function fontSize(size,h) return math.max(6,math.min(size,h-2)) end
-- Profiles -----------------------------------------------------------------------
-- Tick count and total duration of a spell, or nil when ticks are unknown.
function N.profile(id)
    local t=S.DotTiming and S.DotTiming[id]
    if t and t.count then return t.count,t.duration end
    if S.Ticks and S.Ticks.counts[id] and S.Tracker.channelSupported(id) then
        local spec=S.SpellData and S.SpellData.spells[id]
        local effect=spec and spec.effects and spec.effects[1]
        return S.Ticks.counts[id],effect and effect.duration
    end
end
function N.cadence(id) return (N.profile(id)) end
local function profileKey(count,duration) return duration and ('p'..count..'_'..duration) or ('c'..count) end
N.profileKey=profileKey
local function profiledIDs()
    local ids={}
    for id in pairs(S.DotTiming or {}) do if N.profile(id) then ids[id]=true end end
    for id in pairs(S.Ticks and S.Ticks.counts or {}) do if N.profile(id) then ids[id]=true end end
    return ids
end
-- Sorted, cached list of {key,count,duration}; shortest duration first.
function N.profiles()
    if N.profileList then return N.profileList end
    local byKey,list={},{}
    for id in pairs(profiledIDs()) do
        local count,duration=N.profile(id); local key=profileKey(count,duration)
        if not byKey[key] then byKey[key]={key=key,count=count,duration=duration}; list[#list+1]=byKey[key] end
    end
    table.sort(list,function(a,b)
        local x,y=a.duration or math.huge,b.duration or math.huge
        if x~=y then return x<y end
        return a.count<b.count
    end)
    local ref=0; for _,p in ipairs(list) do if p.duration then ref=math.max(ref,p.duration) end end
    N.profileList=list; N.profileByKey=byKey; N.refDuration=ref>0 and ref or nil
    return list
end
local function groupedMode()
    return S.db.dotLayout~=2 and (S.db.dotTicks or S.db.dotWarnings or S.db.dotDurationMode==2)
end
-- Public metrics shared by the native slots, previews and settings.
function N.metrics()
    local db=S.db
    local inner=math.max(db.width,db.healthWidth+30)
    local card=inner-8
    local gap=db.enemyStyle==1 and 3 or 2
    local m={inner=inner,card=card,gap=gap,icons=db.dotLayout==2,slots=math.max(1,math.min(MAX_SLOTS,db.dotSlots))}
    m.content=card-2*PAD
    if m.icons then
        local size=math.max(18,db.rowHeight+8)
        m.elementWidth=size; m.elementHeight=size
        m.perLine=math.max(1,math.floor((m.content+gap)/(size+gap)))
    else
        m.elementHeight=db.enemyStyle==1 and db.rowHeight or math.max(10,db.rowHeight-4)
        m.elementWidth=m.content
    end
    m.grouped=groupedMode(); m.ticks=m.grouped and db.dotTicks
    m.warn=m.grouped and db.dotWarnings; m.proportional=m.grouped and db.dotDurationMode==2
    return m
end
-- Width of a bar for a known total duration (nil = full width).
function N.barWidth(m,duration)
    if m.icons then return m.elementWidth end
    N.profiles()
    if m.proportional and duration and N.refDuration then
        return math.floor(m.content*math.max(MIN_SHARE,math.min(1,duration/N.refDuration))+0.5)
    end
    return m.content
end
local function layout(m,width)
    return {elementWidth=width or m.elementWidth,elementHeight=m.elementHeight,elementSpacing=m.gap,lineSpacing=m.gap,groupSpacing=m.gap}
end
local function signature()
    local db=S.db
    return table.concat({db.width,db.healthWidth,db.rowHeight,db.fontSize,db.enemyStyle,
        tostring(db.enemyBackground),db.dotLayout,db.dotSlots,tostring(db.dotTicks),db.tickColor,db.tickAlpha,db.tickWidth,
        tostring(db.dotWarnings),db.dotWarning,tostring(db.dotPulse),db.dotDurationMode},':')
end
local function filterKey() return S.db.dotFilter..':'..tostring(S.db.dotChannels) end
local function catalogue()
    local ids={}
    for id,entry in pairs(S.Data.spells) do
        if entry.periodic or S.Data.dotGroups[id] or (S.db.dotChannels and S.Tracker.channelSupported(id)) then ids[id]=true end
    end
    for id in pairs(S.Data.dotGroups) do ids[id]=true end
    if S.db.dotChannels then for _,id in ipairs({689,1120,5138,1316697}) do ids[id]=true end end
    return ids
end
local function drains()
    local ex={}
    for id in pairs(S.Data.dotFamilies) do if S.Tracker.channelSupported(id) then ex[id]=true end end
    for _,id in ipairs({689,1120,5138,1316697}) do ex[id]=true end
    return ex
end
-- Default: every harmful aura the player (or pet) applied, selected by the
-- client's PLAYER filter. Optional: catalogue DoTs only. Drains by identity.
function N.filters(key)
    local f={isFromPlayerOrPlayerPet=true}
    N.profiles()
    local p=key and N.profileByKey[key]
    if p then
        local ids={}
        for id in pairs(profiledIDs()) do
            local count,duration=N.profile(id)
            if profileKey(count,duration)==key then ids[id]=true end
        end
        if not S.db.dotChannels then for id in pairs(drains()) do ids[id]=nil end end
        f.includeSpellIDs=ids
    elseif key=='tother' then
        local timed=profiledIDs()
        if S.db.dotFilter==2 then
            local ids=catalogue(); for id in pairs(timed) do ids[id]=nil end
            f.includeSpellIDs=ids
        else
            if not S.db.dotChannels then for id in pairs(drains()) do timed[id]=true end end
            f.excludeSpellIDs=timed
        end
    elseif S.db.dotFilter==2 then f.includeSpellIDs=catalogue()
    elseif not S.db.dotChannels then f.excludeSpellIDs=drains() end
    return f
end
-- Tick style and warning colours -------------------------------------------------
local TICK_COLORS={{1,1,1},{1,0.82,0.3},{0,0,0},{0.75,0.55,1}}
function N.tickColor()
    local c=TICK_COLORS[S.db.tickColor] or TICK_COLORS[1]
    return c[1],c[2],c[3],S.db.tickAlpha/100
end
local NORMAL,WARN,BRIGHT={0.94,0.92,1},{1,0.45,0.25},{1,0.86,0.45}
N.WARN_FILL={0.90,0.24,0.16,0.96}
-- Expiry warning colour for a public remaining time (previews, retention).
function N.warnColor(left)
    if not S.db.dotWarnings or left>S.db.dotWarning then return NORMAL end
    if S.db.dotPulse and math.floor(left/0.35)%2==1 then return BRIGHT end
    return WARN
end
-- Shared bar dressing (native slots and public bars) ------------------------------
-- Marks, expiry zone and tick flash are laid over the fill texture; their
-- extents come from the profile only. Write-only, never read back.
local function dress(w,parent)
    w.marks={}
    w.clip=frame('Frame',parent); w.clip:EnableMouse(false)
    if w.clip.SetClipsChildren then w.clip:SetClipsChildren(true) end
    w.warn=w.clip:CreateTexture(nil,'ARTWORK')
    w.flash=parent:CreateTexture(nil,'OVERLAY',nil,2); w.flash:SetColorTexture(1,0.95,1,1); w.flash:SetAlpha(0)
end
local function applyDress(w,m,width,h,count,duration)
    local fill=w.fillTex
    -- Tick marks.
    local r,g,b,a=N.tickColor(); local tw=S.db.tickWidth
    local n=count or 0
    for i=1,math.max(0,n-1) do
        if not w.marks[i] then w.marks[i]=w.markParent:CreateTexture(nil,'ARTWORK',nil,1) end
    end
    for i,mark in ipairs(w.marks) do
        local shown=m.ticks and not m.icons and i<n
        mark:ClearAllPoints()
        if shown then
            mark:SetPoint('TOPLEFT',w.bar,'TOPLEFT',math.floor(width*i/n-tw/2+0.5),0)
            mark:SetSize(tw,h); mark:SetColorTexture(r,g,b,a)
        end
        mark:SetShown(shown)
    end
    -- Expiry zone: the last `dotWarning` seconds of the bar. The red layer starts
    -- at the fill's edge and is clipped to the zone, so it only exists once the
    -- edge has entered it; the zone then turns from violet to red as time runs.
    local zone=m.warn and not m.icons and duration and duration>0
    w.clip:ClearAllPoints(); w.warn:ClearAllPoints()
    if zone then
        local zw=math.max(1,math.floor(width*math.min(1,S.db.dotWarning/duration)+0.5))
        w.clip:SetPoint('TOPLEFT',w.bar,'TOPLEFT',0,0); w.clip:SetPoint('BOTTOMLEFT',w.bar,'BOTTOMLEFT',0,0)
        w.clip:SetWidth(zw)
        w.warn:SetPoint('TOPLEFT',fill,'TOPRIGHT',0,0); w.warn:SetPoint('BOTTOMLEFT',fill,'BOTTOMRIGHT',0,0)
        w.warn:SetWidth(zw)
        w.warn:SetColorTexture(1,1,1,1)
        if not (CreateColor and pcall(w.warn.SetGradient,w.warn,'HORIZONTAL',CreateColor(unpack(N.WARN_FILL)),CreateColor(0.78,0.30,0.55,0.9))) then
            w.warn:SetColorTexture(rgb(N.WARN_FILL))
        end
    end
    w.clip:SetShown(zone and true or false)
    -- Tick flash at the moving edge of the fill.
    w.flash:ClearAllPoints(); w.flash:SetPoint('CENTER',fill,'RIGHT',0,0); w.flash:SetSize(math.max(3,math.floor(h*0.35)),h+4)
end
-- Native slots -------------------------------------------------------------------
local function configure(w,m)
    local db,c=S.db,C()
    local h=m.elementHeight
    local width=N.barWidth(m,w.duration)
    w.slot:SetSize(m.icons and m.elementWidth or width,h)
    w.icon:ClearAllPoints(); w.bar:ClearAllPoints(); w.name:ClearAllPoints(); w.time:ClearAllPoints()
    local barWidth
    if m.icons then
        w.icon:SetPoint('TOPLEFT',w.slot,'TOPLEFT',1,-1); w.icon:SetPoint('BOTTOMRIGHT',w.slot,'BOTTOMRIGHT',-1,1)
        w.icon:SetShown(true)
        w.bar:SetPoint('BOTTOMLEFT',w.slot,'BOTTOMLEFT',1,1); w.bar:SetPoint('BOTTOMRIGHT',w.slot,'BOTTOMRIGHT',-1,1)
        w.bar:SetHeight(3)
        -- SpellName's Shown aspect belongs to the engine: hide by alpha only.
        w.name:SetPoint('LEFT',w.slot,'LEFT',0,0); w.name:SetSize(1,1); w.name:SetAlpha(0)
        w.time:SetPoint('CENTER',w.slot,'CENTER',0,1); w.time:SetSize(m.elementWidth,h-4); w.time:SetJustifyH('CENTER')
        w.time:SetFont(font(),math.max(9,math.floor(h*0.40)),'OUTLINE')
        w.frameBg:SetColorTexture(0,0,0,0.65)
        barWidth=m.elementWidth-2
    else
        local left=db.enemyStyle==3 and 0 or h+3
        w.icon:SetPoint('LEFT',w.slot,'LEFT',0,0); w.icon:SetSize(h,h); w.icon:SetShown(db.enemyStyle~=3)
        w.bar:SetPoint('TOPLEFT',w.slot,'TOPLEFT',left,0); w.bar:SetPoint('BOTTOMRIGHT',w.slot,'BOTTOMRIGHT',0,0)
        barWidth=width-left
        w.name:SetPoint('LEFT',w.bar,'LEFT',5,0); w.name:SetPoint('RIGHT',w.bar,'RIGHT',-50,0); w.name:SetHeight(h)
        w.name:SetAlpha(barWidth>=100 and 1 or 0); w.name:SetFont(font(),fontSize(db.fontSize,h),'OUTLINE')
        w.time:SetPoint('RIGHT',w.bar,'RIGHT',-4,0); w.time:SetSize(46,h); w.time:SetJustifyH('RIGHT')
        w.time:SetFont(font(),fontSize(db.fontSize+1,h+1),'OUTLINE')
        w.frameBg:SetColorTexture(0,0,0,0)
    end
    w.bar:SetStatusBarColor(rgb(c.accent or {0.62,0.38,0.95},0.92))
    w.bg:SetColorTexture(0.12,0.10,0.17,db.enemyBackground and 0.85 or 0)
    applyDress(w,m,barWidth,m.icons and 3 or h,w.count,w.duration)
end
local function flashAnimation(w,interval)
    local g=w.flash:CreateAnimationGroup(); g:SetLooping('REPEAT')
    local fade=g:CreateAnimation('Alpha'); fade:SetFromAlpha(0.95); fade:SetToAlpha(0); fade:SetDuration(FLASH); fade:SetOrder(1)
    local rest=g:CreateAnimation('Alpha'); rest:SetFromAlpha(0); rest:SetToAlpha(0); rest:SetDuration(math.max(0.05,interval-FLASH)); rest:SetOrder(2)
    return g
end
local function pulseAnimation(target)
    local g=target:CreateAnimationGroup(); g:SetLooping('BOUNCE')
    local a=g:CreateAnimation('Alpha'); a:SetFromAlpha(0.55); a:SetToAlpha(1); a:SetDuration(0.45)
    return g
end
-- Engine-played cosmetics; any API difference only disables the cosmetic.
local function animations(w,m)
    local slot=w.slot
    if not slot.ClearAuraAssignedAnimations then return end
    pcall(function()
        slot:ClearAuraAssignedAnimations(); slot:ClearAuraShownAnimations()
        if m.ticks and not m.icons and w.flashGroup then slot:AddAuraAssignedAnimation(w.flashGroup) end
        if m.warn and S.db.dotPulse and w.pulseGroup then slot:AddAuraShownAnimation(w.pulseGroup) end
    end)
end
local function initialize(slot,r,count,duration)
    -- Runs BEFORE native access restrictions are applied to the slot.
    slot:EnableMouse(false)
    local w={slot=slot,count=count,duration=duration}
    w.frameBg=slot:CreateTexture(nil,'BACKGROUND'); w.frameBg:SetAllPoints()
    w.icon=slot:CreateTexture(nil,'ARTWORK'); w.icon:SetTexCoord(0.08,0.92,0.08,0.92)
    w.bar=frame('StatusBar',slot); w.bar:SetStatusBarTexture(white); w.bar:SetMinMaxValues(0,1)
    w.fillTex=w.bar:GetStatusBarTexture()
    w.bg=w.bar:CreateTexture(nil,'BACKGROUND'); w.bg:SetAllPoints()
    local overlay=frame('Frame',slot); overlay:SetAllPoints(slot)
    overlay:SetFrameLevel(w.bar:GetFrameLevel()+2); overlay:EnableMouse(false)
    w.markParent=overlay
    dress(w,overlay); w.clip:SetFrameLevel(w.bar:GetFrameLevel()+1)
    w.name=text(overlay,12); w.name:SetJustifyH('LEFT')
    w.time=text(overlay,12)
    if count and duration and count>0 then pcall(function() w.flashGroup=flashAnimation(w,duration/count) end) end
    if duration then pcall(function() w.pulseGroup=pulseAnimation(w.warn) end) end
    configure(w,r.metrics)
    slot:SetIcon(w.icon); slot:SetSpellName(w.name)
    slot:SetDurationBar(w.bar,{direction=1,interpolation=0}); slot:SetDurationText(w.time,{})
    animations(w,r.metrics)
    return w
end
local function addGroup(r,key,count,duration)
    local m=r.metrics
    r.container:AddAuraGroup(key,'HARMFUL|PLAYER',{maxFrameCount=m.slots,sortMethod=5,sortDirection=0,
        candidateFilters=N.filters(key),layout=layout(m,N.barWidth(m,duration)),initializeFrame=function(slot)
            -- securecallfunction may swallow callback errors: keep them visible.
            local ok,w=pcall(initialize,slot,r,count,duration)
            if ok then w.group=key; r.widgets[#r.widgets+1]=w
            else r.initError=tostring(A.public(w) or 'restricted initialization error'):sub(1,250) end
        end})
    assert(not r.initError,r.initError)
    r.groups[#r.groups+1]=key; r.groupDuration[key]=duration
end
local function buildContainer(r)
    local c=CreateFrame('AuraContainer',nil,r.root,'CustomAuraContainerTemplate')
    assert(type(c.AddAuraGroup)=='function' and type(c.SetUnit)=='function','AuraContainer API unavailable')
    r.container=c
    c:SetUnit('none'); c:EnableMouse(false)
    local m=N.metrics(); r.metrics=m; r.widgets={}; r.groups={}; r.groupDuration={}; r.initError=nil
    c:SetFlowLayoutAxis(m.icons and 0 or 1); c:SetFlowLayoutAnchorPoint('TOPLEFT'); c:SetFlowLayoutGrowthDirection(1,-1)
    if type(c.SetFlowLayoutMaximumLineSize)=='function' then c:SetFlowLayoutMaximumLineSize(m.icons and m.content or nil) end
    addGroup(r,'dots')
    assert(#r.widgets>0,'AuraButton initialization did not run')
    r.signature=nil; r.filterKey=filterKey(); r.mode=nil
end
local function container(r)
    local ok,err=pcall(buildContainer,r)
    if not ok then
        -- A half-configured container is never reused; a retry builds a new one.
        if r.container then pcall(r.container.SetUnit,r.container,'none'); r.container:Hide(); r.container=nil end
        error(err,0)
    end
end
local function canGroup(c) return type(c.SetAuraGroupEnabled)=='function' end
-- Out of restrictions only: geometry, profile groups and their enablement.
local function reconfigure(r,m)
    local c=r.container
    r.metrics=m
    local grouped=m.grouped and canGroup(c)
    if grouped and not r.profileGroups then
        for _,p in ipairs(N.profiles()) do addGroup(r,p.key,p.count,p.duration) end
        addGroup(r,'tother'); r.profileGroups=true
    end
    for _,w in ipairs(r.widgets) do configure(w,m); animations(w,m) end
    c:SetFlowLayoutAxis(m.icons and 0 or 1)
    if type(c.SetFlowLayoutMaximumLineSize)=='function' then c:SetFlowLayoutMaximumLineSize(m.icons and m.content or nil) end
    for _,key in ipairs(r.groups) do
        c:SetAuraGroupLayout(key,layout(m,N.barWidth(m,r.groupDuration[key])))
        if type(c.SetAuraGroupMaxFrameCount)=='function' then c:SetAuraGroupMaxFrameCount(key,m.slots) end
        if canGroup(c) then c:SetAuraGroupEnabled(key,(key=='dots')~=(grouped==true)) end
    end
    r.signature=signature(); r.mode=grouped and 'profiles' or 'sorted'
end
-- Rows ---------------------------------------------------------------------------
local function makeRow(parent)
    local r={root=frame('Frame',parent),bars={}}
    r.root:EnableMouse(false)
    r.bg=r.root:CreateTexture(nil,'BACKGROUND'); r.bg:SetAllPoints(); r.edges=edges(r.root,1)
    r.accent=r.root:CreateTexture(nil,'ARTWORK'); r.accent:SetPoint('TOPLEFT'); r.accent:SetPoint('TOPRIGHT'); r.accent:SetHeight(2)
    r.head=frame('Frame',r.root); r.head:EnableMouse(false)
    r.header=text(r.head,12)
    r.health=status(r.head); r.health:SetStatusBarColor(0.20,0.55,0.36)
    r.name=text(r.health,10); r.hp=text(r.health,12)
    r.forecast=frame('Frame',r.head); r.forecast:Hide()
    r.spacer=frame('Frame',r.root); r.spacer:EnableMouse(false)
    r.outline=frame('Frame',r.root); r.outline:SetAllPoints(); r.outline:EnableMouse(false)
    r.outline:SetFrameLevel(r.root:GetFrameLevel()+5)
    colorEdges(edges(r.outline,2),1,0.80,0.30,1)
    return r
end
function N.stop()
    N.active=false; N.previewActive=false; N.bound=0
    if N.body then N.body:Hide() end
    for _,r in ipairs(N.rows) do
        if r.container and r.token then pcall(r.container.SetUnit,r.container,'none') end
        r.token=nil; r.guid=nil; r.root:Hide()
    end
end
-- Public bars: test previews, drawn like native slots.
local function publicBar(r,i)
    local b=r.bars[i]
    if b then return b end
    b=frame('Frame',r.spacer); b:EnableMouse(false)
    b.frameBg=b:CreateTexture(nil,'BACKGROUND'); b.frameBg:SetAllPoints()
    b.icon=b:CreateTexture(nil,'ARTWORK'); b.icon:SetTexCoord(0.08,0.92,0.08,0.92)
    b.bar=status(b); b.fillTex=b.bar:GetStatusBarTexture()
    local overlay=frame('Frame',b); overlay:SetAllPoints(b); overlay:SetFrameLevel(b.bar:GetFrameLevel()+2); b.overlay=overlay
    b.markParent=overlay
    dress(b,overlay); b.clip:SetFrameLevel(b.bar:GetFrameLevel()+1)
    b.name=text(overlay,12); b.name:SetJustifyH('LEFT')
    b.time=text(overlay,12)
    r.bars[i]=b; return b
end
local function styleBar(b,m,a)
    local db,c=S.db,C()
    local h=m.elementHeight
    local count,duration
    if m.grouped then count,duration=N.profile(a.id) end
    local width=N.barWidth(m,duration)
    b:SetSize(m.icons and m.elementWidth or width,h)
    b.icon:ClearAllPoints(); b.bar:ClearAllPoints(); b.name:ClearAllPoints(); b.time:ClearAllPoints()
    b.icon:SetTexture(a.icon or select(2,A.spell(a.id)))
    local barWidth
    if m.icons then
        b.icon:SetPoint('TOPLEFT',b,'TOPLEFT',1,-1); b.icon:SetPoint('BOTTOMRIGHT',b,'BOTTOMRIGHT',-1,1); b.icon:Show()
        b.bar:SetPoint('BOTTOMLEFT',b,'BOTTOMLEFT',1,1); b.bar:SetPoint('BOTTOMRIGHT',b,'BOTTOMRIGHT',-1,1); b.bar:SetHeight(3)
        b.name:Hide()
        b.time:SetPoint('CENTER',b,'CENTER',0,1); b.time:SetSize(m.elementWidth,h-4); b.time:SetJustifyH('CENTER')
        b.time:SetFont(font(),math.max(9,math.floor(h*0.40)),'OUTLINE')
        b.frameBg:SetColorTexture(0,0,0,0.65)
        barWidth=m.elementWidth-2
    else
        local left=db.enemyStyle==3 and 0 or h+3
        b.icon:SetPoint('LEFT',b,'LEFT',0,0); b.icon:SetSize(h,h); b.icon:SetShown(db.enemyStyle~=3)
        b.bar:SetPoint('TOPLEFT',b,'TOPLEFT',left,0); b.bar:SetPoint('BOTTOMRIGHT',b,'BOTTOMRIGHT',0,0)
        barWidth=width-left
        b.name:SetPoint('LEFT',b.bar,'LEFT',5,0); b.name:SetPoint('RIGHT',b.bar,'RIGHT',-50,0); b.name:SetHeight(h)
        b.name:SetFont(font(),fontSize(db.fontSize,h),'OUTLINE'); b.name:SetText(a.name or A.spell(a.id))
        b.name:SetShown(barWidth>=100)
        b.time:SetPoint('RIGHT',b.bar,'RIGHT',-4,0); b.time:SetSize(46,h); b.time:SetJustifyH('RIGHT')
        b.time:SetFont(font(),fontSize(db.fontSize+1,h+1),'OUTLINE')
        b.frameBg:SetColorTexture(0,0,0,0)
    end
    b.bar:SetStatusBarColor(rgb(c.accent or {0.62,0.38,0.95},0.92))
    b.bar.bg:SetColorTexture(0.12,0.10,0.17,db.enemyBackground and 0.85 or 0)
    b.count=count; b.duration=duration; b.interval=count and duration and duration/count or nil
    applyDress(b,m,barWidth,m.icons and 3 or h,count,duration)
end
-- Order public effects exactly like the native groups would.
local function ordered(effects,m)
    local list={}
    for _,a in ipairs(effects or {}) do
        if not a.native and a.expires and a.expires>GetTime() then list[#list+1]=a end
    end
    local rank={}
    if m.grouped then for i,p in ipairs(N.profiles()) do rank[p.key]=i end end
    local function key(a) local n,d=N.profile(a.id); return n and profileKey(n,d) or 'tother' end
    table.sort(list,function(x,y)
        if m.grouped then
            local rx,ry=rank[key(x)] or math.huge,rank[key(y)] or math.huge
            if rx~=ry then return rx<ry end
        end
        if x.expires~=y.expires then return x.expires<y.expires end
        return (x.id or 0)<(y.id or 0)
    end)
    local out,perGroup={},{}
    for _,a in ipairs(list) do
        local k=m.grouped and key(a) or 'all'
        perGroup[k]=(perGroup[k] or 0)+1
        if perGroup[k]<=m.slots then out[#out+1]=a end
    end
    return out
end
local function layoutBars(r,m,effects)
    local list=ordered(effects,m)
    local x,y,line=0,0,0
    for i,a in ipairs(list) do
        local b=publicBar(r,i); styleBar(b,m,a); b.aura=a
        b:ClearAllPoints()
        if m.icons then
            if line>=m.perLine then line=0; x=0; y=y+m.elementHeight+m.gap end
            b:SetPoint('TOPLEFT',r.spacer,'TOPLEFT',x,-y); x=x+m.elementWidth+m.gap; line=line+1
        else
            b:SetPoint('TOPLEFT',r.spacer,'TOPLEFT',0,-y); y=y+m.elementHeight+m.gap
        end
        b:Show()
    end
    for i=#list+1,#r.bars do r.bars[i]:Hide(); r.bars[i].aura=nil end
    local height=#list==0 and 1 or (m.icons and (y+m.elementHeight) or (y-m.gap))
    r.spacer:SetSize(m.content,math.max(1,height))
end
local function healthText(u)
    local hp,max=u.hp,u.max; local p=hp/max*100; local mode=S.db.healthMode
    if mode==5 then return string.format('%d (%.0f%%) / %d',hp,p,max)
    elseif mode==4 then return string.format('%d (%.0f%%)',hp,p)
    elseif mode==3 then return string.format('%.0f%%',p)
    elseif mode==2 then return tostring(hp) end
    return hp..' / '..max
end
local function ensureBody()
    local U=S.UI
    if not N.body then
        N.body=frame('Frame',U.enemy); N.body:SetSize(1,1); N.body:EnableMouse(false)
    end
    N.body:ClearAllPoints(); N.body:SetPoint('TOPLEFT',U.enemy,'TOPLEFT',0,-(U.headerOffset or 28))
    N.body:SetSize(N.metrics().inner,1); N.body:Show()
end
local function draw(units,preview)
    local db,c=S.db,C()
    local m=N.metrics()
    local count=math.min(#units,db.maxEnemies)
    ensureBody()
    if not preview and not (N.rows[1] and N.rows[1].container) then
        -- Probe a real group even with no enemy: a bare frame is not readiness.
        local r=N.rows[1] or makeRow(N.body); N.rows[1]=r; container(r); r.root:Hide()
    end
    local restricted=A.combat() or secretAuras()
    N.bound=0; N.pending=false
    local width=m.card
    local sig,fkey=signature(),filterKey()
    for i=1,count do
        local u=units[i]; local r=N.rows[i]
        if not r then r=makeRow(N.body); N.rows[i]=r end
        local live=not preview
        if live then
            if not r.container then container(r) end
            if r.signature~=sig then
                -- A container built in combat keeps its build-time geometry (sorted
                -- group only) until restrictions end: no adopted-widget writes here.
                if restricted then N.pending=true; r.mode=r.mode or 'sorted' else reconfigure(r,m) end
            end
            if r.filterKey~=fkey then
                for _,key in ipairs(r.groups) do r.container:SetAuraGroupCandidateFilters(key,N.filters(key)) end
                r.filterKey=fkey
            end
        end
        local style=db.enemyStyle
        r.bg:SetColorTexture(rgb(c.card or {0.07,0.06,0.1},db.enemyBackground and style~=3 and 0.92 or 0))
        colorEdges(r.edges,rgb(c.line or {0.2,0.16,0.28},db.enemyBorder and style~=3 and 0.9 or 0))
        r.accent:SetColorTexture(rgb(u.target and (c.gold or {1,0.8,0.3}) or (c.accentDim or {0.33,0.19,0.53}),style==1 and 0.9 or 0))
        local markers=db.dotMarkers and ((u.focus and ' [F]' or '')..(u.pet and ' [P]' or '')) or ''
        local separate=db.enemyNameHeader or not db.dotHealth
        -- Head: public block (name, health) anchored below the previous card.
        -- Its geometry only changes with the settings: rebuilt on change only.
        local hw=math.min(db.healthWidth,m.content); local hh=db.healthHeight
        local nw=separate and 0 or math.floor(hw*(db.healthMode==5 and 0.30 or 0.38))
        local headKey=sig..':'..hh..':'..db.healthMode..':'..db.spacing..':'..tostring(separate)..':'..tostring(i==1)
        if r.headKey~=headKey then
            r.head:ClearAllPoints()
            if i==1 then r.head:SetPoint('TOPLEFT',N.body,'TOPLEFT',4+PAD,-(4+PAD))
            else r.head:SetPoint('TOPLEFT',N.rows[i-1].root,'BOTTOMLEFT',PAD,-(db.spacing+PAD)) end
            r.header:ClearAllPoints(); r.header:SetPoint('TOPLEFT',r.head,'TOPLEFT',2,0)
            r.header:SetSize(m.content-4,db.fontSize+4); r.header:SetJustifyH('LEFT')
            r.header:SetFont(font(),db.fontSize,'OUTLINE')
            r.health:ClearAllPoints(); r.health:SetPoint('TOPLEFT',r.head,'TOPLEFT',0,separate and -(db.fontSize+5) or 0); r.health:SetSize(hw,hh)
            r.health.bg:SetShown(db.enemyBackground)
            r.name:ClearAllPoints(); r.name:SetPoint('LEFT',r.health,'LEFT',4,0); r.name:SetSize(math.max(1,nw-8),hh-2)
            r.name:SetJustifyH('LEFT'); r.name:SetFont(font(),math.max(8,math.min(11,hh-6)),'OUTLINE')
            r.hp:ClearAllPoints(); r.hp:SetPoint('RIGHT',r.health,'RIGHT',-4,0); r.hp:SetSize(math.max(1,hw-nw-8),hh-2)
            r.hp:SetJustifyH(separate and 'CENTER' or 'RIGHT')
            r.hp:SetFont(font(),math.max(8,math.min(db.fontSize,hh-4)),'OUTLINE')
            r.headKey=headKey
        end
        local y=0
        A.setName(r.header,u,markers); r.header:SetShown(separate)
        if separate then y=y+db.fontSize+5 end
        A.setName(r.name,u,markers); r.name:SetShown(not separate)
        r.health:Hide(); r.unit=u; r.healthShown=false
        if db.dotHealth then
            if u.preview then
                r.health:SetMinMaxValues(0,u.max); r.health:SetValue(u.hp); r.hp:SetText(healthText(u)); r.health:Show(); y=y+hh
            elseif S.Tracker.health(r.health,r.forecast,u.token,u.guid,nil) then
                S.Tracker.healthText(r.hp,u.token,u.guid,db.healthMode); y=y+hh; r.healthShown=true
            end
        end
        r.head:SetSize(m.content,math.max(1,y))
        local gapHead=y>0 and 4 or 0
        -- Tail: the native container (live) or a public spacer (preview/out of view).
        local tail
        local token=live and u.token and A.sameUnit(u.token,u.guid) and u.token or 'none'
        if r.container then
            if r.token~=token or r.guid~=u.guid then
                r.container:SetUnit('none'); r.container:SetUnit(token); r.token=token; r.guid=u.guid
            end
            r.container:SetShown(token~='none')
        end
        if token~='none' then
            N.bound=N.bound+1
            if r.anchorY~=gapHead or r.anchoredTo~=r.head then
                r.container:ClearAllPoints(); r.container:SetPoint('TOPLEFT',r.head,'BOTTOMLEFT',0,-gapHead)
                r.anchorY=gapHead; r.anchoredTo=r.head
            end
            r.spacer:Hide(); for _,b in ipairs(r.bars) do b:Hide(); b.aura=nil end
            tail=r.container
        else
            r.spacer:ClearAllPoints(); r.spacer:SetPoint('TOPLEFT',r.head,'BOTTOMLEFT',0,-gapHead)
            layoutBars(r,m,preview and u.effects or {}); r.spacer:Show()
            tail=r.spacer
        end
        if r.tail~=tail then
            r.root:ClearAllPoints()
            r.root:SetPoint('TOPLEFT',r.head,'TOPLEFT',-PAD,PAD)
            r.root:SetPoint('BOTTOMLEFT',tail,'BOTTOMLEFT',-PAD,-PAD)
            r.tail=tail
        end
        r.root:SetWidth(width)
        A.outlineTarget(r.outline,u,db.enemyBorder and db.dotSelectionFrame)
        r.root:Show()
    end
    for i=count+1,#N.rows do
        local r=N.rows[i]
        if r.token and r.container then r.container:SetUnit('none') end
        r.token=nil; r.guid=nil; r.unit=nil; r.root:Hide()
    end
    -- Out of combat, prepare one spare card per refresh up to the enemy limit,
    -- so cards needed during a pull already carry their profile groups.
    if not preview and not restricted then
        for i=1,db.maxEnemies do
            local r=N.rows[i]
            if not r or not r.container or r.signature~=sig then
                if not r then r=makeRow(N.body); N.rows[i]=r; r.root:Hide() end
                if not r.container then container(r) end
                if r.signature~=sig then reconfigure(r,m) end
                break
            end
        end
    end
    N.count=count
    -- Click a card (DoT bars included) to target its enemy, out of combat.
    local clicks={}
    if not preview then for i=1,count do local r=N.rows[i]; clicks[i]={frame=r.root,token=r.token} end end
    if S.CardClick then S.CardClick.set(clicks) end
    if preview then N.previewActive=true; N.active=false else N.active=true; N.previewActive=false end
end
-- Persistent, bounded diagnostic log (SavedVariables): native errors only, no
-- unit names, GUIDs or aura data. Lets a later session read what happened.
function N.log(message)
    local db=S.db; if not db then return end
    db.diagLog=db.diagLog or {}
    local get=C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    local entry=string.format('%s v%s combat=%s secret=%s %s',date and date('%H:%M:%S') or '?',
        tostring(get and A.call(get,addon,'Version') or '?'),tostring(A.combat()),tostring(secretAuras()),message)
    table.insert(db.diagLog,1,entry:sub(1,300))
    for i=#db.diagLog,11,-1 do db.diagLog[i]=nil end
end
function N.render(units,preview)
    if preview then
        local ok,err=pcall(draw,units,true)
        if not ok then N.error=tostring(A.public(err) or 'restricted error'):gsub('[\r\n]',' '):sub(1,250); N.log('preview: '..N.error); N.stop(); return false end
        return true
    end
    if N.failed then
        -- Retry automatically out of combat; a sticky failure hid 0.4.38's cause.
        if A.combat() or GetTime()<(N.retryAt or 0) then return false end
        N.failed=false
    end
    local ok,err=pcall(draw,units,false)
    if not ok then
        N.error=tostring(A.public(err) or 'restricted error'):gsub('[\r\n]',' '):sub(1,250)
        N.failures=N.failures+1; N.failed=true; N.log('live: '..N.error)
        -- Retry a few times (a transient client state), never forever.
        N.retryAt=N.failures<3 and GetTime()+30 or math.huge
        N.stop(); return false
    end
    N.lastSuccess=GetTime()
    return true
end
function N.retry() N.failed=false; N.retryAt=nil; N.failures=0; S.dirty=true end
-- Health events between scans: update the bars of the cards in place. A bar
-- that appears or disappears changes the card height: full refresh instead.
function N.refreshHealth()
    if not N.active or not S.db.dotHealth then return end
    for i=1,N.count or 0 do
        local r=N.rows[i]; local u=r and r.unit
        if u and not u.preview then
            local shown=S.Tracker.health(r.health,r.forecast,u.token,u.guid,nil)
            if shown then S.Tracker.healthText(r.hp,u.token,u.guid,S.db.healthMode) end
            if shown~=r.healthShown then S.dirty=true end
        end
    end
end
local function timeText(left) return left<10 and string.format('%.1f s',left) or string.format('%d s',math.floor(left)) end
function N.animate(now)
    -- Live cards are drawn by the engine; only test bars are animated in Lua.
    if not N.previewActive then return end
    for _,r in ipairs(N.rows) do
        for _,b in ipairs(r.bars) do
            local a=b.aura
            if a and b:IsShown() then
                local left=a.expires-now
                if left<=0 and a.preview then a.expires=now+a.duration; left=a.duration end
                left=math.max(0,left)
                b.bar:SetValue(a.duration and a.duration>0 and math.min(1,left/a.duration) or 0)
                b.time:SetText(timeText(left)); b.time:SetTextColor(unpack(N.warnColor(left)))
                if b.interval and S.db.dotTicks and S.db.dotLayout~=2 and a.duration then
                    local phase=(a.duration-left)%b.interval
                    b.flash:SetAlpha(phase<FLASH and 0.95*(1-phase/FLASH) or 0)
                else b.flash:SetAlpha(0) end
                if S.db.dotPulse and b.clip:IsShown() then b.warn:SetAlpha(0.775+0.225*math.sin(now*math.pi/0.45)) else b.warn:SetAlpha(1) end
                if left<=0 then b:Hide() end
            end
        end
    end
end
-- Test bars: three training targets with personal effects that loop, so every
-- setting can be judged live. Public fixtures only; never mixed with real data.
function N.previewUnits(now)
    if not N.previewState then
        local spec={
            {name=L.previewEnemy1,hp=890,max=1092,target=true,effects={{25311,18,6},{11713,24,17},{18881,30,27},{25309,15,4}}},
            {name=L.previewEnemy2,hp=402,max=1310,effects={{25311,18,11},{11713,24,8},{702,120,95}}},
            {name=L.previewEnemy3,hp=1475,max=1475,effects={{25309,15,13}}},
        }
        N.previewState={}
        for i,s in ipairs(spec) do
            local u={guid='PREVIEW-'..i,name=s.name,hp=s.hp,max=s.max,target=s.target,preview=true,effects={}}
            for j,e in ipairs(s.effects) do
                local name,icon=A.spell(e[1])
                u.effects[j]={id=e[1],name=name,icon=icon,duration=e[2],expires=now+e[3],preview=true,own=true}
            end
            N.previewState[i]=u
        end
    end
    -- Loop expired test effects forward, whatever time passed since last shown.
    for _,u in ipairs(N.previewState) do
        for _,a in ipairs(u.effects) do
            if a.expires<=now then a.expires=a.expires+math.ceil((now-a.expires+0.001)/a.duration)*a.duration end
        end
    end
    return N.previewState
end
local function version()
    local get=C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    return get and A.call(get,addon,'Version') or '?'
end
function N.diagnostics()
    local m=N.metrics()
    S.print(string.format('DoT natif %s | affichage=%s | ennemis affichés=%d unités liées=%d | %s ×%d%s | filtre=%s | style différé=%s | auras=gérées par Blizzard',
        version(),N.active and 'ready' or (N.failed and 'erreur' or 'inactive'),N.count or 0,N.bound,
        m.icons and 'icônes' or 'barres',m.slots,m.grouped and ' groupes par profil' or '',
        S.db.dotFilter==2 and 'catalogue' or 'tous mes effets',tostring(N.pending==true)))
    if N.error then S.print('DoT natif erreur ('..N.failures..') : '..N.error) end
end
-- Minimal discriminating probe: one container on the current target, no
-- candidate filter, plain icons. Shows whether the engine itself renders.
function N.selfTest()
    if N.test and N.test:IsShown() then N.test:Hide(); if N.test.c then pcall(N.test.c.SetUnit,N.test.c,'none') end; return end
    if A.combat() then S.print(L.combat); return end
    if not N.test then
        local host=CreateFrame('Frame',nil,UIParent); N.test=host
        host:SetSize(300,74); host:SetPoint('CENTER',UIParent,'CENTER',0,180); host:SetFrameStrata('HIGH')
        local bg=host:CreateTexture(nil,'BACKGROUND'); bg:SetAllPoints(); bg:SetColorTexture(0.04,0.03,0.06,0.92)
        host.title=text(host,12); host.title:SetPoint('TOPLEFT',8,-6); host.title:SetText(L.dotTestTitle)
        local ok,err=pcall(function()
            local c=CreateFrame('AuraContainer',nil,host,'CustomAuraContainerTemplate'); host.c=c
            c:SetPoint('TOPLEFT',host,'TOPLEFT',8,-26); c:EnableMouse(false)
            c:SetFlowLayoutAxis(0); c:SetFlowLayoutAnchorPoint('TOPLEFT'); c:SetFlowLayoutGrowthDirection(1,-1)
            c:AddAuraGroup('dots','HARMFUL|PLAYER',{maxFrameCount=8,sortMethod=5,sortDirection=0,
                layout={elementWidth=32,elementHeight=32,elementSpacing=3},initializeFrame=function(slot)
                    slot:SetSize(32,32); slot:EnableMouse(false)
                    local icon=slot:CreateTexture(nil,'ARTWORK'); icon:SetAllPoints(); icon:SetTexCoord(0.08,0.92,0.08,0.92)
                    local t=text(slot,11); t:SetPoint('CENTER'); t:SetSize(32,14); t:SetJustifyH('CENTER')
                    slot:SetIcon(icon); slot:SetDurationText(t,{})
                end})
        end)
        if not ok then host.error=tostring(A.public(err) or 'error'):sub(1,200) end
    end
    local host=N.test
    host:Show()
    if host.error then S.print(L.dotTestFailed..' '..host.error); return end
    host.c:SetUnit('none'); host.c:SetUnit('target')
    S.print(L.dotTestHelp)
end
