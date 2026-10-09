-- Context-dependent presentation cap without patching game frame-limit memory.
local M = {}; M.__index = M
function M.new()
    local ffi = require 'ffi'
    ffi.cdef[[
        int __stdcall QueryPerformanceCounter(int64_t* value);
        int __stdcall QueryPerformanceFrequency(int64_t* value);
        void __stdcall Sleep(unsigned long milliseconds);
    ]]
    local kernel = ffi.load('kernel32')
    local freq, counter = ffi.new('int64_t[1]'), ffi.new('int64_t[1]')
    assert(kernel.QueryPerformanceFrequency(freq) ~= 0, 'Performance timer unavailable')
    return setmetatable({ffi=ffi, kernel=kernel, frequency=tonumber(freq[0]), counter=counter, last=nil, limit=0}, M)
end
function M:clock()
    self.kernel.QueryPerformanceCounter(self.counter)
    return tonumber(self.counter[0])/self.frequency
end
function M:present(limit, active)
    if not active or limit == 0 then self.last=nil; self.limit=0; return end
    if self.limit ~= limit then self.last=nil; self.limit=limit end
    local now = self:clock()
    if self.last then
        local remaining = 1/limit - (now-self.last)
        if remaining > 0 then
            self.kernel.Sleep(math.ceil(remaining*1000))
            now = self:clock()
        end
    end
    self.last=now
end
return M
