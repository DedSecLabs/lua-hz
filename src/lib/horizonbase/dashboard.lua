local palette=require 'horizonbase.palette'
local logic=require 'horizonbase.logic'
local Status=require 'horizonbase.vehicle_status'
local M={}
M.energyWidth=368 -- 15% wider than the original 320-unit stamina/oxygen panel.
function M.layout(w,h,scale,mode,nitro)
    local width=math.min(mode=='energy' and M.energyWidth or 448,(w-24)/scale)
    local height=mode=='minimal' and 146 or mode=='energy' and 82 or 232
    return {x=w-(width+12)*scale,y=h-(height+20)*scale,width=width*scale,height=height*scale,logicalWidth=width}
end
function M.bounds(settings,s,scale,w,h,staminaShown,oxygenShown)
    local vehicle=s.vehicle and settings.vdb>0
    if not vehicle and not(staminaShown or oxygenShown)then return {}end
    local box=M.layout(w,h,scale,vehicle and(settings.vdb==2 and 'minimal' or 'full')or 'energy')
    local panels={box}
    if vehicle and oxygenShown then
        local energy=M.layout(w,h,scale,'energy');energy.y=box.y-(82+12)*scale
        panels[2]=energy
    end
    return panels
end
function M.draw(o,dl,s,scale,w,h,staminaShown,oxygenShown)
    local im=o.im;local vehicle=s.vehicle and o.config.settings.vdb>0
    if not vehicle and not(staminaShown or oxygenShown)then return end
    local full=vehicle and o.config.settings.vdb~=2
    local panels=M.bounds(o.config.settings,s,scale,w,h,staminaShown,oxygenShown)
    local box=panels[1]
    local x,y=box.x,box.y;local width=box.logicalWidth;local right=x+(width-16)*scale
    local accent=palette.u32(im,'accent')
    local white=im.U32(1,1,1,1);local gold=im.U32(.86,.67,.29,1)
    local red=im.U32(.73,.12,.16,1);local blue=im.U32(.40,.70,.91,1)
    local function text(value,tx,ty,size,kind,tint,stroke)
        o:nativeText(dl,im.ImVec2(tx,ty),tint,value,size*scale,kind,(stroke or 2)*scale)
    end
    local function icon(name,ix,iy,tint,size)
        size=(size or 36)*scale
        local tex=o:texture('dashboard-v031/'..name..'.png')
        if tex then dl:AddImage(tex,im.ImVec2(ix,iy),im.ImVec2(ix+size,iy+size),im.ImVec2(0,0),im.ImVec2(1,1),tint)end
    end
    local function energy(panel)
        local ex,ey=panel.x,panel.y
        local color=oxygenShown and blue or gold
        dl:AddRectFilled(im.ImVec2(ex,ey),im.ImVec2(ex+panel.width,ey+panel.height),palette.u32(im,'sidebar',.55),10*scale)
        icon(oxygenShown and 'swimming-filled' or 'run',ex+18*scale,ey+10*scale,color)
        local label=oxygenShown and 'Oxygen' or 'Stamina';local fontSize=18*scale
        local labelWidth=im.CalcTextSize(label).x*fontSize/im.GetFontSize()
        dl:AddTextFontPtr(im.GetFont(),fontSize,im.ImVec2(ex+panel.width-16*scale-labelWidth,ey+19*scale),color,label)
        o:bar(dl,ex+16*scale,ey+54*scale,(panel.logicalWidth-32)*scale,16*scale,
            oxygenShown and s.oxygen or s.stamina,color,nil,im.U32(.16,.16,.18,1))
    end
    if not vehicle then energy(box);return end
    dl:AddRectFilled(im.ImVec2(x,y),im.ImVec2(x+box.width,y+box.height),palette.u32(im,'sidebar',.55),10*scale)
    local function title(value,tint)
        value=tostring(value):upper()
        local size=math.min(24,(width-36)/o.bitmap:width(value,1,'gothic'))
        if size<16 then
            size=16
            while #value>0 and o.bitmap:width(value..'...',size,'gothic')>width-36 do value=value:sub(1,-2)end
            value=value..'...'
        end
        text(value,right-o.bitmap:width(value,size,'gothic')*scale,y+12*scale,size,'gothic',tint)
    end
    if full then title(s.vehicleName or 'Vehicle',accent)end
    if vehicle then
        local number=tostring(math.max(0,math.floor((s.speed or 0)+.5)))
        -- Equal digit cells reserve three places even when leading places are blank.
        local cell=0
        for digit=0,9 do cell=math.max(cell,o.bitmap:width(tostring(digit),1,'pricedown'))end
        local slots=math.max(3,#number)
        local size=math.min(o:playerNumberSize(),120/(slots*cell))
        local numY=y+(full and 50 or 14)*scale
        local slotX=right-slots*cell*size*scale
        for i=1,#number do
            local digit=number:sub(i,i)
            local edge=slotX+(slots-#number+i)*cell*size*scale
            text(digit,edge-o.bitmap:width(digit,size,'pricedown')*scale,numY,size,'pricedown',white,3)
        end
        text('MPH',right-o.bitmap:width('MPH',16,'gothic')*scale,numY+61*scale,16,'gothic',white,1.5)
        -- The menu and dashboard share confirmed state text, icons and theme roles.
        local observer=o.game.vehicleInfo
        local rowY=y+(full and 50 or 14)*scale
        for i,part in ipairs({'lock','engine','lights','window'})do
            local state=Status.describe(observer,s,part)
            local label=part=='lock' and 'Doors' or part:gsub('^%l',string.upper)
            local status=state.text
            local tint=palette.u32(im,state.token)
            local cell=(width-152)/4;local center=x+(16+(i-.5)*cell)*scale
            local tex=o:texture(state.path)
            if tex then dl:AddImage(tex,im.ImVec2(center-22*scale,rowY),im.ImVec2(center+22*scale,rowY+44*scale),im.ImVec2(0,0),im.ImVec2(1,1),tint)end
            for j,caption in ipairs({label,status})do
                local size=math.min(j==1 and 14 or 15,(cell-6)*im.GetFontSize()/math.max(1,im.CalcTextSize(caption).x))*scale;local tw=im.CalcTextSize(caption).x*size/im.GetFontSize()
                dl:AddTextFontPtr(im.GetFont(),size,im.ImVec2(center-tw/2,rowY+(j==1 and 45 or 61)*scale),tint,caption)
            end
        end
    end
    local barY=y+(vehicle and(full and 136 or 100)or 54)*scale
    local value=logic.clamp((s.vehicleHealth or 0)/1000,0,1)
    o:bar(dl,x+16*scale,barY,(width-32)*scale,16*scale,value,red,nil,im.U32(.16,.16,.18,1))
    local current=o.game.vehicleInfo and o.game.vehicleInfo.current
    if current and current.handle==s.vehicle and current.id==s.networkVehicleId and (current.ownership=='personal' or current.ownership=='family') then
        local name=current.ownership=='personal' and 'key' or 'users'
        local tint=current.ownership=='personal' and gold or blue
        local iy=y+(full and 169 or 124)*scale;local size=(full and 24 or 14)*scale
        local tex=o:texture('vehicle-v040/'..name..'.png')
        if tex then dl:AddImage(tex,im.ImVec2(x+16*scale,iy),im.ImVec2(x+16*scale+size,iy+size),im.ImVec2(0,0),im.ImVec2(1,1),tint)end
        dl:AddTextFontPtr(im.GetFont(),(full and 14 or 13)*scale,im.ImVec2(x+(full and 46 or 35)*scale,iy+(full and 4 or 0)*scale),tint,current.ownership=='personal' and 'Personal Vehicle' or 'Family Vehicle')
    end
    if full then
        local hp=tostring(math.floor(value*100))
        local hpSize=32;local hpW=o.bitmap:width(hp,hpSize,'pricedown')*scale
        local percentW=(o.bitmap:width('%',16,'gothic')+6)*scale
        local footerY=y+169*scale
        icon('car-gear',right-hpW-percentW-54*scale,footerY-2*scale,im.U32(.95,.38,.40,1),44)
        text(hp,right-hpW-percentW,footerY,hpSize,'pricedown',white,2.5)
        text('%',right-percentW+6*scale,footerY+16*scale,16,'gothic',white,1.5)
        if o.game.cruise.active then text('CC '..math.floor(o.game.cruise.target),x+16*scale,y+213*scale,13,'gothic',accent,1.2)end
    end
    if oxygenShown then energy(panels[2])end
end
return M
