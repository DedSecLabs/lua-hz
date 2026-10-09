-- Native helper loads only inside the approved HZ feature runtime.
local M={};M.__index=M
function M.new(root,authorize,load)
    return setmetatable({root=root,authorize=authorize,loader=load,requested=false,status=0},M)
end
function M:activate()self.requested=true;self.failed=false end
function M:load()
    if self.dll then return true end
    local path=self.root..'\\LuaHZVisuals.dll'
    if not self.loader and not doesFileExist(path) then self.error='Native visual helper is not installed.';return false end
    local ok,dll=pcall(function()
        if self.loader then return self.loader(path) end
        local ffi=require 'ffi'
        ffi.cdef[[
            int HZV_Init(const char *root);
            int HZV_Update(int enabled);
            void HZV_Deactivate(void);
            int HZV_Status(void);
            void HZV_Shutdown(void);
        ]]
        return ffi.load(path)
    end)
    if not ok then self.error=tostring(dll);self.failed=true;return false end
    self.dll=dll;return true
end
function M:update()
    if not self.requested or not self.authorize() then self:stop();return end
    if self.failed or not self:load() then return end
    if not self.initialized then
        local result=self.dll.HZV_Init(self.root)
        if result~=1 then self.status=result;self.error='Native game/peer validation not ready ('..tostring(result)..').';return end
        self.initialized=true;self.error=nil
    end
    local status=self.dll.HZV_Update(1)
    self.status=status
    if status<0 then
        self.error='Native asset activation failed ('..tostring(status)..').'
        self.dll.HZV_Deactivate();self.failed=true
    elseif status~=self.reported then
        self.reported=status
        print('[LuaHZ native visuals] state='..status..'; fonts/icons/maps activate only on HZ.')
    end
end
function M:stop()
    self.requested=false
    if self.dll and self.initialized then self.dll.HZV_Deactivate() end
    self.status=0;self.reported=nil
end
function M:cleanup()
    self:stop()
    if self.dll and self.initialized then self.dll.HZV_Shutdown() end
    self.initialized=false
end
function M:diagnostics()
    return '[Native visuals] state='..self.status..'; helper='..tostring(self.dll~=nil)..'; '..(self.error or 'no errors')
end
return M
