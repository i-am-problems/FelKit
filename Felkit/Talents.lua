local _,S=...
local T={}; S.Talents=T
local A,L,D=S.API,S.L,S.TalentData
local byKey={}
for _,t in ipairs(D.talents) do byKey[t.key]=t end
local function integer(v,lo,hi)
    v=A.num(v)
    return v and v>=lo and v<=hi and v==math.floor(v) and v or nil
end
local function contains(list,value)
    list=A.public(list)
    if type(list)~='table' then return false end
    for _,v in ipairs(list) do if A.public(v)==value then return true end end
    return false
end
local function value(t,index,rank)
    for _,m in ipairs(t.mods) do if m.index==index then return m.values[rank] end end
end
local function label(t,rank)
    local name=A.spell(t.spell)
    if name=='#'..t.spell then name=t.name end
    return name..' '..rank..'/'..t.max
end

-- Read the committed active tree each time: preview ranks, API failure and
-- restricted values must never turn into zero ranks or stale cached bonuses.
function T.read()
    local c,api=C_ClassTalents,C_Traits
    if not c or not api then return nil end
    local config=integer(A.call(c.GetActiveConfigID),1,100000000)
    if not config or A.call(api.ConfigHasStagedChanges,config)~=false then return nil end
    local info=A.call(api.GetConfigInfo,config)
    if not contains(A.field(info,'treeIDs'),D.tree) then return nil end
    local out={ranks={},auras={}}
    local needsBuffs=false
    for _,t in ipairs(D.talents) do
        local node=A.call(api.GetNodeInfo,config,t.node)
        if not contains(A.field(node,'entryIDs'),t.entry) then return nil end
        local entry=A.call(api.GetEntryInfo,config,t.entry)
        if A.num(A.field(entry,'definitionID'))~=t.definition then return nil end
        local definition=A.call(api.GetDefinitionInfo,t.definition)
        if A.num(A.field(definition,'spellID'))~=t.spell then return nil end
        local rank=integer(A.field(node,'activeRank'),0,t.max)
        if rank==nil then return nil end
        if rank>0 then
            local active=A.field(node,'activeEntry')
            if A.num(A.field(active,'entryID'))~=t.entry or
                integer(A.field(active,'rank'),0,t.max)~=rank then return nil end
        end
        out.ranks[t.key]=rank
        if t.kind=='buff' and rank>0 then needsBuffs=true end
    end
    if needsBuffs then
        local auras=A.auras('player','HELPFUL')
        if not auras then out.auras=nil
        else for _,a in ipairs(auras) do out.auras[a.id]=true end end
    end
    if A.call(c.GetActiveConfigID)~=config or A.call(api.ConfigHasStagedChanges,config)~=false then return nil end
    return out
end

function T.modifier(state,e,school)
    local out={factor=nil,applied={},notes={}}
    if not state then out.notes[1]=L.talUnknown; return out end
    local sum,buffs=0,1
    for _,t in ipairs(D.talents) do
        local rank=state.ranks[t.key]
        if rank and rank>0 then
            for _,m in ipairs(t.mods) do
                if contains(m.matches,e.effectID) then
                    if t.kind=='passive' then
                        sum=sum+m.values[rank]
                        out.applied[#out.applied+1]=label(t,rank)..' +'..m.values[rank]..'%'
                    elseif t.kind=='critical' then
                        out.notes[#out.notes+1]=label(t,rank)..': '..L.talCritical
                    elseif t.kind=='casting' then
                        out.notes[#out.notes+1]=label(t,rank)..': '..L.talCasting
                    end
                end
            end
        end
    end
    local unknownBuff=false
    for _,b in ipairs(D.buffs) do
        local t=byKey[b.talent]; local rank=state.ranks[t.key]
        if rank>0 and (b.school==0 or b.school==school) then
            if not state.auras then unknownBuff=true
            elseif state.auras[b.id] then
                local bonus=b.value or value(t,b.index,rank)
                buffs=buffs*(1+bonus/100)
                out.applied[#out.applied+1]=label(t,rank)..' +'..bonus..'% ('..L.talActive..')'
            end
        end
    end
    -- This other Master Demonologist aura exists in DB2 but its activation
    -- contract is unqualified. Do not silently equate it with the pet variants.
    if state.auras and state.auras[1214101] then unknownBuff=true end
    if unknownBuff then out.notes[#out.notes+1]=L.talBuffUnknown
    else out.factor=(1+sum/100)*buffs end
    local function conditional(key,applies,message)
        local t=byKey[key]; local rank=state.ranks[key]
        if rank>0 and applies then
            out.notes[#out.notes+1]=label(t,rank)..': '..string.format(message,t.mods[1].values[rank])
        end
    end
    conditional('decimation',contains(byKey.decimation.mods[1].matches,e.effectID),L.talDecimation)
    conditional('siphon',contains(byKey.drains.mods[1].matches,e.effectID),L.talSiphon)
    conditional('shadowBolt',school==6,L.talShadowBolt)
    conditional('amplify',contains(byKey.amplify.mods[1].matches,e.effectID),L.talAmplify)
    if state.ranks.knowledge>0 then out.notes[#out.notes+1]=L.talKnowledge end
    return out
end
