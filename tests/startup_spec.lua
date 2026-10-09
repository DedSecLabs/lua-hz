function sampTextdrawIsExists()return false end
function sampTextdrawGetPos()return 0,0 end
function sampTextdrawSetPos()end
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
local cfg=require 'horizonbase.config';cfg.read=function()configReads=configReads+1;return {modifiers={quickmap=4},custombinds={{name='Stats',command='/stats',key=83,mods=4}}} end;cfg.save=function()return true end
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
function sampIsPlayerConnected(id)return id==17 end
function sampGetPlayerNickname()return 'John_Doe'end
function isPauseMenuActive()return false end
local chat=false
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
for _,f in ipairs(frames)do if f.Condition()then f.draw()end end
assert(im.stack==0)
rawPrint('PASS F9 opens the menu and consumes the SA-MP key')
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
statusEvents.onServerMessage(-1,'John Doe - (Level: 1) - (Playing hours: 7) - (Age: 35) - (Gender: Male) - (Warnings: 0) - (Donator: No)')
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
assert(events.onServerMessage(-1,'John Doe - (Level: 1) - (Playing hours: 7) - (Age: 35) - (Gender: Male) - (Warnings: 0) - (Donator: No)')==nil)
onWindowMessage(0x0100,27,0)
rawPrint('PASS actual incoming chat callback suppresses only owned stats; ordinary and manual responses pass through')

gamestate=5;tick();assert(nativeHud==true);assert(not frames[1].Condition(),'Disconnect must hide the player HUD again')
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
serverPort=7777;tick();assert(commands.luahz and #frames==6,'Re-entering HZ must reuse frame subscriptions')
assert(not frames[1].Condition(),'A new HZ session must wait for a fresh login')
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
