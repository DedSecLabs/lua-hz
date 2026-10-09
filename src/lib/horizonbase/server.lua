local logic = require 'horizonbase.logic'
local M = {}; M.__index = M
function M.new(config, notify, clock, catalog)
    return setmetatable({config = config, notify = notify, now = clock,
        queue = {}, seen = {}, lastSend = -10000, horizon = false,
        zones = {}, icons = {}, textdraws = {}, checkpoint = nil,
        find = {active = false, nextAt = 0}, track = {active = false, nextAt = 0},
        recent = {}, ready = false,catalog=catalog,iconsRevision=0,
        character=require("horizonbase.character").new(clock)}, M)
end

function M:reset()
    self.character:reset();self.statsDue=nil;self.statsRequested=false;self.loginSeen=false;self.characterName=nil
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
    if clean:find('All current checkpoints, trackers and accepted fares have been reset.', 1, true) then
        self.checkpoint = nil; self.track.active = false
    end
    if self.horizon and self.ready then
        local offer = logic.offer(clean)
        if logic.allowOffer(offer, self.config.togs) then self:enqueue(offer.command, 350, 'offer', offer) end
    end
    if self.find.active and clean:find('You are not a detective.',1,true) then
        self.find.active=false; self.notify('Autofind stopped: the server requires the detective job.')
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
    return hide
end

function M:onTextdraw(id, text)
    self.textdraws[id] = text
end

function M:startFind(id, name)
    if not self.horizon then self.notify('Autofind is available on Horizon Roleplay.'); return false end
    self.find = {active = true, id = tostring(id), name = name, nextAt = self.now(), description = 'Requesting location...'}
    self.notify('Tracking ' .. name .. '. Use /autofind to stop.')
    return true
end

function M:toggleTrack()
    if not self.horizon then self.notify('Vehicle tracking is available on Horizon Roleplay.'); return end
    self.track.active = not self.track.active
    self.track.nextAt = self.now()
    self.track.refresh = false
    self.notify(self.track.active and 'Vehicle tracker enabled. Choose your vehicle if prompted.' or 'Vehicle tracker stopped.')
end

function M:requestStats()
    if not self.horizon or not self.ready then return false end
    if self.character.pending or self.statsRequested then return false end
    if self.now()-self.character.lastRequest<10000 then return false end
    self.statsRequested=true
    return true
end

function M:onOutgoing(command,automatic)
    if self.horizon and command:lower():match('^/stats%s*$') then
        self.statsDue=nil;self.statsRequested=false
        local quiet=automatic==true or self.sendingStats==true
        if not quiet or not self.character.pending then self.character:begin(quiet) end
    end
    if command:match('^/trackcar') then
        self.track.pendingDialog = true
        self.track.command = command
    end
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
            t.response = {id = id, list = match, input = rows[match+1] or '', due = self.now() + 250}
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

function M:update(send, respond, canFetch)
    local now = self.now()
    self.character:update()
    if not self.ready then self.queue = {}; return end
    if self.horizon and canFetch and self.characterName and self.characterName~='' and not self.character.pending and
        (self.statsRequested or self.statsDue and now>=self.statsDue) and now-self.character.lastRequest>=10000 and now-self.lastSend>=1200 then
        self:onOutgoing('/stats',true)
        self.sendingStats=true
        local ok,err=pcall(send,'/stats')
        self.sendingStats=nil
        if not ok then error(err) end
        self.lastSend=now;self.lastAction='/stats'
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
        if self.track.active then respond(r.id, 1, r.list, r.input) end
    end
    if now - self.lastSend >= 1200 then
        for i, item in ipairs(self.queue) do
            if now >= item.due then
                table.remove(self.queue, i)
                local allowed = now <= item.expires and (not item.kind or (self.horizon and
                    (item.kind == 'offer' and logic.allowOffer(item.offer,self.config.togs) or item.kind == 'find' and self.find.active or
                     item.kind == 'cohort' and self.find.active and self.config.autofind.cohort or
                     item.kind == 'track' and self.track.active)))
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
