package.path='tests/?.lua;src/lib/?.lua;'..package.path
local Vehicle=require 'horizonbase.vehicle';local now=100;local notices={}
local v=Vehicle.new(function()return now end,function(text)notices[#notices+1]=text end)
local sample={ready=true,alive=true,vehicle=12,networkVehicleId=40,model=401,vehicleName='Test Car',driver=true}
v:update(sample,true);assert(not v.current.ownership)
v:onMessage('Player: You are the owner of this Test Car.');assert(not v.current.ownership)
v:onMessage('You are the owner of this Different Car.');assert(not v.current.ownership)
v:onMessage('You are the owner of this Test Car.');assert(v.current.ownership=='personal')
v:onOutgoing('/car engine',true);now=120;v:onOutgoing('/car engine');assert(v.pending.gui)
v:onMessage('Vehicle lights successfully turned on.');assert(v.pending and v:state('engine')==nil)
v:onMessage('Vehicle engine turned off.');assert(v:state('engine')==false and not v.pending and #notices==1)
v:onOutgoing('/car window');v:onMessage('* Other Person rolls down their window and looks around.','Test_User');assert(v:state('window')==nil)
v:onMessage('* Test User rolls down their window and looks around.','Test_User');assert(v:state('window')==true)
v:onOutgoing('/car hood');v:onMessage('Vehicle hood successfully opened.');assert(v:state('hood')==true)
v:onOutgoing('/car trunk');v:onOutgoing('/changepass not-recorded');v:onMessage('Vehicle trunk successfully opened.');assert(v:state('trunk')==nil)
local epoch=v:token();sample.vehicle=13;sample.networkVehicleId=41;v:update(sample,true)
assert(v:token()~=epoch and not v.current.ownership and v:state('engine')==nil)
v:onOutgoing('/car engine',true);sample.driver=false;v:update(sample,true);v:onMessage('Vehicle engine turned on.');assert(v:state('engine')==nil and not v.pending)
sample.driver=true;v:update(sample,true);v:onMessage('You are in the family that owns this Test Car.');assert(v.current.ownership=='family')
v:onMessage('You are the owner of this Test Car.');assert(v.current.conflict and not v.current.ownership)
v:onOutgoing('/car lights',true);now=9000;v:update(sample,true);assert(not v.pending and #notices==2)
v:onMessage('You are the owner of this Test Car.');assert(not v.current.ownership,'Late ownership must not bind to an old entry')
v:onOutgoing('/car lights');v:onMessage('Vehicle lights successfully turned off.');assert(v:state('lights')==false)
now=70000;v:update(sample,true);assert(v:state('lights')==nil)
v:onOutgoing('/car engine');v:update(sample,false);assert(not v.pending)
sample.alive=false;v:update(sample,true);assert(not v.current)
assert(Vehicle.command('engine')=='/car engine' and not Vehicle.command('engine\n/deletecar'))
print('PASS identity/epoch ownership, ambiguity, actor validation, exact control feedback, duplicate echoes, expiry and cancellation')

local im=require 'fake_imgui';local Config=require 'horizonbase.config'
package.preload.vkeys=function()return {id_to_name=function(id)return 'Key '..id end}end
function getGameTimer()return now end
function getScreenResolution()return 1920,1080 end
local ui=require('horizonbase.ui').new(im,Config.copy(Config.defaults),function()end,function()end)
local actions={};local server={track={active=false}}
local panel=require('horizonbase.vehicle_ui').new(im,ui,v,server,function(kind,arg)actions[#actions+1]={kind,arg};return true end)
panel.open[0]=true;im.clicks['Engine##vehicleAction']=true;panel:draw();assert(#actions==0 and im.stack==0,'On-foot controls must be disabled')
sample.alive=true;sample.driver=true;v:update(sample,true)
panel.open[0]=true;im.clicks['Engine##vehicleAction']=true;panel:draw();assert(actions[1][1]=='vehicleControl' and actions[1][2]=='engine' and not panel.open[0])
panel.open[0]=true;im.clicks['My vehicles##vehicleTab2']=true;panel:draw();assert(panel.page==2 and #actions==1)
im.clicks['Vehicle storage##vehicleAction']=true;panel:draw();assert(actions[2][1]=='storage')
panel.open[0]=true;im.clicks['Track my vehicle##vehicleAction']=true;panel:draw();assert(actions[3][1]=='track')
server.track.active=true;panel.open[0]=true;im.clicks['Stop tracking##vehicleAction']=true;panel:draw();assert(actions[4][1]=='track')
panel.open[0]=true;panel.perform=function()return false,'Rejected action'end;im.clicks['Vehicle storage##vehicleAction']=true;panel:draw();assert(panel.open[0] and panel.notice=='Rejected action')
panel.perform=function()error('Injected vehicle UI failure')end;im.clicks['Vehicle storage##vehicleAction']=true;assert(not pcall(panel.draw,panel) and im.stack==0)
for _,size in ipairs({{640,480},{1280,720},{1920,1080}})do
 function getScreenResolution()return size[1],size[2]end
 panel.perform=function()return true end;panel:draw();assert(im.lastWindowSize.x<=size[1]-24 and im.lastWindowSize.y<=size[2]-24)
end
print('PASS dedicated vehicle tabs, disabled controls, native storage/tracking dispatch, readable viewport sizing and balanced cleanup')
local p=Config.validate({custombinds={{name='Existing K',command='/stats',key=75}}})
assert(p.keybinds.vehicleMenu==0 and p.custombinds[1].key==75)
assert(Config.validate({keybinds={siren=75}}).keybinds.vehicleMenu==0)
assert(Config.validate({}).keybinds.vehicleMenu==75)
assert(Config.validate(Config.parse(Config.serialize(p))).keybinds.vehicleMenu==0)
print('PASS K default collision migration and explicit unset preservation')
local s=require('horizonbase.server').new(Config.copy(Config.defaults),function()end,function()return now end)
s.horizon=true;s.ready=true;s.loginSeen=true;s.track.active=true;s.track.pendingDialog=true
s:onDialog(85,'Vehicle GPS Tracking','\nTest Car\nTest Bike (stored)\nEmpty',2);s:onDialogResponse(85,1,0,'')
assert(s.track.selection.label=='Test Car' and s.track.selection.list==0)
s.track.refresh=true;s.track.pendingDialog=true;s:onDialog(85,'Vehicle GPS Tracking','\nTest Car\nTest Bike (stored)\nEmpty',2)
assert(s.track.response.list==0,'Periodic replay must preserve native first-vehicle index')
for _,index in ipairs({1,2})do
 s.track.active=true;s.track.pendingDialog=true;s:onDialog(85,'Vehicle GPS Tracking','\nTest Car\nTest Bike (stored)\nEmpty',2);s:onDialogResponse(85,1,index,'');assert(not s.track.active and not s.track.selection)
end
print('PASS native GPS leading framing, preserved empty slots, first-row replay and stored/empty selection cancellation')
s.track.active=true;s.track.pendingDialog=true
assert(s:onDialog(80,'Vehicle storage (empty slots available: 6)','Vehicle: Test Car | Status: Spawned',2)==false)
s:onDialogResponse(80,1,0,'');assert(not s.track.active and not s.track.selection and not s.track.response,'Storage dialogs must never become replayable tracking selections')
print('PASS storage/input dialogs cannot be owned or replayed by the vehicle tracker')
