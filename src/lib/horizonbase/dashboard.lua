local logic=require 'horizonbase.logic'
local M={}
M.energyWidth=368 -- 15% wider than the original 320-unit stamina/oxygen panel.
function M.layout(w,h,scale,mode,nitro)
    local width=math.min(mode=='energy' and M.energyWidth or 320,(w-24)/scale)
    local height=mode=='minimal' and 126 or mode=='energy' and 82 or 212
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
        dl:AddRectFilled(im.ImVec2(ex,ey),im.ImVec2(ex+panel.width,ey+panel.height),im.U32(.06,.07,.07,.55),10*scale)
        icon(oxygenShown and 'swimming-filled' or 'run',ex+18*scale,ey+10*scale,color)
        local label=oxygenShown and 'Oxygen' or 'Stamina';local fontSize=18*scale
        local labelWidth=im.CalcTextSize(label).x*fontSize/im.GetFontSize()
        dl:AddTextFontPtr(im.GetFont(),fontSize,im.ImVec2(ex+panel.width-16*scale-labelWidth,ey+19*scale),color,label)
        o:bar(dl,ex+16*scale,ey+54*scale,(panel.logicalWidth-32)*scale,16*scale,
            oxygenShown and s.oxygen or s.stamina,color,nil,im.U32(.16,.16,.18,1))
    end
    if not vehicle then energy(box);return end
    dl:AddRectFilled(im.ImVec2(x,y),im.ImVec2(x+box.width,y+box.height),im.U32(.06,.07,.07,.55),10*scale)
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
    if full then title(s.vehicleName or 'Vehicle',gold)end
    if vehicle then
        local number=tostring(math.max(0,math.floor((s.speed or 0)+.5)))
        -- Equal digit cells reserve three places even when leading places are blank.
        local cell=0
        for digit=0,9 do cell=math.max(cell,o.bitmap:width(tostring(digit),1,'pricedown'))end
        local slots=math.max(3,#number)
        local size=math.min(o:playerNumberSize(),(width-100)/(slots*cell))
        local numY=y+(full and 50 or 14)*scale
        local slotX=right-slots*cell*size*scale
        for i=1,#number do
            local digit=number:sub(i,i)
            local edge=slotX+(slots-#number+i)*cell*size*scale
            text(digit,edge-o.bitmap:width(digit,size,'pricedown')*scale,numY,size,'pricedown',white,3)
        end
        text('MPH',slotX-o.bitmap:width('MPH',16,'gothic')*scale-10*scale,numY+(size-16)*scale,16,'gothic',white,1.5)
        -- Both states remain visible on dark scenes; shape, color and text agree.
        -- Unknown native state stays neutral instead of implying an unlocked car.
        local label=s.locked==true and 'Locked' or s.locked==false and 'Unlocked' or 'Unknown'
        local tint=s.locked==true and im.U32(1,.68,.24,1) or s.locked==false and im.U32(.45,.80,1,1) or im.U32(.85,.87,.90,1)
        icon(s.locked==false and 'car-door-lock-open' or 'car-door-lock',x+18*scale,numY+2*scale,tint,44)
        dl:AddTextFontPtr(im.GetFont(),15*scale,im.ImVec2(x+18*scale,numY+49*scale),tint,label)
    end
    local barY=y+(vehicle and(full and 122 or 88)or 54)*scale
    local value=logic.clamp((s.vehicleHealth or 0)/1000,0,1)
    o:bar(dl,x+16*scale,barY,(width-32)*scale,16*scale,value,red,nil,im.U32(.16,.16,.18,1))
    local current=o.game.vehicleInfo and o.game.vehicleInfo.current
    if current and current.handle==s.vehicle and current.id==s.networkVehicleId and (current.ownership=='personal' or current.ownership=='family') then
        local name=current.ownership=='personal' and 'key' or 'users'
        local tint=current.ownership=='personal' and gold or blue
        local iy=y+(full and 159 or 108)*scale;local size=(full and 24 or 14)*scale
        local tex=o:texture('vehicle-v040/'..name..'.png')
        if tex then dl:AddImage(tex,im.ImVec2(x+16*scale,iy),im.ImVec2(x+16*scale+size,iy+size),im.ImVec2(0,0),im.ImVec2(1,1),tint)end
        dl:AddTextFontPtr(im.GetFont(),(full and 14 or 13)*scale,im.ImVec2(x+(full and 46 or 35)*scale,iy+(full and 4 or 0)*scale),tint,current.ownership=='personal' and 'Personal' or 'Family')
    end
    if full then
        local hp=tostring(math.floor(value*100))
        local hpSize=32;local hpW=o.bitmap:width(hp,hpSize,'pricedown')*scale
        local percentW=(o.bitmap:width('%',16,'gothic')+6)*scale
        local footerY=y+159*scale
        icon('car-gear',right-hpW-percentW-54*scale,footerY-2*scale,im.U32(.95,.38,.40,1),44)
        text(hp,right-hpW-percentW,footerY,hpSize,'pricedown',white,2.5)
        text('%',right-percentW+6*scale,footerY+16*scale,16,'gothic',white,1.5)
        if o.game.cruise.active then text('CC '..math.floor(o.game.cruise.target),x+16*scale,y+193*scale,13,'gothic',gold,1.2)end
    end
    if oxygenShown then energy(panels[2])end
end
return M
