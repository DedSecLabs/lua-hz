-- Small load/status notification drawn using the existing ImGui renderer.
local M={};M.__index=M
function M.new(im,clock)
    return setmetatable({im=im,clock=clock,queue={},announced=false},M)
end
function M:push(text,kind)
    self.queue[#self.queue+1]={text=text,kind=kind or 'info',duration=4500}
    if #self.queue>4 then table.remove(self.queue,1) end
end
function M:announce(version,faults,interfaceReady)
    if self.announced or not interfaceReady or faults.Menu or faults.HUD or faults.Resources then return false end
    self.announced=true
    self:push('LuaHZ v'..version..' has been loaded','info')
    return true
end
function M:active()return self.current~=nil or #self.queue>0 end
function M:draw()
    local now=self.clock()
    if not self.current then
        self.current=table.remove(self.queue,1)
        if not self.current then return end
        self.current.start=now
    end
    local item=self.current;local elapsed=now-item.start
    if elapsed>=item.duration then self.current=nil;return end
    local alpha=math.min(1,elapsed/180,(item.duration-elapsed)/350)
    local im=self.im;local dl=im.GetBackgroundDrawList()
    local screenWidth,h=getScreenResolution();local textSize=im.CalcTextSize(item.text)
    local S=im.GetFontSize()/15
    local w=math.max(300*S,textSize.x+66*S)
    local x,y=screenWidth-26*S-w,h-78*S
    dl:AddRectFilled(im.ImVec2(x,y),im.ImVec2(x+w,y+47*S),im.U32(.08,.085,.095,.94*alpha),12*S)
    local error=item.kind=='error'
    dl:AddCircleFilled(im.ImVec2(x+23*S,y+23*S),9*S,im.U32(error and 1 or .36,error and .59 or .75,error and .15 or .98,alpha),18)
    local icon=self.overlay and self.overlay:texture('ui-v0212/'..(error and 'triangle-alert' or 'check')..'.png')
    if icon then dl:AddImage(icon,im.ImVec2(x+16*S,y+16*S),im.ImVec2(x+30*S,y+30*S),im.ImVec2(0,0),im.ImVec2(1,1),im.U32(1,1,1,alpha)) end
    dl:AddText(im.ImVec2(x+44*S,y+15*S),im.U32(.93,.94,.96,alpha),item.text)
end
return M
