package.path='src/lib/?.lua;'..package.path
local Hud=require 'horizonbase.server_hud'
local pool={[0]={546,66.7},[1]={548,68.8},[2050]={548,68.8},[7]={500,10}}
function sampTextdrawIsExists(id)return pool[id]~=nil end
function sampTextdrawGetPos(id)return unpack(pool[id]) end
function sampTextdrawSetPos(id,x,y)pool[id]={x,y}end
local h=Hud.new()
h:update(true,false,0);assert(pool[0][1]==546)
h:update(true,true,0)
assert(pool[0][1]==-1000 and pool[1][1]==-1000 and pool[2050][1]==-1000)
assert(pool[7][1]==500)
local d={position={x=548,y=68.8},text='_'}
local response=h:onShow(2050,d,true)
assert(response[1]==2050 and d.position.x==-1000)
pool[2050]={d.position.x,d.position.y}
h:update(false,true,100)
assert(pool[0][1]==546 and pool[1][1]==548 and pool[2050][1]==548)
print('PASS Horizon bar layers hide, unrelated textdraws remain and positions restore')
h:update(true,true,1100)
pool[1]={300,300};h:restore();assert(pool[1][1]==300)
h:update(true,true,2200)
local unrelated={position={x=320,y=200},text='Dialog'}
assert(h:onShow(2050,unrelated,true)==nil)
pool[2050]={320,200};h:restore();assert(pool[2050][1]==320)
print('PASS moved/reused textdraw IDs cannot restore stale positions')
h:update(true,true,3300)
local changed=0
function sampTextdrawSetPos(id,x,y)changed=changed+1;pool[id]={x,y}end
-- Foreign server owns the new pool, including any off-screen IDs it uses.
pool[2050]={-1000,-1000}
h:forget()
h:restore()
assert(changed==0 and next(h.positions)==nil)
print('PASS losing server context discards saved textdraw positions without touching a foreign pool')
