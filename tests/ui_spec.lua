function sampTextdrawIsExists()return false end
function sampTextdrawGetPos()return 0,0 end
function sampTextdrawSetPos()end
package.path='tests/?.lua;src/lib/?.lua;src/lib/?/init.lua;'..package.path
package.preload.vkeys=function()return {id_to_name=function(id)return 'Key '..id end}end
function getScreenResolution()return 1920,1080 end
function getWorkingDirectory()return '/fake/moonloader' end
function doesFileExist()return true end
function getGameTimer()return 500 end
local nativeHud=true
function displayHud(value)nativeHud=value end
function displayRadar()end
local im=require 'fake_imgui'
local Config=require 'horizonbase.config'
local prefs=Config.copy(Config.defaults)
local saves=0
local ui=require('horizonbase.ui').new(im,prefs,function()saves=saves+1 end,function()end)
ui:theme()
for tab=1,9 do
    ui.tab=tab;ui:draw();assert(im.stack==0,'Unbalanced ImGui stack on tab '..tab)
    print('PASS settings tab '..tab)
end
ui.tab=9
ui.horizonPage[0]=5
local navRows={}
local originalInvisible=im.InvisibleButton
im.InvisibleButton=function(label,size)
    if label:find('##tab',1,true) then navRows[#navRows+1]={y=im.cursor.y,height=size.y} end
    return originalInvisible(label,size)
end
ui:draw();im.InvisibleButton=originalInvisible
assert(#navRows==9)
for i=2,#navRows do assert(navRows[i].y>=navRows[i-1].y+navRows[i-1].height,'Sidebar tabs overlap')end
assert(navRows[9].y+navRows[9].height<im.GetWindowSize().y-51,'Sidebar overlaps footer actions')
local observation=require('horizonbase.observations').new(getGameTimer)
ui.observations=observation
local action
ui.captureAction=function(value)action=value end
im.clicks['Start capture']=true;ui:draw();assert(action=='on' and im.stack==0)
im.clicks['Capture /families']=true;ui:draw();assert(action=='families' and not ui.open[0] and im.stack==0)
observation.active=true;observation.requests=2;observation.records=4
im.clicks['Stop capture']=true;ui:draw();assert(action=='off' and im.stack==0)
observation.active=false;observation:observeTextdraw(1,'HZ:RP v2.4.47(z)');ui:draw();assert(im.stack==0)
observation.versionConflict=true;ui:draw();assert(im.stack==0)
print('PASS Horizon unknown/observed/conflicting version and capture controls')
ui.server={info=require('horizonbase.server_info').new(getGameTimer),requestInfo=function(_,kind)action=kind;return true end}
ui.server.info.pages.families.rows={{id=1,name='Test Family',leader='Person Test',members=12,online=4}}
ui.server.info.pages.members.rows={{name='Person Test',title='Deputy Director',rank=5,label='Team Lead'}}
ui.server.info.pages.rules.rows={{title='Example',text='Server rule example.'}}
ui.server.info.pages.info.fields.Website='https://hzgaming.net'
for page=0,4 do
    ui.horizonPage[0]=page;ui:draw();assert(im.stack==0 and (im.columnCount or 1)==1)
end
ui.horizonPage[0]=0;ui.infoNotice='Old failed request';im.clicks['Refresh##horizon-families']=true;ui:draw();assert(action=='families' and not ui.infoNotice)
im.clicks['Members##serverTab2']=true;ui:draw();assert(ui.horizonPage[0]==1 and im.stack==0)
assert(math.abs(im.lastWindowSize.x-require('horizonbase.logic').menuWidth*ui.scale)<.01,'F9 must use the Character Status base width')
ui.horizonPage[0]=4;im.clicks['Copy URL##Website']=true;ui:draw();assert(im.clipboard=='https://hzgaming.net')
print('PASS information subpages, tables, refresh dispatch and community clipboard action')
ui.tab=6;ui.server.info.pages.help.rows={{category='GENERAL',text='/families /members /info'}}
im.clicks['Refresh##horizon-help']=true;ui:draw();assert(action=='help' and ui.commandPage==1)
im.clicks['LuaHZ commands##commandTab2']=true;ui:draw();assert(ui.commandPage==2 and im.stack==0)
im.clicks['Server commands##commandTab1']=true;ui:draw();assert(ui.commandPage==1 and im.stack==0)
print('PASS separate Server/LuaHZ command tabs and explicit read-only help refresh')
local ffi=require 'ffi'
ui.tab=4;im.clicks['Command combos##keybindTab2']=true;ui:draw()
im.clicks['Vehicle locks preset']=true;ui:draw()
assert(ffi.string(ui.draft.command)=='/pvl' and ffi.string(ui.draft.command2)=='/gvl')
ui.draft.key=76;ui.draft.mods=4;im.clicks['Save keybind']=true;ui:draw()
assert(prefs.custombinds[1].command2=='/gvl' and prefs.custombinds[1].mods==4)
im.clicks['Edit##custom1']=true;ui:draw();assert(ffi.string(ui.draft.command2)=='/gvl')
ui.capture={draft=true};im.clicks['Normal keybinds##keybindTab1']=true;ui:draw()
assert(ui.keybindPage==1 and not ui.capture and not ui.editIndex and ffi.string(ui.draft.command2)=='')
assert(prefs.custombinds[1].command2=='/gvl','Switching editor tabs must preserve saved combos')
prefs.custombinds[2]={name='Player stats',command='/stats',key=83,mods=4}
local seenInputs,seenButtons={},{}
local oldInput,oldButton=im.InputText,im.Button
im.InputText=function(label,...)seenInputs[label]=true;return oldInput(label,...)end
im.Button=function(label,...)seenButtons[label]=true;return oldButton(label,...)end
ui:draw()
assert(not seenInputs['##customcommand2'] and not seenButtons['Edit##custom1'] and seenButtons['Edit##custom2'],'Normal keybinds must show only the single-command editor and bindings')
seenInputs,seenButtons={},{};im.clicks['Command combos##keybindTab2']=true;ui:draw()
assert(seenInputs['##customcommand2'] and seenButtons['Edit##custom1'] and not seenButtons['Edit##custom2'],'Command combos must show the second field and only sequence bindings')
im.StrCopy(ui.draft.command,'/pvl');ui.draft.key=72
im.clicks['Save keybind']=true;ui:draw()
assert(#prefs.custombinds==2 and ui.bindError:find('two commands',1,true),'An incomplete combo must not save a single-command binding in this tab')
im.InputText,im.Button=oldInput,oldButton
ui:clearDraft();ui.tab=9
print('PASS split keybind editors, vehicle-lock preset, validation, saved-data preservation and canceled drafts/capture on tab changes')
local Logic=require 'horizonbase.logic'
for _,screen in ipairs({{1920,1080},{1280,720},{640,480},{320,240}})do
    local S=Logic.interfaceScale(screen[1],screen[2],200,Logic.menuWidth)
    assert(Logic.menuWidth*S<=screen[1]-24 and 540*S<=screen[2]-24,'Wider menu must remain within its viewport')
end
print('PASS underlined Server tabs, cleared successful-refresh notice and menu width/viewport limits')
ui.tab=1;im.clicks['##togglesettingsstamina']=true;ui:draw()
assert(prefs.settings.stamina==false and saves==2,'Toggle did not save')
print('PASS UI toggle persistence')
ui.capture={section='keybinds',key='quickmap'};assert(ui:captureKey(46,500));assert(prefs.keybinds.quickmap==0)
ui.capture={section='keybinds',key='quickmap'};assert(ui:captureKey(77,1000));assert(prefs.keybinds.quickmap==77)
ui.capture={section='keybinds',key='quickmap'};assert(ui:captureKey(27,1500));assert(prefs.keybinds.quickmap==77)
print('PASS key capture, unset and cancel')
local original=ui.content
ui.content=function()error('Injected page error')end
assert(not pcall(ui.draw,ui));assert(im.stack==0,'Page failure leaked window stack')
ui.content=original
print('PASS page errors close their ImGui windows')
ui.open[0]=true;ui.tab=2;im.sliders['##opacity']=42;ui:draw()
assert(ui:isMapPreview() and prefs.quickmap.opacity==42,'Opacity did not start a live map preview')
ui.tab=7;assert(not ui:isMapPreview())
im.sliders['##hudx']=50;im.sliders['##hudy']=70;ui:draw()
assert(prefs.hud.x==50 and prefs.hud.y==70)
im.sliders['##interfacescale']=150;ui:draw();ui:draw();assert(math.abs(ui.scale-1.5)<.01)
assert(im.lastPositionCondition==im.Cond.Always,'Resized UI was not recentered into the viewport')
print('PASS opacity preview, HUD positioning and UI scaling controls')
local game={sample={ready=true,alive=true,x=10,y=20,z=5,heading=20,weapon=24,ammo=70,money=4360,
    health=90,armour=60,wanted=2,stamina=.6,oxygen=.4,running=true,swimming=true,swimState=3,underwater=true,
    vehicle=123,speed=55,vehicleHealth=900,vehicleName='Infernus'},cruise={active=true,target=60}}
local server={badge={on=true},zones={[1]={min={x=-100,y=-100},max={x=100,y=100},color=0xFF000080}},
    icons={{position={x=150,y=300}}},checkpoint={x=500,y=600},find={active=true,name='John Doe'},track={active=true}}
local overlay=require('horizonbase.overlay').new(im,prefs,game,server)
overlay:initialize();overlay:hud();assert(nativeHud==false)
for _,text in ipairs(im.drawTexts) do assert(not text:find('Magazine') and not text:find('Ammo'),'Ammo label should be removed') end
nativeHud=true;overlay:hud();assert(nativeHud==false,'SA-MP HUD resets must be suppressed again')
overlay.mapOpen=true;overlay:map();overlay.mapOpen=false
prefs.settings.vdb=2;overlay:hud();prefs.settings.vdb=0;overlay:hud()
game.sample.vehicle=false;overlay:hud()
overlay:cleanup();assert(nativeHud==true)
assert(im.drawCalls>150,'Render branches were not exercised')
print('PASS HUD, dashboard styles, map and native HUD restoration')
local clock=0
local toast=require('horizonbase.toast').new(im,function()return clock end)
assert(not toast:announce('0.1.1',{},false))
assert(not toast:announce('0.1.1',{HUD='failed'},true))
assert(not toast:announce('0.1.1',{Menu='failed'},true))
assert(toast:announce('0.1.1',{},true))
assert(not toast:announce('0.1.1',{},true));assert(#toast.queue==1)
toast:draw();clock=400;toast:draw();clock=5000;toast:draw();assert(not toast:active())
print('PASS startup notification requires initialized UI, is shown once, and expires')
toast:push('No personal or group vehicle nearby.','error','vehicle-lock-result')
toast:push('No personal or group vehicle nearby.','error','vehicle-lock-result')
assert(#toast.queue==1,'Repeated lock failures must not stack queued notices')
toast:draw();clock=clock+4000
toast:push('Vehicle lock response was not confirmed. Sequence stopped.','error','vehicle-lock-result')
assert(#toast.queue==0 and toast.current.start==clock and toast.current.text:find('not confirmed',1,true))
clock=clock+4501;toast:draw();assert(not toast:active())
print('PASS keyed vehicle-lock notice refreshes once and expires without queued duplicates')
