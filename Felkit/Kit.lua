local _,S=...
local K={buttons={},flyouts={},queue={},page=1}; S.Kit=K
local A,D,M,L=S.API,S.KitData,S.KitModel,S.L
local utilityStatus={breath=true,invisibility=true,sense=true}
local function known(id)
 return A.call(IsPlayerSpell,id)==true or (C_SpellBook and A.call(C_SpellBook.IsSpellKnown,id)==true)
end
K.isKnown=known
-- A renumbered spell: none of our IDs is learned, so look the learned spell up
-- by the (localized) name of our IDs. Cached until the spell book changes.
K.byName={}
local function byName(family)
 local saved=K.byName[family]
 if saved~=nil then return saved or nil end
 local found=false
 if C_Spell and C_Spell.GetSpellInfo then
  local tried={}
  for _,id in ipairs(D.families[family] or {}) do
   local name=A.spell(id)
   if name and name:sub(1,1)~='#' and not tried[name] then
    tried[name]=true
    local id2=A.num(A.field(A.call(C_Spell.GetSpellInfo,name),'spellID'))
    if id2 and known(id2) then found=id2; break end
   end
  end
 end
 K.byName[family]=found
 return found or nil
end
function K.best(family)
 for _,id in ipairs(D.families[family] or {}) do if known(id) then return id end end
 return byName(family)
end
local function font(p,size)
 local t=p:CreateFontString(nil,'OVERLAY','GameFontNormal')
 t:SetFont(STANDARD_TEXT_FONT or 'Fonts\\FRIZQT__.TTF',size or 11,'OUTLINE'); return t
end
local function backdrop(f)
 f:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Buttons\\WHITE8X8',edgeSize=1})
 f:SetBackdropColor(0.035,0.025,0.055,0.96); f:SetBackdropBorderColor(0.43,0.24,0.60,1)
end
local function tooltip(b)
 GameTooltip:SetOwner(b,'ANCHOR_RIGHT')
 if b:GetAttribute('queueIcon') then
  GameTooltip:SetText(L.kitQueue); GameTooltip:AddLine(L.kitQueueSettings,1,0.85,0.45,true)
  GameTooltip:AddLine(L.kitQueueIconHelp,0.8,0.65,1,true); GameTooltip:Show(); return
 end
 local id=b:GetAttribute('displaySpell')
 if id then GameTooltip:SetSpellByID(id) else GameTooltip:SetText(L.kitUnknown) end
 if b.selectionOnly then
  if utilityStatus[b.family] then
   GameTooltip:AddLine(b.statusEstimated and L.kitStateObserved or b.activeState==true and L.kitStateActive or b.activeState==false and L.kitUtilityInactive or L.kitStateUnknown,0.85,0.8,1,true)
   if b.family~='sense' then GameTooltip:AddLine(L.kitUtilityTarget,0.85,0.8,1,true) end
  end
  GameTooltip:AddLine(L.kitSelectHelp,0.8,0.65,1,true); GameTooltip:Show(); return
 end
 if S.KitStatus.managed[b.group and b.group.key] or b.statusEstimated then
  GameTooltip:AddLine(b.statusEstimated and L.kitStateObserved or b.activeState==true and L.kitStateActive or b.activeState==false and L.kitStateInactive or L.kitStateUnknown,0.85,0.8,1,true)
  if b.group.key=='health' then GameTooltip:AddLine(L.kitHealthCount..': '..(b.healthCount~=nil and tostring(b.healthCount) or '?'),1,1,1,true) end
  if b.group.key=='soul' then GameTooltip:AddLine(L.kitSoulCount..': '..(b.healthCount~=nil and tostring(b.healthCount) or '?'),1,1,1,true) end
 end
 if b:GetAttribute('displayItem') then GameTooltip:AddLine(L.kitUse,0.7,1,0.7,true) end
 if b.group then GameTooltip:AddLine(L.kitClick,0.8,0.65,1,true) end
 if b.group and b.group.stone then GameTooltip:AddLine(b.group.key=='soul' and L.kitSoulBest or b.group.key=='health' and L.kitHealthBest or L.kitCreate,0.8,0.65,1,true) end
 if b.group and b.group.key=='demon' then GameTooltip:AddLine(L.kitDemonShift,0.8,0.65,1,true) end
 GameTooltip:Show()
end
local function action(name,parent,selectionOnly)
 -- Menu entries carry the selected attributes, but have no native action dispatcher.
 local template=selectionOnly and 'SecureHandlerClickTemplate,SecureHandlerStateTemplate,BackdropTemplate' or 'SecureActionButtonTemplate,SecureHandlerStateTemplate,BackdropTemplate'
 local b=CreateFrame('Button',name,parent,template); b.selectionOnly=selectionOnly
 b:SetSize(36,36); backdrop(b)
 b.icon=b:CreateTexture(nil,'ARTWORK'); b.icon:SetPoint('TOPLEFT',2,-2); b.icon:SetPoint('BOTTOMRIGHT',-2,2)
 b.icon:SetTexCoord(0.07,0.93,0.07,0.93)
 b:SetHighlightTexture('Interface\\Buttons\\ButtonHilight-Square')
 b.cooldown=CreateFrame('Cooldown',nil,b,'CooldownFrameTemplate'); b.cooldown:SetAllPoints(b.icon)
 b.cooldown:SetDrawEdge(false); b.cooldown:SetHideCountdownNumbers(true)
 b.time=font(b,10); b.time:SetPoint('BOTTOM',0,2)
 b.count=font(b,12); b.count:SetPoint('TOPRIGHT',-2,-2)
 b.statusMark=font(b,11); b.statusMark:SetPoint('TOPLEFT',2,-2)
 b:RegisterForClicks('AnyUp'); b:SetAttribute('useOnKeyDown',false)
 b:SetScript('OnEnter',tooltip); b:SetScript('OnLeave',function() GameTooltip:Hide() end)
 return b
end
local function selectFamily(g)
 local selected=S.db.kit.selected[g.key]
 if selected and K.best(selected) then return selected end
 for _,family in ipairs(g.families) do if K.best(family) then return family end end
 return g.families[1]
end
local function carried(family,items)
 for rank,id in ipairs((family=='health' and D.healthItems) or D.items[family] or {}) do
  for _,v in ipairs(items or {}) do if v.id==id and v.count>0 then return id end end
  -- A weaker stone must not take precedence over a stronger learned creation:
  -- soulstones and weapon stones always use the best rank.
  if family~='health' and D.families[family] and known(D.families[family][rank]) then return nil end
 end
end
-- One /use per stone, strongest first: a missing stone is skipped and the shared
-- cooldown stops the next lines, so each combat press uses the best stone left.
local lines={}
for _,id in ipairs(D.healthItems) do lines[#lines+1]='/use item:'..id end
K.healthMacro=table.concat(lines,'\n')
function K.fullHealth()
 local hp,max=A.num(A.call(UnitHealth,'player')),A.num(A.call(UnitHealthMax,'player'))
 return hp~=nil and max~=nil and max>0 and hp>=max
end
-- Strongest learned rank whose stone (any talent variant) is not carried.
-- The client may report a lower rank as unknown once a higher one is learned:
-- every rank below a learned one counts as castable.
function K.healthCreate(items)
 local higher=false
 for rank,spell in ipairs(D.families.health) do
  if known(spell) then higher=true end
  if higher then
   local have
   for _,id in ipairs(D.healthRanks[rank]) do
    for _,v in ipairs(items or {}) do if v.id==id and v.count>0 then have=true end end
   end
   if not have then return spell end
  end
 end
end
-- A lower rank is cast by its name and rank text ("Name(Rank 3)"): casting by
-- spell ID may resolve to the highest learned rank, which is already carried.
function K.createText(id)
 local name=A.spell(id)
 local sub=C_Spell and C_Spell.GetSpellSubtext and A.call(C_Spell.GetSpellSubtext,id)
 if type(name)=='string' and name~='' and type(sub)=='string' and sub~='' then return '/cast '..name..'('..sub..')' end
end
-- /fk pierres: what the healthstone button will do, and the game's
-- answer to the last creation attempt.
function K.healthDebug()
 local items=A.inventory(); local carried={}
 for _,v in ipairs(items or {}) do for _,id in ipairs(D.healthItems) do if v.id==id then carried[#carried+1]=id end end end
 local b=K.buttons.health
 local hp,max=A.num(A.call(UnitHealth,'player')),A.num(A.call(UnitHealthMax,'player'))
 S.print('Healthstones: hp='..tostring(hp)..'/'..tostring(max)..' full='..tostring(K.fullHealth())..' items='..(items and 'read' or 'unreadable')..
  ' carried='..(#carried>0 and table.concat(carried,',') or 'none'))
 local known={}
 for _,spell in ipairs(D.families.health) do known[#known+1]=spell..(K.isKnown(spell) and '+' or '-') end
 S.print('ranks '..table.concat(known,' ')..' next='..tostring(K.healthCreate(items))..
  ' type='..tostring(b:GetAttribute('type1'))..' spell='..tostring(b:GetAttribute('spell1'))..
  ' item='..tostring(b:GetAttribute('item1'))..' macro='..tostring(b:GetAttribute('macrotext1')))
 local t=K.healthTrace
 S.print('last: '..(t and (tostring(t.spell)..' '..(t.ok and 'cast ok' or 'not cast')..(t.error and (' · '..t.error) or '')) or 'no attempt'))
end
local function configure(b,g,family,items,rank)
 local id=rank or K.best(family)
 if family=='soul' then id=K.best(family) end
 local item=g.stone and not rank and carried(family,items)
 -- Healthstones: at full health, create the strongest rank not yet carried and
 -- never consume a stone; otherwise use the strongest stone carried.
 local healthIdle,createMacro
 if family=='health' and not rank and items then
  local create=K.healthCreate(items); K.healthFull=K.fullHealth()
  if create and (K.healthFull or not item) then id=create; item=nil; createMacro=K.createText(create)
  elseif K.healthFull then healthIdle=true end
 end
 local kind=item and 'item' or (id and 'spell' or nil)
 if healthIdle then kind=nil end
 -- Soulstone use, or a healthstone rank cast by name: also the macro restored after combat.
 local soulMacro=item and family=='soul' and ('/use [@target,help,nodead][@player] item:'..item) or createMacro
 if soulMacro then kind='macro' end
 if g.stone and not rank and not items then kind=nil end
 b:SetAttribute('type1',kind); b:SetAttribute('spell1',id)
 b:SetAttribute('item1',item and ('item:'..item) or nil)
 b:SetAttribute('macrotext1',soulMacro)
 b:SetAttribute('unit1',g.self and 'player' or nil)
 b:SetAttribute('checkselfcast',true)
 b:SetAttribute('checkfocuscast',true)
 b:SetAttribute('checkmouseovercast',true)
 b:SetAttribute('target-slot1',g.weapon and 16 or nil)
 b:SetAttribute('shift-type1',g.stone and id and 'spell' or nil)
 b:SetAttribute('shift-spell1',g.stone and id or nil)
 b:SetAttribute('shift-macrotext1',nil)
 if id and (family=='breath' or family=='invisibility') then
  b:SetAttribute('type1','macro')
  b:SetAttribute('macrotext1','/cast [@target,help,nodead][@player] '..A.spell(id))
 end
 if id and g.key=='demon' and K.best('domination') then
  b:SetAttribute('shift-type1','macro')
  b:SetAttribute('shift-macrotext1','/cast '..A.spell(K.best('domination'))..'\n/cast '..A.spell(id))
 end
 b:SetAttribute('family',family); b:SetAttribute('displaySpell',id or D.families[family][1])
 b:SetAttribute('displayItem',item); b:SetAttribute('available',id~=nil or item~=nil)
 local queueIcon=g.key=='summon' and S.db.kit.queueButtonDesign=='icon'
 b:SetAttribute('queueIcon',queueIcon)
 if queueIcon then b:SetAttribute('type1',nil); b:SetAttribute('spell1',nil); b:SetAttribute('available',true) end
 -- During combat, stones always remain item actions, even after consumption.
 -- Only explicit Shift-click requests creation. No insecure bag-event attribute writes.
 if g.stone and not rank then
  local fallback
  for i,spell in ipairs(D.families[family]) do if spell==id then fallback=D.items[family][i] end end
  b:SetAttribute('normalType',kind); b:SetAttribute('combatItem','item:'..(item or fallback or D.items[family][1]))
  b:SetAttribute('normalMacro',soulMacro)
  b:SetAttribute('combatType',(family=='soul' or family=='health') and 'macro' or 'item')
  b:SetAttribute('combatMacro',family=='soul' and ('/use [@target,help,nodead][@player] item:'..(item or fallback or D.items[family][1]))
   or family=='health' and K.healthMacro or nil)
  b:SetAttribute('_onstate-combat',[[
   if newstate == '1' then
    self:SetAttribute('type1',self:GetAttribute('combatType')); self:SetAttribute('item1',self:GetAttribute('combatItem'))
    self:SetAttribute('macrotext1',self:GetAttribute('combatMacro'))
   else
    self:SetAttribute('type1',self:GetAttribute('normalType')); self:SetAttribute('macrotext1',self:GetAttribute('normalMacro'))
   end
  ]])
  RegisterStateDriver(b,'combat','[combat] 1; 0')
 end
end
local toggleFlyout=[[
 if self:GetAttribute('queueIcon') then
  if button == 'LeftButton' then
   local window=self:GetFrameRef('flyout')
   if window:IsShown() then window:Hide() else window:Show() end
   return false
  end
  return
 end
 if button == 'RightButton' then
  local panel=self:GetFrameRef('flyout')
  local was=panel:IsShown()
  local header=self:GetFrameRef('header')
  for i=1,header:GetAttribute('menus') do header:GetFrameRef('menu'..i):Hide() end
  if not was then panel:Show() end
 end
]]
local chooseSpell=[[
 if button == 'LeftButton' then
  local owner=self:GetFrameRef('owner')
  owner:SetAttribute('type1',self:GetAttribute('type1'))
  owner:SetAttribute('spell1',self:GetAttribute('spell1'))
  owner:SetAttribute('unit1',self:GetAttribute('unit1'))
  owner:SetAttribute('macrotext1',self:GetAttribute('macrotext1'))
  owner:SetAttribute('shift-type1',self:GetAttribute('shift-type1'))
  owner:SetAttribute('shift-spell1',self:GetAttribute('shift-spell1'))
  owner:SetAttribute('shift-macrotext1',self:GetAttribute('shift-macrotext1'))
  owner:SetAttribute('displayItem',nil)
  owner:SetAttribute('displaySpell',self:GetAttribute('displaySpell'))
  owner:SetAttribute('family',self:GetAttribute('family'))
  self:GetParent():Hide()
 end
]]
function K.setEditing(value)
 if A.combat() then S.print(L.kitDeferred); return end
 K.editing=value==true and S.db.kit.layout=='free'
 K.dragging=nil; K.refresh()
 if K.editing then K.body:Show() end
end
function K.resetPositions()
 if A.combat() then S.print(L.kitDeferred); return end
 S.db.kit.positions={}
 for _,b in pairs(K.buttons) do b.layoutX=nil; b.layoutY=nil end
 K.refresh()
end
function K.updateDrag()
 local drag=K.dragging
 if not drag then return end
 if A.combat() or not K.editing or S.db.kit.layout~='free' then K.dragging=nil; return end
 local mx,my=GetCursorPosition(); mx=A.num(mx); my=A.num(my)
 if not mx or not my then return end
 local scale=S.UI.counter:GetEffectiveScale()
 local x=math.max(-20000,math.min(20000,drag.x+(mx-drag.mx)/scale))
 local y=math.max(-20000,math.min(20000,drag.y+(my-drag.my)/scale))
 S.db.kit.positions[drag.button.group.key]={x=x,y=y}
 drag.button:ClearAllPoints()
 drag.button:SetPoint('CENTER',S.UI.counter,'CENTER',x/S.db.kit.scale,y/S.db.kit.scale)
end
local function mover(b)
 -- Dedicated mouse overlay: dragging cannot activate the underlying spell button.
 local f=CreateFrame('Button',nil,b,'SecureHandlerStateTemplate,BackdropTemplate')
 f:SetAllPoints(b); f:SetFrameLevel(b:GetFrameLevel()+10); backdrop(f)
 f:SetBackdropColor(0.12,0.08,0.03,0.45); f:SetBackdropBorderColor(1,0.8,0.25,1)
 local mark=font(f,18); mark:SetPoint('CENTER'); mark:SetText('+')
 f:EnableMouse(true); f:RegisterForDrag('LeftButton'); f:RegisterForClicks('AnyUp')
 f:SetScript('OnEnter',function()
  GameTooltip:SetOwner(f,'ANCHOR_RIGHT'); GameTooltip:SetText(L['kit_'..b.group.key])
  GameTooltip:AddLine(L.kitDragHelp,1,0.85,0.4,true); GameTooltip:Show()
 end)
 f:SetScript('OnLeave',function() GameTooltip:Hide() end)
 f:SetScript('OnDragStart',function()
  if A.combat() or not K.editing or S.db.kit.layout~='free' then return end
  local p=S.db.kit.positions[b.group.key]; if not p then return end
  local mx,my=GetCursorPosition(); mx=A.num(mx); my=A.num(my)
  if mx and my then K.dragging={button=b,x=p.x,y=p.y,mx=mx,my=my} end
 end)
 local function stop() K.updateDrag(); K.dragging=nil end
 f:SetScript('OnDragStop',stop); f:SetScript('OnMouseUp',stop)
 f:SetScript('OnHide',function() if K.dragging and K.dragging.button==b then K.dragging=nil end end)
 f:SetAttribute('_onstate-combat',[[
  if newstate == '1' then self:Hide()
  elseif self:GetAttribute('editing') then self:Show() else self:Hide() end
 ]])
 RegisterStateDriver(f,'combat','[combat] 1; 0')
 b.mover=f
end
-- Remaining time of my curse on the target, drawn by the engine: the target's
-- auras are secret in combat. Never retain or touch a bound duration text:
-- the client can forbid it. Select only our own parent holder per family.
function K.curseTimer(b,g)
 if b.curseTimers then return true end
 if b.curseTimerAttempted then return false end
 if A.combat() or (C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret()) then b.curseTimerDeferred=true; return false end
 b.curseTimerDeferred=nil
 b.curseTimerAttempted=true
 local timers={}
 local ok,err=pcall(function()
  for _,family in ipairs(g.families) do
   local holder=CreateFrame('Frame',nil,b,'DisableUntrustedLayoutScriptsTemplate')
   holder:SetAllPoints(b.icon); holder:EnableMouse(false); holder:SetFrameLevel(b:GetFrameLevel()+3); holder:SetAlpha(0)
   local entry={holder=holder}; timers[family]=entry
   local c=CreateFrame('AuraContainer',nil,holder,'CustomAuraContainerTemplate'); entry.native=c
   c:SetAllPoints(holder); c:EnableMouse(false); c:SetFrameLevel(holder:GetFrameLevel()+1)
   local ids={}; for _,id in ipairs(D.families[family] or {}) do ids[id]=true end
   c:AddAuraSlot('curse_'..family,'HARMFUL|PLAYER',{candidateFilters={includeSpellIDs=ids},initializeFrame=function(slot)
    slot:SetAllPoints(c); slot:EnableMouse(false)
    local t=font(slot,10); t:SetPoint('BOTTOM',0,2); slot:SetDurationText(t,{})
    entry.ready=true
   end})
   assert(entry.ready,'curse slot initialization did not run')
   c:SetUnit('target')
  end
  b.curseTimers=timers
 end)
 if not ok then
  for _,entry in pairs(timers) do
   entry.holder:SetAlpha(0)
   if entry.native then pcall(entry.native.SetUnit,entry.native,'none'); pcall(entry.native.SetEnabled,entry.native,false) end
  end
  b.curseTimers=nil; K.curseError=tostring(A.public(err) or 'restricted error'):sub(1,200)
 end
 return ok
end
function K.rebindCurses()
 for _,key in ipairs({'curse1','curse2'}) do
  for _,entry in pairs(K.buttons[key] and K.buttons[key].curseTimers or {}) do
   local c=entry.native; pcall(c.SetUnit,c,'none'); pcall(c.SetUnit,c,'target')
  end
 end
end
function K.create()
 if K.header or A.combat() then return end
 S.db.kit=M.settings(S.db.kit)
 K.header=CreateFrame('Frame',nil,S.UI.counter,'SecureHandlerBaseTemplate')
 K.header:SetAllPoints(); K.body=CreateFrame('Frame',nil,K.header); K.body:SetAllPoints()
 K.header:SetAttribute('menus',#D.groups)
 for index,g in ipairs(D.groups) do
  local b=action('FelkitKit'..g.key,K.body); b.group=g; K.buttons[g.key]=b
  if g.key=='health' then b:HookScript('PreClick',function(self) K.healthClickAt=GetTime(); K.healthTrace={spell=self:GetAttribute('macrotext1') or self:GetAttribute('spell1') or self:GetAttribute('item1')} end) end
  if g.reminder then b.halo=S.UI.halo(b,1,0.62,0.12) end
  mover(b)
  local fly=CreateFrame('Frame',nil,K.body,'BackdropTemplate'); backdrop(fly); fly:EnableMouse(true)
  fly:SetFrameStrata('DIALOG'); fly:SetClampedToScreen(true); fly.choices={}; K.flyouts[index]=fly
  -- Use the public API: BackdropTemplate's OnLoad replaces the method installer.
  SecureHandlerSetFrameRef(b,'flyout',fly); SecureHandlerSetFrameRef(b,'header',K.header)
  SecureHandlerSetFrameRef(K.header,'menu'..index,fly)
  SecureHandlerWrapScript(b,'OnClick',b,toggleFlyout)
  if g.key=='summon' then
   b.queueCode=font(b,9); b.queueCode:SetPoint('BOTTOMLEFT',3,3); b.queueCode:SetText('123')
   b.queueCount=font(b,11); b.queueCount:SetPoint('TOPRIGHT',-2,-2)
   b:HookScript('OnClick',function(self,mouse)
    if mouse=='RightButton' and self:GetAttribute('queueIcon') then S.UI.openKit('summons') end
   end)
  end
  for _,family in ipairs(g.families) do
    local c=action(nil,fly,true); c.family=family; SecureHandlerSetFrameRef(c,'owner',b)
    c:SetAttribute('type2',nil)
    if not g.stone then SecureHandlerWrapScript(c,'OnClick',c,[[return nil, true]],chooseSpell)
    else SecureHandlerWrapScript(c,'OnClick',c,[[return nil, true]],[[if button == 'LeftButton' then self:GetParent():Hide() end]]) end
    c:HookScript('PostClick',function(_,mouse)
     if mouse~='LeftButton' then return end
     S.db.kit.selected[g.key]=family
     if not A.combat() then K.refresh() else K.pending=true; K.visuals() end
    end)
    fly.choices[#fly.choices+1]=c
  end
  fly:Hide(); b.flyout=fly
  if g.key=='curse1' or g.key=='curse2' then K.curseTimer(b,g) end
 end
 local icon=S.UI.counter.icon
 SecureHandlerSetFrameRef(icon,'kit',K.body); SecureHandlerSetFrameRef(icon,'header',K.header)
 SecureHandlerWrapScript(icon,'OnClick',icon,[[
  if button == 'LeftButton' and not IsShiftKeyDown() and self:GetAttribute('kitEnabled') then
   local kit=self:GetFrameRef('kit')
   if kit:IsShown() then kit:Hide() else kit:Show() end
   local header=self:GetFrameRef('header')
   for i=1,header:GetAttribute('menus') do header:GetFrameRef('menu'..i):Hide() end
  end
 ]])
 local grip=S.UI.counter.combatGrip
 if grip then SecureHandlerSetFrameRef(grip,'kit',K.body); SecureHandlerSetFrameRef(grip,'header',K.header) end
 K.createQueue()
 SecureHandlerSetFrameRef(K.buttons.summon,'flyout',K.queueWindow)
 K.events=CreateFrame('Frame')
 for _,event in ipairs({'BAG_UPDATE','BAG_UPDATE_DELAYED','SPELLS_CHANGED','PLAYER_ENTERING_WORLD','PLAYER_REGEN_ENABLED','PLAYER_REGEN_DISABLED',
  'GROUP_ROSTER_UPDATE','UNIT_AURA','UNIT_PET','PLAYER_TARGET_CHANGED','UNIT_INVENTORY_CHANGED','MINIMAP_UPDATE_TRACKING','PLAYER_EQUIPMENT_CHANGED','PLAYER_DEAD',
  'DISPLAY_SIZE_CHANGED','UI_SCALE_CHANGED','UNIT_HEALTH','UNIT_MAXHEALTH','UNIT_SPELLCAST_SUCCEEDED','UI_ERROR_MESSAGE','CHAT_MSG_PARTY','CHAT_MSG_PARTY_LEADER','CHAT_MSG_RAID','CHAT_MSG_RAID_LEADER',
  'CHAT_MSG_WHISPER','CHAT_MSG_INSTANCE_CHAT','CHAT_MSG_INSTANCE_CHAT_LEADER'}) do
  local ok=pcall(K.events.RegisterEvent,K.events,event); if not ok then S.failedEvents[event]=true end
 end
 K.cooldownVersion=0
 -- The player's health and casts only (the handler ignores every other unit).
 for _,event in ipairs({'UNIT_HEALTH','UNIT_MAXHEALTH','UNIT_SPELLCAST_SUCCEEDED'}) do
  if pcall(K.events.UnregisterEvent,K.events,event) and not pcall(K.events.RegisterUnitEvent,K.events,event,'player') then
   pcall(K.events.RegisterEvent,K.events,event)
  end
 end
 for _,event in ipairs({'SPELL_UPDATE_COOLDOWN','BAG_UPDATE_COOLDOWN'}) do pcall(K.events.RegisterEvent,K.events,event) end
 K.body:HookScript('OnShow',function() K.visualsDirty=true end)
 K.events:SetScript('OnEvent',function(_,event,text,author,third)
  if event=='SPELL_UPDATE_COOLDOWN' or event=='BAG_UPDATE_COOLDOWN' then
   K.cooldownVersion=K.cooldownVersion+1; K.visualsDirty=true; return
  end
  if event=='BAG_UPDATE' or event=='BAG_UPDATE_DELAYED' or event=='PLAYER_ENTERING_WORLD'
   or event=='PLAYER_REGEN_DISABLED' or event=='PLAYER_REGEN_ENABLED' then
   S.KitStatus.invalidateItems(); K.cooldownVersion=K.cooldownVersion+1
  end
  if event=='BAG_UPDATE' then return end -- one refresh after the bag transaction
  if event=='UNIT_SPELLCAST_SUCCEEDED' then
   -- A healthstone was created (unit, cast GUID, spell ID): rebuild the button without waiting for the bags.
   local spell=A.num(third)
   if A.public(text)=='player' and spell then
    for _,id in ipairs(D.families.health) do
     if id==spell then
      K.healthTrace=K.healthTrace or {}; K.healthTrace.ok=true; K.healthTrace.spell=spell
      if C_Timer and C_Timer.After then C_Timer.After(0.5,function() if not A.combat() then K.refresh() end end) end
     end
    end
   end
   return
  end
  if event=='UI_ERROR_MESSAGE' then
   -- Keep the game's refusal shortly after a healthstone click, for /fk pierres.
   local message=A.public(author)
   if K.healthClickAt and GetTime()-K.healthClickAt<3 and type(message)=='string' then
    K.healthTrace=K.healthTrace or {}; K.healthTrace.error=message
   end
   return
  end
  if event=='UNIT_HEALTH' or event=='UNIT_MAXHEALTH' then
   -- Healthstone action follows full/missing health, out of combat only.
   if A.public(text)=='player' and not A.combat() and K.fullHealth()~=K.healthFull then K.refresh() end
   return
  end
  if event=='SPELLS_CHANGED' or event=='PLAYER_ENTERING_WORLD' then K.byName={}; S.Ticks.syncGuard() end
  if event=='GROUP_ROSTER_UPDATE' or event=='PLAYER_ENTERING_WORLD' or event=='PLAYER_REGEN_ENABLED' then K.rosterCache=nil end
  if event=='UNIT_AURA' then
   local unit=A.public(text)
   if type(unit)~='string' or (unit~='player' and unit~='target' and not unit:match('^raid%d+$') and not unit:match('^party%d+$')) then return end
   S.KitStatus.invalidate(unit)
  elseif event=='GROUP_ROSTER_UPDATE' or event=='PLAYER_ENTERING_WORLD' then S.KitStatus.invalidate() end
  if event=='PLAYER_ENTERING_WORLD' or event=='PLAYER_DEAD' then S.KitStatus.resetDisplay()
  elseif event=='GROUP_ROSTER_UPDATE' then S.KitStatus.resetDisplay('soul')
  elseif event=='UNIT_PET' and A.public(text)=='player' then S.KitStatus.resetDisplay('demon')
  elseif event=='PLAYER_EQUIPMENT_CHANGED' and A.num(text)==16 then S.KitStatus.resetDisplay('weapon') end
  if event=='UNIT_AURA' and A.public(text)~='player' and A.public(text)~='target' then return end -- group: next 0.25 s refresh
  if event=='PLAYER_TARGET_CHANGED' then K.rebindCurses() end
  if event=='UNIT_AURA' or event=='UNIT_PET' or event=='PLAYER_TARGET_CHANGED' or event=='UNIT_INVENTORY_CHANGED' or event=='MINIMAP_UPDATE_TRACKING' then
   -- The target's auras change with every group member's debuff: drawn at
   -- most 20 times a second (the rest on the next frame). Others at once.
   if event=='UNIT_AURA' and A.public(text)=='target' and K.visualsAt and GetTime()-K.visualsAt<0.05 then K.visualsDirty=true
   else K.visuals() end
   return
  end
  if event:find('CHAT_MSG_',1,true)==1 then
   text=A.public(text); author=A.public(author)
   if S.db.enabled and S.db.kit.enabled and M.request(text) and M.enqueue(K.queue,author,GetTime()) then K.renderQueue() end
  else K.refresh() end
 end)
 local elapsed,queueElapsed=0,0
 K.events:SetScript('OnUpdate',function(_,dt)
  K.updateDrag()
  K.updateQueueButtonDrag()
  elapsed=elapsed+dt; queueElapsed=queueElapsed+dt
  if elapsed<0.25 and not (K.visualsDirty and elapsed>=0.05) then return end; elapsed=0
  K.visualsDirty=nil
  if S.db.enabled and S.db.kit.enabled then K.visuals() end
  -- The summon list changes slowly: expiry, renders and row texts every 0.5 s.
  if queueElapsed<0.5 then return end; queueElapsed=0
  if M.expire(K.queue,GetTime()) then K.queueDirty=true end
  if K.queueDirty and not A.combat() then K.queueDirty=nil; K.renderQueue()
  elseif S.db.enabled and S.db.kit.enabled then K.queueVisuals() end
 end)
 K.refresh()
end
function K.refresh()
 if not K.header then return end
 if A.combat() then
  K.dragging=nil; K.queueButtonDragging=nil; K.pending=true
  if S.UI.syncKitEditing then S.UI.syncKitEditing() end
  if S.UI.syncQueueButtonEditing then S.UI.syncQueueButtonEditing() end
  return
 end
 K.pending=nil
 K.dragging=nil
 K.queueButtonDragging=nil
 local cfg=S.db.kit; local items=A.inventory(); local visible={}
 S.KitStatus.items=items; S.KitStatus.itemsRead=items~=nil
 if cfg.layout~='free' then K.editing=false end
 K.body:SetScale(cfg.scale)
 S.UI.counter.icon:SetAttribute('kitEnabled',S.db.enabled and cfg.enabled)
 if S.UI.counter.combatGrip then S.UI.counter.combatGrip:SetAttribute('kitEnabled',S.db.enabled and cfg.enabled) end
 K.header:SetShown(S.db.enabled and cfg.enabled)
 K.layoutQueueButton()
 for _,g in ipairs(D.groups) do
  local b=K.buttons[g.key]; local family=selectFamily(g)
  b.mover:SetAttribute('editing',K.editing==true); b.mover:SetShown(K.editing==true)
  configure(b,g,family,items)
  if g.key=='curse1' or g.key=='curse2' then K.curseTimer(b,g) end
  if g.key=='summon' then
   local icon=b:GetAttribute('queueIcon')
   b.queueCode:SetShown(icon); b.queueCount:SetShown(icon); b.time:SetShown(not icon); b.cooldown:SetShown(not icon)
  end
  local available=b:GetAttribute('available')
  local shown=cfg.visible[g.key] and (available or not cfg.hideUnknown) and (not g.talent or available)
  b:SetShown(shown); if shown then visible[#visible+1]=b end
  local count=0
  for _,c in ipairs(b.flyout.choices) do
   local best=K.best(c.family)
   local show=best~=nil
   configure(c,g,c.family,items,g.stone and best or nil)
   c:SetShown(show==true)
   if show then
    count=count+1; c:ClearAllPoints(); c:SetPoint('TOPLEFT',8+((count-1)%4)*44,-8-math.floor((count-1)/4)*44)
   end
  end
  b.flyout:SetSize(math.max(1,math.min(count,4))*44+12,math.max(1,math.ceil(count/4))*44+12)
  b.flyout:Hide()
 end
 for i,b in ipairs(visible) do
  local x,y=M.position(cfg.layout,i,#visible,cfg.size*cfg.scale,cfg)
  if cfg.layout=='free' then
   local p=cfg.positions[b.group.key]
   if not p then
    -- Capture the current preset position when entering free placement for the first time.
    p={x=b.layoutX or x,y=b.layoutY or y}; cfg.positions[b.group.key]=p
   end
   x,y=p.x,p.y
  end
  b.layoutX,b.layoutY=x,y
  b:ClearAllPoints(); b:SetPoint('CENTER',S.UI.counter,'CENTER',x/cfg.scale,y/cfg.scale); b:SetSize(cfg.size,cfg.size)
  b.flyout:ClearAllPoints(); b.flyout:SetPoint('BOTTOMLEFT',b,'TOPLEFT',0,8)
 end
 if S.UI.syncKitEditing then S.UI.syncKitEditing() end
 K.renderQueue(); K.visuals()
end
local function timeText(seconds)
 if seconds>=60 then return math.ceil(seconds/60)..'m' end
 return tostring(math.ceil(seconds))
end
local function utilityVisual(b,active,expiration,now,estimated)
 b.activeState=active; b.statusEstimated=estimated
 -- Hidden combat data is not evidence of an inactive effect.
 local gray=not b:GetAttribute('available') or active==false
 b.icon:SetDesaturated(gray)
 b.icon:SetVertexColor(gray and 0.55 or 1,gray and 0.55 or 1,gray and 0.55 or 1)
 b.statusMark:SetText(active==true and b:GetAttribute('family')=='sense' and 'ON' or '')
 b.statusMark:SetTextColor(active==true and 0.45 or 1,1,active==true and 0.55 or 1)
 b:SetBackdropBorderColor(active==true and 0.3 or 0.43,active==true and 0.9 or 0.24,active==true and 0.45 or 0.60,1)
 b.time:SetText(active and expiration and expiration>now and timeText(expiration-now) or '')
 -- It drew over the main pass: that pass sets its own values again next time.
 b.grayState,b.statusCleared,b.borderState=nil,nil,nil
end
-- Spell icons only change with the button's spell or item: looked up once.
local function iconOf(f,id,item)
 local key=tostring(id)..':'..tostring(item)
 if f.iconFor==key then return end
 local _,icon=A.spell(id or 0)
 if item and C_Item then icon=A.call(C_Item.GetItemIconByID,item) or icon end
 f.icon:SetTexture(icon)
 f.iconFor=icon and key or nil
end
-- Cooldowns change with the cooldown events (K.cooldownVersion): read once each.
local function cooldownOf(b,g,id,item,now)
 local key=tostring(K.cooldownVersion)..':'..tostring(id)..':'..tostring(item)
 if b.cdKey==key then return b.cdStart,b.cdDuration end
 local cd=C_Spell and A.call(C_Spell.GetSpellCooldown,id)
 local start,duration=A.num(A.field(cd,'startTime')),A.num(A.field(cd,'duration'))
 if item and C_Container and C_Container.GetItemCooldown then
  local ok,s,d=pcall(C_Container.GetItemCooldown,item)
  start=ok and A.num(s) or nil; duration=ok and A.num(d) or nil
 end
 -- Stones share one cooldown: shown even after the last one was used.
 if g.key=='health' or g.key=='soul' then
  local s2,d2=K.stoneCooldown(g.key,now)
  if s2 then start,duration=s2,d2 end
 end
 b.cdKey,b.cdStart,b.cdDuration=key,start,duration
 return start,duration
end
function K.visuals()
 if not K.header or not S.db.enabled or not S.db.kit.enabled then return end
 -- Folded or hidden: nothing to draw; the body redraws when it shows again.
 if K.body and not K.body:IsVisible() then return end
 local now=GetTime(); local T=S.KitStatus; local context=T.read(now)
 K.visualsAt=now
 for _,g in ipairs(D.groups) do
  local b=K.buttons[g.key]
  if b.curseTimerDeferred then K.curseTimer(b,g) end
  local id=b:GetAttribute('displaySpell'); local item=b:GetAttribute('displayItem')
  iconOf(b,id,item)
  local active,expiration,count,estimated=T.display(g.key,b:GetAttribute('family'),context)
  b.activeState=active; b.healthCount=count; b.statusEstimated=estimated
  local managed=T.managed[g.key]
  local stoneCount=g.key=='health' or g.key=='soul'
  local gray=not b:GetAttribute('available') or (managed==true and active==false)
  -- Soulstone: gray only when none is carried; the buff no longer grays it.
  if g.key=='soul' then gray=not b:GetAttribute('available') or count==0 end
  if b.grayState~=gray then
   b.icon:SetDesaturated(gray)
   b.icon:SetVertexColor(gray and 0.55 or 1,gray and 0.55 or 1,gray and 0.55 or 1)
   b.grayState=gray
  end
  local countText=stoneCount and count~=nil and tostring(count) or ''
  if b.countText~=countText then b.count:SetText(countText); b.countText=countText end
  if stoneCount then
   local size=math.max(14,math.floor(S.db.kit.size*0.55))
   if b.countSize~=size then b.countSize=size; b.count:SetFont(STANDARD_TEXT_FONT or 'Fonts\\FRIZQT__.TTF',size,'THICKOUTLINE') end
   local empty=count==0
   if b.countEmpty~=empty then
    if empty then b.count:SetTextColor(1,0.3,0.25) else b.count:SetTextColor(1,1,1) end
    b.countEmpty=empty
   end
  end
  if not b.statusCleared then b.statusMark:SetText(''); b.statusMark:SetTextColor(1,1,1); b.statusCleared=true end
  local start,duration=cooldownOf(b,g,id,item,now)
  local remaining=start and duration and math.max(0,start+duration-now)
  if remaining and remaining>0 and duration>1.5 then
   -- The swipe is the game's: set again only for a new cooldown.
   if b.swipeStart~=start or b.swipeDuration~=duration then
    b.cooldown:SetCooldown(start,duration); b.swipeStart,b.swipeDuration=start,duration
   end
   b.time:SetText(timeText(remaining))
  else
   if b.swipeStart then b.cooldown:Clear(); b.swipeStart,b.swipeDuration=nil,nil end
   b.time:SetText('')
  end
  local missing=g.reminder and active==false and b:GetAttribute('available')
  local border=(g.key=='soul' and active==true) and 'soul' or missing and 'missing' or 'normal'
  if b.borderState~=border then
   if border=='soul' then b:SetBackdropBorderColor(0.3,0.9,0.45,1)
   else b:SetBackdropBorderColor(missing and 1 or 0.43,missing and 0.7 or 0.24,missing and 0.2 or 0.60,1) end
   b.borderState=border
  end
  S.UI.setHalo(b.halo,missing and b:IsShown(),S.db.kit.size)
  if b.curseTimers then
   -- Native descendants may be forbidden; only these addon-owned ancestors
   -- are changed. No native alpha, text, visibility or duration is inspected.
   local family=b:GetAttribute('family')
   for f,entry in pairs(b.curseTimers) do entry.holder:SetAlpha(f==family and 1 or 0) end
   b.time:SetText('')
  elseif g.key=='soul' then
   -- The cooldown text (set above) wins over the soulstone buff timer.
  elseif managed or g.key=='curse1' or g.key=='curse2' then
   b.time:SetText(active and expiration and expiration>now and timeText(expiration-now) or '')
  end
  if g.key=='utility' and utilityStatus[b:GetAttribute('family')] then utilityVisual(b,active,expiration,now,estimated) end
  for _,c in ipairs(b.flyout.choices) do
   iconOf(c,c:GetAttribute('displaySpell'),nil)
   if g.key=='utility' and utilityStatus[c.family] then
    local choiceActive,choiceExpiration,_,choiceEstimated=T.display(g.key,c.family,context)
    utilityVisual(c,choiceActive,choiceExpiration,now,choiceEstimated)
   end
  end
 end
end
-- Longest remaining item cooldown over every rank of a stone, carried or not.
function K.stoneCooldown(key,now)
 if not (C_Container and C_Container.GetItemCooldown) then return end
 local best,bestStart,bestDuration=0
 for _,id in ipairs(key=='health' and D.healthItems or D.items[key] or {}) do
  local ok,s,d=pcall(C_Container.GetItemCooldown,id)
  s=ok and A.num(s); d=ok and A.num(d)
  if s and d and d>1.5 and s+d-now>best then best,bestStart,bestDuration=s+d-now,s,d end
 end
 return bestStart,bestDuration
end
function K.roster()
 -- Rebuilt on group changes, after combat, or after 5 s (late realm names).
 if K.rosterCache and GetTime()<K.rosterAt+5 then return K.rosterCache end
 local names={}
 local raid=A.call(IsInRaid)==true
 local count=A.num(A.call(GetNumGroupMembers)) or 0
 for i=1,count do
  local token=raid and ('raid'..i) or (i==count and 'player' or 'party'..i)
  if UnitFullName then
   local ok,n,r=pcall(UnitFullName,token); n=A.public(n); r=A.public(r)
   if ok and M.author(n) then
    local realm=type(r)=='string' and r~='' and r or A.call(GetNormalizedRealmName)
    local full=realm and (n..'-'..realm) or n
    names[full]=full
    if names[n]==nil then names[n]=full elseif names[n]~=full then names[n]=false end
   end
  end
 end
 K.rosterCache=names; K.rosterAt=GetTime()
 return names
end
function K.createQueue()
 local f=CreateFrame('Frame','FelkitSummonQueue',UIParent,'BackdropTemplate')
 K.queueWindow=f; f:SetSize(520,604); f:SetPoint('CENTER',UIParent,'CENTER',280,0)
 f:SetFrameStrata('DIALOG'); f:SetClampedToScreen(true); f:EnableMouse(true); backdrop(f)
 S.UI.anchor(f,'summons',280,0)
 f.grip:SetHeight(60)
 local function text(parent,value,x,y,width,size)
  local t=font(parent,size); t:SetPoint('TOPLEFT',x,y); t:SetWidth(width); t:SetJustifyH('LEFT'); t:SetText(value)
  return t
 end
 local stripe=f:CreateTexture(nil,'ARTWORK'); stripe:SetPoint('TOPLEFT',1,-1); stripe:SetSize(518,3); stripe:SetColorTexture(0.63,0.38,0.86,1); f.stripe=stripe
 local icon=f:CreateTexture(nil,'ARTWORK'); icon:SetPoint('TOPLEFT',18,-20); icon:SetSize(32,32)
 icon:SetTexture(select(2,A.spell(698))); icon:SetTexCoord(0.07,0.93,0.07,0.93)
 f.title=text(f,L.kitQueue,62,-18,342,17)
 local subtitle=text(f,L.kitQueueSubtitle,62,-42,342,11); subtitle:SetTextColor(0.7,0.65,0.8); f.subtitle=subtitle
 local close=CreateFrame('Button',nil,f,'SecureHandlerClickTemplate,BackdropTemplate'); close:SetSize(92,30); close:SetPoint('TOPRIGHT',-12,-14); K.queueClose=close
 backdrop(close); close:SetBackdropColor(0.30,0.12,0.22,1); close:SetBackdropBorderColor(0.86,0.47,0.62,1)
 close:SetFrameLevel(f.grip:GetFrameLevel()+5)
 close.label=font(close,13); close.label:SetPoint('CENTER'); close.label:SetText(L.kitQueueClose..' ×'); close.label:SetTextColor(1,0.94,0.96)
 close:RegisterForClicks('LeftButtonUp')
 close:SetHighlightTexture('Interface\\Buttons\\ButtonHilight-Square')
 SecureHandlerSetFrameRef(close,'window',f); close:SetAttribute('_onclick',[[self:GetFrameRef('window'):Hide()]])
 K.queueStatus=text(f,'',18,-72,484,13)
 K.queueNotice=text(f,'',18,-95,484,11)
 K.queueEmpty=CreateFrame('Frame',nil,f); K.queueEmpty:SetSize(484,180); K.queueEmpty:SetPoint('TOPLEFT',18,-212)
 local empty=text(K.queueEmpty,L.kitQueueEmpty,0,0,484,18); empty:SetJustifyH('CENTER'); K.queueEmpty.title=empty
 local help=text(K.queueEmpty,L.kitQueueEmptyHelp,42,-38,400,13); help:SetJustifyH('CENTER'); help:SetTextColor(0.74,0.71,0.81); K.queueEmpty.help=help
 local function remove(r)
  if r.request then M.remove(K.queue,r.request); K.renderQueue() end
 end
 K.rows={}
 for i=1,8 do
  local r=CreateFrame('Button',nil,f,'SecureActionButtonTemplate,BackdropTemplate'); r:SetSize(448,46); r:SetPoint('TOPLEFT',18,-126-(i-1)*51)
  backdrop(r); r:SetHighlightTexture('Interface\\Buttons\\ButtonHilight-Square')
  r.number=text(r,'',9,-16,24,11); r.number:SetTextColor(0.63,0.58,0.72)
  r.player=text(r,'',40,-5,292,13); r.player:SetHeight(16); r.player:SetWordWrap(false); r.player:SetTextColor(0.96,0.94,1)
  r.detail=text(r,'',40,-23,292,10); r.detail:SetHeight(12); r.detail:SetWordWrap(false)
  r.action=CreateFrame('Frame',nil,r,'BackdropTemplate'); r.action:SetSize(96,30); r.action:SetPoint('RIGHT',-8,0); backdrop(r.action)
  r.actionText=font(r.action,12); r.actionText:SetPoint('CENTER'); r.actionText:SetText(L.kitQueueInvoke)
  r.remove=CreateFrame('Button',nil,f,'UIPanelButtonTemplate'); r.remove:SetSize(30,30); r.remove:SetPoint('TOPLEFT',472,-134-(i-1)*51); r.remove:SetText('×')
  r.remove:SetScript('OnClick',function() remove(r) end)
  r.remove:SetScript('OnEnter',function(self)
   GameTooltip:SetOwner(self,'ANCHOR_RIGHT'); GameTooltip:SetText(L.kitQueueRemove)
   GameTooltip:AddLine(r.request or '',1,1,1,true); GameTooltip:Show()
  end)
  r.remove:SetScript('OnLeave',function() GameTooltip:Hide() end)
  r:RegisterForClicks('AnyUp'); r:SetAttribute('useOnKeyDown',false)
  r:HookScript('PostClick',function(_,mouse)
   -- Do not claim a successful summon merely because the action was clicked.
   if mouse=='RightButton' then remove(r) end
  end)
  r:SetScript('OnEnter',function(self)
   GameTooltip:SetOwner(self,'ANCHOR_RIGHT'); GameTooltip:SetText(r.request or '')
   GameTooltip:AddLine(r.reason or '',0.8,0.75,0.9,true)
   GameTooltip:AddLine(L.kitQueueHelp,0.8,0.65,1,true); GameTooltip:Show()
  end)
  r:SetScript('OnLeave',function() GameTooltip:Hide() end); K.rows[i]=r
 end
 local function changePage(delta)
   if A.combat() then S.print(L.kitQueueCombat); return end
   K.page=math.max(1,K.page+delta); K.renderQueue()
 end
 local function pageButton(label,x,delta)
  local b=CreateFrame('Button',nil,f,'UIPanelButtonTemplate'); b:SetSize(112,28); b:SetPoint('BOTTOMLEFT',x,42); b:SetText(label)
  b:SetScript('OnClick',function() changePage(delta) end); return b
 end
 K.queuePrevious=pageButton(L.previous,18,-1); K.queueNext=pageButton(L.next,390,1)
 K.pageLabel=font(f,12); K.pageLabel:SetPoint('BOTTOM',0,50)
 local hint=text(f,L.kitQueueFooter,18,-578,484,10); hint:SetTextColor(0.64,0.59,0.73); hint:SetJustifyH('CENTER'); f.hint=hint
 f:EnableMouseWheel(true); f:SetScript('OnMouseWheel',function(_,delta) if delta~=0 then changePage(delta>0 and -1 or 1) end end)
 local opener=CreateFrame('Button','FelkitQueueToggle',UIParent,'SecureHandlerClickTemplate,BackdropTemplate')
 opener:SetSize(146,40); opener:SetClampedToScreen(true); K.queueToggle=opener
 backdrop(opener); opener:SetBackdropColor(0.13,0.055,0.21,1); opener:SetBackdropBorderColor(0.72,0.45,0.95,1)
 opener:SetFrameLevel(K.body:GetFrameLevel()+5)
 local glyph=opener:CreateTexture(nil,'ARTWORK'); glyph:SetTexture(select(2,A.spell(698))); opener.glyph=glyph
 opener.label=text(opener,L.kitQueueOpen,40,-5,78,11); opener.label:SetTextColor(1,0.96,1)
 opener.code=text(opener,'123',40,-20,60,15); opener.code:SetTextColor(1,0.82,0.35)
 opener.badge=CreateFrame('Frame',nil,opener,'BackdropTemplate'); backdrop(opener.badge); opener.badge:SetBackdropColor(0.02,0.01,0.035,1)
 opener.count=font(opener.badge,11); opener.count:SetPoint('CENTER'); opener.count:SetText('0'); opener.count:SetTextColor(1,1,1)
 opener:RegisterForClicks('AnyUp')
 opener:SetHighlightTexture('Interface\\Buttons\\ButtonHilight-Square')
 opener:SetScript('OnEnter',function(self)
  GameTooltip:SetOwner(self,'ANCHOR_RIGHT'); GameTooltip:SetText(L.kitQueue)
  GameTooltip:AddLine(L.kitQueueSettings,1,0.85,0.45,true)
  GameTooltip:AddLine(L.kitQueueHelp,0.8,0.65,1,true); GameTooltip:Show()
 end)
 opener:SetScript('OnLeave',function() GameTooltip:Hide() end)
 SecureHandlerSetFrameRef(opener,'window',f); opener:SetAttribute('_onclick',[[if button == 'LeftButton' then local f=self:GetFrameRef('window'); if f:IsShown() then f:Hide() else f:Show() end end]])
 opener:HookScript('OnClick',function(_,button) if button=='RightButton' then S.UI.openKit('summons') end end)
 local grip=CreateFrame('Button',nil,opener,'SecureHandlerStateTemplate,BackdropTemplate'); opener.mover=grip
 grip:SetAllPoints(opener); grip:SetFrameLevel(opener:GetFrameLevel()+10); backdrop(grip)
 grip:SetBackdropColor(0.12,0.08,0.03,0.65); grip:SetBackdropBorderColor(1,0.8,0.25,1)
 local mark=font(grip,20); mark:SetPoint('CENTER'); mark:SetText('+')
 grip:EnableMouse(true); grip:RegisterForDrag('LeftButton'); grip:RegisterForClicks('AnyUp')
 grip:SetScript('OnEnter',function()
  GameTooltip:SetOwner(grip,'ANCHOR_RIGHT'); GameTooltip:SetText(L.kitQueueButtonMove)
  GameTooltip:AddLine(L.kitQueueButtonDrag,1,0.85,0.4,true); GameTooltip:Show()
 end)
 grip:SetScript('OnLeave',function() GameTooltip:Hide() end)
 grip:SetScript('OnDragStart',function()
  if A.combat() or not K.queueButtonEditing then return end
  local mx,my=GetCursorPosition(); mx=A.num(mx); my=A.num(my)
  if mx and my then K.queueButtonDragging={x=K.queueButtonX,y=K.queueButtonY,mx=mx,my=my} end
 end)
 local function stop() K.updateQueueButtonDrag(); K.queueButtonDragging=nil end
 grip:SetScript('OnDragStop',stop); grip:SetScript('OnMouseUp',stop)
 grip:SetScript('OnClick',function(_,button) if button=='RightButton' then K.setQueueButtonEditing(false) end end)
 grip:SetScript('OnHide',function() K.queueButtonDragging=nil end)
 grip:SetAttribute('_onstate-combat',[[if newstate == '1' then self:Hide() elseif self:GetAttribute('editing') then self:Show() else self:Hide() end]])
 RegisterStateDriver(grip,'combat','[combat] 1; 0')
 f:Hide()
end
function K.placeQueueButton()
 if not K.queueToggle or A.combat() then return end
 local cfg,b=S.db.kit,K.queueToggle
 if not cfg.queueButtonPosition then
  local x,y=S.UI.counter:GetCenter()
  local ratio=S.UI.counter:GetEffectiveScale()/UIParent:GetEffectiveScale()
  cfg.queueButtonPosition={x=x*ratio-UIParent:GetWidth()/2,y=y*ratio-UIParent:GetHeight()/2-49*ratio}
 end
 local p=cfg.queueButtonPosition; local scale=cfg.queueButtonScale
 local maxX=math.max(0,(UIParent:GetWidth()-b:GetWidth()*scale)/2-4)
 local maxY=math.max(0,(UIParent:GetHeight()-b:GetHeight()*scale)/2-4)
 K.queueButtonX=math.max(-maxX,math.min(maxX,p.x)); K.queueButtonY=math.max(-maxY,math.min(maxY,p.y))
 b:ClearAllPoints(); b:SetPoint('CENTER',UIParent,'CENTER',K.queueButtonX/scale,K.queueButtonY/scale)
end
function K.layoutQueueButton()
 if not K.queueToggle or A.combat() then return end
 local cfg,b=S.db.kit,K.queueToggle
 local compact,icon=cfg.queueButtonDesign=='compact',cfg.queueButtonDesign=='icon'
 b:SetScale(cfg.queueButtonScale); b:SetSize(icon and 48 or (compact and 104 or 146),icon and 48 or (compact and 34 or 40))
 b:SetBackdropColor(compact and 0.045 or 0.13,compact and 0.035 or 0.055,compact and 0.07 or 0.21,1)
 b.glyph:ClearAllPoints(); b.glyph:SetSize(icon and 42 or (compact and 24 or 26),icon and 42 or (compact and 24 or 26))
 b.glyph:SetPoint('LEFT',icon and 3 or (compact and 6 or 7),0)
 b.label:SetShown(not compact and not icon)
 b.code:ClearAllPoints(); b.code:SetWidth(icon and 38 or (compact and 40 or 60)); b.code:SetPoint('TOPLEFT',icon and 4 or (compact and 35 or 40),icon and -30 or (compact and -9 or -20))
 b.badge:ClearAllPoints(); b.badge:SetSize(24,20)
 if icon then b.badge:SetPoint('TOPRIGHT',-1,-1) else b.badge:SetPoint('RIGHT',-3,0) end
 K.placeQueueButton()
 local enabled=S.db.enabled and cfg.enabled
 if not enabled or icon then K.queueButtonEditing=false end
 b:SetShown(enabled and not icon); b.mover:SetAttribute('editing',K.queueButtonEditing==true); b.mover:SetShown(K.queueButtonEditing==true)
 if S.UI.syncQueueButtonEditing then S.UI.syncQueueButtonEditing() end
end
function K.setQueueButtonEditing(value)
 if A.combat() then S.print(L.kitDeferred); return end
 K.queueButtonEditing=value==true and S.db.enabled and S.db.kit.enabled and S.db.kit.queueButtonDesign~='icon'
 K.queueButtonDragging=nil; K.layoutQueueButton()
end
function K.resetQueueButtonPosition()
 if A.combat() then S.print(L.kitDeferred); return end
 K.queueButtonDragging=nil; S.db.kit.queueButtonPosition=nil; K.layoutQueueButton()
end
function K.updateQueueButtonDrag()
 local drag=K.queueButtonDragging
 if not drag then return end
 if A.combat() or not K.queueButtonEditing then K.queueButtonDragging=nil; return end
 local mx,my=GetCursorPosition(); mx=A.num(mx); my=A.num(my)
 if not mx or not my then return end
 local scale=UIParent:GetEffectiveScale()
 S.db.kit.queueButtonPosition={x=drag.x+(mx-drag.mx)/scale,y=drag.y+(my-drag.my)/scale}
 K.placeQueueButton()
 S.db.kit.queueButtonPosition={x=K.queueButtonX,y=K.queueButtonY}
end
function K.layoutQueue()
 if not K.queueWindow or A.combat() then K.pending=true; return end
 local f,cfg=K.queueWindow,S.db.kit
 local w,h=cfg.queueWidth,cfg.queueHeight
 local scale=math.min(cfg.queueScale,math.max(1,UIParent:GetWidth()-32)/w,math.max(1,UIParent:GetHeight()-32)/h)
 f:SetSize(w,h); f:SetScale(scale); f.stripe:SetWidth(w-2)
 f.title:SetWidth(w-178); f.subtitle:SetWidth(w-178)
 K.queueStatus:SetWidth(w-36); K.queueNotice:SetWidth(w-36)
 K.queueEmpty:SetSize(w-36,180); K.queueEmpty:ClearAllPoints(); K.queueEmpty:SetPoint('TOPLEFT',18,-126-(h-306)/2)
 K.queueEmpty.title:SetWidth(w-36); K.queueEmpty.help:SetWidth(w-120)
 local pitch=(h-196)/8
 for i,r in ipairs(K.rows) do
  r:SetSize(w-72,pitch-5); r:ClearAllPoints(); r:SetPoint('TOPLEFT',18,-126-(i-1)*pitch)
  r.player:SetWidth(w-228); r.detail:SetWidth(w-228)
  r.remove:ClearAllPoints(); r.remove:SetPoint('TOPLEFT',w-48,-126-(i-1)*pitch-(pitch-35)/2)
 end
 K.queueNext:ClearAllPoints(); K.queueNext:SetPoint('BOTTOMRIGHT',-18,42)
 f.hint:ClearAllPoints(); f.hint:SetPoint('BOTTOMLEFT',18,14); f.hint:SetWidth(w-36)
end
function K.queueVisuals()
 if not K.queueWindow then return end
 local combat=A.combat()
 local key=#K.queue..':'..tostring(combat)
 if K.queueKey~=key then
  K.queueToggle.count:SetText(tostring(#K.queue))
  if K.buttons.summon and K.buttons.summon.queueCount then K.buttons.summon.queueCount:SetText(tostring(#K.queue)) end
  K.queueStatus:SetText(string.format(L.kitQueueCount,#K.queue))
  K.queueNotice:SetText(combat and L.kitQueueFrozen or L.kitQueueReadyHint)
  K.queueNotice:SetTextColor(combat and 1 or 0.7,combat and 0.72 or 0.65,combat and 0.3 or 0.8)
  K.queueKey=key
 end
 for _,r in ipairs(K.rows) do
  if r.request then
   local age=math.max(0,math.floor(GetTime()-r.lastRequest))
   r.detail:SetText(r.reason..' · '..string.format(L.kitQueueAge,math.floor(age/60),age%60))
   r.detail:SetTextColor(r.available and 0.65 or 0.8,r.available and 0.86 or 0.69,r.available and 0.73 or 0.52)
   r.actionText:SetText(combat and L.kitQueuePaused or (r.available and L.kitQueueInvoke or L.kitQueueUnavailable))
   r.actionText:SetTextColor(r.available and not combat and 0.95 or 0.6,r.available and not combat and 0.87 or 0.57,1)
   r.action:SetBackdropColor(0.16,0.09,0.24,r.available and not combat and 1 or 0.45)
   r:SetBackdropBorderColor(0.28,0.19,0.38,1)
  end
 end
end
function K.renderQueue()
 if not K.queueWindow then return end
 K.queueKey=nil
 if A.combat() then K.pending=true; return end
 K.layoutQueue()
 local names=K.roster(); local spell=K.best('summon'); local pages=math.max(1,math.ceil(#K.queue/8))
 K.page=math.min(K.page,pages); K.pageLabel:SetText(K.page..' / '..pages)
 K.queuePrevious:SetEnabled(K.page>1); K.queueNext:SetEnabled(K.page<pages)
 K.queueEmpty:SetShown(#K.queue==0)
 for i,b in ipairs(K.rows) do
  local request=K.queue[(K.page-1)*8+i]
  b:SetAttribute('type1',nil); b:SetAttribute('macrotext1',nil); b.request=request and request.name or nil
  b:SetShown(request~=nil)
  b.remove:SetShown(request~=nil)
  if request then
   local full=names[request.name]
   local canSummon=S.db.enabled and S.db.kit.enabled and spell and full and M.author(full)
   b.available=not not canSummon; b.lastRequest=request.last
   b.reason=not (S.db.enabled and S.db.kit.enabled) and L.kitQueueDisabled or (not spell and L.kitUnknown or (not canSummon and L.kitQueueOutside or L.kitQueueGrouped))
   b.player:SetText(request.name); b.number:SetText(tostring((K.page-1)*8+i))
   if canSummon then
    local name=A.spell(spell)
    b:SetAttribute('type1','macro')
    b:SetAttribute('macrotext1','/stopmacro [combat]\n/cleartarget\n/targetexact '..full..'\n/cast [exists,help,nodead] '..name)
   end
  end
 end
 K.queueVisuals()
end
function K.openQueue()
 if not K.queueWindow then return end
 if A.combat() then S.print(L.kitQueueCombat); return end
 K.renderQueue(); K.queueWindow:SetShown(not K.queueWindow:IsShown())
end
