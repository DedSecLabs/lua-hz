-- Deliberate one-shot commands documented by Horizon's Ultimate Job Guide.
-- Availability comes from the current character snapshot, never skill levels.
local M={}
local jobs={
 detective={names={'detective'},actions={{'cohort','Find accomplices','cohort','target'}}},
 lawyer={names={'lawyer'},actions={{'lawyerduty','Lawyer duty','lawyerduty'},{'wanted','Wanted list','wanted'},{'free','Reduce sentence','free','target'},{'defend','Defend player','defend','price',200,1000}}},
 mechanic={names={'mechanic','car mechanic'},actions={{'fix','Fix vehicle','fix'},{'tunecar','Tune vehicle','tunecar'},{'hyd','Add hydraulics','hyd'},{'nos','Add nitro','nos'},{'repair','Offer repair','repair','price',1,1000000}}},
 bodyguard={names={'bodyguard'},actions={{'guard','Offer armor','guard','price',200,1000}}},
 armsdealer={names={'arms dealer','armsdealer'},actions={{'getmats','Get materials','getmats'}}},
 boxer={names={'boxer'},actions={{'boxstats','Boxing stats','boxstats'}}},
 drugsmuggler={names={'drug smuggler'},actions={{'getcrate','Get drug crate','getcrate','crate'}}},
 taxi={names={'taxi driver','taxi'},actions={{'fare','Set taxi fare','fare','fare',1,50}}},
 craftsman={names={'craftsman'},actions={{'craft','Craft items','craft'},{'craftmats','Get materials','getmats'}}},
 trucker={names={'trucker','blueberry trucker'},actions={{'loadtruck','Load truck','loadtruck'},{'checktruck','Check truck','checktruck'},{'hijacktruck','Hijack truck','hijacktruck'}}},
 pizza={names={'pizza delivery','pizza boy','pizza delivery boy'},actions={{'getpizza','Get pizza','getpizza'}}},
 pilot={names={'aircraft pilot','pilot'},actions={{'loadaircraft','Load aircraft','loadaircraft'}}},
 farmer={names={'farmer'},actions={{'farm','Start farming','farm'},{'harvest','Harvest crops','harvest'}}},
 garbage={names={'garbage man','garbageman'},actions={{'pickuptrash','Pick up trash','pickuptrash'}}},
 smuggler={names={'smuggler'},actions={{'transport','Transport packages','transport'}}},
 lumberjack={names={'lumberjack'},actions={{'chopwood','Chop wood','chopwood'}}},
 miner={names={'miner','stone miner'},actions={{'mine','Mine stone','mine'}}},
 forklift={names={'forklift driver'},actions={{'pickupcrates','Pick up crates','pickupcrates'}}},
 drugdealer={names={'drug dealer'},actions={{'getseeds','Get seeds','getseeds'},{'plantseeds','Plant seeds','plantseeds'},{'getcrack','Get crack','getcrack'}}},
 prostitute={names={'prostitute'},actions={}},
}
local order={'detective','lawyer','mechanic','bodyguard','armsdealer','boxer','drugsmuggler','taxi','craftsman','trucker','pizza','pilot','farmer','garbage','smuggler','lumberjack','miner','forklift','drugdealer','prostitute'}
local function normalize(s)
 return type(s)=='string' and s:lower():gsub('%s*%[.-%]',''):match('^%s*(.-)%s*$')or ''
end
function M.has(character,key)
 local spec=jobs[key];if not spec then return false end
 for _,field in ipairs({'Job','Job 2'})do
  local value=normalize(character and character.fields[field])
  for _,name in ipairs(spec.names)do if name==value then return true end end
 end
 return false
end
function M.list(character)
 local out={}
 for _,key in ipairs(order)do if M.has(character,key)then
  for _,a in ipairs(jobs[key].actions)do out[#out+1]={id=a[1],label=a[2],command=a[3],mode=a[4],min=a[5],max=a[6],job=key}end
 end end
 return out
end
function M.get(character,id)
 for _,action in ipairs(M.list(character))do if action.id==id then return action end end
end
local function integer(value,lo,hi)
 local n=type(value)=='string' and value:match('^%d+$')and tonumber(value)or type(value)=='number' and value
 if n and n==math.floor(n)and n>=lo and n<=hi then return tostring(n)end
end
function M.command(character,id,target,value)
 local a=M.get(character,id);if not a then return nil,'Your current jobs do not provide this action.'end
 local cmd='/'..a.command
 if a.mode=='target' or a.mode=='price'then
  local player=integer(target,0,1004);if not player then return nil,'Choose an online player ID.'end
  cmd=cmd..' '..player
 end
 if a.mode=='price' or a.mode=='fare'then
  local amount=integer(value,a.min,a.max);if not amount then return nil,('Enter a whole amount from %d to %d.'):format(a.min,a.max)end
  cmd=cmd..' '..amount
 elseif a.mode=='crate'then
  if value~='pot' and value~='crack'then return nil,'Choose pot or crack.'end
  cmd=cmd..' '..value
 end
 return cmd
end
return M
