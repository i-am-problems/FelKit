local _,S=...
local T={}; S.KitStatus=T
local A,D=S.API,S.KitData
local function contains(ids,id)
 for _,candidate in ipairs(ids or {}) do if candidate==id then return true end end
 return false
end
-- All activity is three-state: true, false, or nil when the client hides it.
function T.aura(auras,ids,now,own)
 if not auras then return nil end
 local unknown=false
 for _,a in ipairs(auras) do
  local expires=a.statusExpires or a.expires
  if contains(ids,a.id) and (not expires or expires>now) then
   if not own or a.own then return true,expires end
   if not a.ownerKnown then unknown=true end
  end
 end
 if not unknown then return false end
end
function T.healthCount(items)
 if not items then return nil end
 local count=0
 for _,item in ipairs(items) do if contains(D.healthItems,item.id) then count=count+item.count end end
 return count
end
-- Soulstones carried (every rank), read from the bags like healthstones.
function T.soulCount(items)
 if not items then return nil end
 local count=0
 for _,item in ipairs(items) do if contains(D.items.soul,item.id) then count=count+item.count end end
 return count
end
function T.weapon(enchant,family,auras,now)
 if not enchant or type(enchant.active)~='boolean' then return nil end
 if not enchant.active then return false end
 local active
 if enchant.id then active=contains(D.enchants[family],enchant.id)
 else active=T.aura(auras,D.auras[family],now); if active==false then active=nil end end
 if active then return true,enchant.ms and enchant.ms>0 and now+enchant.ms/1000 or nil end
 return active
end
local function readEnchant()
 -- Structured API includes the new Imbue slot as well as temporary enchants.
 local slot=Enum and Enum.WeaponSlot and A.num(Enum.WeaponSlot.MainHand)
 if slot and C_Item and C_Item.GetWeaponEnchantInfo then
  local entries=A.call(C_Item.GetWeaponEnchantInfo,slot)
  if type(entries)=='table' then
   local unknown=false
   for _,e in ipairs(entries) do
    local active=A.field(e,'hasEnchant'); local id=A.num(A.field(e,'enchantID'))
    if active==true and id and (contains(D.enchants.fire,id) or contains(D.enchants.stone,id)) then
     return {active=true,ms=A.num(A.field(e,'timeLeft')),id=id}
    end
    if type(active)~='boolean' or (active and not id) then unknown=true end
   end
   if not unknown then return {active=false} end
   return nil
  end
 end
 -- Forever legacy API: main hand flag, milliseconds, charges, enchant ID.
 if GetWeaponEnchantInfo then
  local ok,flag,ms,_,id=pcall(GetWeaponEnchantInfo)
  flag=A.public(flag)
  if ok and type(flag)=='boolean' then return {active=flag,ms=A.num(ms),id=A.num(id)} end
 end
end
function T.soul(now)
 T.unitSouls=T.unitSouls or {}
 local units={'player'}
 local count=math.min(40,A.num(A.call(GetNumGroupMembers)) or 0)
 local raid=A.call(IsInRaid)==true
 for i=1,count do units[#units+1]=raid and 'raid'..i or 'party'..i end
 if A.call(UnitIsPlayer,'target')==true and A.call(UnitCanAssist,'player','target')==true then units[#units+1]='target' end
 local unknown=false
 for _,unit in ipairs(units) do
  if unit=='player' or A.call(UnitExists,unit)~=false then
   local guid=A.guid(unit); local saved=T.unitSouls[unit]
   if not saved or not guid or saved.guid~=guid or now>=saved.next then
    local active,expires=T.aura(A.auras(unit,'HELPFUL'),D.auras.soul,now)
    saved={guid=guid,active=active,expires=expires,next=now+1}; T.unitSouls[unit]=saved
   end
   local active,expires=saved.active,saved.expires
   if expires and expires<=now then active=false end
   if active then return true,expires end
   if active==nil then unknown=true end
  end
 end
 if not unknown then return false end
end
function T.invalidate(unit)
 T.soulCache=nil
 if unit and T.unitSouls then T.unitSouls[unit]=nil else T.unitSouls={} end
end
function T.tracking()
 local modern=C_Minimap and C_Minimap.GetTrackingInfo
 local count=A.num(A.call(C_Minimap and C_Minimap.GetNumTrackingTypes or GetNumTrackingTypes))
 if not count then return nil end
 local unknown=false
 for i=1,math.min(count,50) do
  if modern then
   local info=A.call(modern,i)
   local id=A.num(A.field(info,'spellID'))
   local name=A.field(info,'name')
   if id==5500 or (not id and name and name==A.spell(5500)) then
    local active=A.field(info,'active'); if type(active)=='boolean' then return active end
    unknown=true
   elseif not id then unknown=true end
  elseif GetTrackingInfo then
   local ok,name,_,active=pcall(GetTrackingInfo,i)
   name=A.public(name); active=A.public(active)
   if ok and name==A.spell(5500) then
    if type(active)=='boolean' then return active end
    if type(active)=='number' then return active~=0 end
   end
   if not ok or not name then unknown=true end
  else unknown=true end
 end
 if not unknown then return false end
end
-- Display-only bag snapshot. Destruction and secure action configuration keep
-- their own fresh inventory reads. Bag/world events invalidate this snapshot.
function T.invalidateItems() T.itemsRead=nil; T.items=nil end
function T.inventory()
 if not T.itemsRead then
  T.items=A.inventory(); T.itemsRead=T.items~=nil
 end
 return T.items
end
function T.read(now)
 local player=A.auras('player','HELPFUL')
 local friendly=A.call(UnitCanAssist,'player','target')==true and A.call(UnitIsDeadOrGhost,'target')==false
 local helpful=player
 local helpfulSubject='player'
 if friendly then helpful=A.auras('target','HELPFUL'); helpfulSubject=A.guid('target') end
 local target=not friendly and A.auras('target','HARMFUL') or nil
 local pet=A.call(UnitExists,'pet'); local dead=A.call(UnitIsDeadOrGhost,'pet')
 local alive
 if pet==false or dead==true then alive=false elseif pet==true and dead==false then alive=true end
 if not T.soulCache or now>=T.soulCache.next then
  local active,expires=T.soul(now); T.soulCache={active=active,expires=expires,next=now+1}
 end
 return {now=now,player=player,target=target,helpful=helpful,helpfulSubject=helpfulSubject,targetSubject=A.guid('target'),
  pet=alive,items=T.inventory(),enchant=readEnchant(),soul=T.soulCache,channel=A.channel()}
end
function T.forButton(key,family,c)
 if key=='health' then
  local count=T.healthCount(c.items)
  if count==nil then return nil end
  return count>0,nil,count
 end
 if key=='soul' then
  local count=T.soulCount(c.items)
  if c.soul.expires and c.soul.expires<=c.now then return false,nil,count end
  return c.soul.active,c.soul.expires,count
 end
 if key=='demon' or key=='sacrifice' then
  local active,expires=T.aura(c.player,D.auras.sacrifice,c.now)
  if active then return true,expires end
  if key=='sacrifice' then return active end
  if c.pet==true then return true end
  if c.pet==false and active==false then return false end
  return nil
 end
 if key=='weapon' then return T.weapon(c.enchant,family,c.player,c.now) end
 if key=='link' then return T.aura(c.player,D.auras.link,c.now) end
 if key=='ward' or key=='armor' then return T.aura(c.player,D.families[family],c.now) end
 if key=='curse1' or key=='curse2' then return T.aura(c.target,D.families[family],c.now,true) end
 if key=='utility' then
  if family=='eye' and c.channel and c.channel.id==126 then return true,c.channel.finish end
  if family=='sense' then
   local active=T.tracking(); if active~=nil then return active end
   if T.aura(c.player,D.families.sense,c.now) then return true end
   return nil
  end
  local auras=c.player
  if family=='breath' or family=='invisibility' then auras=c.helpful end
  return T.aura(auras,D.families[family],c.now)
 end
end
T.managed={health=true,soul=true,demon=true,sacrifice=true,link=true,ward=true,armor=true,weapon=true,utility=true}
-- Session-only observations, shared by the main button and its menu choices.
-- Combat does not change the display policy. Hidden reads never renew a timer.
function T.resetDisplay(key)
 for id,saved in pairs(T.displayCache or {}) do
  if not key or saved.key==key then T.displayCache[id]=nil end
 end
end
function T.display(key,family,c)
 local active,expires,count=T.forButton(key,family,c)
 local subject='player'
 if key=='utility' and (family=='breath' or family=='invisibility') then subject=c.helpfulSubject
 elseif key=='curse1' or key=='curse2' then subject=c.targetSubject end
 T.displayCache=T.displayCache or {}
 local id=key..':'..(family or '')
 local saved=T.displayCache[id]
 if not subject or (saved and saved.subject~=subject) then T.displayCache[id]=nil; saved=nil end
 if active~=nil then
  -- The aura may remain identifiable while only its expiration becomes hidden.
  if active and not expires and saved and saved.active and saved.expires and saved.expires>c.now then
   return active,saved.expires,count,true
  end
  if subject then T.displayCache[id]={key=key,subject=subject,active=active,expires=expires,count=count} end
  return active,expires,count,false
 end
 if saved then
  if count==nil then count=saved.count end
  if saved.active and saved.expires and saved.expires<=c.now then return false,nil,count,true end
  return saved.active,saved.expires,count,true
 end
 return nil,nil,count,false
end
