package.path='src/lib/?.lua;'..package.path
local M=require 'horizonbase.native_visuals'
local authorized=false
local counts={load=0,init=0,update=0,stop=0,cleanup=0}
local status=1
local dll={HZV_Init=function()counts.init=counts.init+1;return 1 end,
    HZV_Update=function()counts.update=counts.update+1;return status end,
    HZV_Deactivate=function()counts.stop=counts.stop+1 end,
    HZV_Shutdown=function()counts.cleanup=counts.cleanup+1 end}
local native=M.new('C:\\Test',function()return authorized end,function()counts.load=counts.load+1;return dll end)
native:activate();native:update();assert(counts.load==0 and counts.update==0)
authorized=true;native:activate();native:update();assert(counts.load==1 and counts.init==1 and counts.update==1)
authorized=false;native:update();assert(counts.stop==1 and native.status==0)
authorized=true;native:activate();native:update();assert(counts.load==1 and counts.init==1 and counts.update==2)
status=-3;native:update();assert(native.failed and counts.stop==2)
native:update();assert(counts.update==3,'Failed assets must not repeatedly load')
native:cleanup();assert(counts.cleanup==1)
print('PASS native helper loads only on HZ, restores on leaving, reuses resources and fails closed')
