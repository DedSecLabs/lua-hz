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
panel.open[0]=true;panel.cursor=true;im.clicks['Engine##vehicleAction']=true;panel:draw();assert(#actions==0 and im.stack==0,'On-foot controls must be disabled')
sample.alive=true;sample.driver=true;v:update(sample,true)
panel.open[0]=true;panel.cursor=true;im.clicks['Engine##vehicleAction']=true;panel:draw();assert(actions[1][1]=='vehicleControl' and actions[1][2]=='engine' and panel.open[0])
panel.open[0]=true;panel.cursor=true;im.clicks['My vehicles##vehicleTab3']=true;panel:draw();assert(panel.page==3 and #actions==1)
-- This fake dispatcher completes immediately; runtime normally clears queued.
panel.queued=false;im.clicks['Storage##vehicleAction']=true;panel:draw();assert(actions[2][1]=='storage')
panel.queued=false;panel.open[0]=true;panel.cursor=true;im.clicks['Track vehicle##vehicleAction']=true;panel:draw();assert(actions[3][1]=='track')
panel.queued=false;server.track.active=true;panel.open[0]=true;panel.cursor=true;im.clicks['Stop tracking##vehicleAction']=true;panel:draw();assert(actions[4][1]=='track')
panel.queued=false;panel.open[0]=true;panel.cursor=true;panel.perform=function()return false,'Rejected action'end;im.clicks['Storage##vehicleAction']=true;panel:draw();assert(panel.open[0] and panel.notice=='Rejected action')
panel.perform=function()error('Injected vehicle UI failure')end;im.clicks['Storage##vehicleAction']=true;assert(not pcall(panel.draw,panel) and im.stack==0)
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
-- An outside trunk request must work without assigning the nearby car's state to the last driven car.
now=100000;sample.vehicle=false;sample.x=0;sample.y=0;sample.z=10;v:reset();v:update(sample,true)
assert(v:available('trunk') and not v:available('hood') and not v:available('engine'))
v:onOutgoing('/car trunk',true);assert(v.pending)
v:onMessage('Vehicle trunk successfully opened.');assert(not v.pending and not v.current and v:state('trunk')==nil)
v:onOutgoing('/trunkbalance',true)
v:onMessage('Player: *** Test User\'s Test Car Trunk ***');assert(not v.pending.draft)
v:onMessage('*** Test User\'s Test Car Trunk ***')
v:onMessage('Slot 1: MP5');v:onMessage('Pot: 25 grams');v:onMessage('Crack: 0 grams');v:onMessage('Advertisement: unrelated')
now=100800;v:update(sample,true);assert(v.cargo and #v.cargo.rows==3 and not v.pending)
sample.x=4;v:update(sample,true);assert(not v.cargo,'Walking away must invalidate nearby trunk contents')
v:onOutgoing('/trunkbalance',true);v:onMessage("You can't check the status of the trunk if it's closed! /car trunk to open it.")
assert(not v.pending and notices[#notices]=='Open the trunk before viewing its contents.')
sample.vehicle=12;sample.networkVehicleId=40;sample.x=0;v:update(sample,true)
v:onOutgoing('/car window',true);v:onMessage("You can't open the window in these type of vehicles.")
assert(not v.pending and not v:available('window') and v:state('window')==nil)
v:onOutgoing('/car hood',true);v:onMessage("This command can't be used in this vehicle.");assert(not v.pending and not v:available('hood'))
sample.vehicle=13;v:update(sample,true);assert(v:available('window') and v:available('hood'),'Rejections must not leak into another vehicle entry')
panel.cursor=false;panel.page=1;im.clicks['Engine##vehicleAction']=true;local before=#actions;panel:draw();assert(#actions==before,'Glance mode cannot dispatch a driving mouse click')
print('PASS outside trunk dispatch, scoped contents, walk-away invalidation, immediate rejections and pointer-only interaction')
now=110000;v:reset();sample.vehicle=false;v:update(sample,true)
v:onOutgoing('/trunkbalance',true)
assert(not v:onMessage('Slot 1: MP5'),'Rows before a recognized header must remain visible')
assert(not v:onMessage("Player: *** Test User's Test Car Trunk ***"))
now=110400;v:onOutgoing('/trunkbalance');assert(v.pending.gui,'Deferred outgoing echo preserves GUI silence')
assert(v:onMessage("*** Test User's Test Car Trunk ***"))
assert(v:onMessage('Slot 1: MP5') and v:onMessage('Pot: 25 grams') and v:onMessage('Crack: 0 grams'))
assert(not v:onMessage('Advertisement: ordinary chat'))
v:onOutgoing('/trunkbalance',false)
assert(not v.pending.gui and not v:onMessage("*** Test User's Test Car Trunk ***"),'Explicit manual/keybind commands revoke quiet ownership')
assert(not v:onMessage('Slot 1: MP5'))
v:onOutgoing('/trunkbalance',true);now=now+8001
assert(not v:onMessage("*** Test User's Test Car Trunk ***"),'Expired requests never suppress chat')
sample.vehicle=13;v:update(sample,true);v:onOutgoing('/car lights',true)
panel.page=1;panel.cursor=true;im.drawTexts={};panel:draw()
for _,text in ipairs(im.drawTexts)do assert(text~='Waiting for server')end
print('PASS bounded quiet GUI trunk framing, preserved unrelated/manual output, echo ownership, expiry and minimal pending presentation')
local Overlay=require 'horizonbase.overlay'
local dockSample={ready=true,alive=true,vehicle=false,underwater=false}
local dockGame={sample=dockSample,cruise={active=false}}
ui.overlay=Overlay.new(im,ui.prefs,dockGame,server)
for _,screen in ipairs({{640,480},{1280,720},{1920,1080}})do
 local foot=panel:layout(screen[1],screen[2])
 for _,state in ipairs({{vehicle=12,underwater=false},{vehicle=false,underwater=true},{vehicle=12,underwater=true},{vehicle=false,underwater=false}})do
  dockSample.vehicle=state.vehicle;dockSample.underwater=state.underwater
  local seated=panel:layout(screen[1],screen[2])
  assert(foot.width==seated.width and foot.height==seated.height and foot.scale==seated.scale,'Entering, exiting or oxygen visibility must not resize the vehicle menu')
  assert(seated.x>=0 and seated.x+seated.width<=screen[1] and seated.y>=0 and seated.y+seated.height<=screen[2])
 end
end
print('PASS constant vehicle dock size across on-foot/seated/oxygen contexts and viewport bounds')
