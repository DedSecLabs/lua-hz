local logic=require 'horizonbase.logic'
local M={}
function M.layout(w,h,scale,mode,nitro)
    local width=math.min(320,(w-24)/scale)
    local height=mode=='minimal' and 112 or mode=='energy' and 82 or 198
    return {x=w-(width+12)*scale,y=h-(height+20)*scale,width=width*scale,height=height*scale,logicalWidth=width}
end
function M.draw(o,dl,s,scale,w,h,staminaShown,oxygenShown)
    local im=o.im;local vehicle=s.vehicle and o.config.settings.vdb>0
    if not vehicle and (s.vehicle or not(staminaShown or oxygenShown))then return end
    local full=vehicle and o.config.settings.vdb~=2
    local box=M.layout(w,h,scale,vehicle and(full and 'full' or 'minimal')or 'energy')
    local x,y=box.x,box.y;local width=box.logicalWidth;local right=x+(width-16)*scale
    local white=im.U32(1,1,1,1);local gold=im.U32(.86,.67,.29,1)
    local red=im.U32(.73,.12,.16,1);local green=im.U32(.20,.46,.13,1);local blue=im.U32(.40,.70,.91,1)
    local color=vehicle and red or oxygenShown and blue or gold
    dl:AddRectFilled(im.ImVec2(x,y),im.ImVec2(x+box.width,y+box.height),im.U32(.06,.07,.07,.55),10*scale)
    local function text(value,tx,ty,size,kind,tint,stroke)
        o:nativeText(dl,im.ImVec2(tx,ty),tint,value,size*scale,kind,(stroke or 2)*scale)
    end
    local function icon(name,ix,iy,tint)
        local tex=o:texture('dashboard-v0221/'..name..'.png')
        if tex then dl:AddImage(tex,im.ImVec2(ix,iy),im.ImVec2(ix+36*scale,iy+36*scale),im.ImVec2(0,0),im.ImVec2(1,1),tint)end
    end
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
        if s.locked~=nil then icon(s.locked and 'car-door-lock' or 'car-door-lock-open',x+18*scale,numY+4*scale,s.locked and red or green)end
    else icon(oxygenShown and 'swimming-filled' or 'run',x+18*scale,y+10*scale,color)end
    local barY=y+(vehicle and(full and 110 or 76)or 54)*scale
    local value=vehicle and logic.clamp((s.vehicleHealth or 0)/1000,0,1)or(oxygenShown and s.oxygen or s.stamina)
    o:bar(dl,x+16*scale,barY,(width-32)*scale,16*scale,value,color,nil,im.U32(.16,.16,.18,1))
    if full then
        local hp=tostring(math.floor(value*100))
        local hpSize=32;local hpW=o.bitmap:width(hp,hpSize,'pricedown')*scale
        local percentW=(o.bitmap:width('%',16,'gothic')+6)*scale
        local footerY=y+145*scale
        icon('car-gear',right-hpW-percentW-46*scale,footerY-2*scale,red)
        text(hp,right-hpW-percentW,footerY,hpSize,'pricedown',white,2.5)
        text('%',right-percentW+6*scale,footerY+16*scale,16,'gothic',white,1.5)
        if o.game.cruise.active then text('CC '..math.floor(o.game.cruise.target),x+16*scale,y+179*scale,13,'gothic',gold,1.2)end
    end
end
return M
