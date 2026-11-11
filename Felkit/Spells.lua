local _,S=...
local P={}; S.Spells=P
local A,L=S.API,S.L
local function finite(n) return type(n)=='number' and n==n and n~=math.huge and n~=-math.huge end
-- Public out-of-combat inputs form a coherent reference, never a claim about
-- hidden live stats/auras. Keep it in memory only, and discard on invalid reads
-- outside combat (respec, equipment transition, zoning, unsupported build).
local references={}
-- The pinned DB2 build, or a later hotfix build of the same client version:
-- Blizzard bumps the build number on hotfixes without touching these rows
-- (70425 -> 70450 changed none), so a hotfix must not hide every calculation.
function P.buildMatches(version,build)
    version=A.public(version); build=A.public(build)
    if version==nil or build==nil then return false end
    if tostring(version)..'.'..tostring(build)==S.SpellData.build then return true end
    local pinnedVersion,pinnedBuild=S.SpellData.build:match('^(.*)%.(%d+)$')
    local n=tonumber(build)
    return tostring(version)==pinnedVersion and n~=nil and n>=tonumber(pinnedBuild)
end
local function supported() return P.buildMatches(GetBuildInfo()) end
local function readInputs()
    local spirit
    if type(UnitStat)=='function' then
        local ok,_,effective=pcall(UnitStat,'player',5)
        if ok then spirit=A.num(effective) end
    end
    return {level=A.num(A.call(UnitLevel,'player')),spirit=spirit,
        powers={[3]=A.num(A.call(GetSpellBonusDamage,3)),[6]=A.num(A.call(GetSpellBonusDamage,6))},
        talents=S.Talents.read()}
end
local function complete(input,key)
    local stat=key=='spirit' and input.spirit or input.powers[key]
    return finite(input.level) and input.level>0 and finite(stat) and stat>=0
        and input.talents and (key=='spirit' or input.talents.auras~=nil)
end
function P.clearReference() references={} end
function P.captureReference()
    if A.combat() then return end
    if not supported() then P.clearReference(); return end
    local input=readInputs()
    for _,key in ipairs({3,6,'spirit'}) do references[key]=complete(input,key) and input or nil end
end
function P.inputs(key)
    local input=readInputs()
    if not supported() then P.clearReference(); return input end
    local valid=complete(input,key)
    if not A.combat() then
        references[key]=valid and input or nil
    elseif not valid and references[key] then
        return references[key],true
    end
    return input,false
end
function P.component(e,spec,level,power)
    local out={coefficient=e.coefficient,periodic=e.periodic,variable=e.variable}
    if not finite(out.coefficient) or out.coefficient<0 then out.coefficient=nil end
    if finite(power) and out.coefficient then out.bonus=power*out.coefficient end
    if finite(level) and level>=spec.level and finite(e.base) and finite(e.perLevel) then
        local cap=spec.maxLevel>0 and spec.maxLevel or 60
        local growth=math.max(0,math.min(level,cap)-spec.level)*e.perLevel
        -- DB2 float base with symmetric variance; level growth is additive.
        out.low=e.base*(1-e.variance/2)+growth
        out.high=e.base*(1+e.variance/2)+growth
        if out.bonus then out.totalLow=out.low+out.bonus; out.totalHigh=out.high+out.bonus end
    end
    if e.periodic and (not e.variable or e.average) and finite(e.duration) and finite(e.interval) and e.interval>0 then
        local n=e.duration/e.interval
        if n>0 and n==math.floor(n) then out.ticks=n end
    end
    return out
end
function P.lifeTap(id)
    local spec=S.SpellData.lifeTap[id]
    if not spec then return end
    local input,reference=P.inputs('spirit')
    local level,spirit=input.level,input.spirit
    if not finite(spirit) or spirit<0 then spirit=nil end
    local state=input.talents
    local rank=state and state.ranks.lifeTap
    local bonus
    if rank then
        bonus=0
        for _,t in ipairs(S.TalentData.talents) do
            if t.key=='lifeTap' and rank>0 then bonus=t.mods[1].values[rank] end
        end
    end
    local base
    if finite(level) and level>=spec.level then
        base=spec.base+math.max(0,math.min(level,spec.maxLevel)-spec.level)*spec.perLevel
    end
    local before=base and spirit and base+spirit
    local total=before and bonus and before*(1+bonus/100)
    return {base=base,spirit=spirit,rank=rank,bonus=bonus,total=total,gain=before and bonus and before*bonus/100,reference=reference}
end
-- Locale-free DoT profile keyed by spell ID: DB2 duration/interval and the same
-- component/talent model as the grimoire. No client text is read, so every
-- language gets the same values. Unknown inputs leave the total unknown.
function P.periodic(id)
    local spec=S.SpellData.spells[id]
    if not spec or not supported() then return nil end
    local input=P.inputs(spec.school)
    local power=input.powers[spec.school]
    if not finite(power) then power=nil end
    local duration,interval,count,total
    for _,e in ipairs(spec.effects) do
        if e.periodic then
            local c=P.component(e,spec,input.level,power)
            local factor=S.Talents.modifier(input.talents,e,spec.school).factor
            duration=duration or e.duration; interval=interval or e.interval; count=count or c.ticks
            if total~=false and c.ticks and c.totalLow and factor then
                total=(total or 0)+(c.totalLow+c.totalHigh)/2*c.ticks*factor
            else total=false end
        end
    end
    if not finite(duration) or duration<=0 or duration>600 then return nil end
    if not finite(interval) or interval<=0 or interval>duration then interval=nil end
    return {duration=duration,interval=interval,count=count,total=total or nil,source='spell-data'}
end
local function fmt(n) return finite(n) and string.format('%.1f',n) or '?' end
local function range(lo,hi)
    if not finite(lo) or not finite(hi) then return '?' end
    if math.abs(lo-hi)<0.05 then return fmt(lo) end
    return fmt(lo)..'–'..fmt(hi)
end
local function line(baseLow,baseHigh,coefficient,bonus,totalLow,totalHigh,factor)
    return '('..L.spBase..' '..range(baseLow,baseHigh)..' + '..L.spBonus..' '..fmt(bonus)..
        ' ('..fmt(coefficient and coefficient*100)..'% SP)) × '..
        (factor and string.format('%.3f',factor) or '?')..' = '..
        range(factor and totalLow and totalLow*factor,factor and totalHigh and totalHigh*factor)
end
function P.text(id,kind,compact)
    local spec=S.SpellData.spells[id]
    local version,build=GetBuildInfo()
    if A.public(version)==nil or A.public(build)==nil then return L.spMismatch end
    local source=L.spSource..' '..S.SpellData.build
    if not P.buildMatches(version,build) then return source..'\n'..L.spMismatch end
    if S.SpellData.lifeTap[id] then
        local rows={L.tapHeading}
        for _,r in ipairs(P.summary(id,kind,true)) do rows[#rows+1]=r.label..(r.value and (': '..r.value) or '') end
        return table.concat(rows,'\n')
    end
    if not spec then
        return source..'\n'..((kind=='utility' or kind=='proc') and L.na or L.spUnsupported)
    end
    local input,reference=P.inputs(spec.school)
    local power=input.powers[spec.school]
    if not finite(power) then power=nil end
    local level=input.level
    local rows={L.spHeading,source,L.spPower..' '..fmt(power)..' | '..L.spLevel..' '..fmt(level)}
    if reference then rows[#rows+1]=L.spCombatReference end
    local talents=input.talents
    local sumLow,sumHigh=0,0
    local complete=true
    for _,e in ipairs(spec.effects) do
        local c=P.component(e,spec,level,power)
        local talent=S.Talents.modifier(talents,e,spec.school)
        local factor=talent.factor
        rows[#rows+1]=''
        rows[#rows+1]=e.periodic and (e.average and L.spAverageTick or (e.variable and L.spVariable or L.spTick)) or L.spDirect
        rows[#rows+1]=line(c.low,c.high,c.coefficient,c.bonus,c.totalLow,c.totalHigh,factor)
        rows[#rows+1]=L.talApplied..': '..(#talent.applied>0 and table.concat(talent.applied,', ') or
            (factor and L.talNone or L.unknown))
        rows[#rows+1]=L.talEffective..': '..fmt(factor and c.bonus and c.bonus*factor)..
            ' ('..fmt(factor and c.coefficient and c.coefficient*factor*100)..'% SP)'
        local n=e.periodic and c.ticks or 1
        if e.periodic then
            if c.ticks then
                rows[#rows+1]=string.format(L.spTiming,c.ticks,fmt(e.interval),fmt(e.duration))
                rows[#rows+1]=L.spPeriodicTotal..': '..line(c.low and c.low*n,c.high and c.high*n,
                    c.coefficient and c.coefficient*n,c.bonus and c.bonus*n,
                    c.totalLow and c.totalLow*n,c.totalHigh and c.totalHigh*n,factor)
            else rows[#rows+1]=L.spUnequal; n=nil end
        end
        for _,note in ipairs(talent.notes) do rows[#rows+1]=note end
        if n and c.totalLow and factor then
            sumLow=sumLow+c.totalLow*n*factor; sumHigh=sumHigh+c.totalHigh*n*factor
        else complete=false end
    end
    if #spec.effects>1 then
        rows[#rows+1]='\n'..L.spCombined..': '..(complete and
            range(sumLow,sumHigh) or L.unknown)
    end
    return table.concat(rows,'\n')
end

-- Area spells (Rain of Fire, Hellfire): totals are per target hit.
P.aoe={[5740]=true,[6219]=true,[11677]=true,[11678]=true,[1949]=true,[11683]=true,[11684]=true}
-- Compact presentation only: the same component/talent model supplies every
-- value. Verbose provenance, formulas and conditional talents stay on Shift.
function P.summary(id,kind,details)
    local rows={}
    local function row(label,value,tone) rows[#rows+1]={label=label,value=value,tone=tone} end
    if not P.buildMatches(GetBuildInfo()) then
        row(L.spMismatch,nil,'warning'); return rows
    end
    if S.SpellData.lifeTap[id] then
        local c=P.lifeTap(id)
        -- Result first, then what it is made of: base + Spirit, then the talent.
        -- The game's own tooltip already states the mana and health amounts: the
        -- compact card shows only what they are made of; the detail window keeps both.
        local pad=details and '  ' or ''
        if details then row(L.tapMana,fmt(c.total),'hero'); row(L.tapHealth,c.total and ('−'..fmt(c.total)) or '?','health') end
        row(pad..L.spBase,fmt(c.base),'value'); row(pad..L.tapSpirit,'+'..fmt(c.spirit)..(details and ' (100%)' or ''),'mana')
        if c.rank then
            row(pad..L.tapTalent..' '..c.rank..'/2',c.rank>0 and c.bonus and ('+'..fmt(c.bonus)..'%  (+'..fmt(c.gain)..')') or '—',
                c.rank>0 and 'talent' or 'muted')
        end
        if details then
            -- Detail window and Shift text keep the full calculation.
            row(L.tapFormula,'('..fmt(c.base)..' + '..fmt(c.spirit)..') × '..
                (c.bonus and string.format('%.2f',1+c.bonus/100) or '?'),'muted')
        end
        if not c.rank then row(L.talUnknown,nil,'warning') end
        if c.reference then row(L.spCombatReference,nil,'muted') end
        return rows
    end
    local spec=S.SpellData.spells[id]
    if not spec then
        row((kind=='utility' or kind=='proc') and L.na or L.spUnsupported,nil,'muted'); return rows
    end
    local input,reference=P.inputs(spec.school)
    local power=input.powers[spec.school]
    if not finite(power) then power=nil end
    local level=input.level
    local state=input.talents
    local components,notices,seen={},{},{}
    local totalLow,totalHigh,complete=0,0,true
    local talentLow,talentHigh=0,0
    local applied,appliedSeen={},{}
    for _,e in ipairs(spec.effects) do
        local c=P.component(e,spec,level,power)
        local t=S.Talents.modifier(state,e,spec.school)
        local lo=t.factor and c.totalLow and c.totalLow*t.factor
        local hi=t.factor and c.totalHigh and c.totalHigh*t.factor
        local n=1
        if e.periodic then n=c.ticks end
        if n and lo then
            totalLow=totalLow+lo*n; totalHigh=totalHigh+hi*n
            talentLow=talentLow+(lo-c.totalLow)*n; talentHigh=talentHigh+(hi-c.totalHigh)*n
        else complete=false end
        for _,name in ipairs(t.applied) do
            if not appliedSeen[name] then applied[#applied+1]=name; appliedSeen[name]=true end
        end
        components[#components+1]={e=e,c=c,t=t,lo=lo,hi=hi}
        if not t.factor then
            local notice=state and L.talBuffUnknown or L.talUnknown
            if not seen[notice] then notices[#notices+1]=notice; seen[notice]=true end
        end
    end
    row(P.aoe[id] and L.spCardTotalAoe or L.spCardTotal,complete and range(totalLow,totalHigh) or '?','hero')
    if details then
        row(L.spTalentGain,complete and ('+'..range(talentLow,talentHigh)) or '?','talent')
        for _,name in ipairs(applied) do row(name,nil,'talent') end
    end
    -- One block per component (direct hit, then over time); its detail rows are
    -- indented under the block's first row.
    local periodic=false
    local baseLow,baseHigh,spSum,coefSum=0,0,0,0
    for i,part in ipairs(components) do
        local e,c,t=part.e,part.c,part.t
        if i>1 and not details then row(' ',nil,'spacer') end
        if e.periodic then
            periodic=true
            if c.ticks then
                row(e.average and L.spAverageTick or L.spCardTick,range(part.lo,part.hi)..' × '..c.ticks,'value')
                row('  '..L.spCardRhythm,fmt(e.interval)..' s  ·  '..fmt(e.duration)..' s '..L.spCardDuration,'muted')
            else row(L.spCardReference,range(part.lo,part.hi),'value') end
        elseif #components>1 then row(L.spCardInitial,range(part.lo,part.hi),'value') end
        row('  '..L.spCardBaseSP,range(c.low,c.high)..' + '..fmt(c.bonus)..' ('..
            fmt(c.coefficient and c.coefficient*100)..'% SP)','sp')
        if not t.factor or math.abs(t.factor-1)>0.000001 then
            row('  '..L.spCardTalents,t.factor and ('+'..fmt((t.factor-1)*100)..'%') or '?','talent')
        end
        row('  '..L.spCardEffective,fmt(t.factor and c.bonus and c.bonus*t.factor)..' ('..
            fmt(t.factor and c.coefficient and c.coefficient*t.factor*100)..'% SP)','effective')
        if e.periodic and not c.ticks then row(e.variable and L.spCardVariable or L.spUnequal,nil,'warning') end
        local n=e.periodic and c.ticks or 1
        if complete and t.factor and c.low and c.bonus then
            baseLow=baseLow+c.low*t.factor*n; baseHigh=baseHigh+c.high*t.factor*n; spSum=spSum+c.bonus*t.factor*n
            coefSum=coefSum+(c.coefficient or 0)*t.factor*n
        end
    end
    -- DoTs (Immolate included) and area spells: the whole spell split into base
    -- and effective spell power, both after talents, so they add up to the total.
    if (periodic or P.aoe[id]) and complete then
        if not details then row(' ',nil,'spacer') end
        -- The whole spell's share of spell power, after talents.
        row(P.aoe[id] and L.spCardSumAoe or L.spCardSum,range(baseLow,baseHigh)..' + '..fmt(spSum)..' ('..fmt(coefSum*100)..'% SP)','sum')
    end
    for _,notice in ipairs(notices) do row(notice,nil,'warning') end
    if reference then row(L.spCombatReference,nil,'muted') end
    return rows
end

-- The client calls post processors before Show(). Only annotate the primary
-- spell tooltip, never a spell embedded in an item/unit tooltip. No native text
-- is read, replaced or used as a base damage input.
local annotated=setmetatable({},{__mode='k'})
local hooked=setmetatable({},{__mode='k'})
-- Value colours inside one line: base white, spell power blue, effective spell
-- power coral, and every "(x% SP)" share dimmed.
local SP,EFFECTIVE,DIM='|cff5cc8ff','|cffff6a55','|cff9890ad'
function P.paint(value,tone)
    if type(value)~='string' then return value end
    if tone=='sp' or tone=='sum' then
        local base,bonus,share=value:match('^(.-) %+ (.-) (%(.-%))$')
        if base then return base..' + '..(tone=='sum' and EFFECTIVE or SP)..bonus..'|r '..DIM..share..'|r' end
    elseif tone=='effective' then
        local bonus,share=value:match('^(.-) (%(.-%))$')
        if bonus then return bonus..' '..DIM..share..'|r' end
    end
    return value
end
local enlarged=setmetatable({},{__mode='k'})
-- Game fonts have no bold face: an outlined copy reads as bold.
local function boldFont(name,base,extra)
    if not CreateFont or not base or type(base.GetFont)~='function' then return nil end
    local font=_G[name] or CreateFont(name)
    local path,size=base:GetFont()
    if not path or not size or font:SetFont(path,size+(extra or 0),'OUTLINE')==false then return nil end
    return font
end
local function setFont(tip,side,font)
    local name=A.call(tip.GetName,tip); local n=A.num(A.call(tip.NumLines,tip))
    if type(name)~='string' or not n or not font then return end
    local region=_G[name..side..n]
    if region and type(region.SetFontObject)=='function' then
        region:SetFontObject(font)
        enlarged[tip]=enlarged[tip] or {}; table.insert(enlarged[tip],region)
    end
end
-- The total stands out: header-sized label, header-sized bold figure.
local function enlarge(tip)
    if not GameTooltipHeaderText or not GameTooltipText then return end
    P.heroFont=P.heroFont or boldFont('FelkitTooltipHero',GameTooltipHeaderText,1)
    setFont(tip,'TextLeft',GameTooltipHeaderText)
    setFont(tip,'TextRight',P.heroFont or GameTooltipHeaderText)
end
-- Spell power (blue) and effective spell power (red) values in bold.
local function embolden(tip)
    if not GameTooltipText then return end
    P.boldFont=P.boldFont or boldFont('FelkitTooltipBold',GameTooltipText)
    setFont(tip,'TextRight',P.boldFont)
end
function P.tooltip(tip,data)
    -- Tooltip cards belong to the grimoire module: off with it.
    if not S.ready or not S.db.enabled or not S.db.grimoire or not S.db.spellTooltips then return end
    if not tip or (tip~=GameTooltip and tip~=ItemRefTooltip) then return end
    data=A.public(data)
    local id=A.num(A.field(data,'id'))
    if not id or id<=0 or id>100000000 or id~=math.floor(id) then return end
    local spec=S.SpellData.spells[id]
    local entry=S.Data.spells[id]
    if not spec and not entry then return end
    local getter=tip.GetPrimaryTooltipData or tip.GetTooltipData
    local primary=A.call(getter,tip)
    if A.field(primary,'type')~=Enum.TooltipDataType.Spell or A.num(A.field(primary,'id'))~=id then return end
    P.annotate(tip,id,entry)
end
-- Adds the card below a spell tooltip once (cleared with the tooltip).
function P.annotate(tip,id,entry)
    if not hooked[tip] then
        tip:HookScript('OnTooltipCleared',function(self)
            annotated[self]=nil
            -- Lines are reused by every tooltip: give back the normal font.
            for _,region in ipairs(enlarged[self] or {}) do region:SetFontObject(GameTooltipText) end
            enlarged[self]=nil
        end)
        hooked[tip]=true
    end
    if annotated[tip] then return end
    annotated[tip]=true
    tip:AddLine(' ')
    if A.call(IsShiftKeyDown)==true then
        for line in (P.text(id,entry and entry.kind,true)..'\n'):gmatch('(.-)\n') do
            if line==L.spHeading then tip:AddLine('FelKit: '..line,0.78,0.55,1,true)
            else tip:AddLine(line=='' and ' ' or line,0.88,0.88,0.92,true) end
        end
    else
        local colors={hero={1,0.92,0.1},health={1,0.4,0.42},value={1,1,1},sp={1,1,1},mana={0.45,0.7,1},
            talent={0.45,0.95,0.55},muted={0.62,0.6,0.7},warning={1,0.72,0.32},effective={1,0.42,0.33},sum={1,1,1}}
        for _,r in ipairs(P.summary(id,entry and entry.kind)) do
            local color=colors[r.tone] or colors.value
            if r.tone=='spacer' then tip:AddLine(' ')
            elseif r.value and type(tip.AddDoubleLine)=='function' then
                local hero=r.tone=='hero'
                -- Labels: block rows bright, indented detail rows softer, the final sum warm.
                local lr,lg,lb=0.84,0.8,0.94
                if hero then lr,lg,lb=1,0.82,0
                elseif r.tone=='sum' then lr,lg,lb=0.98,0.82,0.5
                elseif r.label:sub(1,2)=='  ' then lr,lg,lb=0.66,0.63,0.78 end
                tip:AddDoubleLine(r.label,P.paint(r.value,r.tone),lr,lg,lb,color[1],color[2],color[3])
                if hero then enlarge(tip)
                elseif r.tone=='sp' or r.tone=='effective' or r.tone=='sum' then embolden(tip) end
            else
                tip:AddLine(r.label..(r.value and ('  '..r.value) or ''),color[1],color[2],color[3],true)
            end
        end
    end
end
-- Action bar macros with #showtooltip: the game shows the spell, but the
-- tooltip data describes the macro. Resolve the macro's spell and add the card.
function P.actionTooltip(tip,slot)
    if not S.ready or not S.db.enabled or not S.db.grimoire or not S.db.spellTooltips or tip~=GameTooltip then return end
    if not GetActionInfo or not GetMacroSpell then return end
    local ok,kind,macro=pcall(GetActionInfo,slot)
    if not ok or A.public(kind)~='macro' then return end
    local spell=A.num(A.call(GetMacroSpell,A.public(macro)))
    if not spell then return end
    local entry=S.Data.spells[spell]
    if not S.SpellData.spells[spell] and not entry then return end
    if annotated[tip] then return end
    P.annotate(tip,spell,entry)
    tip:Show() -- resize to the added lines
end
function P.hintMatches(tip,text)
    if not S.ready or not S.db.enabled or (tip~=GameTooltip and tip~=ItemRefTooltip) then return false end
    text=A.public(text)
    local hint=A.public(SPELLBOOK_SPELL_NOT_ON_ACTION_BAR)
    if type(text)~='string' or type(hint)~='string' or text~=hint then return false end
    local data=A.call(tip.GetPrimaryTooltipData or tip.GetTooltipData,tip)
    local id=A.num(A.field(data,'id'))
    return Enum and Enum.TooltipDataType and A.field(data,'type')==Enum.TooltipDataType.Spell
        and id and S.Data.spells[id]~=nil or false
end
function P.suppressBarHint(tip,line)
    if P.hintMatches(tip,A.field(A.public(line),'leftText')) then return true end
end
function P.clearAddedBarHint(tip,text)
    if not P.hintMatches(tip,text) then return end
    local name=A.call(tip.GetName,tip); local n=A.num(A.call(tip.NumLines,tip))
    if type(name)~='string' or not n or n<1 or n>200 or n~=math.floor(n) then return end
    local region=_G[name..'TextLeft'..n]
    if region and type(region.SetText)=='function' then region:SetText('') end
end
function P.setupTooltips()
    if TooltipDataProcessor and TooltipDataProcessor.AllTypes~=nil and not P.hintRegistered and type(TooltipDataProcessor.AddLinePreCall)=='function' then
        P.hintRegistered=pcall(TooltipDataProcessor.AddLinePreCall,TooltipDataProcessor.AllTypes,P.suppressBarHint)
    end
    if type(hooksecurefunc)=='function' then
        P.hintHooks=P.hintHooks or setmetatable({},{__mode='k'})
        for _,tip in ipairs({GameTooltip,ItemRefTooltip}) do
            if not P.hintHooks[tip] and type(tip.AddLine)=='function' then
                P.hintHooks[tip]=pcall(hooksecurefunc,tip,'AddLine',P.clearAddedBarHint)
            end
        end
    end
    if not P.actionHooked and type(hooksecurefunc)=='function' and GameTooltip and type(GameTooltip.SetAction)=='function' then
        P.actionHooked=pcall(hooksecurefunc,GameTooltip,'SetAction',P.actionTooltip)
    end
    if P.tooltipRegistered then return end
    if not TooltipDataProcessor or type(TooltipDataProcessor.AddTooltipPostCall)~='function' or
        not Enum or not Enum.TooltipDataType or not Enum.TooltipDataType.Spell then return end
    local ok=pcall(TooltipDataProcessor.AddTooltipPostCall,Enum.TooltipDataType.Spell,P.tooltip)
    P.tooltipRegistered=ok
end
