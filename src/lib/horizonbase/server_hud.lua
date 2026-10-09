-- Horizon's health bar is a server textdraw, separate from DISPLAY_HUD.
-- Position signatures verified in akacross/hud's Horizon live capture:
-- https://github.com/akacross/hud/blob/main/hud.lua (SERVERS.hrp).
-- Retain original positions so reload/unload restores the server display.
local M={};M.__index=M
local OFF=-1000
function M.new()
    return setmetatable({active=false,positions={},scanDue=0},M)
end
function M.isHealthBar(x,y)
    if type(x)~='number' or type(y)~='number' then return false end
    x,y=math.floor(x),math.floor(y)
    return x==546 and y==66 or x==548 and y==68
end
function M:onShow(id,td,horizon)
    self.positions[id]=nil -- A reused ID belongs to this new textdraw.
    if self.active and horizon and td.position and M.isHealthBar(td.position.x,td.position.y) then
        self.positions[id]={x=td.position.x,y=td.position.y}
        td.position={x=OFF,y=OFF}
        return {id,td}
    end
end
function M:forget()
    self.positions={};self.active=false;self.scanDue=0
end
function M:restore()
    for id,pos in pairs(self.positions) do
        if sampTextdrawIsExists(id) then
            local x,y=sampTextdrawGetPos(id)
            if x==OFF and y==OFF then sampTextdrawSetPos(id,pos.x,pos.y) end
        end
    end
    self:forget()
end
function M:update(active,horizon,now)
    if not active then
        if self.active then self:restore() end
        return
    end
    self.active=true
    if not horizon or now<self.scanDue then return end
    self.scanDue=now+1000
    -- Also covers textdraws already present when /luahzreload is used.
    for id=0,2303 do
        if sampTextdrawIsExists(id) then
            local x,y=sampTextdrawGetPos(id)
            if M.isHealthBar(x,y) then
                self.positions[id]={x=x,y=y}
                sampTextdrawSetPos(id,OFF,OFF)
            elseif x~=OFF or y~=OFF then self.positions[id]=nil end
        else self.positions[id]=nil end
    end
end
return M
