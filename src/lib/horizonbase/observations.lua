-- Read-only, bounded observations. Endpoint authorization belongs to the runtime.
local M={};M.__index=M
local commands={buylevel=true,pvlock=true,pvl=true,gvl=true,rules=true,families=true,
    myguns=true,settings=true,killcheckpoint=true,members=true,info=true,help=true,carhelp=true}
local readOnly={families=true,rules=true,members=true,info=true,settings=true,myguns=true,help=true,carhelp=true}
local vehicleCommands={carhelp=true,vstorage=true,trackcar=true,trunkbalance=true,pvl=true,pvlock=true,gvl=true}
local carParts={engine=true,lights=true,window=true,hood=true,trunk=true}
local function observedCommand(command,mode)
    local lower=command:lower()
    local name=lower:match('^/([%w_]+)%s*$')
    if mode~='vehicles' then return commands[name] and '/'..name or nil end
    if vehicleCommands[name] then return '/'..name end
    local part=lower:match('^/car%s+([a-z]+)%s*$')
    if carParts[part] then return '/car '..part end
    local action,slot=lower:match('^/(%a+)%s+(%d+)%s*$')
    if (action=='trackcar' or action=='vstorage') and #slot<=4 then return '/'..action..' '..slot end
end
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
function M.ownership(text)
    if type(text)~='string' or #text>256 then return end
    local s=clean(text)
    local name=s:match('^You are the owner of this (.+)%.$')
    local kind='personal'
    if not name then name=s:match('^You are in the family that owns this (.+)%.$');kind='family' end
    if name and #name<=64 then return kind,name end
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
function M:start(write,close,path,mode)
    if self.active then return false,'Capture is already enabled.' end
    if mode~=nil and mode~='vehicles' then return false,'Unknown capture mode.' end
    self.write,self.close,self.path=write,close,path
    self.active=true;self.untilAt=self.now()+300000;self.window=nil;self.single=false
    self.mode=mode or 'commands';self.vehicleSample=nil;self.vehicleDialog=nil
    self.bytes,self.records,self.requests=0,0,0;self.captureError=nil;self.lastReason=nil
    self:record({event='capture_start',schema=1,mode=self.mode,reference='2.4.47 [Z]',
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
    self.active=false;self.window=nil;self.vehicleDialog=nil;self.vehicleSample=nil;self.lastReason=reason or 'stopped'
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
    if self.vehicleDialog and now>=self.vehicleDialog.untilAt then self.vehicleDialog=nil end
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
    local observed=observedCommand(command,self.mode)
    if not observed then
        if self.window then self:record({event='window_end',request=self.window.request,reason='other command'}) end
        self.window=nil;self.vehicleDialog=nil
        if self.single then self:stop('another command interrupted capture') end
        return
    end
    local now=self.now()
    if self.window and self.window.command==observed and now-self.window.started<250 then return end
    if self.requests>=MAX_REQUESTS then self:stop('request limit');return end
    self.requests=self.requests+1
    self.vehicleDialog=nil
    self.window={request=self.requests,command=observed,started=now,untilAt=now+8000,count=0}
    self:record({event='request',request=self.requests,command=observed,source=source or 'outgoing event'})
end
function M:vehicleContext(sample)
    self:update()
    if not self.active or self.mode~='vehicles' then return end
    local row={event='vehicle_context',vehicle_handle=sample.vehicle or 0,
        network_vehicle_id=sample.networkId or -1,model=sample.model or 0,
        driver=sample.driver==true,vehicle_name=sample.vehicleName or '',lock_state=sample.lockState or -1}
    local previous=self.vehicleSample;local changed=not previous
    for _,key in ipairs({'vehicle_handle','network_vehicle_id','model','driver','lock_state'})do
        if previous and previous[key]~=row[key] then changed=true end
    end
    self.vehicleSample=row
    if changed then self:record(row) end
end
function M:contextFields(row)
    if self.mode~='vehicles' then return end
    for _,key in ipairs({'vehicle_handle','network_vehicle_id','model','driver','lock_state'})do
        if self.vehicleSample then row[key]=self.vehicleSample[key]
        elseif key=='driver' then row[key]=false
        else row[key]=-1 end
    end
end
function M:event(kind,data)
    self:update()
    if not self.active then return end
    if self.mode=='vehicles' and kind=='chat' then
        local owner,name=M.ownership(data and data.text)
        if owner then
            local row={event='vehicle_ownership_message',ownership=owner,vehicle_name=name,
                text=data.text,candidate=true,association_unverified=true}
            self:contextFields(row);self:record(row);return
        end
    end
    if not self.window then return end
    local w=self.window
    if w.count>=96 then
        self:record({event='window_end',request=w.request,reason='event limit'});self.window=nil;return
    end
    local row={event=kind,request=w.request,command=w.command,candidate=true}
    self:contextFields(row)
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
    self:update();self.vehicleDialog=nil
    local lower=(title or ''):lower()
    if style==3 or self.mode=='vehicles' and style==1 or lower:find('password',1,true) or lower:find('login',1,true) or lower:find('register',1,true) then
        self:event('dialog_excluded',{reason='sensitive dialog'});self.window=nil;return
    end
    local window=self.window
    self:event('dialog',{id=id,style=style,title=title or '',text=text or ''})
    if self.active and self.mode=='vehicles' and window and self.window==window and
        (style==2 or style==4 or style==5) and
        (window.command:match('^/vstorage') or window.command:match('^/trackcar')) then
        self.vehicleDialog={id=id,request=window.request,command=window.command,untilAt=self.now()+60000}
    end
end
function M:dialogResponse(id,button,list)
    self:update()
    local dialog=self.vehicleDialog
    if not self.active or not dialog then return end
    self.vehicleDialog=nil
    if id~=dialog.id or (button~=0 and button~=1) or type(list)~='number' or list~=math.floor(list) or list< -1 or list>1999 then return end
    local row={event='vehicle_dialog_response',id=id,button=button,list_index=list,
        request=dialog.request,command=dialog.command,candidate=true}
    self:contextFields(row);self:record(row)
    if self.active and button==1 then
        self.window={request=dialog.request,command=dialog.command,started=self.now(),untilAt=self.now()+8000,count=0}
    end
end
return M
