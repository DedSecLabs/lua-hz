-- Session snapshots; only exact rows of a LuaHZ-owned refresh may be hidden.
local logic=require 'horizonbase.logic'
local M={};M.__index=M
local kinds={families=true,members=true,rules=true,settings=true,info=true,help=true,licenses=true}
local settingNames={'Global Chat','Newbie Chat','Speedo','Toys','GPS','Wristwatch','CHUD','VDB','Low HP Blink','Turfs','Damage Informer'}
local linkNames={'Website','Forums','Discord','Faction Discord','Gang Discord'}
local rulesFooter='*** This is a short version of our server rulebook. Please visit hzgaming.net to see a full list of the server rules ***'
M.settingNames=settingNames;M.linkNames=linkNames
local ruleNames={['Deathmatching (DM)']=true,['Revenge Killing (RK)']=true,['Non-RP Car Ramming']=true,
    ['Gun Discharge Exploits']=true,['Powergaming/Metagaming (PG/MG)']=true,['Logging to Avoid']=true,
    ['Exploiting']=true,['Robberies/Kidnapping']=true,['Hacking/Cheats']=true}
local function trim(s)return s:match('^%s*(.-)%s*$')end
local function count(t)local n=0;for _ in pairs(t)do n=n+1 end;return n end
local function safeText(s)return s and #s>0 and #s<=160 and not s:find('[%c{}]') end
function M.kind(command)
    local name=type(command)=='string' and command:lower():match('^/([a-z]+)%s*$')
    return kinds[name] and name or nil
end
function M.safeLink(value)
    if type(value)~='string' or #value>200 or value:find('[%c%s]') then return end
    value=value:gsub('^https?://','')
    if value=='hzgaming.net' or value=='forums.hzgaming.net' or
        value=='hzgaming.net/discord' or value=='hzgaming.net/factiondiscord' or value=='hzgaming.net/gangdiscord' then
        return 'https://'..value
    end
end
function M.family(text)
    local clean=logic.strip(text)
    local id,name,leader,members,online=clean:match('^%*%s+(%d+)%.%s+(.-)%s+|%s+Leader:%s+(.-)%s+|%s+Members:%s+(%d+)%s+|%s+Online:%s+(%d+)%s*$')
    id,members,online=tonumber(id),tonumber(members),tonumber(online)
    if not id or id<1 or id>1000 or not safeText(name) or not safeText(leader) or members>1000000 or online>members then return end
    return {id=id,name=name,leader=leader,members=members,online=online}
end
function M.member(text)
    -- The color boundary separates arbitrary-length titles and names; do not guess from word counts.
    local title,name,rank,label,tail=text:match('^%*%s+(.-)%s+{%x%x%x%x%x%x}([^{}]+){%x%x%x%x%x%x}%s+%((%d+)%)%s+%(([^()]+)%)(.*)$')
    if not title then return end
    title,name,label=trim(logic.strip(title)),trim(name),trim(label);rank=tonumber(rank)
    if not safeText(title) or not safeText(name) or not safeText(label) or rank>100 or trim(logic.strip(tail))~='' then return end
    return {title=title,name=name,rank=rank,label=label}
end
function M.new(clock)
    local self=setmetatable({now=clock},M);self:reset();return self
end
function M:reset()
    self.active=nil;self.pages={};self.respect=nil
    for kind in pairs(kinds)do self.pages[kind]={rows={},fields={},lastRequest=-10000}end
end
function M:begin(kind,quiet)
    if not kinds[kind] then return false end
    if self.active and self.active.kind==kind and self.now()-self.active.started<250 then
        if quiet~=nil then self.active.quiet=quiet==true end
        return true
    end
    if self.active then self:finish(true,'Another command interrupted the response.')end
    self.active={kind=kind,started=self.now(),expires=self.now()+8000,rows={},fields={},seen={},header=false,quiet=quiet==true}
    local p=self.pages[kind];p.loading=true;p.error=nil;p.lastRequest=self.now()
    return true
end
function M:cancel(kind,reason)
    if self.active and self.active.kind==kind then self.active=nil end
    if self.pages[kind] then self.pages[kind].loading=false;self.pages[kind].error=reason end
end
function M:finish(partial,reason)
    local d=self.active;if not d then return end
    local p=self.pages[d.kind];self.active=nil;p.loading=false
    if #d.rows==0 and count(d.fields)==0 then p.error=reason or 'No recognized response. Try Refresh.';return end
    if d.kind=='families' then
        table.sort(d.rows,function(a,b)return a.id<b.id end)
        for i,row in ipairs(d.rows)do if row.id~=i then partial=true end end
    elseif d.kind=='members' then table.sort(d.rows,function(a,b)return a.name:lower()<b.name:lower()end)
    elseif d.kind=='settings' then partial=partial or count(d.fields)~=#settingNames or not d.commands
    elseif d.kind=='info' then partial=partial or count(d.fields)~=#linkNames
    elseif d.kind=='rules' then partial=partial or not d.footer or #d.rows~=9 end
    if d.kind=='licenses' then partial=partial or count(d.fields)~=3 end
    p.rows=d.rows;p.fields=d.fields;p.commands=d.commands;p.updatedAt=self.now();p.partial=partial==true;p.error=reason
end
function M:onCommand(command,quiet)
    local kind=M.kind(command)
    if kind then return self:begin(kind,quiet==true)end
    if type(command)=='string' and command:lower():match('^/buylevel%s*$') then self.respect=nil end
end
function M:onMessage(text,character)
    if type(text)~='string' or #text>8192 then return false end
    local clean=trim(logic.strip(text))
    local remaining=clean:match('^You need (%d+) more respect points to buy your next level%.$')
    if remaining and #remaining<=9 then self.respect={remaining=tonumber(remaining),updatedAt=self.now(),level=character and character.fields.Level,
        points=character and character.fields['Respect points']};return false end
    local kind
    if clean=='Gangs:' then kind='families'
    elseif clean=='Members Online:' then kind='members'
    elseif clean=='*** Server Rules ***' then kind='rules'
    elseif clean:match('^Global Chat: ') and clean:find(' | Newbie Chat:',1,true) then kind='settings'
    elseif clean:match('^Website: ') and clean:find(' | Forums:',1,true) then kind='info' end
    if clean=='Your licenses...' then kind='licenses' end
    if kind and (not self.active or self.active.kind~=kind) then self:begin(kind)end
    local d=self.active;if not d then return false end
    if self.now()>=d.expires then self:finish(true,'Response window ended.');return false end
    local quiet=d.quiet==true
    local recognized=kind==d.kind and kind~='settings' and kind~='info'
    if kind then d.header=true end
    if d.kind=='licenses' and d.header then
        local label,value=clean:match('^%*%* ([^:]+) license: ([^%.]+)%.$')
        if (label=="Driver's" or label=='Pilot' or label=='Boating') and
            (value=='Acquired' or value=='Not acquired') then
            d.fields[label]=value;recognized=true
            if count(d.fields)==3 then self:finish(false)end
        end
    elseif d.kind=='families' and d.header then
        local row=M.family(text)
        if row then recognized=true end
        if row and not d.seen[row.id] and #d.rows<100 then d.rows[#d.rows+1]=row;d.seen[row.id]=true end
    elseif d.kind=='members' and d.header then
        local row=M.member(text)
        if row then recognized=true end
        if row and not d.seen[row.name] and #d.rows<500 then d.rows[#d.rows+1]=row;d.seen[row.name]=true
        elseif clean:match('^%* ') and not row then d.invalid=true end
    elseif d.kind=='rules' and d.header then
        local title,body=clean:match('^(.-) %- (.+)$')
        if title and ruleNames[title] and #body<=1024 then
            if not d.seen[title] then d.rows[#d.rows+1]={title=title,text=body};d.seen[title]=true end
            recognized=true
        elseif clean==rulesFooter then
            d.footer=true;recognized=true;self:finish(d.invalid==true)
        elseif title and not title:find(':',1,true) then d.invalid=true
        end
    elseif d.kind=='settings' then
        local validLine,parts=true,0
        for part in (clean..' | '):gmatch('(.-)%s+|%s+')do
            parts=parts+1
            local name,value=trim(part):match('^(.-):%s+(%a+)$')
            local knownPart=false
            if value=='On' or value=='Off' then
                for _,known in ipairs(settingNames)do if name==known then d.fields[name]=value;knownPart=true end end
            end
            if not knownPart then validLine=false end
        end
        recognized=parts>0 and validLine
        if clean:match('^Available commands: ') then
            local valid=true;local body=clean:sub(#'Available commands: '+1)
            for token in body:gmatch('%S+')do if not token:match('^/[a-z]+$') then valid=false end end
            if valid and #body>0 and #body<=512 then d.commands=body;recognized=true end
            if count(d.fields)==#settingNames and d.commands then self:finish(false)end
        end
    elseif d.kind=='info' then
        local validLine,parts=true,0
        for part in (clean..' | '):gmatch('(.-)%s+|%s+')do
            parts=parts+1
            local name,value=trim(part):match('^(.-):%s+(%S+)$');local url=M.safeLink(value)
            local knownPart=false
            if url then for _,known in ipairs(linkNames)do if name==known then d.fields[name]=url;knownPart=true end end end
            if not knownPart then validLine=false end
        end
        recognized=parts>0 and validLine
        if count(d.fields)==#linkNames then self:finish(false)end
    elseif d.kind=='help' then
        local row=require('horizonbase.server_help').row(text)
        if row then
            recognized=true
            if not d.seen[clean] and #d.rows<100 then
                d.rows[#d.rows+1]=row;d.seen[clean]=true
            end
        elseif clean:match('^%*%*%* [A-Z]+ %*%*%*') then d.invalid=true end
    end
    return quiet and recognized==true
end
function M:update(character)
    local d=self.active
    if d and self.now()>=d.expires then self:finish(d.invalid==true)end
    if self.respect and character then
        local f=character.fields
        if f.Level~=self.respect.level or f['Respect points']~=self.respect.points then self.respect=nil end
    end
end
return M
