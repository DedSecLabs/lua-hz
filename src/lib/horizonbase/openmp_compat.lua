-- Local QA: read-only integration with the verified open.mp client build 6.
-- The runtime creates this lazily on HZ; foreign calls never initialize FFI.
local bit=require('bit')
local M={}
function M.new(authorized,injected)
    local api,previous,eventAt,lastKey,pollAt,pollKey=nil,nil,nil,nil,nil,nil
    local function initialize()
        if api then return api end
        if injected then api=injected;return api end
        local ffi=require('ffi')
        pcall(ffi.cdef,[[
            void* __stdcall GetModuleHandleA(const char*);
            void* __stdcall GetProcAddress(void*,const char*);
            typedef struct {void* base;void* allocation;unsigned long allocationProtect,bytes,state,protect,type;} LuaHZOMPReadMemory;
        ]])
        local kernel=ffi.load('kernel32');local user=ffi.load('user32')
        local query=ffi.cast('unsigned long (__stdcall *)(const void*,void*,unsigned long)',kernel.GetProcAddress(kernel.GetModuleHandleA('kernel32.dll'),'VirtualQuery'))
        local memory=ffi.new('LuaHZOMPReadMemory[1]')
        api={module=function()return tonumber(ffi.cast('uintptr_t',kernel.GetModuleHandleA('omp-client.dll')))end,
            readable=function(address,n)
                if address==0 or address+n<address or address+n>4294967295 then return false end
                local p=ffi.cast('const void*',address)
                if query(p,memory,ffi.sizeof(memory[0]))~=ffi.sizeof(memory[0]) then return false end
                local info=memory[0]
                return info.state==0x1000 and bit.band(info.protect,0x101)==0
                    and address+n<=tonumber(ffi.cast('uintptr_t',info.base))+tonumber(info.bytes)
            end,
            byte=function(address)return tonumber(ffi.cast('const unsigned char*',address)[0])end,
            word=function(address)return tonumber(ffi.cast('const unsigned long*',address)[0])end,
            down=function(code)
                local get=ffi.cast('short (__stdcall *)(int)',kernel.GetProcAddress(kernel.GetModuleHandleA('user32.dll'),'GetAsyncKeyState'))
                return get~=nil and bit.band(get(code),0x8000)~=0
            end,
            keepAlive={kernel,user}}
        return api
    end
    local function state()
        if not authorized() then return false,false end
        local ok,known,opened=pcall(function()
            local a=initialize();local base=a.module()
            if not base or base==0 or not a.readable(base,0x100) then return false,false end
            local pe=a.word(base+0x3c)
            if pe>=0x1000 or not a.readable(base+pe,0x80)
                or a.word(base+pe+8)~=0x69430243 or a.word(base+pe+40)~=0xb23e4
                or a.word(base+pe+80)~=0x219000 then return false,false end
            local cmp=base+0x40727;local flag=base+0x1d1690
            if not a.readable(cmp,12) or not a.readable(flag,1)
                or a.byte(cmp)~=0x83 or a.byte(cmp+1)~=0xfb or a.byte(cmp+2)~=0x78
                or a.byte(cmp+5)~=0x80 or a.byte(cmp+6)~=0x3d or a.word(cmp+7)~=flag
                or a.byte(cmp+11)~=0 then return false,false end
            local value=a.byte(flag)
            if value~=0 and value~=1 then return false,false end
            return true,value==1
        end)
        if not ok then return false,false end
        return known,opened
    end
    return {
        state=state,
        noteWindowKey=function(_,code,now)
            eventAt=now;lastKey=code
            return not(pollKey==code and pollAt and now-pollAt>=0 and now-pollAt<=100)
        end,
        pollKey=function(_,code,now)
            local known=state()
            if not known or code==0 then previous=nil;return false end
            local down=initialize().down(code)
            local edge=previous==false and down;previous=down
            if edge and not(lastKey==code and eventAt and now-eventAt>=0 and now-eventAt<=100) then
                pollAt=now;pollKey=code;return true
            end
            return false
        end,
        reset=function()previous=nil;eventAt=nil;lastKey=nil;pollAt=nil;pollKey=nil end,
    }
end
return M
