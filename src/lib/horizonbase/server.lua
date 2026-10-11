local logic = require 'horizonbase.logic'
local M = {}; M.__index = M
function M.new(config, notify, clock, catalog, actionNotify)
    return setmetatable({config = config, notify = notify, actionNotify=actionNotify or notify, now = clock,
        queue = {}, seen = {}, lastSend = -10000, horizon = false,
        zones = {}, icons = {}, textdraws = {}, checkpoint = nil,
        find = {active = false, nextAt = 0}, track = {active = false, nextAt = 0},
        recent = {}, ready = false,catalog=catalog,iconsRevision=0,
        character=require("horizonbase.character").new(clock),info=require('horizonbase.server_info').new(clock)}, M)
end

function M:reset()
    self.info:reset();self.infoRequested=nil;self.sendingInfo=nil;self.infoEcho=nil
    self.commandSequence=nil;self.sequenceNextAt=nil
    self.clearNavigation=nil;self.clearNextAt=nil
    self.character:reset();self.statsDue=nil;self.invDue=nil;self.statsRequested=false;self.loginSeen=false;self.characterName=nil
    if self.catalog then self.catalog:unbind() end
    self.iconsRevision=self.iconsRevision+1
    self.queue, self.seen, self.zones, self.icons, self.textdraws = {}, {}, {}, {}, {}
    self.find, self.track = {active = false, nextAt = 0}, {active = false, nextAt = 0}
    self.checkpoint, self.horizon, self.ready = nil, false, false
    self.recent={};self.lastSend=-10000;self.lastAction=nil;self.sendingStats=nil;self.catalogEnabled=nil
end

function M:bindLocations()
    if not self.catalog or not self.horizon then return end
    local changed,err=self.catalog:bind()
    local enabled=self.config.quickmap.rememberLocations
    if (changed or enabled and not self.catalogEnabled) and enabled then
        for _,icon in pairs(self.icons) do self.catalog:observe(icon) end
    end
    self.catalogEnabled=enabled
    return changed,err
end
function M:onMapIcon(id,position,kind,color,style)
    local icon={position=position,kind=kind,color=color,style=style}
    self.icons[id]=icon;self.iconsRevision=self.iconsRevision+1
    if self.catalog and self.config.quickmap.rememberLocations then self.catalog:observe(icon) end
end
function M:removeMapIcon(id)
    self.icons[id]=nil;self.iconsRevision=self.iconsRevision+1
end

function M:enqueue(command, delay, kind, offer)
    if not self.ready then return end
    local now = self.now()
    local last = self.seen[command]
    if last and now - last < 4000 then return end
    self.seen[command] = now
    self.queue[#self.queue + 1] = {command = command, due = now + (delay or 0), kind = kind, offer = offer,
        expires = kind == 'offer' and now + 4000 or now + 10000}
end

function M:onMessage(text)
    local sequence=self.commandSequence
    if self.horizon and self.ready and sequence and sequence.locks and sequence.waiting
        and self.now()<sequence.deadline and require('horizonbase.vehicle_locks').nearbyFailure(logic.strip(text),sequence.locks[sequence.index]) then
        if sequence.index==1 then
            sequence.index=2;sequence.waiting=false;sequence.due=sequence.nextDue
            return true -- Hide only the expected owned failure that starts the fallback.
        else
            self:cancelSequence();self.actionNotify('No personal or group vehicle nearby.')
            return true -- Replace the owned final failure with one player notice.
        end
    end
    local infoHide=self.horizon and self.info:onMessage(text,self.character) or false
    if self.horizon and self.character.helpPending and self.character:ingestHelp(text) then
        local clean = logic.strip(text)
        self.recent[#self.recent + 1] = clean
        if #self.recent > 20 then table.remove(self.recent, 1) end
        return true
    end
    local clean = logic.strip(text)
    self.recent[#self.recent + 1] = clean
    if #self.recent > 20 then table.remove(self.recent, 1) end
    if self.horizon and clean:find('Welcome to Horizon Roleplay', 1, true) then
        if not self.loginSeen then
            self.loginSeen=true;self.statsDue=self.now()+5000
        end
    end
    local hide=self.horizon and self.character:ingest(text,self.characterName) or false
    -- A matching own-character stats snapshot also recovers HUD login state after script reload.
    if self.horizon and self.character.updatedAt then self.loginSeen=true end
    if self.horizon and clean=='All current checkpoints, trackers and accepted fares have been reset.' then
        local owned=self.clearNavigation and self.clearNavigation.sent and self.now()<self.clearNavigation.expires
        self.clearNavigation=nil;self:clearLocalNavigation()
        if owned then self.actionNotify('Navigation cleared.','info','quick-actions');return true end
    end
    if self.horizon and self.ready then
        local offer = logic.offer(clean)
        if logic.allowOffer(offer, self.config.togs) then self:enqueue(offer.command, 350, 'offer', offer) end
    end
    if self.find.active and clean:find('You are not a detective.',1,true) then
            self:stopFind(); self.notify('Autofind stopped: the server requires the detective job.')
    elseif self.find.active and (clean:find('You are unable to find this person.',1,true) or
        clean:find("You can't find that person as they're hidden in one of their turfs.",1,true)) then
        self.find.description='The server cannot locate this target.'; self.find.nextAt=self.now()+60000
    end
    local vehicleLocation=clean:match('^Your vehicle is located in (.+)%.$')
    if vehicleLocation and self.track.active then self.track.location=vehicleLocation end
    local found = logic.findResult(clean)
    if found and self.find.active and logic.normalizeName(found.name) == logic.normalizeName(self.find.name) then
        self.find.description = found.place or (found.cohort and 'Last seen with ' .. found.cohort) or 'No cohort found'
        if found.kind == 'found' and self.config.autofind.cohort then
            self:enqueue('/cohort ' .. self.find.id, 1500, 'cohort')
        end
        self.find.nextAt = self.now() + 30000
    end
    -- Honor the server's detective cooldown instead of flooding /find retries.
    local seconds = clean:match('[Ww]ait (%d+) seconds') or clean:match('(%d+) seconds before.*find')
    if seconds and self.find.active then self.find.nextAt = self.now() + (tonumber(seconds) + 1) * 1000 end
    return hide or infoHide
end

function M:onTextdraw(id, text)
    self.textdraws[id] = text
    local sequence=self.commandSequence
    if self.horizon and self.ready and sequence and sequence.locks and sequence.waiting and self.now()<sequence.deadline
        and require('horizonbase.vehicle_locks').success(text) then self:cancelSequence()end
end

function M:startFind(id, name,quiet)
    if not self.horizon then self.notify('Autofind is available on Horizon Roleplay.'); return false end
    if self.clearNavigation then return false end
    self.find = {active = true, id = tostring(id), name = name,
        nextAt=math.max(self.now(),(self.seen['/find '..id] or -10000)+4000),description = 'Requesting location...'}
    if quiet then self.actionNotify('Finding '..name..'.','info','quick-actions')
    else self.notify('Tracking ' .. name .. '. Use /autofind to stop.')end
    return true
end

function M:toggleTrack(quiet)
    if not self.horizon then self.notify('Vehicle tracking is available on Horizon Roleplay.'); return end
    if self.track.active then
        self:stopTrack()
        if quiet then self.actionNotify('Vehicle tracking stopped.','info','quick-actions')else self.notify('Vehicle tracker stopped.')end
        return true
    end
    if self.clearNavigation then return false end
    self.track.active = true
    self.track.nextAt = self.now()
    self.track.refresh = false
    if quiet then self.actionNotify('Choose your vehicle when prompted.','info','quick-actions')
    else self.notify('Vehicle tracker enabled. Choose your vehicle if prompted.')end
    return true
end

function M:dropNavigationQueue(findOnly,trackOnly)
    for i=#self.queue,1,-1 do
        local item=self.queue[i]
        if (not trackOnly and (item.kind=='find' or item.kind=='cohort')) or
            (not findOnly and item.kind=='track') or
            (not findOnly and not trackOnly and item.kind=='offer' and item.offer and item.offer.kind=='taxi') then
            table.remove(self.queue,i);self.seen[item.command]=nil
        end
    end
end
function M:stopFind()
    self.find={active=false,nextAt=0};self:dropNavigationQueue(true,false)
end
function M:stopTrack()
    self.track={active=false,nextAt=0};self:dropNavigationQueue(false,true)
end
function M:clearLocalNavigation()
    self.checkpoint=nil;self:dropNavigationQueue(false,false)
    self.find={active=false,nextAt=0};self.track={active=false,nextAt=0}
end
function M:requestClearNavigation()
    if not self.horizon or not self.ready or not self.loginSeen or self.clearNavigation or self.now()<(self.clearNextAt or 0)then return false end
    self:cancelSequence()
    self.clearNavigation={expires=self.now()+5000};self.clearNextAt=self.now()+3000
    return true
end

function M:requestStats()
    if not self.horizon or not self.ready then return false end
    if self.character.pending or self.statsRequested then return false end
    if self.now()-self.character.lastRequest<10000 then return false end
    self.statsRequested=true
    return true
end

function M:requestInfo(kind)
    local page=self.info.pages[kind]
    if not self.horizon or not self.ready or not self.loginSeen or not page or self.infoRequested or self.info.active then return false end
    if self.now()-page.lastRequest<10000 then return false end
    page.loading=true;page.error=nil;page.lastRequest=self.now()
    self.infoRequested={kind=kind,expires=self.now()+10000}
    return true
end

function M:cancelSequence()
    self.commandSequence=nil
end

function M:requestSequence(binding)
    local validated=require('horizonbase.config').binding(binding,1)
    if not self.horizon or not self.ready or not self.loginSeen or not validated or not validated.command2
        or self.clearNavigation or self.commandSequence or self.now()<(self.sequenceNextAt or 0) then return false end
    local now=self.now()
    local locks=require('horizonbase.vehicle_locks').pair(validated.command,validated.command2)
    self.commandSequence={steps={validated.command,validated.command2},index=1,due=now,expires=now+(locks and 8000 or 5000),locks=locks}
    self.sequenceNextAt=now+4000
    return true
end

function M:onOutgoing(command,automatic)
    if self.horizon then
        local kind=require('horizonbase.server_info').kind(command)
        local echo=self.infoEcho
        if automatic==nil and echo and echo.kind==kind and self.now()<=echo.expires then
            -- SAMP.Lua may deliver the outgoing RPC event after sampSendChat returns.
            self.infoEcho=nil
            print('[Server refresh] owned outgoing echo: '..kind)
            return
        end
        if kind then self.infoEcho=nil end
        if require('horizonbase.server_info').kind(command) and self.infoRequested then
            self.info:cancel(self.infoRequested.kind,'Request replaced by a newer command.');self.infoRequested=nil
        end
        self.info:onCommand(command,self.sendingInfo==kind or kind=='help' and self.sendingHelp==true)
    end
    local lower=command:lower()
    if self.horizon and lower:match('^/stats%s*$') then
        self.statsDue=nil;self.statsRequested=false
        local quiet=automatic==true or self.sendingStats==true
        if not quiet or not self.character.pending then self.character:begin(quiet) end
    elseif self.horizon and lower:match('^/inv%s*$') then
        local quiet=automatic==true or self.sendingInv==true
        self.character:begin(quiet,true)
    elseif self.horizon and lower:match('^/help%s*$') then
        local quiet=automatic==true or self.sendingHelp==true
        self.character:beginHelp(quiet)
    end
    if command:match('^/trackcar') then
        self.track.pendingDialog = true
        self.track.command = command
    end
end

function M:noteManualCommand(command)
    if not self.horizon or type(command)~='string' or not command:match('^/') then return end
    self:cancelSequence()
    self.infoEcho=nil
    if self.character.helpPending then self.character.helpQuiet=false end
    if self.info.active then self.info.active.quiet=false end
    self.info:onCommand(command,false)
end

function M:onDialog(id, title, text, style)
    if self.horizon then self.character:ingest(text,self.characterName) end
    local t = self.track
    if not t.pendingDialog then return false end
    local rows={}
    for row in ((text or '')..'\n'):gmatch('(.-)\r?\n') do rows[#rows+1]=row end
    if style==5 then table.remove(rows,1) end
    -- Only replay an explicit prior user choice in the same /trackcar dialog.
    if t.refresh and t.selection and title == t.selection.title then
        local match
        for i,row in ipairs(rows) do
            local number=logic.strip(row):match('[Vv]ehicle%s*#(%d+)')
            local label=logic.strip(row):match('^[^\t]+')
            if t.selection.number and number==t.selection.number or
                not t.selection.number and label==t.selection.label then
                if match then match=nil;break end
                match=i-1
            end
        end
        if match then
            t.response = {id = id, list = match, input = rows[match+1] or '', due = self.now() + 250,expires=self.now()+2000}
            t.pendingDialog = false; t.refresh = false
            return true
        end
    end
    if t.refresh and t.selection then
        t.active=false; t.refresh=false
        self.notify('Vehicle tracker stopped because the server opened a different dialog. Select the vehicle again.')
    end
    t.dialog = {id = id, title = title, rows=rows}
    t.pendingDialog = false
    return false
end

function M:onDialogResponse(id, button, list, input)
    local t = self.track
    if t.dialog and t.dialog.id == id then
        if button == 1 then
            local row=logic.strip(t.dialog.rows[list+1] or input or '')
            t.selection = {title = t.dialog.title, list = list, input = input or '',
                number=row:match('[Vv]ehicle%s*#(%d+)'),label=row:match('^[^\t]+')}
        else t.active = false end
        t.dialog = nil
    end
end

function M:update(send, respond, canFetch, canInfo, canActions)
    local now = self.now()
    if self.infoEcho and now>self.infoEcho.expires then self.infoEcho=nil end
    self.character:update()
    self.info:update(self.character)
    if canInfo==nil then canInfo=canFetch end
    if self.infoRequested and (not self.ready or now>=self.infoRequested.expires) then
        self.info:cancel(self.infoRequested.kind,'Request could not run. Try Refresh during gameplay.');self.infoRequested=nil
    end
    local clear=self.clearNavigation
    if clear then
        if not self.horizon then self.clearNavigation=nil;return end
        if now>=clear.expires then
            self.clearNavigation=nil
            self.actionNotify(clear.sent and 'Navigation clear was not confirmed.' or 'Navigation clear canceled before sending.','error','quick-actions')
        elseif not clear.sent then
            if not self.ready or not canActions then self.clearNavigation=nil;return end
            if now-self.lastSend>=1200 then
                clear.sent=true;clear.expires=now+5000
                local ok,err=pcall(send,'/killcheckpoint')
                if not ok then self.clearNavigation=nil;error(err)end
                self.lastSend=now;self.lastAction='/killcheckpoint'
            end
            return
        else return end -- Pause tracking/offer traffic until the server confirms or times out.
    end
    if self.commandSequence and (not self.horizon or not self.ready or not self.loginSeen or not canActions or now>=self.commandSequence.expires) then
        self:cancelSequence()
    end
    if not self.ready then self.queue = {}; return end
    if self.commandSequence then
        local sequence=self.commandSequence
        if sequence.locks and sequence.waiting and now>=sequence.deadline then
            self:cancelSequence();self.actionNotify('Vehicle lock response was not confirmed. Sequence stopped.')
        elseif not sequence.waiting and now>=sequence.due and now-self.lastSend>=1200 then
            local command=sequence.steps[sequence.index]
            if sequence.locks then sequence.waiting=true;sequence.deadline=now+3000;sequence.nextDue=now+2000 end
            self:onOutgoing(command,false)
            local ok,err=pcall(send,command)
            if not ok then self:cancelSequence();error(err)end
            self.lastSend=now;self.lastAction=command
            if not sequence.locks then
                sequence.index=sequence.index+1;sequence.due=now+2000
                if sequence.index>#sequence.steps then self:cancelSequence()end
            end
        end
        return -- Keep other LuaHZ requests out of the two-command sequence.
    end
    if self.infoRequested and self.horizon and canInfo and not self.info.active and not self.character.pending and now-self.lastSend>=1200 then
        local kind=self.infoRequested.kind;self.infoRequested=nil
        self.info:begin(kind,true);self.sendingInfo=kind
        if kind=='help' then self.character:beginHelp(true)end
        self.infoEcho={kind=kind,expires=now+1000}
        print('[Server refresh] sending owned request: '..kind)
        local ok,err=pcall(send,'/'..kind)
        self.sendingInfo=nil
        if not ok then
            self.infoEcho=nil;self.info:cancel(kind,'Request failed.')
            if kind=='help' then self.character.helpPending=nil;self.character.helpQuiet=false end
            error(err)
        end
        self.lastSend=now;self.lastAction='/'..kind
    end
    canFetch=canFetch and not self.info.active
    if self.horizon and canFetch and self.characterName and self.characterName~='' and not self.character.pending and
        (self.statsRequested or self.statsDue and now>=self.statsDue) and now-self.character.lastRequest>=10000 and now-self.lastSend>=1200 then
        self:onOutgoing('/stats',true)
        self.sendingStats=true
        local ok,err=pcall(send,'/stats')
        self.sendingStats=nil
        if not ok then error(err) end
        self.lastSend=now;self.lastAction='/stats'
    end
    if self.character.inventoryDue then
        self.character.inventoryDue=false
        self.invDue=now+1500
    end
    if self.horizon and canFetch and self.invDue and now>=self.invDue and not self.character.pending and now-self.lastSend>=1200 then
        self:onOutgoing('/inv',true)
        self.sendingInv=true
        local ok,err=pcall(send,'/inv')
        self.sendingInv=nil
        if not ok then error(err) end
        self.invDue=nil;self.lastSend=now;self.lastAction='/inv'
    end
    if self.horizon and canFetch and self.character.helpNeeded and not self.invDue and not self.character.pending
        and not self.character.helpPending and now-self.lastSend>=1200 then
        self.sendingHelp=true
        self:onOutgoing('/help',true)
        self.infoEcho={kind='help',expires=now+1000}
        local ok,err=pcall(send,'/help')
        self.sendingHelp=nil
        if not ok then
            self.infoEcho=nil;self.info:cancel('help','Request failed.')
            self.character.helpPending=nil;self.character.helpQuiet=false
            error(err)
        end
        self.character.helpNeeded=false;self.lastSend=now;self.lastAction='/help'
    end
    if self.horizon then
        if self.find.active and not self.find.paused and now >= self.find.nextAt then
            self:enqueue('/find ' .. self.find.id, 0, 'find'); self.find.nextAt = now + 30000
        end
        if self.track.active and now >= self.track.nextAt and
            (not self.track.sentInitial or self.track.selection or
             self.track.command and self.track.command:match('^/trackcar%s+%S')) then
            self.track.refresh = self.track.selection ~= nil
            self:enqueue(self.track.command or '/trackcar', 0, 'track')
            self.track.nextAt = now + 15000
            self.track.sentInitial = true
        end
    end
    if self.track.response and now >= self.track.response.due then
        local r = self.track.response; self.track.response = nil
        if self.track.active and canActions~=false and (not r.expires or now<=r.expires)then respond(r.id, 1, r.list, r.input) end
    end
    if now - self.lastSend >= 1200 then
        for i, item in ipairs(self.queue) do
            if now >= item.due then
                table.remove(self.queue, i)
                local allowed = now <= item.expires and (not item.kind or (self.horizon and
                    (item.kind == 'offer' and logic.allowOffer(item.offer,self.config.togs) or item.kind == 'find' and self.find.active and not self.find.paused and canActions~=false or
                     item.kind == 'cohort' and self.find.active and not self.find.paused and self.config.autofind.cohort and canActions~=false or
                     item.kind == 'track' and self.track.active and canActions~=false)))
                if allowed then
                    if item.kind == 'track' then self:onOutgoing(item.command) end
                    send(item.command); self.lastSend = now
                    self.lastAction = item.command
                end
                break
            end
        end
    end
end

return M
