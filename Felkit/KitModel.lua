local _,S=...
local M={}; S.KitModel=M
M.defaultVisible={}
M.defaultSelected={demon='void',health='health',utility='invisibility',weapon='stone',curse2='elements',curse1='recklessness'}
M.defaultPositions={soul={x=41.87107159574628,y=49.90000000000001},curse2={x=22.27913185097036,y=-61.21141168559331},
 curse1={x=56.41274215487211,y=-32.56991186884034},summon={x=-64.15020344671665,y=11.31141168559329},
 demon={x=64.15020344671663,y=11.31141168559331},health={x=0,y=65.13982373768071},
 armor={x=-22.27913185097036,y=-61.21141168559332},utility={x=-41.87107159574629,y=49.9},
 weapon={x=-63.49930542362068,y=-30.79827105165323},ward={x=21.87730382159414,y=-60.1073982483782}}
function M.settings(old)
 old=type(old)=='table' and old or {}
 -- 0.7.5: the defaults are the owner's own kit of 22 October 2026.
 local d={enabled=old.enabled~=false,layout='orb',hideUnknown=old.hideUnknown~=false,
  size=S.Model.number(old.size,28,52,36),scale=S.Model.number(old.scale,0.5,2,1),
  queueWidth=S.Model.number(old.queueWidth,460,800,550),queueHeight=S.Model.number(old.queueHeight,540,820,616),
  queueScale=S.Model.number(old.queueScale,0.65,1.5,1),
  queueButtonScale=S.Model.number(old.queueButtonScale,0.6,1.8,1.05),queueButtonDesign='icon',queueIconMigrated=true,
  circleDistance=S.Model.number(old.circleDistance,-200,200,-31),
  horizontalDirection=old.horizontalDirection=='left' and 'left' or 'right',
  verticalDirection=old.verticalDirection=='down' and 'down' or 'up',
  gridDirection='right',visible={},selected={},positions={},queueButtonPosition={x=469.5619505283089,y=-64.30173622535858}}
 if old.queueIconMigrated==true and (old.queueButtonDesign=='compact' or old.queueButtonDesign=='full') then d.queueButtonDesign=old.queueButtonDesign end
 local qp=type(old.queueButtonPosition)=='table' and old.queueButtonPosition
 local qx=qp and S.Model.number(qp.x,-20000,20000)
 local qy=qp and S.Model.number(qp.y,-20000,20000)
 if qx and qy then d.queueButtonPosition={x=qx,y=qy} end
 -- Felkit orb look and reminders.
 local N=S.Model.number
 d.orbSize=N(old.orbSize,40,96,58); d.smallScale=N(old.smallScale,40,90,62)
 d.orbArc=N(old.orbArc,120,300,220); d.orbGap=N(old.orbGap,0,24,7); d.rowGap=N(old.rowGap,0,24,7)
 d.divider=old.divider~=false; d.orbGlow=old.orbGlow~=false
 local arts={arcane=true,fel=true,shadow=true,item=true,class=true,none=true}
 d.orbArt=arts[old.orbArt] and old.orbArt or 'arcane'
 local rings={purple=true,gold=true,silver=true,fel=true,cyan=true}
 d.ringColor=rings[old.ringColor] and old.ringColor or 'purple'
 d.orbRingColor=rings[old.orbRingColor] and old.orbRingColor or 'gold'
 local alerts={cyan=true,orange=true,green=true,red=true,pink=true,white=true}
 d.alertColor=alerts[old.alertColor] and old.alertColor or 'cyan'
 d.countPos=(old.countPos=='corner' or old.countPos=='hidden') and old.countPos or 'middle'
 local r=type(old.reminders)=='table' and old.reminders or {}
 d.reminders={}
 for _,k in ipairs({'soul','health','armor','weapon','link'}) do d.reminders[k]=r[k]~=false end
 if old.gridDirection=='left' or old.gridDirection=='up' or old.gridDirection=='down' then d.gridDirection=old.gridDirection end
 if old.layout=='horizontal' or old.layout=='vertical' or old.layout=='circle' or old.layout=='free' or old.layout=='grid' then d.layout=old.layout end
 for _,g in ipairs(S.KitData.groups) do
  local saved,selected
  if type(old.visible)=='table' then saved=old.visible[g.key] end
  if type(saved)=='boolean' then d.visible[g.key]=saved else d.visible[g.key]=M.defaultVisible[g.key]~=false end
  if type(old.selected)=='table' then selected=old.selected[g.key] end
  if selected==nil then selected=M.defaultSelected[g.key] end
  for _,family in ipairs(g.families) do if selected==family then d.selected[g.key]=family end end
  local p=type(old.positions)=='table' and old.positions[g.key] or M.defaultPositions[g.key]
  local x=type(p)=='table' and S.Model.number(p.x,-20000,20000)
  local y=type(p)=='table' and S.Model.number(p.y,-20000,20000)
  if x and y then d.positions[g.key]={x=x,y=y} end
 end
 return d
end
function M.position(layout,i,n,size,options)
 local cfg=options or {}
 local gap=size+8
 local offset=math.max(58,(46+size)/2+8)
 if layout=='horizontal' then return (cfg.horizontalDirection=='left' and -1 or 1)*(offset+(i-1)*gap),0 end
 if layout=='vertical' then return 0,(cfg.verticalDirection=='up' and 1 or -1)*(offset+(i-1)*gap) end
 if layout=='grid' then
  local col,row=(i-1)%4,math.floor((i-1)/4)
  if cfg.gridDirection=='up' or cfg.gridDirection=='down' then
   return col*gap,(cfg.gridDirection=='up' and 1 or -1)*(offset+row*gap)
  end
  return (cfg.gridDirection=='left' and -1 or 1)*(offset+col*gap),-row*gap
 end
 -- Negative spacing allows a tighter ring, while keeping the shard clickable.
 local radius=(46+size)/2+8
 local centerRadius=radius
 for a=1,n do
  local aa=math.pi/2-(a-1)*2*math.pi/math.max(1,n)
  centerRadius=math.max(centerRadius,((46+size)/2+8)/math.max(math.abs(math.cos(aa)),math.abs(math.sin(aa))))
  radius=math.max(radius,centerRadius)
  for b=a+1,n do
   local ab=math.pi/2-(b-1)*2*math.pi/math.max(1,n)
   local separation=math.max(math.abs(math.cos(aa)-math.cos(ab)),math.abs(math.sin(aa)-math.sin(ab)))
   radius=math.max(radius,gap/separation)
  end
 end
 radius=math.max(centerRadius,radius+(cfg.circleDistance or 24))
 local angle=math.pi/2-(i-1)*2*math.pi/math.max(1,n)
 return math.cos(angle)*radius,math.sin(angle)*radius
end
function M.request(text)
 if type(text)~='string' or #text>2048 then return false end
 text=text:gsub('|H.-|h.-|h',''):gsub('|T.-|t',''):gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r','')
 return text:find('%f[%w]123%f[%W]')~=nil
end
function M.author(name)
 -- This value may enter a secure /targetexact macro. Reject macro/markup delimiters.
 return type(name)=='string' and #name>0 and #name<=100 and not name:find('[%c%[%]"/\\;|,=]')
  and not name:find('^%s') and not name:find('%s$')
end
function M.enqueue(queue,name,now)
 if not M.author(name) then return false end
 for _,r in ipairs(queue) do if r.name==name then r.last=now; return true end end
 if #queue>=100 then table.remove(queue,1) end
 queue[#queue+1]={name=name,first=now,last=now}; return true
end
function M.expire(queue,now)
 local changed=false
 for i=#queue,1,-1 do
  if now-queue[i].last>=600 then table.remove(queue,i); changed=true end
 end
 return changed
end
function M.remove(queue,name)
 for i=#queue,1,-1 do if queue[i].name==name then table.remove(queue,i); return true end end
end
