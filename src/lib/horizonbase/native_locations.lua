-- Mirror remembered Horizon POIs during the ESC menu using owned native blips.
-- GTA SA 1.0 US tRadarTrace: 175 x 0x28 at 0xBA86F0; Radar.h in gta-reversed.
local bit=require 'bit'
local Game=require 'horizonbase.game'
local M={};M.__index=M
local MAX,RESERVE=175,32
local function close(a,b)return (a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2<=1 end
local function key(r)local p=r.position;return ('%d:%.3f:%.3f:%.3f'):format(r.kind,p.x,p.y,p.z)end
local function valid(r)
    if type(r.kind)~='number' or r.kind<5 or r.kind>63 or r.kind==41 or r.kind~=math.floor(r.kind) then return false end
    for _,axis in ipairs({'x','y','z'})do
        local v=r.position and r.position[axis]
        if type(v)~='number' or v~=v or math.abs(v)>10000 then return false end
    end
    return true
end
function M.scan()
    local memory=require 'memory'
    local out={used=0,blips={}}
    for i=0,MAX-1 do
        local p=0xBA86F0+i*0x28
        if bit.band(memory.getuint8(p+0x25,false),2)~=0 then
            out.used=out.used+1
            local position={x=memory.getfloat(p+8,false),y=memory.getfloat(p+12,false),z=memory.getfloat(p+16,false)}
            local r={kind=memory.getuint8(p+0x24,false),position=position,
                handle=memory.getuint16(p+20,false)*65536+i}
            if valid(r)then out.blips[#out.blips+1]=r end
        end
    end
    return out
end
function M.new(server,config,scan)
    return setmetatable({server=server,config=config,owned={},scan=scan or M.scan,shown=0,limited=0},M)
end
function M:remove(entry)
    if Game.call('doesBlipExist',false,entry.handle)then pcall(removeBlip,entry.handle)end
end
function M:cleanup()
    for _,entry in pairs(self.owned)do self:remove(entry)end
    self.owned={};self.shown=0;self.limited=0;self.enabled=false
end
function M:sync(now,sample,inMenu)
    local catalog=self.server.catalog
    local enabled=inMenu and sample.ready and self.server.horizon and self.server.loginSeen and
        self.config.quickmap.rememberLocations and self.config.quickmap.nativeLocations and catalog and catalog.address
    if not enabled then self:cleanup();return end
    if self.enabled and now-(self.lastScan or -1000)<1000 then return end
    self.enabled=true;self.lastScan=now
    local ok,pool=pcall(self.scan)
    if not ok then self:cleanup();self.error=tostring(pool);return end
    self.error=nil
    local ownedCount=0;local ownedHandles={}
    for k,entry in pairs(self.owned)do
        if Game.call('doesBlipExist',false,entry.handle)then ownedCount=ownedCount+1;ownedHandles[entry.handle]=true else self.owned[k]=nil end
    end
    local budget=math.max(0,MAX-RESERVE-(pool.used-ownedCount))
    local candidates={}
    for _,record in ipairs(catalog:savedOnly(self.server.icons,self.server.iconsRevision))do
        if valid(record)then
            local duplicate=false
            for _,blip in ipairs(pool.blips)do
                if not ownedHandles[blip.handle] and close(record.position,blip.position)then duplicate=true;break end
            end
            if not duplicate then candidates[#candidates+1]=record end
        end
    end
    table.sort(candidates,function(a,b)
        local function distance(r)local p=r.position;return (p.x-(sample.x or 0))^2+(p.y-(sample.y or 0))^2 end
        local da,db=distance(a),distance(b)
        return da==db and key(a)<key(b) or da<db
    end)
    local wanted={}
    for i=1,math.min(budget,#candidates)do wanted[key(candidates[i])]=candidates[i]end
    for k,entry in pairs(self.owned)do if not wanted[k]then self:remove(entry);self.owned[k]=nil end end
    self.limited=math.max(0,#candidates-budget)
    self.shown=0
    for k,record in pairs(wanted)do
        if not self.owned[k]then
            local p=record.position
            local handle=Game.call('addSpriteBlipForCoord',-1,p.x,p.y,p.z,record.kind)
            if handle>=0 and Game.call('doesBlipExist',false,handle)then
                -- A map blip only, with no 3D checkpoint/marker.
                local success=pcall(changeBlipDisplay,handle,2)
                if success then self.owned[k]={handle=handle} else self:remove({handle=handle})end
            end
        end
        if self.owned[k]then self.shown=self.shown+1 end
    end
    self.lastShown=self.shown;self.lastLimited=self.limited
end
function M:diagnostics()
    return ('[Native locations] remembered_shown=%d; limited=%d; last_menu_shown=%d; last_menu_limited=%d; error=%s; reserve=%d'):format(
        self.shown,self.limited,self.lastShown or 0,self.lastLimited or 0,tostring(self.error),RESERVE)
end
return M
