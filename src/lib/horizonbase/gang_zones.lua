-- SA-MP sends gang-zone colors as ABGR, unlike map-icon RGBA.
-- Native pool layout: BlastHackNet/SAMP-API, 0.3.7-R5-1/CGangZonePool.h.
-- Read the existing pool only; never create, edit or request native zones.
local bit=require 'bit'
local Game=require 'horizonbase.game'
local M={};M.__index=M
local function finite(n,limit)
    return type(n)=='number' and n==n and math.abs(n)<=limit
end
local function pointer(n)
    return finite(n,0xFFFFFFFC) and n>=0x10000 and n%4==0
end
function M.color(zone,now,opacity)
    local c=zone.flashColor~=nil and math.floor(now/500)%2==1 and zone.flashColor or zone.color
    return bit.band(c,255)/255,bit.band(bit.rshift(c,8),255)/255,
        bit.band(bit.rshift(c,16),255)/255,bit.band(bit.rshift(c,24),255)/255*opacity
end
function M.snapshot(pool,memory)
    if not pointer(pool) then return nil,'Gang-zone pool unavailable.' end
    local zones={}
    for id=0,1023 do
        if memory.getuint32(pool+0x1000+id*4,false)~=0 then
            local p=memory.getuint32(pool+id*4,false)
            if pointer(p) then
                -- Native rectangle order is minX, maxY, maxX, minY.
                local x1,y2,x2,y1=memory.getfloat(p,false),memory.getfloat(p+4,false),
                    memory.getfloat(p+8,false),memory.getfloat(p+12,false)
                if finite(x1,10000) and finite(x2,10000) and finite(y1,10000) and finite(y2,10000) and x1<x2 and y1<y2 then
                    local color=memory.getuint32(p+16,false)
                    local alternate=memory.getuint32(p+20,false)
                    zones[id]={min={x=x1,y=y1},max={x=x2,y=y2},color=color,
                        flashColor=alternate~=color and alternate or nil}
                end
            end
        end
    end
    return zones
end
function M.new(server)
    return setmetatable({server=server,nextScan=0},M)
end
function M:sync(now,force)
    if not force and now<self.nextScan then return end
    self.nextScan=now+500
    local pool=Game.call('sampGetGangzonePoolPtr',0)
    if not pointer(pool) then self.error='Gang-zone pool unavailable.';return end
    local memory=require 'memory'
    local ok,zones=pcall(M.snapshot,pool,memory)
    if not ok or not zones then self.error=tostring(zones);return end
    self.server.zones=zones;self.error=nil;self.lastScan=now
end
function M.diagnostics(zones)
    local ids={};local flashing=0
    for id,z in pairs(zones) do ids[#ids+1]=id;if z.flashColor~=nil then flashing=flashing+1 end end
    table.sort(ids)
    local lines={('[Gang zones] active=%d; flashing=%d; colors=ABGR'):format(#ids,flashing)}
    for _,id in ipairs(ids) do
        local z=zones[id]
        lines[#lines+1]=('[Gang zone] id=%d x1=%.2f y1=%.2f x2=%.2f y2=%.2f color=0x%s flash=%s'):format(
            id,z.min.x,z.min.y,z.max.x,z.max.y,bit.tohex(z.color,8):upper(),
            z.flashColor~=nil and '0x'..bit.tohex(z.flashColor,8):upper() or 'off')
    end
    return lines
end
return M
