-- Read-only, bounded observations. Endpoint authorization belongs to the runtime.
local M={};M.__index=M
local commands={buylevel=true,pvlock=true,pvl=true,gvl=true,rules=true,families=true,
    myguns=true,settings=true,killcheckpoint=true,members=true,info=true,help=true}
local readOnly={families=true,rules=true,members=true,info=true,settings=true,myguns=true,help=true}
function M.requestCommand(name)
    if type(name)~='string' then return end
    name=name:lower():match('^/?([a-z]+)$')
    if readOnly[name] then return '/'..name end
end
local MAX_BYTES,MAX_RECORDS,MAX_REQUESTS=131072,512,30
local function quote(value)
    return '"'..value:gsub('[%z\1-\31\128-\255\\"]',function(c)
        if c=='\\' then return '\\\\' elseif c=='"' then return '\\"' end
        return ('\\u%04x'):format(c:byte())
    end)..'"'
end
local function encode(row)
    local keys={};for key in pairs(row) do keys[#keys+1]=key end;table.sort(keys)
    local out={}
    for _,key in ipairs(keys) do
        local v=row[key];local kind=type(v)
        if kind=='string' then v=quote(v)
        elseif kind=='boolean' then v=tostring(v)
        elseif kind=='number' and v==v and math.abs(v)~=math.huge then v=tostring(v)
        else v='null' end
        out[#out+1]=quote(key)..':'..v
    end
    return '{'..table.concat(out,',')..'}\n'
end
local function clean(text)
    return (text or ''):gsub('{%x%x%x%x%x%x}',''):gsub('~[%w]~',' '):gsub('%s+',' '):match('^%s*(.-)%s*$')
end
function M.version(text)
    if type(text)~='string' or #text>256 then return end
    local s=clean(text):lower()
    s=s:gsub('^hz:rp%s*',''):gsub('^horizon roleplay%s*','')
    local major,minor,patch,build=s:match('^v?(%d+)%.(%d+)%.(%d+)%s*%[([a-z])%]$')
    if not major then major,minor,patch,build=s:match('^v?(%d+)%.(%d+)%.(%d+)%s*%(([a-z])%)$') end
    if major and #major<=3 and #minor<=3 and #patch<=3 then
        return ('%d.%d.%d [%s]'):format(tonumber(major),tonumber(minor),tonumber(patch),build:upper())
    end
end
function M.new(clock,notify)
    local self=setmetatable({now=clock,notify=notify or function()end},M)
    self:reset();return self
end
function M:reset()
    self:stop('session ended')
    self.observedVersion=nil;self.versionSource=nil;self.versionConflict=false
    self.loginTitle=false;self.versionCandidates={}
    self.path=nil;self.captureError=nil;self.lastReason=nil
end
function M:observeTextdraw(id,text,source)
    if type(text)~='string' then return end
    local s=clean(text):lower()
    if s:gsub('_',' ')=='horizon roleplay' then self.loginTitle=true end
    local version=M.version(text)
    if version then
        -- A standalone Vx.y.z needs the login title; a complete HZ:RP label is self-describing.
        self.versionCandidates[id]={version=version,source=source or 'server textdraw'}
        if s:match('^hz:rp%s') or s:match('^horizon roleplay%s') then self.loginTitle=true end
    else self.versionCandidates[id]=nil end
    if self.loginTitle then
        for _,candidate in pairs(self.versionCandidates) do
            if self.observedVersion and self.observedVersion~=candidate.version then
                self.versionConflict=true
            elseif not self.versionConflict then
                self.observedVersion=candidate.version;self.versionSource=candidate.source
            end
        end
    end
end
function M:hideTextdraw(id) self.versionCandidates[id]=nil end
function M:versionStatus()
    if self.versionConflict then return 'Conflicting version observations; compatibility not verified.' end
    if not self.observedVersion then return 'Version not observed; compatibility not verified.' end
    if self.observedVersion=='2.4.47 [Z]' then return 'Matches the reference version; server helpers are not fully verified.' end
    return 'Different from the reference version; compatibility needs checking.'
end
function M:start(write,close,path)
    if self.active then return false,'Capture is already enabled.' end
    self.write,self.close,self.path=write,close,path
    self.active=true;self.untilAt=self.now()+300000;self.window=nil;self.single=false
    self.bytes,self.records,self.requests=0,0,0;self.captureError=nil;self.lastReason=nil
    self:record({event='capture_start',schema=1,reference='2.4.47 [Z]',
        observed=self.versionConflict and 'conflicting' or self.observedVersion or 'unknown',
        note='Candidate events within 8 seconds of allowed commands; unrelated server traffic may overlap. Text bytes map to Unicode codepoints 0-255.'})
    return self.active,self.captureError
end
function M:record(row)
    if not self.active then return end
    row.time_ms=self.now()
    local line=encode(row)
    if self.records>=MAX_RECORDS or self.bytes+#line>MAX_BYTES then self:stop('capture limit');return end
    local ok,result,err=pcall(self.write,line)
    if not ok or not result then
        self.captureError='Capture write failed: '..tostring(ok and err or result)
        self:stop('write failure');self.notify(self.captureError);return
    end
    self.bytes=self.bytes+#line;self.records=self.records+1
end
function M:stop(reason)
    if not self.active then return end
    local line=encode({event='capture_end',time_ms=self.now(),reason=reason or 'stopped',requests=self.requests or 0})
    if self.write and self.records<MAX_RECORDS and self.bytes+#line<=MAX_BYTES then
        local ok,result,err=pcall(self.write,line)
        if ok and result then self.bytes=self.bytes+#line;self.records=self.records+1
        elseif not self.captureError then self.captureError='Capture finish write failed: '..tostring(ok and err or result) end
    end
    self.active=false;self.window=nil;self.lastReason=reason or 'stopped'
    local close=self.close;self.close=nil;self.write=nil
    if close then
        local ok,result,err=pcall(close)
        if not ok or not result then
            self.captureError='Capture close failed: '..tostring(ok and err or result)
        end
    end
    self.notify('Capture stopped ('..self.lastReason..'). '..tostring(self.path or ''))
end
function M:update()
    local now=self.now()
    if self.active then
        if now>=self.untilAt then self:stop('five-minute limit')
        elseif self.window and now>=self.window.untilAt then
            self:record({event='window_end',request=self.window.request,command=self.window.command,reason='elapsed'})
            self.window=nil
            if self.single then self:stop('command window completed') end
        end
    end
end
function M:onOutgoing(command,source)
    self:update()
    if not self.active or type(command)~='string' then return end
    local name=command:lower():match('^/([%w_]+)%s*$')
    if not commands[name] then
        if self.window then self:record({event='window_end',request=self.window.request,reason='other command'}) end
        self.window=nil
        if self.single then self:stop('another command interrupted capture') end
        return
    end
    local now=self.now()
    if self.window and self.window.command=='/'..name and now-self.window.started<250 then return end
    if self.requests>=MAX_REQUESTS then self:stop('request limit');return end
    self.requests=self.requests+1
    self.window={request=self.requests,command='/'..name,started=now,untilAt=now+8000,count=0}
    self:record({event='request',request=self.requests,command='/'..name,source=source or 'outgoing event'})
end
function M:event(kind,data)
    self:update()
    if not self.active or not self.window then return end
    local w=self.window
    if w.count>=96 then
        self:record({event='window_end',request=w.request,reason='event limit'});self.window=nil;return
    end
    local row={event=kind,request=w.request,command=w.command,candidate=true}
    for key,value in pairs(data or {}) do
        if type(value)=='string' then
            local limit=key=='text' and 8192 or 256
            if #value>limit then row.truncated=true end
            row[key]=value:sub(1,limit)
        else row[key]=value end
    end
    w.count=w.count+1;self:record(row)
end
function M:dialog(id,style,title,text)
    local lower=(title or ''):lower()
    if style==3 or lower:find('password',1,true) or lower:find('login',1,true) or lower:find('register',1,true) then
        self:event('dialog_excluded',{reason='sensitive dialog'});self.window=nil;return
    end
    self:event('dialog',{id=id,style=style,title=title or '',text=text or ''})
end
return M
