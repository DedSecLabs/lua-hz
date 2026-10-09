package.path='tests/?.lua;src/lib/?.lua;'..package.path
local Native=require 'horizonbase.native_locations'
local Config=require 'horizonbase.config'
local prefs=Config.copy(Config.defaults)
local records={{kind=6,position={x=0,y=0,z=0}},{kind=7,position={x=10,y=10,z=0}},{kind=10,position={x=20,y=20,z=0}}}
local catalog={address='Horizon Roleplay',savedOnly=function()return records end}
local server={catalog=catalog,horizon=true,loginSeen=true,icons={},iconsRevision=0}
local state={ready=true,x=0,y=0}
local handles={[7]={kind=6,position={x=0,y=0,z=0}}};local nextHandle=100;local creates=0;local removed={};local reserveUsed=0
function doesBlipExist(handle)return handles[handle]~=nil end
function addSpriteBlipForCoord(x,y,z,kind)
    creates=creates+1;nextHandle=nextHandle+1
    handles[nextHandle]={kind=kind,position={x=x,y=y,z=z}}
    return true,nextHandle
end
function changeBlipDisplay(handle,display)assert(display==2 and handles[handle])end
function removeBlip(handle)assert(handle~=7,'Never delete a server/native marker');handles[handle]=nil;removed[#removed+1]=handle end
local function scan()
    local pool={used=reserveUsed,blips={}}
    for handle,r in pairs(handles)do pool.used=pool.used+1;pool.blips[#pool.blips+1]={kind=r.kind,position=r.position,handle=handle}end
    return pool
end
local bridge=Native.new(server,prefs,scan)
bridge:sync(0,state,false);assert(creates==0)
server.loginSeen=false;bridge:sync(0,state,true);assert(creates==0)
server.loginSeen=true;bridge:sync(0,state,true)
assert(creates==2 and bridge.shown==2 and handles[7],'Live native location must deduplicate')
bridge:sync(999,state,true);assert(creates==2,'Throttled sync must not recreate markers')
bridge:sync(1000,state,true);assert(creates==2 and #removed==0,'Stable markers retain their handles')
prefs.quickmap.nativeLocations=false;bridge:sync(1001,state,true);assert(bridge.shown==0 and #removed==2 and handles[7])
prefs.quickmap.nativeLocations=true;bridge:sync(1002,state,true);assert(bridge.shown==2)
bridge:sync(1003,state,false);assert(bridge.shown==0,'Leaving ESC immediately clears additions even if timer is paused')
reserveUsed=142;bridge:sync(1004,state,true);assert(bridge.shown==0 and bridge.limited==2,'Native server capacity must remain reserved')
reserveUsed=141;bridge:sync(2004,state,true);assert(bridge.shown==1 and bridge.limited==1)
local nearest
for handle,r in pairs(handles)do if handle~=7 then nearest=r end end
assert(nearest.position.x==10,'Nearest known location wins when capacity is limited')
bridge.scan=function()error('injected scan failure')end
bridge:sync(3004,state,true);assert(bridge.shown==0 and bridge.error and handles[7])
bridge.scan=scan;reserveUsed=0;bridge:sync(4004,state,true);assert(bridge.shown==2)
server.horizon=false;bridge:sync(4005,state,true);assert(bridge.shown==0 and handles[7])
print('PASS native-map saved/live deduplication, pause scope, stable handles, capacity reserve, nearest priority, failure/disable/disconnect cleanup')

-- Validate the actual native trace offsets and generation-bearing handles.
local old=package.loaded.memory
local base=0xBA86F0
package.loaded.memory={
    getuint8=function(p)if p==base+0x25 then return 2 elseif p==base+0x24 then return 6 end return 0 end,
    getuint16=function(p)assert(p==base+20);return 3 end,
    getfloat=function(p)if p==base+8 then return 10 elseif p==base+12 then return 20 elseif p==base+16 then return 30 end error('unexpected read')end}
local pool=Native.scan();assert(pool.used==1 and pool.blips[1].handle==3*65536 and pool.blips[1].position.y==20)
package.loaded.memory=old
print('PASS native trace scan observes the 175-slot pool and preserves handle generations')
