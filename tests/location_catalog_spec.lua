package.path='tests/?.lua;src/lib/?.lua;'..package.path
local Catalog=require 'horizonbase.location_catalog'
local Config=require 'horizonbase.config'
local Server=require 'horizonbase.server'
local directory=assert(arg[1],'Temporary test directory required')
local now=1000
local function clock()return now end
local function icon(kind,x,y,z)return {kind=kind,position={x=x or 10,y=y or 20,z=z or 5},color=0,style=0}end
local a=Catalog.new(directory,clock)
-- Migrate the user's existing Horizon catalog without removing the old file.
local legacy=directory..'/3231332e33322e362e3233323a37373737.txt'
local seed=assert(io.open(legacy,'wb'))
seed:write('LUAHZ-LOCATIONS 1\nserver=213.32.6.232:7777\n22\t-100.000\t-100.000\t5.000\t900\n');seed:close()
assert(a:bind() and #a.records==1 and a.dirty)
assert(a.path==directory..'/horizon.txt' and a.address=='Horizon Roleplay')
assert(a:flush())
assert(a:clear())
assert(io.open(legacy,'rb')):close()
print('PASS one Horizon catalog migrates previous observations and preserves the legacy file')
assert(a:observe(icon(31)))
assert(not a:observe(icon(31,10.1,20.1,5)))
assert(#a.records==1)
assert(not a:observe(icon(32,10.2,20.2,5)) and a.records[1].kind==32 and a.records[1].position.x==10.2)
assert(a:observe(icon(6,40,50,5)))
for _,kind in ipairs({0,1,2,3,4,41,64}) do assert(not a:observe(icon(kind,100+kind,20,5)))end
assert(not a:observe(icon(6,0/0,20,5)))
assert(not a:observe(icon(6,math.huge,20,5)))
assert(#a.records==2)
assert(a.dirty)
now=1004;assert(a:update() and a.dirty)
now=1005;assert(a:update() and not a.dirty)
local b=Catalog.new(directory,clock);assert(b:bind())
assert(#b.records==2 and b.records[1].kind==32)
print('PASS cache round trip, debounced writes, positional dedup/status replacement and transient/invalid exclusions')

local server=Server.new(Config.copy(Config.defaults),function()end,clock,b)
server:onMapIcon(1,{x=200,y=300,z=5},45,0,0)
server:removeMapIcon(1)
assert(#b.records==3 and #b:savedOnly(server.icons,server.iconsRevision)==3)
server:onMapIcon(1,{x=10,y=20,z=5},31,0,0) -- Reused slot at a different location.
assert(#b.records==3 and b.records[1].kind==31)
local visible=b:savedOnly(server.icons,server.iconsRevision)
assert(#visible==2)
server:removeMapIcon(1)
assert(#b:savedOnly(server.icons,server.iconsRevision)==3)
server:reset();assert(#b.records==0 and b.address==nil)
assert(not server:bindLocations() and not b.address,'Other servers cannot activate the Horizon catalog')
server.horizon=true
assert(server:bindLocations());assert(#b.records==3)
assert(not server:bindLocations());assert(#b.records==3,'Reconnect uses the same Horizon catalog')
assert(b:clear());assert(#b.records==0)
local cleared=Catalog.new(directory,clock);cleared:bind();assert(#cleared.records==0)
print('PASS stream-out retention, live precedence, reused slots, disconnect persistence, Horizon-only activation and clear')

local c=Catalog.new(directory,clock);c:bind()
c:observe(icon(6));assert(c:flush())
c:observe(icon(29,60,20,5))
local rename=os.rename
os.rename=function(from,to)
    if from==c.path..'.tmp' and to==c.path then return nil,'Injected commit failure' end
    return rename(from,to)
end
assert(not c:flush());os.rename=rename
local restored=Catalog.new(directory,clock);restored:bind()
assert(#restored.records==1,'Failed commit must restore the previous valid file')
assert(c:flush())
assert(os.remove(c.path..'.bak'));assert(os.rename(c.path,c.path..'.bak'))
local recovered=Catalog.new(directory,clock);recovered:bind()
assert(#recovered.records==2,'Missing primary must recover an interrupted commit from backup')
local f=assert(io.open(recovered.path,'wb'));f:write('broken file\nos.execute("untrusted")\n');f:close()
local corrupt=Catalog.new(directory,clock);corrupt:bind()
assert(#corrupt.records==2 and corrupt.error,'Corrupt primary must fall back to valid backup')
corrupt:observe(icon(6,70,90,5))
os.rename=function(from,to)
    if from==corrupt.path..'.tmp' and to==corrupt.path then return nil,'Injected recovered-file commit failure' end
    return rename(from,to)
end
assert(not corrupt:flush());os.rename=rename
local recoveredAgain=Catalog.new(directory,clock);recoveredAgain:bind()
assert(#recoveredAgain.records==2,'A failed repair must preserve the known-good backup')
print('PASS file rollback/recovery preserves previous observations')

local bounded=Catalog.new(directory,clock);bounded:bind();assert(bounded:clear())
for i=1,3001 do bounded:observe(icon(6,i*2,0,5)) end
assert(#bounded.records==3000)
print('PASS catalog size stays bounded')
