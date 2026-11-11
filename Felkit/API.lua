local _,S=...
local A={}; S.API=A
function A.chat(text)
    local db=S.db or (type(FelkitDB)=='table' and FelkitDB)
    if db and db.chatMessages==false then return end
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage('|cffb879efFelKit:|r '..text) end
end
function A.public(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end
function A.call(fn,...)
    if type(fn)~='function' then return nil end
    local ok,value=pcall(fn,...)
    if not ok then return nil end
    return A.public(value)
end
function A.field(t,k) if type(t)=='table' then return A.public(t[k]) end end
function A.num(v) v=A.public(v); if type(v)=='number' and v==v then return v end end
function A.guid(unit) return A.call(UnitGUID,unit) end
function A.combat() return A.call(InCombatLockdown)~=false end
function A.cursor()
    if not GetCursorInfo then return 'unknown' end
    local ok,kind,id=pcall(GetCursorInfo)
    if not ok then return 'unknown' end
    if issecretvalue and (issecretvalue(kind) or issecretvalue(id)) then return 'unknown' end
    kind=A.public(kind); id=A.public(id)
    return kind,id
end
function A.inventory()
    if not C_Container or not C_Container.GetContainerItemInfo then return nil end
    local items,total={},0
    -- The extra equipped bag is outside NUM_BAG_SLOTS on Forever.
    -- Never enumerate arbitrary container IDs: those include bank tabs.
    local constants=Constants and A.field(Constants,'InventoryConstants')
    local normal=A.num(NUM_BAG_SLOTS) or A.num(A.field(constants,'NumBagSlots')) or 4
    local extra=A.num(NUM_REAGENTBAG_SLOTS) or A.num(A.field(constants,'NumReagentBagSlots')) or 0
    local last=A.num(NUM_TOTAL_EQUIPPED_BAG_SLOTS) or (normal+extra)
    local bank=Enum and A.num(A.field(Enum.BagIndex,'CharacterBankTab_1'))
    if bank then last=math.min(last,bank-1) end
    if last<0 or last>20 or last~=math.floor(last) then return nil end
    for bag=0,last do
        local slots=A.num(A.call(C_Container.GetContainerNumSlots,bag))
        if not slots then return nil end
        local soul=false
        if C_Container.GetContainerNumFreeSlots then
            local ok,_,family=pcall(C_Container.GetContainerNumFreeSlots,bag)
            family=A.num(family)
            soul=ok and family and math.floor(family/4)%2==1 or false
        end
        -- Or a bag item of the Soul Bag kind (class 1, subclass 1).
        if not soul and bag>0 and C_Container.ContainerIDToInventoryID and GetInventoryItemID and C_Item and C_Item.GetItemInfoInstant then
            local inv=A.call(C_Container.ContainerIDToInventoryID,bag)
            local item=inv and A.call(GetInventoryItemID,'player',inv)
            if item then
                local ok,_,_,_,_,_,classID,subClassID=pcall(C_Item.GetItemInfoInstant,item)
                soul=ok and A.public(classID)==1 and A.public(subClassID)==1 or false
            end
        end
        for slot=1,slots do
            local ok,raw=pcall(C_Container.GetContainerItemInfo,bag,slot)
            if not ok or (issecretvalue and issecretvalue(raw)) then return nil end
            if raw then
                local id=A.num(A.field(raw,'itemID'))
                local count=A.num(A.field(raw,'stackCount'))
                local locked=A.field(raw,'isLocked')
                if not id or not count or type(locked)~='boolean' then return nil end
                items[#items+1]={id=id,count=count,locked=locked,bag=bag,slot=slot,soul=soul}
                if id==6265 then total=total+count end
            end
        end
    end
    return items,total
end
function A.pickup(bag,slot)
    if not C_Container or not C_Container.PickupContainerItem then return false end
    return pcall(C_Container.PickupContainerItem,bag,slot)
end
function A.split(bag,slot,count)
    if not C_Container or not C_Container.SplitContainerItem then return false end
    return pcall(C_Container.SplitContainerItem,bag,slot,count)
end
function A.delete() if not DeleteCursorItem then return false end; return pcall(DeleteCursorItem) end
-- The game's pick-up and put-down sounds (file IDs), muted for 0.3 s around a deletion.
-- Muting a sound file lasts only this session, so a reload cannot leave them off.
local SHARD_SOUNDS={567568,567574}
local quietUntil
function A.quiet()
    if not (MuteSoundFile and UnmuteSoundFile and C_Timer and C_Timer.After) then return end
    if not quietUntil then for _,id in ipairs(SHARD_SOUNDS) do pcall(MuteSoundFile,id) end end
    quietUntil=GetTime()+0.3
    C_Timer.After(0.35,function()
        if quietUntil and GetTime()>=quietUntil then
            quietUntil=nil
            for _,id in ipairs(SHARD_SOUNDS) do pcall(UnmuteSoundFile,id) end
        end
    end)
end
function A.restore() if ClearCursor then pcall(ClearCursor) end end
function A.spell(id)
    local info=C_Spell and A.call(C_Spell.GetSpellInfo,id)
    return A.field(info,'name') or ('#'..id), A.field(info,'iconID') or 134400
end
function A.description(id)
    return C_Spell and A.call(C_Spell.GetSpellDescription,id) or nil
end
local function auraTrace(trace,key)
    if trace then trace[key]=(trace[key] or 0)+1 end
end
local function auraError(trace,raw)
    if not trace or trace.error then return end
    local text=A.public(raw)
    if type(text)=='string' then trace.error=text:gsub('[\r\n]',' '):sub(1,180) end
end
function A.auras(unit,filter,partial,trace)
    local result,complete={},true
    if not C_UnitAuras or not C_UnitAuras.GetAuraDataByIndex then auraTrace(trace,'unavailable'); return nil end
    for i=1,255 do
        local ok,a=pcall(C_UnitAuras.GetAuraDataByIndex,unit,i,filter)
        if not ok then auraTrace(trace,'failed'); auraError(trace,a); return partial and result or nil,false end
        if issecretvalue and issecretvalue(a) then
            auraTrace(trace,'masked')
            if not partial then return nil end
            complete=false
        elseif not a then auraTrace(trace,'ended'); return result,complete
        else
        auraTrace(trace,'records')
        local id=A.num(A.field(a,'spellId'))
        local source=A.field(a,'sourceUnit')
        local instance=A.num(A.field(a,'auraInstanceID'))
        if not id then
            auraTrace(trace,'idUnreadable')
            if not partial then return nil end
            complete=false
        else
        local duration=A.num(A.field(a,'duration'))
        local expires=A.num(A.field(a,'expirationTime'))
        local statusExpires=expires and expires>0 and expires or nil
        if not duration or duration<=0 or not expires or expires<=0 then duration=nil; expires=nil end
        local ownership=source and A.call(UnitIsUnit,source,'player')
        -- Missing/secret ownership cannot prove removal of a previously owned DoT.
        local entry=S.Data.spells[id]
        if filter=='HARMFUL' and entry and (entry.periodic or S.Data.dotGroups[id]) and
            type(ownership)~='boolean' then
            if not partial then return nil end
            complete=false
        end
        local own=ownership==true
        result[#result+1]={id=id,instance=instance,source=source,own=own,ownerKnown=type(ownership)=='boolean',duration=duration,expires=expires,statusExpires=statusExpires,
            name=A.field(a,'name'),icon=A.field(a,'icon')}
        end
        end
    end
    return partial and result or nil,false -- Partial positives never prove removal.
end
function A.procRecord(raw,identified)
    raw=A.public(raw)
    if type(raw)~='table' then return nil end
    local id=A.num(A.field(raw,'spellId'))
    if (id and id~=S.Data.procID) or (not identified and id~=S.Data.procID) then return nil end
    local duration=A.num(A.field(raw,'duration'))
    local expires=A.num(A.field(raw,'expirationTime'))
    if not duration or duration<=0 then duration=nil end
    if not expires or expires<=0 then expires=nil end
    return {id=S.Data.procID,instance=A.num(A.field(raw,'auraInstanceID')),duration=duration,expires=expires}
end
function A.procAura()
    local api=C_UnitAuras or {}
    local trace={}; A.procTrace=trace
    local function query(key,fn,...)
        if type(fn)~='function' then trace[key]='unavailable'; return nil end
        local ok,raw=pcall(fn,...)
        if not ok then trace[key]='error'; return nil end
        if issecretvalue and issecretvalue(raw) then trace[key]='secret'; return nil end
        if raw==nil then trace[key]='absent'; return nil end
        local aura=A.procRecord(raw,true)
        trace[key]=aura and 'present' or 'unreadable'
        return aura
    end
    local aura=query('id',api.GetPlayerAuraBySpellID,S.Data.procID)
    if aura then return true,aura,'aura-id' end
    -- The player's real 0.4.33 trace reports false while Shadow Trance is up.
    -- A nil ID lookup must not prevent other public APIs from proving presence.
    -- The proc's name is constant: read once (SPELLS_CHANGED forgets it).
    local name=A.procName
    if not name then
        local info=C_Spell and A.call(C_Spell.GetSpellInfo,S.Data.procID)
        name=A.field(info,'name')
        if type(name)=='string' and not (issecretvalue and issecretvalue(name)) and name~='' then A.procName=name end
    end
    if type(name)=='string' and name~='' then
        aura=query('name',api.GetAuraDataBySpellName,'player',name,'HELPFUL')
        if aura then return true,aura,'aura-name' end
    else trace.name='unavailable' end
    local scan=api.GetAuraDataByIndex
    if type(scan)~='function' then
        trace.scan='unavailable'
        if trace.id=='absent' or trace.name=='absent' then return false,nil,'aura-absent' end
        return nil,nil,'aura-unknown'
    end
    local complete=true
    for i=1,255 do
        local ok,raw=pcall(scan,'player',i,'HELPFUL')
        if not ok then trace.scan='error'; return nil,nil,'aura-unknown' end
        if issecretvalue and issecretvalue(raw) then complete=false
        elseif raw==nil then
            trace.scan=complete and 'absent' or 'partial'
            if complete then return false,nil,'aura-absent' end
            return nil,nil,'aura-unknown'
        elseif type(raw)=='table' then
            local id=A.num(A.field(raw,'spellId'))
            -- An exact localized public name is also usable if only the ID is secret.
            local match=id==S.Data.procID or (not id and type(name)=='string' and A.field(raw,'name')==name)
            if match then
                trace.scan='present'; return true,A.procRecord(raw,true),'aura-scan'
            end
            if not id then complete=false end
        else complete=false end
    end
    trace.scan='incomplete'; return nil,nil,'aura-unknown'
end
-- PLAYER is evaluated by the client, so masked sourceUnit does not discard our
-- actual debuffs. Opaque clocks go straight to native widgets, never arithmetic.
function A.enemyAuraNames()
    if A.dotAuraNames then return A.dotAuraNames end
    local names,families={},{}
    for id,entry in pairs(S.Data.spells) do
        local family=S.Data.dotFamilies[id] or id
        if entry.periodic or S.Data.dotGroups[id] or family==689 or family==1120 or family==5138 or family==1316697 then
            families[family]=true
        end
    end
    local seen={}
    for id in pairs(families) do
        local info=C_Spell and A.call(C_Spell.GetSpellInfo,id)
        local name=A.field(info,'name')
        if type(name)=='string' and name~='' and not seen[name] then names[#names+1]=name; seen[name]=true end
    end
    table.sort(names); A.dotAuraNames=names
    return names
end
function A.enemyAuras(unit,diagnostic)
    if not diagnostic and S.NativeDots and S.NativeDots.active and
        C_Secrets and A.call(C_Secrets.ShouldAurasBeSecret)==true then
        return {},false
    end
    local trace=diagnostic and {raw={},player={},names={},clock={}} or nil
    local all,complete=A.auras(unit,'HARMFUL',true,trace and trace.raw)
    all=all or {}
    local api=C_UnitAuras or {}
    local function consume(raw,route)
        if type(raw)~='table' then auraTrace(route,'invalid'); return end
        auraTrace(route,'records')
        local id=A.num(A.field(raw,'spellId'))
        local instance=A.num(A.field(raw,'auraInstanceID'))
        if not id then auraTrace(route,'idUnreadable') end
        if not instance then auraTrace(route,'instanceUnreadable') end
        local source=A.field(raw,'sourceUnit')
        local foreign=source and A.call(UnitIsUnit,source,'player')==false and A.call(UnitIsUnit,source,'pet')~=true
        if foreign then auraTrace(route,'foreign'); return end
        local entry=id and S.Data.spells[id]
        if entry and not (entry.periodic or entry.channel or S.Data.dotGroups[id]) then auraTrace(route,'unsupported'); return end
        local duration=A.num(A.field(raw,'duration'))
        local expires=A.num(A.field(raw,'expirationTime'))
        local effect
        if id and duration and duration>0 and expires and expires>0 then
            effect={id=id,instance=instance,own=true,ownerKnown=true,generic=entry==nil,duration=duration,expires=expires,
                name=A.field(raw,'name'),icon=A.field(raw,'icon')}
        else
            auraTrace(route,'clockUnreadable')
            local clock
            local ct=trace and trace.clock
            if not instance then auraTrace(ct,'noInstance')
            elseif type(api.GetAuraDuration)~='function' then auraTrace(ct,'unavailable')
            else
                local ok,value=pcall(api.GetAuraDuration,unit,instance)
                if not ok then auraTrace(ct,'failed'); auraError(ct,value)
                elseif issecretvalue and issecretvalue(value) then auraTrace(ct,'masked')
                elseif value==nil then auraTrace(ct,'empty')
                else clock=value; auraTrace(ct,'accepted') end
            end
            if clock then
                effect={id=id or 0,instance=instance,own=true,ownerKnown=true,native=true,
                    nativeDuration=clock,nativeName=raw.name,nativeIcon=raw.icon}
            end
        end
        if effect then
            for j=#all,1,-1 do
                if (instance and all[j].instance==instance) or (not instance and id and all[j].id==id and all[j].own) then table.remove(all,j) end
            end
            all[#all+1]=effect; auraTrace(route,'accepted')
        end
    end
    local function scanResult(ok,raw,route)
        if not ok then auraTrace(route,'failed'); auraError(route,raw); return 'error' end
        if issecretvalue and issecretvalue(raw) then auraTrace(route,'masked'); return 'masked' end
        if raw==nil then auraTrace(route,'ended'); return 'empty' end
        consume(raw,route); return 'record'
    end
    local lookup=api.GetAuraDataByIndex
    if type(lookup)=='function' then
        for i=1,255 do
            local ok,raw=pcall(lookup,unit,i,'HARMFUL|PLAYER')
            local status=scanResult(ok,raw,trace and trace.player)
            if status=='error' or status=='empty' then break end
            -- A masked entry says nothing about the following entries.
        end
    else auraTrace(trace and trace.player,'unavailable') end
    local own=false
    for _,effect in ipairs(all) do if effect.own then own=true; break end end
    -- Try exact client-localized names only when indexed reads found no owned
    -- effect. The native PLAYER filter still supplies the ownership proof.
    -- While the native engine draws the DoTs, this public fallback is not shown.
    local native=not diagnostic and S.NativeDots and S.NativeDots.active
    if native then
    elseif not own and type(api.GetAuraDataBySpellName)=='function' then
        for _,name in ipairs(A.enemyAuraNames()) do
            local ok,raw=pcall(api.GetAuraDataBySpellName,unit,name,'HARMFUL|PLAYER')
            scanResult(ok,raw,trace and trace.names)
        end
    elseif not own then auraTrace(trace and trace.names,'unavailable') end
    return all,complete,trace
end
function A.groupUnits()
    local units={'player','pet'}
    local raid=A.call(IsInRaid)==true
    local count=A.num(A.call(GetNumGroupMembers)) or 0
    for i=1,math.min(raid and 40 or 4,raid and count or math.max(0,count-1)) do
        units[#units+1]=(raid and 'raid' or 'party')..i
        units[#units+1]=(raid and 'raidpet' or 'partypet')..i
    end
    return units
end
function A.groupEngaged(token,auras,units)
    if A.call(UnitAffectingCombat,token)~=true then return false end
    units=units or A.groupUnits()
    for _,a in ipairs(auras or {}) do
        if a.own and (not a.expires or a.expires>GetTime()) then return true end
    end
    for _,member in ipairs(units) do
        local threat=A.num(A.call(UnitThreatSituation,member,token))
        if threat and threat>=0 and threat<=3 then return true end
        if A.call(UnitIsUnit,token..'target',member)==true then return true end
        for _,a in ipairs(auras or {}) do
            if a.source and A.call(UnitIsUnit,a.source,member)==true and
                (not a.expires or a.expires>GetTime()) then return true end
        end
    end
    return false
end
-- Identity of a nameplate unit. When the client hides its GUID, the token
-- itself is the identity (prefix "plate:"): valid while the plate exists.
-- Selection outline of an enemy card. Public GUIDs decide directly; otherwise
-- the plate token is compared with the target natively. A secret answer never
-- reaches a Lua branch: it only drives the outline's alpha.
function A.outlineTarget(frame,u,enabled)
    if not enabled then frame:Hide(); return end
    if u.targetKnown~=false and u.target==true then frame:SetAlpha(1); frame:Show(); return end
    if u.targetKnown then frame:Hide(); return end
    local ok,same=false,nil
    if u.token and UnitIsUnit then ok,same=pcall(UnitIsUnit,u.token,'target') end
    if ok and issecretvalue and issecretvalue(same) then
        if frame.SetAlphaFromBoolean and pcall(frame.SetAlphaFromBoolean,frame,same,1,0) then frame:Show(); return end
    elseif ok and same==true then frame:SetAlpha(1); frame:Show(); return end
    frame:Hide()
end
function A.sameUnit(token,guid)
    if type(guid)=='string' and guid:sub(1,6)=='plate:' then
        return guid:sub(7)==token and S.plates[token]==true and A.call(UnitExists,token)~=false
    end
    return A.guid(token)==guid
end
local function reject(reason) if S.unitReasons then S.unitReasons[reason]=(S.unitReasons[reason] or 0)+1 end end
local function masked(kind) if S.unitMasked then S.unitMasked[kind]=(S.unitMasked[kind] or 0)+1 end end
-- Unit names can be secret in combat: Lua cannot read them, but a FontString
-- can display them. Keep the raw value aside and hand it to the widget only.
function A.setName(fs,u,suffix)
    suffix=suffix or ''
    fs:SetText(u.name..suffix)
    if u.nativeName==nil then return end
    if not (suffix~='' and pcall(function() fs:SetText(u.nativeName..suffix) end)) then pcall(fs.SetText,fs,u.nativeName) end
end
function A.unit(token,groupUnits)
    -- Nameplates can be forbidden to addons (instances): GetNamePlateForUnit then
    -- returns nil while the nameplate unit token stays fully usable.
    if not S.plates[token] or A.call(UnitExists,token)==false then reject('absent'); return nil end
    local guid=A.guid(token)
    if type(guid)~='string' then guid='plate:'..token; masked('guid') end
    local attackable=A.call(UnitCanAttack,'player',token)
    if attackable==nil then attackable=A.call(UnitIsFriend,'player',token)==false end
    local combat=A.call(UnitAffectingCombat,token)==true
    local dead=A.call(UnitIsDeadOrGhost,token)==true
    if attackable~=true then reject('notAttackable'); return nil end
    if S.db.enemiesCombatOnly and not combat then reject('notInCombat'); return nil end
    if dead then reject('dead'); return nil end
    local hp,max=A.num(A.call(UnitHealth,token)),A.num(A.call(UnitHealthMax,token))
    if not hp or not max or max<=0 then hp=nil; max=nil end
    local all,complete=A.enemyAuras(token)
    -- Target/focus may expose public auras that the nameplate view omits.
    -- Check identity both before and after reading an alias to avoid recycled tokens.
    local combined={}; local seen={}
    local function append(list)
        for _,a in ipairs(list or {}) do
            local key=tostring(a.id)..':'..tostring(a.instance)..':'..tostring(a.own)
            local index=seen[key]
            if not index then combined[#combined+1]=a; seen[key]=#combined
            elseif not combined[index].expires and a.expires then combined[index]=a end
        end
    end
    append(all)
    local removalKnown=false
    local native=S.NativeDots and S.NativeDots.active
    for _,alias in ipairs({'target','focus','mouseover'}) do
        if not native and alias~=token and A.guid(alias)==guid then
            local extra,known=A.enemyAuras(alias)
            if A.guid(alias)==guid then
                append(extra)
                if alias=='target' then removalKnown=known==true end
            end
        end
    end
    local effects,channelAuras={},{}
    for _,a in ipairs(combined) do
        local entry=S.Data.spells[a.id]
        if a.native or a.generic or (entry and (entry.periodic or S.Data.dotGroups[a.id] or (S.db.dotChannels and S.Tracker.channelSupported(a.id))) and a.own) then
            if not (entry and entry.channel and not S.db.dotChannels) then effects[#effects+1]=a end
        end
        if a.own and S.Tracker.channelSupported(a.id) then channelAuras[a.id]=a end
    end
    if not A.sameUnit(token,guid) then reject('recycled'); return nil end
    -- Default: only enemies engaged with me, my pet, group or raid. Unchecked:
    -- every attackable enemy whose nameplate is visible.
    if S.db.enemiesCombatOnly and not A.groupEngaged(token,combined,groupUnits) then reject('notEngaged'); return nil,guid end
    local okName,rawName=pcall(UnitName,token)
    local name,nativeName=okName and A.public(rawName),nil
    if okName and rawName~=nil and name==nil then nativeName=rawName; masked('name') end
    return {guid=guid,name=type(name)=='string' and name or '?',nativeName=nativeName,attackable=attackable,combat=combat,
        dead=false,hp=hp,max=max,aurasKnown=complete==true or removalKnown,
        auraRemovalKnown=removalKnown or (complete==true and A.call(UnitIsUnit,token,'target')==true),
        effects=S.Model.effects(effects,GetTime()),channelAuras=channelAuras,target=A.call(UnitIsUnit,token,'target')==true}
end
function A.channel()
    if not UnitChannelInfo then return nil end
    local ok,name,_,icon,startMs,endMs,_,_,id=pcall(UnitChannelInfo,'player')
    name=A.public(name); id=A.num(id); startMs=A.num(startMs); endMs=A.num(endMs)
    if not ok or not id or not startMs or not endMs or endMs<=startMs then return nil end
    local spellName,spellIcon=A.spell(id)
    return {id=id,name=name or spellName,icon=A.public(icon) or spellIcon,start=startMs/1000,finish=endMs/1000}
end
function A.catalogue()
    local ids={}
    for id in pairs(S.Data.spells) do ids[id]=true end
    for id in pairs(S.SpellData and S.SpellData.spells or {}) do ids[id]=true end
    if C_SpellBook then
        local n=A.num(A.call(C_SpellBook.GetNumSpellBookSkillLines)) or 0
        -- General is not the warlock catalogue. Modern professions have their own book.
        for i=2,math.min(n,40) do
            local line=A.call(C_SpellBook.GetSpellBookSkillLineInfo,i)
            local offset=A.num(A.field(line,'itemIndexOffset'))
            local count=A.num(A.field(line,'numSpellBookItems'))
            if offset and count then
                for slot=offset+1,offset+math.min(count,500) do
                    local info=A.call(C_SpellBook.GetSpellBookItemInfo,slot,0)
                    local id=A.num(A.field(info,'spellID'))
                    if id then ids[id]=true end
                end
            end
        end
    end
    local rows={}
    for id in pairs(ids) do
        local info=C_Spell and A.call(C_Spell.GetSpellInfo,id)
        if info then
            local entry=S.Data.spells[id] or {kind='unclassified',school='unknown',source='spellbook'}
            local spec=S.SpellData and S.SpellData.spells[id]
            if spec and not S.Data.spells[id] then
                entry={kind=spec.effects[1].periodic and 'periodic' or 'direct',
                    school=spec.school==3 and 'fire' or (spec.school==6 and 'shadow' or 'unknown'),source='spSource'}
            end
            rows[#rows+1]={id=id,name=A.field(info,'name') or ('#'..id),icon=A.field(info,'iconID'),data=entry}
        end
    end
    table.sort(rows,function(a,b) if a.name~=b.name then return a.name<b.name end return a.id<b.id end)
    return rows
end
