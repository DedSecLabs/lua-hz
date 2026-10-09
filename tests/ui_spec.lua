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
for tab=1,8 do
    ui.tab=tab;ui:draw();assert(im.stack==0,'Unbalanced ImGui stack on tab '..tab)
    print('PASS settings tab '..tab)
end
ui.tab=1;im.clicks['##togglesettingsstamina']=true;ui:draw()
assert(prefs.settings.stamina==false and saves==1,'Toggle did not save')
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
    health=90,armour=60,wanted=2,stamina=.6,oxygen=.4,running=true,swimming=true,swimState=3,
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
