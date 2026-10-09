package.path='src/lib/?.lua;'..package.path
local disabled,clock,playing,progress=0,0,{},0
local calls={}
PLAYER_PED=10;PLAYER_HANDLE=0
package.preload.memory=function()return {getuint8=function(address)
    assert(address==0xB73575);return disabled
end}end
function getGameTimer()return clock end
function setPlayerWeaponsScrollable(handle,enabled)
    assert(handle==0);disabled=enabled and 0 or 1;calls[#calls+1]=enabled
end
function isCharPlayingAnim(ped,name)assert(ped==10);return playing[name] or false end
function getCharAnimCurrentTime()return progress end
local Guard=require 'horizonbase.reload_guard'
local guard=Guard.new()
local sample={ready=true,alive=true,weapon=24,playerId=59}
guard:begin(sample);assert(guard.active and disabled==1)
guard:onClear(59);assert(guard.active,'A pre-animation clear must not cancel the pending reload lock')
guard:begin(sample);assert(#calls==1,'Repeated R must not create another guard')
clock=500;guard:update(sample,true);assert(guard.active)
guard:onAnimation(60,'OTHER');assert(not guard.anim,'Foreign animations must not change local reload')
guard:onAnimation(59,'ServerReloadVariant');playing.ServerReloadVariant=true
clock=800;guard:update(sample,true);assert(guard.active and guard.seen)
clock=2300;guard:update(sample,true);assert(guard.active,'Completion follows the animation, not a guessed delay')
playing.ServerReloadVariant=false;guard:update(sample,true);assert(not guard.active and disabled==0)
print('PASS immediate cycle lock, repeat suppression, own-player animation and actual completion')

clock=3000;playing.RIFLE_load=true;guard:begin(sample);guard:update(sample,true)
assert(guard.active and guard.anim=='RIFLE_load');progress=1
guard:update(sample,true);assert(not guard.active and disabled==0,'Frozen final frame is complete')
playing={};progress=0;guard:begin(sample);clock=5501;guard:update(sample,true)
assert(not guard.active and disabled==0,'Rejected command must not leave controls locked')
clock=6000;guard:begin(sample);clock=8300;guard:onAnimation(59,'LateReload');clock=8600
guard:update(sample,true);assert(guard.active,'Allow late animation time to start')
clock=9100;guard:update(sample,true);assert(not guard.active)
print('PASS native-animation fallback, final frame and missing/late server-response release')

for _,reason in ipairs({'focus','death','vehicle','disconnect','ped','weapon','clear','timeout','cleanup'})do
    clock=10000;disabled=0;guard:begin(sample)
    local state={ready=true,alive=true,weapon=24,playerId=59}
    if reason=='death' then state.alive=false
    elseif reason=='vehicle' then state.vehicle=123
    elseif reason=='disconnect' then state.ready=false
    elseif reason=='ped' then PLAYER_PED=11
    elseif reason=='weapon' then state.weapon=0
    elseif reason=='clear' then guard:onAnimation(59,'Reload_Test');guard:onClear(60);assert(guard.active);guard:onClear(59)
    elseif reason=='timeout' then clock=26000
    elseif reason=='cleanup' then guard:clear()end
    guard:update(state,reason~='focus');assert(not guard.active and disabled==0,reason)
    PLAYER_PED=10
end
disabled=1;clock=30000;guard:begin(sample);guard:clear()
assert(disabled==1,'An existing weapon-cycle restriction must remain disabled')
local saved=setPlayerWeaponsScrollable;setPlayerWeaponsScrollable=nil
guard:begin(sample);assert(not guard.active);setPlayerWeaponsScrollable=saved
print('PASS focus/death/vehicle/disconnect/ped/weapon/clear/timeout/cleanup and prior restriction preservation')
