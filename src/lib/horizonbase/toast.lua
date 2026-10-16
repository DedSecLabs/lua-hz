local palette=require 'horizonbase.palette'
-- Small load/status notification drawn using the existing ImGui renderer.
local M={};M.__index=M
function M.new(im,clock)
    return setmetatable({im=im,clock=clock,queue={},announced=false},M)
end
function M:push(text,kind,key)
    if key then
        if self.current and self.current.key==key then
            self.current.text=text;self.current.kind=kind or 'info';self.current.start=self.clock()
            return
        end
        for _,item in ipairs(self.queue)do
            if item.key==key then item.text=text;item.kind=kind or 'info';return end
        end
    end
    self.queue[#self.queue+1]={text=text,kind=kind or 'info',duration=4500,key=key}
    if #self.queue>4 then table.remove(self.queue,1) end
end
function M:announce(version,faults,interfaceReady)
    if self.announced or not interfaceReady or faults.Menu or faults.HUD or faults.Resources then return false end
    self.announced=true
    self:push('LuaHZ v'..version..' has been loaded','info')
    return true
end
function M:active()return self.current~=nil or #self.queue>0 end
local function linesFor(text,measure,width)
    local lines={};local line=''
    for word in text:gmatch('%S+')do
        local candidate=line=='' and word or line..' '..word
        if measure(candidate)<=width then line=candidate
        else
            if line~='' then lines[#lines+1]=line;line=''end
            for i=1,#word do
                local char=word:sub(i,i)
                if line~='' and measure(line..char)>width then lines[#lines+1]=line;line=''end
                line=line..char
            end
        end
    end
    if line~='' then lines[#lines+1]=line end
    return #lines>0 and lines or {''}
end
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
    local screenWidth,h=getScreenResolution()
    local dashboard=require 'horizonbase.dashboard'
    local panel,S
    if self.overlay then panel,S=self.overlay:energyPanelLayout(screenWidth,h)
    else
        S=math.min(im.GetFontSize()/15,(screenWidth-24)/dashboard.energyWidth,(h-24)/82)
        panel=dashboard.layout(screenWidth,h,S,'energy')
    end
    local fontSize=18*S;local w=panel.width;local margin=12*S
    local measure=function(text)return im.CalcTextSize(text).x*fontSize/im.GetFontSize()end
    local lines=linesFor(item.text,measure,w-72*S)
    if #lines>3 then
        lines={lines[1],lines[2],lines[3]}
        while #lines[3]>0 and measure(lines[3]..'...')>w-72*S do lines[3]=lines[3]:sub(1,-2)end
        lines[3]=lines[3]..'...'
    end
    local height=math.max(panel.height,(#lines*22+32)*S)
    local x,y=panel.x,panel.y+panel.height-height
    if self.overlay and (not self.hudVisible or self.hudVisible())then
        for _,panel in ipairs(self.overlay:lowerHudBounds(screenWidth,h))do
            if x+w>panel.x and x<panel.x+panel.width then y=math.min(y,panel.y-12*S-height)end
        end
    end
    y=math.max(margin,y)
    dl:AddRectFilled(im.ImVec2(x,y),im.ImVec2(x+w,y+height),palette.u32(im,'sidebar',.94*alpha),12*S)
    local error=item.kind=='error'
    local centerY=y+height/2
    dl:AddCircleFilled(im.ImVec2(x+28*S,centerY),12*S,error and im.U32(1,.59,.15,alpha) or palette.u32(im,'accent',alpha),18)
    local icon=self.overlay and self.overlay:texture('ui-v0212/'..(error and 'triangle-alert' or 'check')..'.png')
    if icon then dl:AddImage(icon,im.ImVec2(x+18*S,centerY-10*S),im.ImVec2(x+38*S,centerY+10*S),im.ImVec2(0,0),im.ImVec2(1,1),im.U32(1,1,1,alpha)) end
    for i,line in ipairs(lines)do
        dl:AddTextFontPtr(im.GetFont(),fontSize,im.ImVec2(x+52*S,y+(height-#lines*22*S)/2+(i-1)*22*S),im.U32(.93,.94,.96,alpha),line)
    end
end
return M
