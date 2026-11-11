local _, S = ...
S.Model = {}
local M = S.Model
function M.number(value, lo, hi, fallback)
    local n = tonumber(value)
    if not n or n ~= n or n < lo or n > hi then return fallback end
    return n
end
-- 0.7.5: the defaults are the owner's own settings of 22 October 2026 (onboarding,
-- language, refusals and diagnostics stay per account).
M.defaultPositions={counter={x=343.888671875,y=7.4444580078125},summons={x=239,y=53.00006103515625},
    main={x=-516.6668701171875,y=162.77783203125},enemies={x=601.0399169921875,y=310.4361572265625}}
function M.settings(old)
    old = type(old) == 'table' and old or {}
    local d = {version=1, enabled=true, shards=true, grimoire=true, spellDetails=true, spellTooltips=true, channels=true, enemies=true,
        nightfall=true, procTimers=true, raidAssign=true, visual=true, sound=true, pulse=true, minimap=true, compact=true, chatMessages=false,
        dotAuto=true, dotPredict=true, dotChannels=true, dotSelectionFrame=true, dotDurationMode=1, dotWarnings=true, dotPulse=true, dotHealth=true, dotMarkers=true, dotTicks=false, dotTargetFirst=true, dotWarning=3, warnSix=false, warnThree=false, dotProfiles={},
        dotFilter=1, dotLayout=1, dotSlots=6, onboarded=false, enemyHeader=false, tickColor=1, tickAlpha=100, tickWidth=2,
        locked=false, autoShards=true, pruneSoulBag=false, tickAnimate=true, tickMarks=false, keep=6, scale=1, opacity=0.9, intensity=0.35, width=280,
        rowHeight=20, spacing=2, fontSize=12, maxEnemies=7, healthMode=1,
        enemyNameHeader=false, enemiesCombatOnly=true, healthWidth=170, healthHeight=18,
        enemyStyle=2, enemyBorder=true, enemyBackground=false, enemyLocked=false, enemyAutoHeight=true, enemyHeight=420, dotConfirmedOnly=true,
        angle=271.4774395150263, procVolume=60, procSound=0, procStyle=8, channelTickColor=2, alertScale=1, barY=0, barGap=130, barWidth=12, barHeight=160, barOpacity=0.9,
        positions={}, channelSpells={}}
    -- Saved positions replace these one by one.
    for k,p in pairs(M.defaultPositions) do d.positions[k]={x=p.x,y=p.y} end
    -- Felkit: which DoT engine draws enemies (applied at load, so a reload switches).
    d.dotEngine=old.dotEngine=='cards' and 'cards' or 'window'
    d.fontFace=type(old.fontFace)=='string' and old.fontFace or 'friz'
    d.fontOutline=type(old.fontOutline)=='string' and old.fontOutline or 'OUTLINE'
    d.procs=S.Procs.settings(old.procs)
    d.raid=S.Assign.settings(old.raid)
    for k,v in pairs(d) do
        if type(v)=='boolean' and type(old[k])=='boolean' then d[k]=old[k] end
    end
    local bounds={tickColor={1,4},tickAlpha={10,100},tickWidth={1,3},dotFilter={1,2},dotLayout={1,2},dotSlots={1,10},enemyStyle={1,3},enemyHeight={160,900},dotDurationMode={1,2},healthWidth={100,600},healthHeight={12,48},dotWarning={1,10},keep={0,80},scale={0.65,1.6},opacity={0.25,1},intensity={0.05,0.8},
        width={220,600},rowHeight={10,36},spacing={2,20},fontSize={8,18},maxEnemies={1,12},
        healthMode={1,5},angle={0,360},procVolume={0,100},procSound={0,20},procStyle={1,9},channelTickColor={1,7},alertScale={0.5,2},barGap={20,500}}
    -- 0.6.18: proc size, gap, position, opacity and pulse are fixed by the chosen style.
    -- 0.6.15: the maximum is capped at 80; a larger saved value becomes 80.
    if type(old.keep)=='number' and old.keep>80 and old.keep<=200 then old.keep=80 end
    for k,b in pairs(bounds) do d[k]=M.number(old[k],b[1],b[2],d[k]) end
    d.procVolume=math.floor(d.procVolume/10+0.5)*10
    -- 0.5.5: the player prefers a 3 s warning (adjustable); undo 0.5.4's 6 s once.
    if d.warnSix and not d.warnThree and d.dotWarning==6 then d.dotWarning=3 end
    d.warnSix=true; d.warnThree=true
    d.diagLog={}
    if type(old.diagLog)=='table' then
        for i=1,math.min(10,#old.diagLog) do if type(old.diagLog[i])=='string' then d.diagLog[#d.diagLog+1]=old.diagLog[i]:sub(1,300) end end
    end
    for _,k in ipairs({'tickColor','tickAlpha','tickWidth','dotFilter','dotLayout','dotSlots','keep','rowHeight','spacing','fontSize','maxEnemies','healthMode','procSound','procStyle','channelTickColor','dotDurationMode','healthWidth','healthHeight','enemyStyle','enemyHeight'}) do d[k]=math.floor(d[k]) end
    if type(old.positions)=='table' then
        for k,p in pairs(old.positions) do
            if type(k)=='string' and type(p)=='table' then
                local x,y=M.number(p.x,-10000,10000),M.number(p.y,-10000,10000)
                if x and y then d.positions[k]={x=x,y=y} end
            end
        end
    end
    if type(old.channelSpells)=='table' then
        for id,v in pairs(old.channelSpells) do
            if type(id)=='number' and type(v)=='boolean' then d.channelSpells[id]=v end
        end
    end
    if type(old.dotProfiles)=='table' then
        for id,p in pairs(old.dotProfiles) do
            if type(id)=='number' and type(p)=='table' then
                local duration=M.number(p.duration,0.1,600)
                if duration then d.dotProfiles[id]={duration=duration,interval=M.number(p.interval,0.1,duration),
                    total=M.number(p.total,0.1,10000000),source='manual'} end
            end
        end
    end
    d.shardRefused={}
    if type(old.shardRefused)=='table' then
        for k,v in pairs(old.shardRefused) do if type(k)=='string' and v==true then d.shardRefused[k]=true end end
    end
    local languages={auto=true,en=true,fr=true,es=true,pt=true,de=true,it=true,zh=true,ru=true}
    d.language=type(old.language)=='string' and languages[old.language] and old.language or 'auto'
    if S.KitModel then d.kit=S.KitModel.settings(old.kit) end
    d.multiTarget=M.multiTarget(old.multiTarget)
    -- LibDBIcon button: starts where the add-on's own button was.
    local icon=type(old.minimapIcon)=='table' and old.minimapIcon or {}
    d.minimapIcon={minimapPos=M.number(icon.minimapPos,0,360,old.angle~=nil and d.angle or 235.956945277904),hide=d.minimap==false}
    return d
end
-- Multi-Target DoTs window (Warlock HUD port): Warlock HUD's own bounds and
-- defaults. Its on/off is S.db.enemies, never stored here.
M.didColors={'white','gold','purple','red','orange','green','cyan','pink','black'}
function M.choice(value,list,fallback)
    for _,v in ipairs(list) do if v==value then return value end end
    return fallback
end
M.multiTargetKeys={'corruption','bane','curse','drain','immolate','siphonlife','demonicbrand'}
function M.multiTarget(old)
    old=type(old)=='table' and old or {}
    local p={barTexture=type(old.barTexture)=='string' and old.barTexture or 'auto',healthTexture=old.healthTexture==true,
        barFont=type(old.barFont)=='string' and old.barFont or 'general',barFontSize=M.number(old.barFontSize,0,24,0),
        barFontOutline=type(old.barFontOutline)=='string' and old.barFontOutline or 'general',kitColors=old.kitColors~=false,kitRings=old.kitRings~=false,kitEdges=old.kitEdges~=false,layout=3,multiDotHideOutOfCombat=old.layout~=2 and old.multiDotHideOutOfCombat~=false,
        multiDotAlpha=M.number(old.multiDotAlpha,0.3,1,0.75),multiDotScale=M.number(old.multiDotScale,0.7,1.6,1.15),
        multiDotWidth=M.number(old.multiDotWidth,260,700,486.9806397134812),multiDotHeight=M.number(old.multiDotHeight,150,800,494.3526533410917),
        multiDotX=M.number(old.multiDotX,0,1,0.6899731920128888),multiDotY=M.number(old.multiDotY,0,1,0.5541122910772355),
        -- 0.7.0: one health bar style; DoTs as Warlock HUD icons or equal-width
        -- bars (the former bar styles become equal bars), always sorted by expiry.
        dotStyle=(old.dotStyle=='hud' or old.dotStyle=='equal') and old.dotStyle or 'kit',
        iconPlace=M.choice(old.iconPlace,{'right','below'},'right'),
        iconShape=M.choice(old.iconShape,{'square','rounded','round','diamond','hexagon'},'square'),
        iconBorder=M.choice(old.iconBorder,{'none','gold','purple','silver','black','red','fel'},'none'),
        iconSize=math.floor(M.number(old.iconSize,0,48,0)),iconTimeBar=old.iconTimeBar==true,
        healthHeight=math.floor(M.number(old.healthHeight,8,40,25)),
        -- 0.7.1: denser tables, bar height, click to target, Does It Die look.
        spacing=math.floor(M.number(old.spacing,0,16,4)),barHeight=math.floor(M.number(old.barHeight,8,30,12)),
        clickTarget=old.clickTarget~=false,
        -- 0.7.2: health colour and how the target stands out.
        healthColor=M.choice(old.healthColor,{'green','red','reaction'},'red'),
        selectStyle=M.choice(old.selectStyle,{'line','outline','fill','health'},'line'),
        selectColor=M.choice(old.selectColor,M.didColors,'gold'),
        selectSize=math.floor(M.number(old.selectSize,1,4,3)),
        didFill=M.choice(old.didFill,{'stripes','flat','smooth','none'},'smooth'),
        didDotColors=M.choice(old.didDotColors,{'school','each','single'},'single'),
        didColor=M.choice(old.didColor,M.didColors,'white'),
        didOpacity=math.floor(M.number(old.didOpacity,10,100,65)),
        didOutline=M.choice(old.didOutline,{'dashed','solid','none'},'solid'),
        didOutlineColor=M.choice(old.didOutlineColor,M.didColors,'black'),
        didOutlineSize=math.floor(M.number(old.didOutlineSize,1,3,2)),
        didIcon=M.choice(old.didIcon,{'skull','cross','check','boss'},'skull'),
        didPlateIconSize=math.floor(M.number(old.didPlateIconSize,12,40,18)),
        didPlateIconPos=M.choice(old.didPlateIconPos,{'left','right','above'},'left'),
        showName=old.showName==true,showPortrait=old.showPortrait~=false,
        execute=old.execute==true,
        didBars=old.didBars~=false,didPlates=old.didPlates~=false,
        transparent=old.transparent~=false,header=old.header==true,
        -- 0.7.5: the window moves only while unlocked (Display tab).
        locked=old.locked~=false,
        enabled={},mainOrder={},defaultDotIcons={}}
    if type(old.enabled)=='table' then
        for k,v in pairs(old.enabled) do
            if type(k)=='string' and #k<=64 and v==false and k~='executeMarker' then p.enabled[k]=false end
        end
    end
    local valid,seen={},{}
    for _,k in ipairs(M.multiTargetKeys) do valid[k]=true end
    if type(old.mainOrder)=='table' then
        for _,k in ipairs(old.mainOrder) do
            if valid[k] and not seen[k] then p.mainOrder[#p.mainOrder+1]=k; seen[k]=true end
        end
    end
    for _,k in ipairs(M.multiTargetKeys) do if not seen[k] then p.mainOrder[#p.mainOrder+1]=k end end
    return p
end
-- Shards that may go: the excess over the maximum, taken from regular bags;
-- soul bags only when the player allows it (includeSoul).
function M.excess(items, total, keep, includeSoul)
    if not items or not total then return nil end
    local loose=0
    for _,v in ipairs(items) do
        if v.id==6265 and (includeSoul or not v.soul) then loose=loose+v.count end
    end
    return math.max(0,math.min(total-keep,loose))
end
-- Deletable shard stacks, last bag and last slot first; regular bags before
-- soul bags, so a soul bag is emptied only when nothing else is left.
function M.looseStacks(items, includeSoul)
    local out={}
    for _,v in ipairs(items or {}) do
        if v.id==6265 and (includeSoul or not v.soul) and not v.locked and v.count>0 then out[#out+1]=v end
    end
    table.sort(out,function(a,b)
        if (a.soul==true)~=(b.soul==true) then return not a.soul end
        if a.bag~=b.bag then return a.bag>b.bag end
        return a.slot>b.slot
    end)
    return out
end
-- One input, one bag slot, at most the current excess, in combat too.
-- The game allows one item deletion per key press or click: the next input takes the next.
function M.prune(api, keep, includeSoul)
    if M.number(keep,0,80)==nil or keep~=math.floor(keep) then return 'invalid' end
    if api.cursor() then return 'cursor' end
    local items,total=api.inventory()
    if not items or not total then return 'unavailable' end
    local excess=M.excess(items,total,keep,includeSoul)
    if excess<=0 then return 'nothing',nil,total end
    local stacks=M.looseStacks(items,includeSoul)
    if not stacks[1] then return 'nothing',nil,total end
    local s=stacks[1]
    if not api.split then
        -- Without a split, the first stack that fits the excess whole.
        s=nil
        for _,v in ipairs(stacks) do if v.count<=excess then s=v; break end end
        if not s then return 'stack' end
    end
    local take=math.min(s.count,excess)
    if api.quiet then api.quiet() end
    local ok
    if take<s.count then ok=api.split(s.bag,s.slot,take)
    else ok=api.pickup(s.bag,s.slot) end
    if not ok then api.restore(); return 'blocked' end
    local kind,id=api.cursor()
    if kind~='item' or id~=6265 then
        -- Unexpected cursor content is never destroyed.
        api.restore(); return 'changed'
    end
    local deleted=api.delete()
    if not deleted or api.cursor() then api.restore(); return 'blocked' end
    return 'requested',take,total-take,excess-take
end
function M.effects(auras, now)
    local out={}
    for _,a in ipairs(auras or {}) do
        if a.own and a.id and (not a.expires or a.expires>now) then out[#out+1]=a end
    end
    table.sort(out,function(a,b)
        local x,y=a.expires or math.huge,b.expires or math.huge
        if x~=y then return x<y end
        if a.id~=b.id then return a.id<b.id end
        return (a.instance or 0)<(b.instance or 0)
    end)
    return out
end
function M.replaceUnit(state, token, unit, includeIdle)
    local old=state.tokens[token]
    state.tokens[token]=nil
    if old and state.units[old] and state.units[old].token==token then state.units[old]=nil end
    if unit and unit.guid and unit.attackable and (includeIdle or unit.combat) and not unit.dead then
        local previous=state.units[unit.guid]
        if previous and previous.token~=token then state.tokens[previous.token]=nil end
        unit.token=token; state.tokens[token]=unit.guid; state.units[unit.guid]=unit
    end
end
function M.proc(state, active, initial)
    local sound = active==true and state.active==false and not initial
    state.active=active -- nil means unknown, regain after unknown is silent
    return active==true,sound
end
-- A prediction requires a verified, build-specific cadence and an actual phase anchor.
function M.ticks(startTime, endTime, interval, now, verified, anchor)
    local ticks={}
    if not verified or not anchor or not interval or interval<=0 then return ticks end
    local t=anchor+interval
    for _=1,100 do
        if t>endTime then break end
        if t>=now and t>=startTime then ticks[#ticks+1]=t end
        t=t+interval
    end
    return ticks
end
function M.component(base, power, coefficient)
    if type(base)~='number' or type(power)~='number' or type(coefficient)~='number' then return nil end
    return base+power*coefficient
end
