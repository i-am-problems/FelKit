-- Original Warlock All-in-One tracker. No DoTimer code or assets are embedded.
local _,S=...
local A=S.API
local T={targets={},pending={},serial=0,profiles={}}
S.Tracker=T
local function positive(v,limit)
    v=A.num(v); return v and v>0 and v<=limit and v or nil
end
function T.clear()
    T.targets={}; T.pending={}; T.profiles={}; T.serial=0; T.channel=nil
end
function T.group(id) return S.Data.dotGroups[id] end
function T.channelSupported(id)
    local family=S.Data.dotFamilies[id]
    return family==689 or family==1120 or family==5138 or family==1316697
end
function T.supported(id)
    local d=S.Data.spells[id]
    return d and not d.channel and (d.periodic or T.group(id))
end
-- Spell facts come from the spell ID (DB2 data and the grimoire model), never from
-- the client's localized description, so every language gets the same profile.
-- Totals follow spell power and talents: keep them for one second only.
local function spellData(id)
    if not T.supported(id) then return nil end -- Channels keep their native module.
    local p=S.Spells and S.Spells.periodic and S.Spells.periodic(id)
    -- Agony grows over time; a linear projection would misrepresent its remaining damage.
    if p and S.Data.agony[id] then p.total=nil end
    return p
end
function T.profile(id)
    local manual=S.db.dotProfiles[id]
    if not S.db.dotAuto and manual then return manual end
    local now=GetTime(); local cached=T.profiles[id]
    if type(cached)~='table' or not cached.time or now<cached.time or now-cached.time>1 then
        cached={time=now,value=spellData(id) or false}; T.profiles[id]=cached
    end
    local data=cached.value or nil
    local timing=S.db.dotAuto and S.DotTiming[id]
    if timing then
        return {duration=timing.duration,count=timing.count,
            interval=timing.count and timing.duration/timing.count or nil,
            total=data and data.total or nil,source='forever-catalogue'}
    end
    return data
end
function T.setProfile(id,duration,interval,total)
    id=tonumber(id); duration=positive(tonumber(duration),600)
    interval=tonumber(interval); total=tonumber(total)
    if not id or not T.supported(id) or not duration or not interval or interval<0 or interval>duration or
        not total or total<0 or total>10000000 then return false end
    S.db.dotProfiles[id]={duration=duration,interval=interval>0 and interval or nil,total=total>0 and total or nil,source='manual'}
    T.profiles[id]=nil
    return true
end
local function tokens()
    local out={'target','focus','mouseover'}
    for token in pairs(S.plates or {}) do out[#out+1]=token end
    return out
end
-- SENT gives a name, not a GUID. Reject duplicate names and inaccessible candidates.
function T.resolve(name)
    name=A.public(name)
    if type(name)~='string' or name=='' then return nil end
    local match
    for _,token in ipairs(tokens()) do
        local n=A.call(UnitName,token)
        if n==name and A.call(UnitCanAttack,'player',token)==true and A.call(UnitIsDeadOrGhost,token)==false then
            local guid=A.guid(token)
            if type(guid)~='string' then return nil end
            if match and match.guid~=guid then return nil,'ambiguous' end
            match={guid=guid,name=n}
        end
    end
    return match
end
-- A missing SENT target may be recovered from the selected hostile unit. It is
-- an estimate: focus/mouseover macros without a readable SENT name cannot be proven.
local function selectedTarget()
    local guid=A.guid('target'); local name=A.call(UnitName,'target')
    if type(guid)=='string' and type(name)=='string' and
        A.call(UnitCanAttack,'player','target')==true and A.call(UnitIsDeadOrGhost,'target')==false then
        return {guid=guid,name=name,assumed=true}
    end
end
local function remember(cast,p)
    if not T.pending[cast] then
        local count,oldest,key=0,math.huge,nil
        for k,v in pairs(T.pending) do
            count=count+1; if v.time<oldest then oldest=v.time; key=k end
        end
        if count>=16 and key then T.pending[key]=nil end
    end
    T.pending[cast]=p
end
local function targetRecord(guid,name)
    local target=T.targets[guid]
    if not target then
        local count=0; for _ in pairs(T.targets) do count=count+1 end
        if count>=64 then return nil end
        T.serial=T.serial+1
        target={guid=guid,name=name,effects={},order=T.serial}; T.targets[guid]=target
    end
    return target
end
-- Only an observed CHANNEL_START can establish a destination; never attach a
-- channel to a newly selected target during an update or a reload.
function T.trackChannel(c,event,cast)
    if not S.db.enabled or not S.db.enemies or not S.db.dotChannels or not c or not T.channelSupported(c.id) then
        T.channel=nil; S.dirty=true; return
    end
    if event=='UNIT_SPELLCAST_CHANNEL_START' then
        cast=A.public(cast)
        local p=type(cast)=='string' and T.pending[cast] or nil
        local target
        if p then
            if not p.blocked and p.id==c.id and GetTime()-p.time<=15 then target=p.target end
        else target=selectedTarget() end
        if type(cast)=='string' then remember(cast,{id=c.id,time=GetTime(),blocked=true}) end
        T.channel=target and {guid=target.guid,id=c.id,start=c.start,initialDuration=c.finish-c.start,
            targetAssumed=target.assumed} or nil
    end
    local state=T.channel
    if state and state.id==c.id and state.start==c.start then
        state.effect={id=c.id,name=c.name,icon=c.icon,own=true,channel=true,
            duration=c.finish-c.start,expires=c.finish,tickStart=state.start,
            count=S.Ticks.counts[c.id],interval=state.initialDuration/S.Ticks.counts[c.id],
            predicted=state.targetAssumed==true}
    else T.channel=nil end
    S.dirty=true
end
function T.event(event,unit,arg2,arg3,id)
    if A.public(unit)~='player' or not S.db.enabled or not S.db.enemies then return end
    local now=GetTime()
    if event=='UNIT_SPELLCAST_SENT' then
        local cast=A.public(arg3); id=A.num(id)
        if type(cast)~='string' or not id or not (T.channelSupported(id) or (S.db.dotPredict and T.supported(id))) then return end
        local name=A.public(arg2)
        local explicit=type(name)=='string' and name~=''
        local target
        if explicit then
            local reason
            target,reason=T.resolve(name)
            if not target and reason=='ambiguous' then
                local selected=selectedTarget()
                if selected and selected.name==name then target=selected end
            end
        else target=selectedTarget() end
        -- Identical mob names may use the selected GUID as an explicit estimate.
        -- An unresolved name that does not match the selection is still rejected.
        remember(cast,{target=target,id=id,time=now,blocked=explicit and not target})
    elseif event=='UNIT_SPELLCAST_START' then
        local cast=A.public(arg2); id=A.num(arg3)
        if not S.db.dotPredict or type(cast)~='string' or not id or not T.supported(id) or T.pending[cast] then return end
        remember(cast,{target=selectedTarget(),id=id,time=now})
    elseif event=='UNIT_SPELLCAST_SUCCEEDED' then
        -- Cast success is not hit success. Never replace an existing confirmed
        -- aura on a recast until a new owned aura has actually been observed.
        if S.db.dotConfirmedOnly then S.dirty=true; return end
        local cast=A.public(arg2); id=A.num(arg3)
        if not S.db.dotPredict or type(cast)~='string' or not id or not T.supported(id) then return end
        local p=T.pending[cast]
        -- Keep bounded tombstones to reject duplicate, failed or stale success events.
        remember(cast,{id=id,time=now,blocked=true})
        if p then
            if p.blocked or p.id~=id or now-p.time>15 then return end
        else p={target=selectedTarget()} end
        if not p.target then return end
        local spec=T.profile(id)
        if not spec then return end
        local target=targetRecord(p.target.guid,p.target.name)
        if not target then return end
        local group=T.group(id)
        for key,a in pairs(target.effects) do
            if key==id or (group and T.group(a.id)==group) or
                (S.Data.dotFamilies[id] and S.Data.dotFamilies[id]==S.Data.dotFamilies[a.id]) then target.effects[key]=nil end
        end
        local name,icon=A.spell(id)
        target.effects[id]={id=id,name=name,icon=icon,duration=spec.duration,expires=now+spec.duration,
            interval=spec.interval,count=spec.count,total=spec.total,own=true,predicted=true,assumedTarget=p.target.assumed,source=spec.source}
        S.dirty=true
    elseif event=='UNIT_SPELLCAST_FAILED' or event=='UNIT_SPELLCAST_INTERRUPTED' then
        local cast=A.public(arg2)
        if type(cast)=='string' then remember(cast,{id=A.num(arg3),time=now,blocked=true}) end
    end
end
function T.forecast(effects,now)
    local total,known,unknown=0,0,0
    for _,a in ipairs(effects) do
        local d=S.Data.spells[a.id]
        if d and d.periodic then
            if a.total and a.duration and a.expires then
                total=total+a.total*math.max(0,math.min(1,(a.expires-now)/a.duration)); known=known+1
            else unknown=unknown+1 end
        end
    end
    return known>0 and total or nil,unknown>0
end
function T.decorate(a)
    if a.native or a.predicted or a.channel then return a end
    if T.channelSupported(a.id) and a.duration then
        a.count=S.Ticks.counts[a.id]; a.interval=a.count and a.duration/a.count or nil
        return a
    end
    local p=T.profile(a.id)
    if p then
        a.count=p.count
        a.interval=p.count and a.duration and a.duration/p.count or p.interval
        a.total=p.total; a.source=p.source
    end
    return a
end
function T.merge(observed,now)
    local byGUID,ordered={},{}
    for _,u in ipairs(observed) do byGUID[u.guid]=u; ordered[#ordered+1]=u end
    -- Keep a public, owned aura's last known expiration by GUID even when its
    -- original cast was not observed. A later restricted scan is not its removal.
    if S.db.dotPredict or S.db.dotConfirmedOnly then
        for _,u in ipairs(observed) do
            do -- Public positives remain valid even when another aura is unreadable.
                for _,a in ipairs(u.effects) do
                    if not a.predicted and a.own and (T.supported(a.id) or a.generic) and a.duration and a.expires and
                        a.expires>now and a.expires<=now+600 then
                        local t=targetRecord(u.guid,u.name)
                        if t and not t.effects[a.id] then
                            T.decorate(a)
                            local cached={}; for k,v in pairs(a) do cached[k]=v end
                            cached.predicted=true; cached.confirmed=true
                            t.effects[a.id]=cached
                        end
                    end
                end
            end
        end
    end
    -- Only enemies actually observed as eligible nameplates may be retained.
    -- Keep identity/combat state, never cached health or recycled unit tokens.
    for _,u in ipairs(observed) do
        local t=T.targets[u.guid]
        if not t and T.channel and T.channel.guid==u.guid then t=targetRecord(u.guid,u.name) end
        if t then t.name=u.name; t.combat=u.combat==true; u.order=t.order end
    end
    for guid,t in pairs(T.targets) do
        if S.excludedEnemies and S.excludedEnemies[guid] then
            T.targets[guid]=nil
            if T.channel and T.channel.guid==guid then T.channel=nil end
        else
        local any=false
        local observedUnit=byGUID[guid]
        local observedIDs,observedGroups,observedFamilies={},{},{}
        if observedUnit then
            for _,a in ipairs(observedUnit.effects) do
                observedIDs[a.id]=a
                local g=T.group(a.id); if g then observedGroups[g]=a.id end
                local family=S.Data.dotFamilies[a.id]; if family then observedFamilies[family]=a.id end
            end
        end
        for id,a in pairs(t.effects) do
            if (not S.db.dotPredict or S.db.dotConfirmedOnly) and not a.confirmed then a.expires=now end
            local seen=observedIDs[id]
            if seen then
                a.confirmed=true
                if seen.expires then
                    a.expires=seen.expires; a.duration=seen.duration
                    if a.count and a.duration then a.interval=a.duration/a.count end
                end
            elseif observedUnit and observedUnit.aurasKnown and
                ((a.confirmed and observedUnit.auraRemovalKnown~=false) or (T.group(id) and observedGroups[T.group(id)]) or
                    (S.Data.dotFamilies[id] and observedFamilies[S.Data.dotFamilies[id]])) then
                a.expires=now
            end
            if a.expires<=now then t.effects[id]=nil else any=true end
        end
        local channelActive=T.channel and T.channel.guid==guid and T.channel.effect and T.channel.effect.expires>now and
            (not S.db.dotConfirmedOnly or T.channel.confirmed)
        if not any and not channelActive then T.targets[guid]=nil
        elseif (S.db.dotPredict or S.db.dotConfirmedOnly) and observedUnit then
            local u=byGUID[guid]
            u.order=t.order
            local seen,instances={},{}
            for i,a in ipairs(u.effects) do
                seen[a.id]=true
                if a.instance then instances[a.instance]=true end
                -- A masked clock is not a refresh: retain the original deadline.
                if not a.native and not a.expires and t.effects[a.id] and t.effects[a.id].confirmed then u.effects[i]=t.effects[a.id] end
            end
            for id,a in pairs(t.effects) do
                if not seen[id] and not (a.instance and instances[a.instance]) then u.effects[#u.effects+1]=a end
            end
        end
        end
    end
    for _,token in ipairs(tokens()) do
        local guid=A.guid(token)
        if type(guid)=='string' then
            if A.call(UnitIsDeadOrGhost,token)==true then
                T.targets[guid]=nil; byGUID[guid]=nil
                if T.channel and T.channel.guid==guid then T.channel=nil end
            end
        end
    end
    local channel=T.channel
    if channel and channel.effect and channel.effect.expires>now then
        local u=byGUID[channel.guid]
        local aura=u and u.channelAuras and u.channelAuras[channel.id]
        if aura and aura.duration and aura.expires and aura.expires-aura.duration>=channel.start-0.25 then channel.confirmed=true end
        if u and (not S.db.dotConfirmedOnly or channel.confirmed) then
            for i=#u.effects,1,-1 do if u.effects[i].id==channel.id then table.remove(u.effects,i) end end
            u.effects[#u.effects+1]=channel.effect
        end
    elseif channel then T.channel=nil end
    local list={}
    local targetGUID,focusGUID,petGUID=A.guid('target'),A.guid('focus'),A.guid('pettarget')
    for _,u in ipairs(ordered) do
        if byGUID[u.guid] then
            u.target=targetGUID==u.guid
            -- In combat GUIDs are secret: the outline then asks the plate natively.
            u.targetKnown=targetGUID~=nil and type(u.guid)=='string' and u.guid:sub(1,6)~='plate:'
            u.focus=focusGUID==u.guid; u.pet=petGUID==u.guid
            for _,a in ipairs(u.effects) do T.decorate(a) end
            table.sort(u.effects,function(a,b)
                local x,y=a.expires or math.huge,b.expires or math.huge
                if x~=y then return x<y end
                if a.id~=b.id then return a.id<b.id end
                return (a.instance or 0)<(b.instance or 0)
            end)
            list[#list+1]=u
        end
    end
    table.sort(list,function(a,b)
        if S.db.dotTargetFirst and a.target~=b.target then return a.target end
        if (a.order or math.huge)~=(b.order or math.huge) then return (a.order or math.huge)<(b.order or math.huge) end
        return a.guid<b.guid
    end)
    return list
end
-- Native formatting accepts secret numeric arguments. Never read the formatted text back.
function T.healthText(text,unit,guid,mode)
    text:SetText('?')
    if not unit or not A.sameUnit(unit,guid) then return false end
    local ok=pcall(function()
        if mode==3 or mode==4 or mode==5 then
            if not UnitHealthPercent or not CurveConstants or not CurveConstants.ScaleTo100 then error('no percentage API') end
            if mode==5 then text:SetFormattedText('%d (%.0f%%) / %d',UnitHealth(unit),UnitHealthPercent(unit,false,CurveConstants.ScaleTo100),UnitHealthMax(unit))
            elseif mode==4 then text:SetFormattedText('%d (%.0f%%)',UnitHealth(unit),UnitHealthPercent(unit,false,CurveConstants.ScaleTo100))
            else text:SetFormattedText('%.0f%%',UnitHealthPercent(unit,false,CurveConstants.ScaleTo100)) end
        elseif mode==2 then text:SetFormattedText('%d',UnitHealth(unit))
        else text:SetFormattedText('%d / %d',UnitHealth(unit),UnitHealthMax(unit)) end
    end)
    if not A.sameUnit(unit,guid) then text:SetText('?'); return false end
    if not ok then
        text:SetText('?')
        -- Older clients may lack the native curve API; only public numbers may be divided.
        if mode==3 or mode==4 or mode==5 then
            local hp,max=A.num(A.call(UnitHealth,unit)),A.num(A.call(UnitHealthMax,unit))
            if not A.sameUnit(unit,guid) then return false end
            if hp and max and max>0 then
                text:SetText(mode==5 and string.format('%d (%.0f%%) / %d',hp,hp/max*100,max) or mode==4 and string.format('%d (%.0f%%)',hp,hp/max*100) or string.format('%.0f%%',hp/max*100)); return true
            end
        end
    end
    return ok
end
-- Restricted health is handed only to native widgets; never compared or formatted.
function T.health(bar,forecast,unit,guid,amount)
    bar:Hide(); forecast:Hide()
    if not unit or not A.sameUnit(unit,guid) then return false end
    local ok=pcall(function()
        bar:SetMinMaxValues(0,UnitHealthMax(unit)); bar:SetValue(UnitHealth(unit))
        if amount then forecast:SetMinMaxValues(0,UnitHealthMax(unit)); forecast:SetValue(amount) end
    end)
    if ok and A.sameUnit(unit,guid) then bar:Show(); forecast:SetShown(amount~=nil); return true end
    return false
end
