package.path='tests/?.lua;src/lib/?.lua;'..package.path
local Zones=require 'horizonbase.gang_zones'
local im=require 'fake_imgui'
local Overlay=require 'horizonbase.overlay'
local function near(a,b)assert(math.abs(a-b)<.0001,tostring(a)..' ~= '..tostring(b))end
local pool,p=0x10000,0x20000
local listed=true;local alternate=0x800000FF -- Half-transparent red in ABGR.
local memory={getuint32=function(address)
    if address>=pool+0x1000 and address<pool+0x2000 then return listed and address==pool+0x1000 and 1 or 0 end
    if address==pool then return p end
    if address==p+16 then return 0x8000FF00 end -- Green: old decoder made this invisible.
    if address==p+20 then return alternate end
    error('Unexpected pool read: '..address)
end,getfloat=function(address)
    return assert(({[p]=-100,[p+4]=200,[p+8]=300,[p+12]=-200})[address])
end}
assert(not Zones.snapshot(0,memory))
local zones=assert(Zones.snapshot(pool,memory));local z=assert(zones[0])
assert(z.min.x==-100 and z.min.y==-200 and z.max.x==300 and z.max.y==200)
local r,g,b,a=Zones.color(z,0,.8);near(r,0);near(g,1);near(b,0);near(a,128/255*.8)
r,g,b,a=Zones.color(z,500,.8);near(r,1);near(g,0);near(b,0);near(a,128/255*.8)
r,g,b,a=Zones.color(z,1000,.8);near(g,1)
local lines=Zones.diagnostics(zones)
assert(lines[1]:find('active=1; flashing=1',1,true))
assert(lines[2]:find('color=0x8000FF00 flash=0x800000FF',1,true))
print('PASS native rectangle bounds and ABGR opacity/red-green flash phases match server colors')

local server={zones={}}
local sync=Zones.new(server)
function sampGetGangzonePoolPtr()return pool end
package.loaded.memory=memory
sync:sync(0);assert(server.zones[0],'Pool backfill must recover zones whose initial events were missed')
alternate=0x8000FF00
sync:sync(499);assert(server.zones[0].flashColor)
sync:sync(500);assert(not server.zones[0].flashColor,'Stop flash must reconcile to native state')
listed=false;sync:sync(1000);assert(next(server.zones)==nil,'Native removal must remove the overlay zone')
listed=true;sync:sync(1500);assert(server.zones[0])
local float=memory.getfloat;memory.getfloat=function()error('Simulated unreadable pool')end
sync:sync(2000);assert(sync.error and server.zones[0],'Failed native scan must retain observed zones')
memory.getfloat=float
function sampGetGangzonePoolPtr()return 0 end
sync:sync(2500);assert(sync.error and server.zones[0])
function sampGetGangzonePoolPtr()return pool end
sync:sync(2501,true);assert(not sync.error and server.zones[0])
print('PASS native backfill, scan throttling, stop/delete reconciliation and event fallback after failed reads')

im.U32=function(r,g,b,a)return {r=r,g=g,b=b,a=a}end
local rectangles={}
local dl={AddRectFilled=function(_,a,b,color)rectangles[#rectangles+1]={a=a,b=b,color=color}end}
for _,name in ipairs({'PushClipRect','PopClipRect','AddText'})do dl[name]=function()end end
im.GetBackgroundDrawList=function()return dl end
function getScreenResolution()return 1920,1080 end
local clock=500
function getGameTimer()return clock end
server.icons={};server.zones[0].flashColor=0x800000FF
local prefs={quickmap={gangzones=true,opacity=100}}
local overlay=Overlay.new(im,prefs,{sample={ready=false}},server)
overlay:map()
local box=rectangles[2];near(box.color.r,1);near(box.color.g,0);near(box.color.a,128/255*.7)
assert(box.a.x<box.b.x and box.a.y<box.b.y,'World coordinates must produce an unclipped positive map rectangle')
clock=1000;rectangles={};overlay:map();near(rectangles[2].color.g,1)
prefs.quickmap.gangzones=false;rectangles={};overlay:map();assert(#rectangles==1)
print('PASS actual map rendering flashes red, retains transparency and honors the gang-zone toggle')
