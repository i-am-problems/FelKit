local _,S=...
local A=S.API
local T={}; S.Ticks=T
-- Counts reported by WarlockTicks (Embwana), Forever 1.60.1, file 9054986.
-- ID/rank mapping: docs/seed-provenance.json. Predictions, never observed hits.
-- Kept separate from the generated historical spell catalogue.
T.counts={
    [689]=5,[699]=5,[709]=5,[7651]=5,[11699]=5,[11700]=5, -- Drain Life
    [1120]=5,[8288]=5,[8289]=5,[11675]=5, -- Drain Soul
    [5138]=5,[6226]=5,[11703]=5,[11704]=5, -- Drain Mana
    [1316697]=6, -- Wrack
    [5740]=4,[6219]=4,[11677]=4,[11678]=4, -- Rain of Fire
    [1949]=15,[11683]=15,[11684]=15, -- Hellfire
}
function T.capture(c,event)
    if not c then T.schedule=nil; return end
    if event=='UNIT_SPELLCAST_CHANNEL_START' then
        local count=T.counts[c.id]
        T.schedule=count and {id=c.id,start=c.start,duration=c.finish-c.start,count=count} or nil
    elseif T.schedule and T.schedule.id~=c.id then
        T.schedule=nil
    end
    -- Loading/enabling mid-channel cannot establish an unshortened duration.
end
function T.active(c)
    return c and T.schedule and T.schedule.id==c.id and S.db.enabled and
        S.db.channels and S.db.channelSpells[c.id]~=false
end
-- Map the ORIGINAL tick times into the bar's CURRENT remaining-time range.
-- Pushback can truncate the channel but never divides the shorter time by count.
function T.positions(c,span)
    local result={}
    if not T.active(c) or not span or span<=0 then return result end
    local s=T.schedule
    for i=1,s.count-1 do -- the final tick is the left edge, not an interior mark
        local tick=s.start+s.duration*i/s.count
        local ratio=(c.finish-tick)/span
        if tick<=c.finish and ratio>=0 and ratio<1 then result[#result+1]=ratio end
    end
    return result
end
-- Mark colours offered in the settings: gold, white, violet, green, red, cyan, black.
T.COLORS={{1,0.85,0.35},{1,1,1},{0.78,0.48,1},{0.45,1,0.45},{1,0.35,0.3},{0.35,0.85,1},{0,0,0}}
local FLASH=0.4 -- seconds a passed tick keeps flashing
local pools,flashes={},{}
-- Marks are hidden once, not on every 50 ms pass.
local function hideBar(bar)
    local marks=pools[bar]
    if marks and marks.key then for _,mark in ipairs(marks) do mark:Hide() end; marks.key=nil end
    local burst=flashes[bar]
    if burst and burst.shown then for _,mark in ipairs(burst) do mark:Hide() end; burst.shown=nil end
end
function T.hide()
    for bar in pairs(pools) do hideBar(bar) end
    for bar in pairs(flashes) do hideBar(bar) end
end
-- Ticks passed less than FLASH seconds ago: {ratio, age}. Same mapping as T.positions.
function T.passed(c,span,now)
    local result={}
    if not T.active(c) or not span or span<=0 then return result end
    local s=T.schedule
    for i=1,s.count-1 do
        local tick=s.start+s.duration*i/s.count
        local age=now-tick
        local ratio=(c.finish-tick)/span
        if tick<=c.finish and age>=0 and age<FLASH and ratio>=0 and ratio<=1 then result[#result+1]={ratio=ratio,age=age} end
    end
    return result
end
-- Returns true when the bar carries marks; false leaves it to be cleared.
local function draw(bar,c,now)
    if not bar or A.call(bar.IsShown,bar)~=true then return false end
    if A.field(bar,'channeling')~=true or A.field(bar,'reverseChanneling')==true then return false end
    local unit=A.field(bar,'unit'); if unit and unit~='player' then return false end
    if A.call(bar.GetOrientation,bar)~='HORIZONTAL' then return false end
    local ok,lo,hi=pcall(bar.GetMinMaxValues,bar)
    lo=A.num(lo); hi=A.num(hi)
    if not ok or lo~=0 or not hi or hi<=0 then return false end
    local width=A.num(A.call(bar.GetWidth,bar)); local height=A.num(A.call(bar.GetHeight,bar))
    if not width or width<=0 or not height or height<=0 then return false end
    local reverse=A.call(bar.GetReverseFill,bar)
    if type(reverse)~='boolean' then return false end
    local positions=T.positions(c,hi)
    local color=T.COLORS[S.db.channelTickColor] or T.COLORS[1]
    pools[bar]=pools[bar] or {}; local marks=pools[bar]
    -- The marks stay where they are while the channel, bar and colour are the same.
    local key=table.concat(positions,',')..':'..width..':'..height..':'..tostring(reverse)..':'..tostring(S.db.channelTickColor)
    if marks.key~=key then
        for i=#positions+1,#marks do marks[i]:Hide() end
        for i,ratio in ipairs(positions) do
            if not marks[i] then marks[i]=bar:CreateTexture(nil,'OVERLAY') end
            local mark=marks[i]
            mark:SetColorTexture(color[1],color[2],color[3],0.9)
            mark:ClearAllPoints(); mark:SetSize(2,height)
            mark:SetPoint('CENTER',bar,'LEFT',(reverse and 1-ratio or ratio)*width,0)
            mark:Show()
        end
        marks.key=key
    end
    -- Optional animation: a passed tick widens into a bright flash that fades.
    flashes[bar]=flashes[bar] or {}; local burst=flashes[bar]
    if burst.shown then for _,mark in ipairs(burst) do mark:Hide() end; burst.shown=nil end
    if not S.db.tickAnimate or not now then return true end
    for i,p in ipairs(T.passed(c,hi,now)) do
        burst.shown=true
        if not burst[i] then burst[i]=bar:CreateTexture(nil,'OVERLAY',nil,2) end
        local mark=burst[i]; local k=p.age/FLASH
        mark:SetColorTexture(math.min(1,color[1]+0.35),math.min(1,color[2]+0.35),math.min(1,color[3]+0.35),1-k)
        mark:ClearAllPoints(); mark:SetSize(2+10*k,height+6*(1-k))
        mark:SetPoint('CENTER',bar,'LEFT',(reverse and 1-p.ratio or p.ratio)*width,0)
        mark:Show()
    end
    return true
end
-- 0.6.19 offered "channel protection" macros; the option is gone. Their macros
-- ("AIO <spell>" with the [nochanneling] body) are removed once, out of combat.
-- A macro with another body, even with the same name, is never touched.
T.GUARD={{689},{1120},{5138},{755},{5740},{1949},{1316697}}
function T.guardName(name)
    local s=('AIO '..name):sub(1,16)
    while #s>0 and s:byte(#s)>=128 and s:byte(#s)<192 do s=s:sub(1,-2) end
    if #s>0 and s:byte(#s)>=192 then s=s:sub(1,-2) end
    return s
end
function T.guardBody(name) return '#showtooltip '..name..'\n/cast [nochanneling] '..name end
local function macroBody(index)
    if not GetMacroInfo then return nil end
    local ok,_,_,body=pcall(GetMacroInfo,index)
    return ok and A.public(body) or nil
end
function T.syncGuard()
    if T.guardCleaned or A.combat() or not GetMacroIndexByName or not DeleteMacro then return end
    for _,ids in ipairs(T.GUARD) do
        local name=A.spell(ids[1])
        if type(name)=='string' and name~='' then
            local index=A.num(A.call(GetMacroIndexByName,T.guardName(name))) or 0
            if index>0 and macroBody(index)==T.guardBody(name) then pcall(DeleteMacro,index) end
        end
    end
    T.guardCleaned=true
end
-- Known for good once every add-on has loaded.
local external
local function originalLoaded()
    if external~=nil then return external end
    local loaded=C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    local value=A.call(loaded,'WarlockTicks')==true
    if IsLoggedIn and IsLoggedIn() then external=value end
    return value
end
function T.render(c,now)
    -- Avoid a second overlay when the original addon is already loaded.
    if not T.active(c) or now>=c.finish or S.demoUntil or originalLoaded() then T.hide(); return end
    if not draw(PlayerCastingBarFrame,c,now) then hideBar(PlayerCastingBarFrame) end
    if CastingBarFrame~=PlayerCastingBarFrame and not draw(CastingBarFrame,c,now) then hideBar(CastingBarFrame) end
end
