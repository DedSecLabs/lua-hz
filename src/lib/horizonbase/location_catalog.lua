-- One growing Horizon location catalog. Pure Lua persistence.
local M={};M.__index=M
local LIMIT=3000
local function finite(n,limit)
    return type(n)=='number' and n==n and math.abs(n)<=limit
end
local function valid(kind,p)
    return type(kind)=='number' and kind==math.floor(kind) and kind>=5 and kind<=63 and kind~=41 and
        type(p)=='table' and finite(p.x,10000) and finite(p.y,10000) and finite(p.z,5000)
end
local function close(a,b)
    return (a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2<=1
end
function M.new(directory,clock)
    return setmetatable({directory=directory,clock=clock or os.time,records={},revision=0,dirty=false},M)
end
function M:markDirty()
    self.revision=self.revision+1
    if not self.dirty then self.due=self.clock()+5 end
    self.dirty=true
end
function M:observe(icon)
    if not self.address or not valid(icon.kind,icon.position) then return false end
    local p=icon.position;local now=self.clock()
    for _,record in ipairs(self.records) do
        if close(record.position,p) then
            local changed=record.kind~=icon.kind or record.position.x~=p.x or record.position.y~=p.y or
                record.position.z~=p.z or now-record.lastSeen>=60
            record.kind=icon.kind;record.position={x=p.x,y=p.y,z=p.z};record.lastSeen=now
            if changed then self:markDirty() end
            return false
        end
    end
    if #self.records>=LIMIT then
        local oldest=1
        for i=2,#self.records do if self.records[i].lastSeen<self.records[oldest].lastSeen then oldest=i end end
        table.remove(self.records,oldest)
    end
    self.records[#self.records+1]={kind=icon.kind,position={x=p.x,y=p.y,z=p.z},lastSeen=now}
    self:markDirty();return true
end

local function read(path,address)
    local f=io.open(path,'rb')
    if not f then return nil end
    local text=f:read(1024*1024+1);f:close()
    if not text or #text>1024*1024 then return nil,'Location file is too large.' end
    text=text:gsub('\r\n','\n')
    local server,body=text:match('^LUAHZ%-LOCATIONS 1\nserver=([^\n]+)\n(.*)$')
    if server~=address then return nil,'Location file has an invalid version or server identity.' end
    local rows={}
    for line in body:gmatch('[^\n]+') do
        local kind,x,y,z,last=line:match('^(%d+)\t([%d%.%-]+)\t([%d%.%-]+)\t([%d%.%-]+)\t(%d+)$')
        kind=tonumber(kind);local p={x=tonumber(x),y=tonumber(y),z=tonumber(z)}
        last=tonumber(last)
        if valid(kind,p) and finite(last,1e11) and #rows<LIMIT then
            local duplicate=false
            for _,old in ipairs(rows) do if close(old.position,p) then duplicate=true;break end end
            if not duplicate then rows[#rows+1]={kind=kind,position=p,lastSeen=last} end
        end
    end
    return rows
end
function M:bind()
    if self.address then return false end
    local address='Horizon Roleplay'
    self.address=address;self.path=self.directory..'/horizon.txt'
    self.records={};self.dirty=false;self.revision=self.revision+1
    self.recovered=false
    local rows,loadError=read(self.path,address)
    if not rows then
        -- A prior valid file remains available if an interrupted write damaged it.
        rows=read(self.path..'.bak',address)
        self.recovered=rows~=nil
    end
    if not rows and not loadError then
        -- Import the first QA build's Horizon cache once, preserving its file.
        local legacy=self.directory..'/3231332e33322e362e3233323a37373737.txt'
        rows=read(legacy,'213.32.6.232:7777') or read(legacy..'.bak','213.32.6.232:7777')
        if rows then self:markDirty() end
    end
    self.records=rows or {};self.error=loadError
    return true,self.error
end
function M:unbind()
    local ok,err=self:flush()
    self.address=nil;self.path=nil;self.records={};self.revision=self.revision+1
    self.dirty=false
    return ok,err
end
function M:serialize()
    local lines={'LUAHZ-LOCATIONS 1','server='..self.address}
    for _,record in ipairs(self.records) do
        local p=record.position
        lines[#lines+1]=('%d\t%.3f\t%.3f\t%.3f\t%d'):format(record.kind,p.x,p.y,p.z,record.lastSeen)
    end
    return table.concat(lines,'\n')..'\n'
end
function M:flush()
    if not self.path or not self.dirty then return true end
    local temp=self.path..'.tmp'
    -- Preserve a known-good backup when replacing a recovered corrupt primary.
    local backup=self.path..(self.recovered and '.invalid' or '.bak')
    local f,err=io.open(temp,'wb')
    if not f then self.error=err;return nil,err end
    local wrote,writeError=f:write(self:serialize())
    local closed,closeError=f:close()
    if not wrote or not closed then
        os.remove(temp);self.error=writeError or closeError;return nil,self.error
    end
    local old=io.open(self.path,'rb')
    if old then
        old:close()
        local existingBackup=io.open(backup,'rb')
        if existingBackup then
            existingBackup:close()
            local removed,removeError=os.remove(backup)
            if not removed then os.remove(temp);self.error=removeError;return nil,removeError end
        end
        local moved,moveError=os.rename(self.path,backup)
        if not moved then os.remove(temp);self.error=moveError;return nil,moveError end
    end
    local moved,moveError=os.rename(temp,self.path)
    if not moved then
        if old then os.rename(backup,self.path) end
        os.remove(temp);self.error=moveError;return nil,moveError
    end
    self.dirty=false;self.error=nil;self.recovered=false;return true
end
function M:update()
    if self.dirty and self.clock()>=(self.due or 0) then
        local ok,err=self:flush()
        if not ok then self.due=self.clock()+30 end
        return ok,err
    end
    return true
end
function M:clear()
    if not self.address then return false,'Connect to Horizon first.' end
    self.records={};self:markDirty();return self:flush()
end
function M:savedOnly(live,liveRevision)
    if liveRevision~=nil and self.savedRevision==self.revision and self.savedLiveRevision==liveRevision then return self.saved end
    local saved={}
    for _,record in ipairs(self.records) do
        local current=false
        for _,icon in pairs(live) do if close(record.position,icon.position) then current=true;break end end
        if not current then saved[#saved+1]=record end
    end
    self.saved=saved;self.savedRevision=self.revision;self.savedLiveRevision=liveRevision
    return saved
end
return M
