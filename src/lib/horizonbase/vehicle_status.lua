-- Presentation only: confirmed states are never inferred from an action request.
local M={}
function M.describe(observer,sample,part)
 local c=observer and observer.current;sample=sample or {}
 local matching=c and c.handle==sample.vehicle and c.id==sample.networkVehicleId
 local value
 if matching then
  if part=='lock' then value=sample.locked else value=observer:state(part)end
 end
 if type(value)~='boolean' then value=nil end
 local unavailable=matching and c.unavailable and c.unavailable[part]
 local text,active
 if unavailable then text='Unavailable'
 elseif value==nil then text='Unknown'
 elseif part=='lock' then text=value and 'Locked' or 'Unlocked';active=not value
 elseif part=='window' or part=='hood' or part=='trunk' then text=value and 'Open' or 'Closed';active=value
 else text=value and 'On' or 'Off';active=value end
 local path=part=='lock' and ('dashboard-v031/'..(value==false and 'car-door-lock-open' or 'car-door-lock')) or 'vehicle-v040/'..part
 return {text=text,token=active and 'accent' or 'muted',value=value,known=value~=nil,path=path..'.png'}
end
return M
