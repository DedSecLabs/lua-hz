-- Bounded, session-only parsing of Horizon's ordinary /stats response.
local logic=require 'horizonbase.logic'
local M={};M.__index=M
M.groups={
    {'Character',{'Level','Playing hours','Gender','Age','Phone number','Warnings','Respect points','Upgrades','Donator'}},
    {'Work & faction',{'Faction','Rank','Division','Job','Job 2'}},
    {'Finances',{'Total wealth','Cash','Bank balance','Insurance','Married to'}},
    {'Health & record',{'Health','Armor','Spawn armor','Crimes','Arrests','Wanted Level','Radio'}},
    {'Inventory',{'Materials','Pot','Crack','Packages','Crates','Rope','Cigars','Sprunk','Spray','Seeds','Blindfolds','Ref Tokens','Screwdriver','Wristwatch','Tire','Firstaid','Receiver','GPS','Bug Sweep','Lockpicks'}}
}
local known={}
for _,group in ipairs(M.groups) do for _,label in ipairs(group[2]) do known[label:lower()]=label end end
known.armour='Armor';known['spawn armour']='Spawn armor'
known.family='Faction';known.crew='Division'
-- Distinct commands from the Horizon job guide. /help lists these only for jobs the player has.
M.helpJobs={
    {name='Detective',commands={'cohort'}},
    {name='Lawyer',commands={'lawyerduty','defend'}},
    {name='Mechanic',commands={'mechduty'}},
    {name='Bodyguard',commands={'guard'}},
    {name='Arms Dealer',commands={'sellgun'}},
    {name='Boxer',commands={'boxstats'}},
    {name='Drug Smuggler',commands={'getcrate'}},
    {name='Taxi Driver',commands={'fare'}},
    {name='Craftsman',commands={'craft'}},
    {name='Trucker',commands={'loadtruck','hijacktruck'}},
    {name='Pizza Delivery',commands={'getpizza'}},
    {name='Aircraft Pilot',commands={'loadaircraft'}},
    {name='Farmer',commands={'harvest'}},
    {name='Garbage Man',commands={'pickuptrash'}},
    {name='Lumberjack',commands={'chopwood'}},
    {name='Miner',commands={'mine'}},
    {name='Forklift Driver',commands={'pickupcrates'}},
    {name='Fishing',commands={'sellallfish'}},
    {name='Car Jacker',commands={'sellcar'}},
    {name='Drug Dealer',commands={'sellpot','sellcrack'}},
}
local function count(t)local n=0;for _ in pairs(t)do n=n+1 end;return n end
function M.new(clock)
    return setmetatable({now=clock,fields={},lines={},state='empty',lastRequest=-10000},M)
end
function M:reset()
    self.quiet=false;self.quietTailUntil=nil;self.quietStarted=false
    self.fields={};self.lines={};self.state='empty';self.pending=nil;self.draft=nil
    self.updatedAt=nil;self.name=nil;self.error=nil;self.partial=nil;self.merge=false;self.inventoryDue=false
    self.helpNeeded=false;self.helpPending=nil;self.helpQuiet=false;self.helpText=nil;self.helpLast=nil
    self.lastLine=nil;self.lastRequest=-10000
end
function M:begin(quiet,merge)
    self.quiet=quiet==true;self.quietStarted=false;self.quietTailUntil=nil
    self.merge=merge==true
    local now=self.now()
    self.pending=now+12000;self.draft=merge and {fields={}} or nil
    self.lines={};self.lastRequest=now;self.state='loading';self.error=nil
end
function M:commit()
    local d=self.draft
    local n=d and count(d.fields) or 0
    if not d or (self.merge and n<1) or (not self.merge and n<5) then return false end
    if self.merge then
        for key,value in pairs(d.fields) do self.fields[key]=value end
    else
        self.name=d.name;self.fields=d.fields;self.partial=d.fields.Donator==nil
        self.inventoryDue=true
        self.helpNeeded=self.fields['Job 2']==nil or self.fields.Job==nil
    end
    self.merge=false;self.updatedAt=self.now()
    self.quietTailUntil=self.quiet and self.now()+250 or nil
    self.quiet=false;self.quietStarted=false
    self.draft=nil;self.pending=nil;self.state='ready';self.error=nil
    return true
end
-- Horizon's observed stats frame uses exactly 99 underscores. Filtering only
-- occurs during our request, or its brief closing frame; manual /stats stays visible.
local separator=string.rep('_',99)
function M:ingest(text,expectedName)
    if type(text)~='string' or #text>8192 then return false end
    local now=self.now();local clean=logic.strip(text)
    local quiet=self.quiet and self.pending and now<=self.pending
    local tail=self.quietTailUntil and now<=self.quietTailUntil
    if not (self.pending and now<=self.pending) then
        if tail and clean:match('^%s*(.-)%s*$')==separator then self.quietTailUntil=nil;return true end
        return tail and clean:match('^%s*$')~=nil or false
    end
    local hide=quiet==true
    for line in (clean..'\n'):gmatch('(.-)\r?\n') do
        local trimmed=line:match('^%s*(.-)%s*$')
        if trimmed==separator and quiet and now-self.lastRequest<=3000 then
            self.quietStarted=true
        elseif trimmed=='' then
            if not (quiet and self.quietStarted) then hide=false end
        elseif quiet and self.merge and trimmed:lower()=='inventory:' then
            -- Header of an owned /inv reply. The item rows are hidden separately.
        else
            local name=line:match('^%s*(.-)%s*%-%s*%([Ll]evel:%s*')
            if name then
                if not expectedName or logic.normalizeName(name)~=logic.normalizeName(expectedName) then
                    self.draft=nil;self.quiet=false;self.quietStarted=false;return false
                end
                self.draft={name=name,fields={}}
                self.quietStarted=quiet==true
            end
            local opening=line:find('(',1,true)
            local body=name and line:sub(opening) or trimmed
            local parsed={}
            local recognized=false;local exact=body:match('^%(')~=nil
            if self.draft and exact then
                for label,value in body:gmatch('%(([^:()]+):%s*([^()]*)%)') do
                    local key=known[label:match('^%s*(.-)%s*$'):lower()]
                    if key then
                        parsed[key]=value:match('^%s*(.-)%s*$'):gsub('[%c]',''):sub(1,160)
                        recognized=true
                    end
                end
                -- A long /stats line is split by chat inside the next field, for example "(Crat".
                -- Keep the completed fields. Ordinary chat mixed into the line still rejects it.
                local leftover=body:gsub('%([^()]*%)',''):gsub('[%s%-]','')
                if leftover~='' and not leftover:match('^%([^)]*$') then exact=false end
                if not exact then recognized=false end
                if recognized then
                    for key,value in pairs(parsed)do self.draft.fields[key]=value end
                    self.lastLine=now
                    if #self.lines<12 then self.lines[#self.lines+1]=line:sub(1,2048) end
                    if self.draft.fields.Donator then self:commit() end
                end
            end
            if not (recognized and exact) then hide=false end
        end
    end
    return hide
end
function M:beginHelp(quiet)
    local now=self.now()
    self.helpQuiet=quiet==true;self.helpPending=now+12000;self.helpText='';self.helpLast=nil
end
function M:ingestHelp(text)
    if not self.helpPending or self.now()>self.helpPending then return false end
    local clean=logic.strip(text)
    -- Only the server's *** category lines belong to /help. Nearby chat stays on the normal path.
    if not require('horizonbase.server_help').row(text) then return false end
    self.helpText=self.helpText..'\n'..clean
    self.helpLast=self.now()
    return self.helpQuiet==true
end
function M:finishHelp()
    local commands={}
    for command in (self.helpText or ''):lower():gmatch('/([%w]+)') do commands[command]=true end
    local function names(field)
        return field and field:lower() or ''
    end
    local leftover={}
    for _,job in ipairs(M.helpJobs) do
        local present=false
        for _,command in ipairs(job.commands) do if commands[command] then present=true;break end end
        if present and not names(self.fields.Job):find(job.name:lower(),1,true)
            and not names(self.fields['Job 2']):find(job.name:lower(),1,true) then
            leftover[#leftover+1]=job.name
        end
    end
    if #leftover==1 and self.fields['Job 2']==nil and self.fields.Job~=nil then
        self.fields['Job 2']=leftover[1]
    elseif #leftover==1 and self.fields.Job==nil then
        self.fields.Job=leftover[1]
    end
    self.helpNeeded=false;self.helpPending=nil;self.helpQuiet=false;self.helpText=nil;self.helpLast=nil
end
function M:update()
    if self.helpPending and self.helpLast and self.now()-self.helpLast>=750 then self:finishHelp() end
    if self.helpPending and self.now()>self.helpPending then self.helpPending=nil;self.helpQuiet=false end
    if self.pending and self.now()>self.pending then
        self.quiet=false;self.quietTailUntil=nil;self.quietStarted=false
    end
    if self.draft and self.now()-(self.lastLine or 0)>=750 then self:commit() end
    if self.pending and self.now()>self.pending then
        self.quiet=false;self.quietStarted=false;self.quietTailUntil=nil
        self.pending=nil;self.draft=nil;self.state=self.updatedAt and 'ready' or 'empty'
        self.error='No recognized /stats response. Try Refresh or /stats in chat.'
    end
end
function M:diagnostics()
    local out={('[Character status] state=%s; fields=%d; partial=%s; updated=%s; error=%s'):format(
        self.state,count(self.fields),tostring(self.partial),tostring(self.updatedAt),tostring(self.error))}
    for _,line in ipairs(self.lines)do out[#out+1]='[Character stats response] '..line end
    return out
end
return M
