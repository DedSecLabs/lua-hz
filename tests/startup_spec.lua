function sampTextdrawIsExists(id)return id==200 end
function sampTextdrawGetPos()return 0,0 end
function sampTextdrawSetPos()end
function sampTextdrawGetString()error('Runtime must not scan native textdraw strings')end
-- Runtime entry-point smoke test using explicit MoonLoader stubs. Does not run GTA.
package.path='tests/?.lua;src/lib/?.lua;src/lib/?/init.lua;'..package.path
local im=require 'fake_imgui'
local frames,inits,commands,sent,logs={},{},{},{},{}
local rawPrint=print
function print(...)local values={...};for i,v in ipairs(values)do values[i]=tostring(v)end;logs[#logs+1]=table.concat(values,' ')end
function script_name()end;function script_author()end;function script_version()end;function script_description()end
package.preload['lib.moonloader']=function()return {}end
package.preload['horizonbase.ui_backend']=function()return im end
package.preload['samp.events']=function()return {}end
package.preload['vkeys']=function()return {id_to_name=function()return 'F9'end}end
local cycleDisabled=0
package.preload['memory']=function()return {getuint8=function(address)
    assert(address==0xB73575);return cycleDisabled
end}end
function setPlayerWeaponsScrollable(handle,enabled)cycleDisabled=enabled and 0 or 1 end
local reloadPlaying=false
function isCharPlayingAnim(_,name)return reloadPlaying and name=='Reload_Test'end
function getCharAnimCurrentTime()return .5 end
package.preload['horizonbase.limiter']=function()return {new=function()return {present=function()end}end}end
local configReads=0
local cfg=require 'horizonbase.config';cfg.read=function()configReads=configReads+1;return {modifiers={quickmap=4},custombinds={{name='Stats',command='/stats',key=83,mods=4},{name='Vehicle locks',command='/pvl',command2='/gvl',key=76,mods=4}}} end;cfg.save=function()return true end
local Catalog=require 'horizonbase.location_catalog'
local catalogNew=Catalog.new
local catalog
if arg[1] then
    Catalog.new=function(_,clock)catalog=catalogNew(arg[1],clock);return catalog end
end
function getWorkingDirectory()return 'C:\\Test\\moonloader'end
function doesDirectoryExist()return true end;function createDirectory()end
function doesFileExist()return false end
function getScreenResolution()return 1920,1080 end
local gameClock=1000
function getGameTimer()return gameClock end
function wait()coroutine.yield()end
function isSampLoaded()return true end;function isSampfuncsLoaded()return true end;function isSampAvailable()return true end
local gamestate=3
local endpoint,serverPort='192.0.2.10',7777
function sampGetCurrentServerAddress()return endpoint,serverPort end
function sampGetGamestate()return gamestate end
function sampAddChatMessage(text)logs[#logs+1]=text end
function sampRegisterChatCommand(name,fn)commands[name]=fn end
function sampUnregisterChatCommand(name)commands[name]=nil end
function sampSendChat(command)sent[#sent+1]=command end
function sampSendDialogResponse()end
function sampGetCurrentServerName()return 'Horizon Roleplay'end
function sampGetPlayerIdByCharHandle()return true,17 end
function sampGetPlayerColor()return 0xFF2641FE end
function sampGetMaxPlayerId()return 20 end
function sampIsPlayerConnected(id)return id==17 or id==18 end
function sampGetPlayerNickname(id)return id==18 and 'Jane_Doe' or 'John_Doe'end
function isPauseMenuActive()return false end
local chat=false
local chatText=''
function sampGetChatInputText()return chatText end
function sampIsChatInputActive()return chat end;function sampIsDialogActive()return false end
PLAYER_PED=1;PLAYER_HANDLE=0
function doesCharExist()return true end;function isCharDead()return false end
function getCharCoordinates()return 0,0,10 end
function getCharPointer()return 0 end
function getCharHealth()return 100 end;function getCharArmour()return 50 end
local heldWeapon=0
function getCurrentCharWeapon()return heldWeapon end;function getAmmoInCharWeapon()return 0 end
function getTimeOfDay()return 22,56 end
function getPlayerMoney()return 4360 end;function storeWantedLevel()return true,2 end
function getCharHeading()return 90 end;function isCharSwimming()return false end
function getCharSpeed()return 0 end;function getPadState()return 0 end
function isCharInAnyCar()return false end
local pressed,down=nil,{}
function isKeyJustPressed(code)return code==pressed end
function isKeyDown(code)return down[code] or false end
local accelerator
function setGameKeyState(key,value)if key==16 then accelerator=value end end
local nativeHud=true
function displayHud(value)nativeHud=value end;function displayRadar()end
local consumed=0
function consumeWindowMessage()consumed=consumed+1 end
local script={}
function thisScript()return script end
im.OnInitialize=function(fn)inits[#inits+1]=fn end
im.OnFrame=function(cond,fn)local frame={Condition=cond,draw=fn};frames[#frames+1]=frame;return frame end
assert(loadfile('src/HorizonBase.lua'))()
local thread=coroutine.create(main)
local function tick()local ok,err=coroutine.resume(thread);assert(ok,err)end
tick();tick()
assert(#frames==0 and next(commands)==nil and #sent==0 and configReads==0)
assert(not package.loaded['horizonbase.runtime'] and not package.loaded['horizonbase.ui_backend'])
onWindowMessage(0x0100,120,0);onD3DPresent();assert(consumed==0 and nativeHud==true)
endpoint='213.32.6.232';tick();tick()
assert(not frames[1].Condition(),'Player HUD must stay hidden before login')
assert(nativeHud==false,'Vanilla player HUD must also stay hidden on the login screen')
require('samp.events').onServerMessage(-1,'Welcome to Horizon Roleplay, John Doe.')
assert(frames[1].Condition(),'Successful login must show the HUD')
for _,fn in ipairs(inits)do fn()end
assert(commands.lsettings and commands.luahz and commands.luahzreload and commands.luahzdebug and commands.autofind and commands.autotrackcar and commands.hbdebug)
for _,f in ipairs(frames)do if f.Condition()then f.draw()end end
assert(nativeHud==false)
rawPrint('PASS entry-point startup and login-gated HUD frame')
function doesCharExist()return false end;tick();assert(not frames[1].Condition())
function doesCharExist()return true end;tick();assert(frames[1].Condition(),'Transient ped loss must not discard successful login')
onWindowMessage(0x0100,120,0)
assert(consumed==1)
assert(not frames[1].Condition(),'Settings must hide the custom player HUD so it cannot overlap the menu')
for _,f in ipairs(frames)do if f.Condition()then f.draw()end end
assert(im.stack==0)
rawPrint('PASS F9 opens the menu and consumes the SA-MP key')
local searchConsumed=consumed
onWindowMessage(0x0100,73,0)
assert(consumed==searchConsumed and frames[3].Condition() and not frames[5].Condition(),'Typing I in F9 must not open Character Status')
onWindowMessage(0x0100,27,0);chat=true
local before=consumed;onWindowMessage(0x0100,77,0);assert(consumed==before)
chat=false
rawPrint('PASS chat input suppresses map shortcut')
local count=#sent
pressed=83;tick();assert(#sent==count) -- S alone is not Alt+S.
down[18]=true;chat=true;tick();assert(#sent==count)
chat=false;tick();assert(#sent==count+1 and sent[#sent]=='/stats')
pressed=nil;tick();assert(#sent==count+1)
down[18]=nil;onWindowMessage(0x0100,120,0);tick();down[18]=true;pressed=83;tick();assert(#sent==count+1)
pressed=nil;down[18]=nil;onWindowMessage(0x0100,27,0)
local consumedBefore=consumed
assert(frames[1].Condition(),'Closing settings must restore the custom player HUD')
onWindowMessage(0x0100,77,0);assert(consumed==consumedBefore)
down[18]=true;onWindowMessage(0x0104,77,0x20000000);assert(consumed==consumedBefore+1)
onWindowMessage(0x0104,77,0x20000000);down[18]=nil
rawPrint('PASS custom Alt+S dispatch, typing suppression and exact map combo')
assert(frames[2].HideCursor and frames[2].LockPlayer==false,'Map must leave player input unlocked')
function isCharInAnyCar()return true end
function storeCarCharIsInNoSave()return 5 end
function doesVehicleExist()return true end
function getDriverOfCar()return PLAYER_PED end
function getCarModel()return 400 end
function getCarSpeed()return 10 end
function getCarHealth()return 1000 end
tick();pressed=97;tick();pressed=nil
assert(accelerator and accelerator>0,'Cruise must be active before opening the map')
down[18]=true;onWindowMessage(0x0104,77,0x20000000);down[18]=nil
assert(frames[2].Condition())
accelerator=nil;tick();assert(accelerator and accelerator>0,'Cruise must continue while Quickmap is open')
local inputBefore=consumed;onWindowMessage(0x0100,87,0);assert(consumed==inputBefore,'W must reach GTA while the map is open')
down[83]=true;tick();assert(accelerator==0,'Normal brake must still cancel cruise on the map');down[83]=nil
onWindowMessage(0x0100,27,0)
assert(not frames[2].Condition())
function isCharInAnyCar()return false end
rawPrint('PASS Quickmap keeps player controls and cruise active, passes movement input and preserves braking')
heldWeapon=22
gameClock=2000;local reloadBefore=#sent
pressed=82;tick();assert(#sent==reloadBefore+1 and sent[#sent]=='/reload 2')
assert(cycleDisabled==1,'R must immediately gate native weapon cycling')
local reloadEvents=require 'samp.events'
assert(reloadEvents.onApplyPlayerAnimation(17,'TEST','Reload_Test',false,false,false,false,0)==nil,
    'The server animation must pass through untouched')
reloadPlaying=true
pressed=nil;tick();assert(#sent==reloadBefore+1)
gameClock=2400;pressed=82;tick();assert(#sent==reloadBefore+1 and cycleDisabled==1,'Repeated R during reload must stay quiet')
reloadPlaying=false;pressed=nil;tick();assert(cycleDisabled==0,'Native completion restores weapon cycling')
assert(reloadEvents.onClearPlayerAnimation(17)==nil,'Clear-animation RPC must pass through')
gameClock=2500;chat=true;pressed=82;tick();assert(#sent==reloadBefore+1)
chat=false;pressed=nil
heldWeapon=0;gameClock=3000;pressed=82;tick();assert(#sent==reloadBefore+1)
heldWeapon=43;gameClock=3500;tick();assert(#sent==reloadBefore+1)
pressed=nil;heldWeapon=22
rawPrint('PASS reload hotkey fires for guns, stays quiet for fists/camera and is blocked while typing')

local statusBefore=consumed
onWindowMessage(0x0100,73,0);assert(consumed==statusBefore+1 and frames[5].Condition())
assert(not frames[1].Condition(),'Character Status must hide the custom player HUD')
assert(frames[5].LockPlayer==true and not frames[5].HideCursor)
frames[5].draw();assert(im.stack==0)
local typingCount=#sent;pressed=82;tick();assert(#sent==typingCount,'Status panel must block gameplay shortcuts')
pressed=nil;onWindowMessage(0x0100,73,0);assert(not frames[5].Condition())
onWindowMessage(0x0100,73,0);onWindowMessage(0x0100,27,0);assert(not frames[5].Condition())
chat=true;statusBefore=consumed;onWindowMessage(0x0100,73,0);assert(consumed==statusBefore);chat=false
rawPrint('PASS I opens/closes Character Status; Escape, typing and gameplay-hotkey guards')
-- Complete the stats request queued by opening the empty panel before checking other queue traffic.
gameClock=4000;tick()
local statusEvents=require 'samp.events'
statusEvents.onServerMessage(-1,'John Doe - (Level: 1) - (Playing hours: 7) - (Age: 35) - (Gender: Male) - (Warnings: 0) - (Job: Detective [lvl: 1]) - (Donator: No)')
gameClock=5500
commands.autofind('17');tick();assert(sent[#sent]=='/find 17')
local events=require 'samp.events'
assert(events.onCreateGangZone(9,{x=-100,y=-200},{x=300,y=200},0x8000FF00)==nil)
assert(events.onGangZoneFlash(9,0x800000FF)==nil)
commands.luahzdebug()
local turfFound=false
for _,line in ipairs(logs)do if line:find('id=9 x1=-100.00 y1=-200.00 x2=300.00 y2=200.00 color=0x8000FF00 flash=0x800000FF',1,true) then turfFound=true end end
assert(turfFound,'Debug must include the received live turf and flash colors')
assert(events.onGangZoneStopFlash(9)==nil)
assert(events.onGangZoneDestroy(9)==nil)
rawPrint('PASS gang-zone create/flash/stop/destroy callbacks retain native handling and report live diagnostics')
assert(events.onSetMapIcon(7,{x=12.5,y=-30,z=4},22,0xFF2244AA,1)==nil)
commands.luahzdebug()
local markerFound=false
for _,line in ipairs(logs) do
    if line:find('id=7 type=22 sprite=Hospital rgba=0xFF2244AA style=1 x=12.50 y=-30.00 z=4.00',1,true) then markerFound=true end
end
assert(markerFound,'Debug must report the actual server-supplied marker fields')
if catalog then assert(catalog.address=='Horizon Roleplay' and #catalog.records==1,'Horizon must bind its catalog before map events') end
assert(events.onRemoveMapIcon(7)==nil)
if catalog then assert(#catalog.records==1,'Stream-out must retain the remembered observation') end
commands.luahzdebug()
assert(logs[#logs-1]:find('Component status') or logs[#logs]:find('Component status'))
rawPrint('PASS map events preserve native handling and diagnostics capture the received sprite/color/position')
assert(events.onPlayAudioStream('https://example.test/song.mp3',{x=0,y=0,z=0},0,false)==nil)
assert(events.onStopAudioStream()==nil)
rawPrint('PASS audio observations pass server play/stop events through unchanged')
events.onPlayerQuit(17,0)
events.onPlayerJoin(18,0xFF2641FE,false,'John_Doe')
rawPrint('PASS player rejoin callback uses the installed SAMP.Lua argument layout')
commands.autofind('');tick()
rawPrint('PASS registered tracking command reaches the server queue')
-- Exercise the real callback return that controls chat visibility.
gameClock=20000;onWindowMessage(0x0100,73,0)
im.clicks.Refresh=true;frames[5].draw();tick()
local sep=string.rep('_',99)
assert(events.onServerMessage(-1,sep)==false)
assert(events.onServerMessage(-1,'John Doe - (Level: 1) - (Playing hours: 7) - (Age: 35) - (Gender: Male) - (Warnings: 0)')==false)
assert(events.onServerMessage(-1,'Advertisement: ordinary chat')==nil)
assert(events.onServerMessage(-1,'(Cash: $4,360) - (Donator: No)')==false)
assert(events.onServerMessage(-1,sep)==false)
assert(events.onServerMessage(-1,'Unrelated server message')==nil)
events.onSendCommand('/stats')
assert(events.onServerMessage(-1,'John Doe - (Level: 1) - (Playing hours: 7) - (Age: 35) - (Gender: Male) - (Warnings: 0) - (Job: Detective [lvl: 1]) - (Donator: No)')==nil)
onWindowMessage(0x0100,27,0)
rawPrint('PASS actual incoming chat callback suppresses only owned stats; ordinary and manual responses pass through')

-- Capture through real callback wrappers with an injected file sink, never the game filesystem.
local originalOpen=io.open
local captured,closedCapture={},0
io.open=function(path,mode)
    if path:find('luahz-observations',1,true) then
        if mode=='rb' then return nil end
        assert(mode=='wb')
        return {write=function(_,line)captured[#captured+1]=line;return true end,
            flush=function()return true end,close=function()closedCapture=closedCapture+1;return true end}
    end
    return originalOpen(path,mode)
end
local noExtraSend=#sent
commands.luahzcapture('on')
assert(#captured==1 and #sent==noExtraSend,'Enabling capture must not issue server commands')
assert(events.onSendCommand('/families')==nil)
for i=1,12 do assert(events.onServerMessage(-1,('* %d. Test Family'):format(i))==nil) end
assert(#captured==14 and captured[3]:find('1. Test Family',1,true))
assert(events.onSetCheckpoint({x=1,y=2,z=3})==nil)
assert(captured[#captured]:find('"event":"checkpoint"',1,true))
assert(events.onSetRaceCheckpoint(1,{x=1,y=2,z=3},{x=4,y=5,z=6},2)==nil)
assert(captured[#captured]:find('"next_x":4',1,true))
assert(events.onDisableRaceCheckpoint()==nil)
assert(events.onShowDialog(10,0,'Families','test table')==nil)
assert(events.onShowTextDraw(200,{text='V2.4.47[Z]',position={x=0,y=0}})==nil)
assert(events.onShowTextDraw(201,{text='Horizon Roleplay',position={x=0,y=0}})==nil)
commands.luahzversion();commands.luahzdebug()
local observed=false
for _,line in ipairs(logs)do if line:find('Horizon version: 2.4.47 [Z]',1,true) then observed=true end end
assert(observed and #sent==noExtraSend)
commands.luahzcapture('off');assert(closedCapture==1)
local blockedRequestRows=#captured
commands.luahzcapture('buylevel');commands.luahzcapture('gvl');commands.luahzcapture('killcheckpoint')
assert(#captured==blockedRequestRows and #sent==noExtraSend,'Capture must never submit action commands')
commands.luahzcapture('families')
assert(#sent==noExtraSend,'Requested capture must send from the main loop, not its input callback')
gameClock=22000;tick()
assert(#sent==noExtraSend+1 and sent[#sent]=='/families','Direct capture must send exactly one selected read-only request')
assert(captured[#captured]:find('"source":"explicit read-only capture"',1,true))
for i=1,12 do assert(events.onServerMessage(-1,('* %d. Direct Test Family'):format(i))==nil) end
gameClock=30001;tick();assert(closedCapture==2,'One-command capture must close automatically after its response window')
assert(captured[#captured]:find('command window completed',1,true))
gameClock=43000 -- Let the earlier simulated /inv request expire before testing another refresh.
onWindowMessage(0x0100,120,0)
im.clicks['Server##tab']=true;im.clicks['Refresh##horizon-families']=true;frames[3].draw();tick()
assert(sent[#sent]=='/families','Server tab Refresh must send its read-only request with F9 open')
gameClock=43050;events.onSendCommand('/families') -- Deferred native echo after sampSendChat has returned.
assert(events.onServerMessage(-1,'Gangs:')==false)
assert(events.onServerMessage(-1,'* 1. Quiet Test Family | Leader: Person Test | Members: 10 | Online: 1')==false)
assert(events.onServerMessage(-1,'Interest gained: $41')==nil,'Unrelated server announcements must remain visible')
chat=true;chatText='/families';onWindowMessage(0x0100,13,0);chat=false
events.onSendCommand('/families')
assert(events.onServerMessage(-1,'Gangs:')==nil,'Manual requests must remain visible')
onWindowMessage(0x0100,27,0)
rawPrint('PASS GUI refresh preserves quiet ownership across deferred callbacks and manual Enter restores visible commands')
local lockStart=#sent
gameClock=46000;down[18]=true;pressed=76;tick()
assert(#sent==lockStart+1 and sent[#sent]=='/pvl')
gameClock=46250;assert(events.onServerMessage(-1,'You are not near any vehicle that you own.')==false)
pressed=nil;gameClock=47999;tick();assert(#sent==lockStart+1)
gameClock=48000;tick();assert(#sent==lockStart+2 and sent[#sent]=='/gvl')
gameClock=48250;events.onTextDrawSetString(2050,'~g~Test Vehicle Unlocked')
gameClock=50000;pressed=76;tick();assert(sent[#sent]=='/pvl')
pressed=nil;chat=true;gameClock=52000;tick();chat=false;down[18]=nil
local groupLocks=0;for _,cmd in ipairs(sent)do if cmd=='/gvl' then groupLocks=groupLocks+1 end end
tick();local groupLocksAfter=0;for _,cmd in ipairs(sent)do if cmd=='/gvl' then groupLocksAfter=groupLocksAfter+1 end end
assert(groupLocksAfter==groupLocks,'Typing must cancel the delayed step without resuming it')
rawPrint('PASS actual lock hotkey waits for explicit failure before fallback, recognizes success and cancels on typing')
gameClock=56000;down[18]=true;pressed=76;tick();pressed=nil
assert(sent[#sent]=='/pvl')
assert(events.onServerMessage(-1,'You are not near any vehicle that you own.')==false)
gameClock=58000;tick();assert(sent[#sent]=='/gvl')
local quietLockLogs=#logs
assert(events.onServerMessage(-1,'You are not near any vehicle that your family owns.')==false)
assert(#logs==quietLockLogs and frames[4].Condition(),'Owned final lock error must use the toast without chat spam')
assert(events.onServerMessage(-1,'You are not near any vehicle that your family owns.')==nil,'Unowned/manual errors must remain visible')
down[18]=nil
rawPrint('PASS actual owned neither-nearby lock failure becomes a toast while normal server errors remain visible')
commands.luahzcapture('help');gameClock=65000;tick()
assert(sent[#sent]=='/help')
assert(events.onServerMessage(-1,'*** GENERAL *** /families /members /info')==nil,'Diagnostic help capture must not hide its response')
gameClock=73001;tick();assert(closedCapture==3)
commands.autofind('')
chat=true;local actionConsumed=consumed;onWindowMessage(0x0100,85,0)
assert(consumed==actionConsumed and not frames[7].Condition());chat=false
onWindowMessage(0x0100,85,0);assert(frames[7].Condition() and not frames[3].Condition())
assert(not frames[1].Condition(),'Quick Actions must hide the custom player HUD')
onWindowMessage(0x0100,85,0x40000000);assert(frames[7].Condition(),'Held U must not toggle repeatedly')
local beforeAction=#sent;im.clicks['Clear navigation##quickAction']=true;frames[7].draw()
assert(#sent==beforeAction and not frames[7].Condition(),'GUI actions send from the main loop after closing the panel')
gameClock=75000;tick();assert(sent[#sent]=='/killcheckpoint')
local clearCount=0;for _,command in ipairs(sent)do if command=='/killcheckpoint' then clearCount=clearCount+1 end end
tick();local clearCountAfter=0;for _,command in ipairs(sent)do if command=='/killcheckpoint' then clearCountAfter=clearCountAfter+1 end end
assert(clearCountAfter==clearCount,'Pending acknowledgment must not resend the action')
assert(events.onServerMessage(-1,'All current checkpoints, trackers and accepted fares have been reset.')==false)
onWindowMessage(0x0100,85,0);im.clicks['Find player##quickAction']=true;frames[7].draw()
actionConsumed=consumed;onWindowMessage(0x0100,73,0);onWindowMessage(0x0100,85,0)
assert(consumed==actionConsumed and frames[7].Condition() and not frames[5].Condition(),'Typing I or U in the selector must not open/close panels')
im.clicks['Jane_Doe (18)##quickTarget18']=true;frames[7].draw()
local oldNickname=sampGetPlayerNickname
function sampGetPlayerNickname(id)return id==18 and 'Changed_Player' or oldNickname(id)end
gameClock=76500;local findCount=0;for _,cmd in ipairs(sent)do if cmd=='/find 18' then findCount=findCount+1 end end;tick()
local findCountAfter=0;for _,cmd in ipairs(sent)do if cmd=='/find 18' then findCountAfter=findCountAfter+1 end end
assert(findCountAfter==findCount,'A changed target must be rejected after selection and before sending')
sampGetPlayerNickname=oldNickname
onWindowMessage(0x0100,85,0);im.clicks['Find player##quickAction']=true;frames[7].draw()
im.clicks['Jane_Doe (18)##quickTarget18']=true;frames[7].draw();gameClock=78000;tick();assert(sent[#sent]=='/find 18')
onWindowMessage(0x0100,85,0);im.clicks['Stop finding##quickAction']=true;frames[7].draw();tick()
onWindowMessage(0x0100,75,0);im.drawTexts={};frames[8].draw();assert(table.concat(im.drawTexts,'|'):find('Trunk balance',1,true),'K must open Trunk while on foot')
im.clicks['My vehicles##vehicleTab3']=true;im.clicks['Track vehicle##vehicleAction']=true;down[18]=true;tick();frames[8].draw();down[18]=nil;gameClock=79500;tick();assert(sent[#sent]=='/trackcar')
im.clicks['Stop tracking##vehicleAction']=true;down[18]=true;tick();frames[8].draw();down[18]=nil;tick()
im.clicks['Controls##vehicleTab1']=true;im.clicks['Doors##vehicleAction']=true;down[18]=true;tick();frames[8].draw();down[18]=nil;gameClock=81000;tick();assert(sent[#sent]=='/pvl')
events.onTextDrawSetString(2050,'~g~Test Vehicle Unlocked')
onWindowMessage(0x0100,75,0);onWindowMessage(0x0100,85,0);onWindowMessage(0x0100,27,0);assert(not frames[7].Condition())
assert(frames[7].LockPlayer and not frames[7].HideCursor)
rawPrint('PASS character U panel and separate K storage/tracking/locking actions')
local parkedCar=2
function isCharInAnyCar()return parkedCar~=nil end
function storeCarCharIsInNoSave()return parkedCar or 0 end
function doesVehicleExist()return parkedCar~=nil end
function sampGetVehicleIdByCarHandle()return true,40 end
function getCarModel()return 401 end
function getNameOfVehicleModel()return 'TEST'end
function getGxtText()return 'Test Car'end
function getCarHealth()return 1000 end
function getCarDoorLockStatus()return 0 end
gameClock=83000;tick();events.onServerMessage(-1,'You are the owner of this Test Car.')
local vehicleBefore=#sent
chat=true;onWindowMessage(0x0100,75,0);assert(not frames[8].Condition());chat=false
onWindowMessage(0x0100,75,0);assert(frames[8].Condition() and not frames[7].Condition())
im.drawTexts={};frames[8].draw();assert(table.concat(im.drawTexts,'|'):find('Engine',1,true),'K must open Controls while seated')
onWindowMessage(0x0100,75,0x40000000);assert(frames[8].Condition())
im.clicks['Engine##vehicleAction']=true;down[18]=true;tick();frames[8].draw();down[18]=nil;assert(frames[8].Condition() and not frames[8].LockPlayer and frames[8].PassKeyboard and #sent==vehicleBefore)
gameClock=84500;tick();assert(sent[#sent]=='/car engine' and #sent==vehicleBefore+1)
events.onServerMessage(-1,'Vehicle engine turned off.')
im.clicks['Hood##vehicleAction']=true;down[18]=true;tick();frames[8].draw();down[18]=nil;
parkedCar=3;gameClock=86000;tick();assert(#sent==vehicleBefore+1,'Changed vehicle must cancel an unsent control')
onWindowMessage(0x0100,75,0);onWindowMessage(0x0008,0,0);assert(not frames[8].Condition())
onWindowMessage(0x0007,0,0);onWindowMessage(0x0100,75,0);onWindowMessage(0x0100,27,0);assert(not frames[8].Condition())
onWindowMessage(0x0100,75,0);im.clicks['My vehicles##vehicleTab3']=true;im.clicks['Storage##vehicleAction']=true;down[18]=true;tick();frames[8].draw();down[18]=nil;gameClock=88000;tick();assert(sent[#sent]=='/vstorage')
parkedCar=nil;tick()
rawPrint('PASS K repeat/typing/escape/focus guards, deferred control send, identity revalidation and storage while on foot')
local vehicleSendCount=#sent
commands.luahzcapture('vstorage');assert(#sent==vehicleSendCount,'Capture cannot request a storage action')
commands.luahzcapture('vehicles');tick();assert(#sent==vehicleSendCount,'Vehicle capture only observes user actions')
assert(events.onServerMessage(-1,'You are the owner of this Test Car.')==nil)
assert(captured[#captured]:find('"event":"vehicle_ownership_message"',1,true))
assert(events.onSendCommand('/vstorage')==nil)
assert(events.onShowDialog(801,2,'Vehicle Storage','Select','Cancel','Test Car')==nil)
gameClock=gameClock+9000;tick()
assert(events.onSendDialogResponse(801,1,0,'private response text')==nil)
assert(captured[#captured]:find('"event":"vehicle_dialog_response"',1,true))
assert(events.onServerMessage(-1,'Your vehicle was spawned at its last parking location.')==nil)
assert(captured[#captured]:find('last parking location',1,true))
assert(#sent==vehicleSendCount and not table.concat(captured):find('private response text',1,true))
onWindowMessage(0x0008,0,0);local vehicleStopped=#captured
onWindowMessage(0x0007,0,0);tick()
assert(#captured==vehicleStopped,'Focus return must not restart vehicle capture')
rawPrint('PASS actual vehicle capture command, entry/menu response passthrough, no action sends, private input exclusion and focus cancellation')
commands.luahzstatus();im.clicks['Licenses##characterTab6']=true;frames[5].draw()
gameClock=gameClock+1500;tick();assert(sent[#sent]=='/licenses','License refresh must run while I is open')
assert(events.onServerMessage(-1,'Your licenses...')==false)
assert(events.onServerMessage(-1,"** Driver's license: Acquired.")==false)
assert(events.onServerMessage(-1,'** Pilot license: Acquired.')==false)
assert(events.onServerMessage(-1,'** Boating license: Acquired.')==false)
onWindowMessage(0x0100,27,0)
commands.luahzvehicle();im.drawTexts={};frames[8].draw();assert(table.concat(im.drawTexts,'|'):find('Trunk balance',1,true),'Vehicle command must reopen Trunk while on foot')
down[18]=true;tick();im.clicks['Trunk##vehicleTab2']=true;im.clicks['Trunk balance##vehicleAction']=true;frames[8].draw();down[18]=nil
gameClock=gameClock+1500;tick();assert(sent[#sent]=='/trunkbalance')
assert(events.onServerMessage(-1,"*** John Doe's Test Car Trunk ***")==false)
assert(events.onServerMessage(-1,'Slot 1: MP5')==false)
assert(events.onServerMessage(-1,'Pot: 25 grams')==false)
assert(events.onServerMessage(-1,'Crack: 0 grams')==false)
assert(events.onServerMessage(-1,'Advertisement: unrelated')==nil)
chat=true;chatText='/trunkbalance';onWindowMessage(0x0100,13,0);chat=false
events.onSendCommand('/trunkbalance')
assert(events.onServerMessage(-1,"*** John Doe's Test Car Trunk ***")==nil,'Manual chat takeover must restore trunk output')
assert(events.onServerMessage(-1,'Slot 1: MP5')==nil)
onWindowMessage(0x0100,27,0)
rawPrint('PASS GUI trunk callback filtering and immediate manual-command takeover')
events.onSendCommand('/stats')
events.onServerMessage(-1,'John Doe - (Level: 1) - (Playing hours: 7) - (Age: 35) - (Gender: Male) - (Job: Bodyguard) - (Job 2: None) - (Donator: No)')
commands.luahzactions();im.clicks['Find player##quickAction']=true;frames[7].draw()
assert(not im.clicks['Offer armor##quickAction'])
im.clicks['Offer armor##quickAction']=true;frames[7].draw()
local inputText=im.InputText
im.InputText=function(label,ptr,size)
 if label=='##jobTarget'then im.StrCopy(ptr,'18')elseif label=='##jobAmount'then im.StrCopy(ptr,'200')end
 return false
end
im.clicks['Run##jobSubmit']=true;frames[7].draw();im.InputText=inputText
local jobBefore=#sent
sampGetPlayerNickname=function(id)return id==18 and 'Changed_Player' or oldNickname(id)end
gameClock=gameClock+1500;tick();assert(#sent==jobBefore,'Job target identity must be revalidated before sending')
sampGetPlayerNickname=oldNickname
rawPrint('PASS live I license refresh, profession-specific action forms and queued player identity revalidation')
noExtraSend=#sent
commands.luahzcapture('families');assert(#sent==noExtraSend,'A queued capture must remain unsent before the main loop')
rawPrint('PASS runtime capture preserves chat/dialog/checkpoint/textdraw callbacks and observes version without extra commands')

local beforeDisconnectClose=closedCapture
gamestate=5;tick();assert(nativeHud==true);assert(not frames[1].Condition(),'Disconnect must hide the player HUD again')
assert(closedCapture==beforeDisconnectClose+1,'Disconnect must close a live capture file exactly once')
io.open=originalOpen
if catalog then
    assert(catalog.address==nil)
    local loaded=catalogNew(arg[1]);loaded:bind()
    assert(#loaded.records==1,'Disconnect must flush the catalog to disk')
end
rawPrint('PASS disconnect restores native HUD')
assert(next(commands)==nil,'Foreign/disconnected clients must not retain LuaHZ command registrations')
gamestate=3;endpoint='192.0.2.10';tick()
local outsideSent,outsideConsumed=#sent,consumed
onWindowMessage(0x0100,120,0);onD3DPresent();assert(#sent==outsideSent and consumed==outsideConsumed)
for _,frame in ipairs(frames)do assert(not frame.Condition(),'No UI frame may activate on a foreign server')end
endpoint='213.32.6.232';serverPort=7778;tick();assert(next(commands)==nil)
onWindowMessage(0x0008,0,0) -- remember focus changes while LuaHZ is inactive
serverPort=7777;tick();assert(commands.luahz and #frames==8,'Re-entering HZ must reuse frame subscriptions')
assert(not frames[1].Condition(),'A new HZ session must wait for a fresh login')
local afterDisconnect=#captured
commands.luahzcapture('on');assert(#captured==afterDisconnect,'Capture requires login and never automatically resumes')
commands.luahzversion()
assert(logs[#logs]:find('unknown',1,true),'Reconnect must clear the observed version')
local staleCommand=commands.autofind
local staleEvent=events.onServerMessage
assert(staleEvent(-1,'Welcome to Horizon Roleplay, John Doe.')==nil)
assert(not frames[1].Condition(),'Re-entry must preserve an unfocused window')
onWindowMessage(0x0007,0,0)
assert(frames[1].Condition())
commands.autofind('17')
endpoint='192.0.2.10'
assert(staleEvent(-1,'Welcome to Horizon Roleplay, John Doe.')==nil,'Stale events must pass through')
staleCommand('17');onD3DPresent();tick()
assert(next(commands)==nil and #sent==outsideSent,'Queued HZ commands must not escape into another server')
assert(nativeHud==true)
rawPrint('PASS real runtime HZ/foreign/HZ cleanup, stale callbacks, wrong port and fresh login')
onScriptTerminate(script)
for _,line in ipairs(logs)do assert(not line:find('stopped after an error',1,true),line)end
rawPrint('PASS no component errors during startup smoke test')
