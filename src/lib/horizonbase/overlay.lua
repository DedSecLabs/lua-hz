local logic=require 'horizonbase.logic'
local mapIcons=require 'horizonbase.map_icons'
local M={};M.__index=M
local hudStyle={fontSize=32,padding=12,gap=12,lineGap=2,labelGap=6,barHeight=22,
    playerWidth=350,
    bottomMargin=30}

function M.new(im,config,game,server)
    local self=setmetatable({im=im,config=config,game=game,server=server,textures={},tiles={},mapOpen=false,nativeHidden=false,serverHud=require('horizonbase.server_hud').new()},M)
    self.bitmap=require('horizonbase.bitmap_font').new(im,function(rel)return self:texture(rel)end)
    return self
end

function M:texture(rel)
    if self.textures[rel]~=nil then return self.textures[rel] or nil end
    for _,base in ipairs({'horizonbase','lunahz'}) do
        local path=getWorkingDirectory()..'\\resource\\'..base..'\\'..rel:gsub('/','\\')
        if doesFileExist(path) then
            local ok,tex=pcall(self.im.CreateTextureFromFile,path)
            if ok and tex~=nil and tex~=0 then self.textures[rel]=tex;return tex end
        end
    end
    self.textures[rel]=false;return nil
end

function M:initialize()
    self:texture('hud-v0218/hud-font.png');self:texture('hud-v0218/wanted-star.png')
    self:texture('ui-v0212/radar_centre.png')
    -- Upload optional assets one per rendered frame, rather than blocking the
    -- first interface frame with every map tile, weapon and radar sprite.
    self.warmup={};self.warmupIndex=1
    for i=1,36 do self.warmup[#self.warmup+1]={path='sa_map/'..i..'.jpg',tile=i} end
    for i=0,46 do self.warmup[#self.warmup+1]={path='weaponicons/'..i..'.png'} end
    for kind=2,63 do self.warmup[#self.warmup+1]={path='ui-v0212/'..mapIcons.file(kind)} end
end

function M:warmupPending()
    return self.warmup~=nil and self.warmupIndex<=#self.warmup
end

function M:warmupStep()
    if not self:warmupPending() then return end
    local item=self.warmup[self.warmupIndex]
    local tex=self:texture(item.path)
    if item.tile then self.tiles[item.tile]=tex or false end
    self.warmupIndex=self.warmupIndex+1
end

function M:serverMapIcon(dl,icon,x,y,size,alpha)
    local im=self.im;local file=mapIcons.file(icon.kind)
    local texture=file and self:texture('ui-v0212/'..file)
    if texture then
        local halfW=size/2;local halfH=halfW*(icon.kind==6 and 61/64 or 1)
        local function image(offsetX,offsetY,color)
            dl:AddImage(texture,im.ImVec2(x-halfW+offsetX,y-halfH+offsetY),
                im.ImVec2(x+halfW+offsetX,y+halfH+offsetY),im.ImVec2(0,0),im.ImVec2(1,1),color)
        end
        local outline=math.max(1,size/20)
        for _,offset in ipairs({{-1,0},{1,0},{0,-1},{0,1}}) do
            image(offset[1]*outline,offset[2]*outline,im.U32(0,0,0,alpha))
        end
        -- SA-MP's color field applies only to type 0, not colored sprite artwork.
        image(0,0,im.U32(1,1,1,alpha))
    else
        local half=size*(icon.kind==1 and .34 or .17)
        local color=im.U32(1,1,1,alpha)
        if icon.kind==0 then
            local r,g,b,a=mapIcons.rgba(icon.color,alpha)
            if a<=0 then return end
            color=im.U32(r,g,b,a)
        end
        dl:AddRectFilled(im.ImVec2(x-half-1,y-half-1),im.ImVec2(x+half+1,y+half+1),im.U32(0,0,0,alpha),0)
        dl:AddRectFilled(im.ImVec2(x-half,y-half),im.ImVec2(x+half,y+half),color,0)
    end
end

function M:playerMapIcon(dl,x,y,heading,size)
    local im=self.im
    local angle=math.rad(heading);local c,s=math.cos(angle),math.sin(angle)
    local texture=self:texture('ui-v0212/radar_centre.png')
    if texture then
        local half=size/2
        local function draw(offsetX,offsetY,color)
            local function point(u,v) return im.ImVec2(x+offsetX+u*c+v*s,y+offsetY-u*s+v*c) end
            dl:AddImageQuad(texture,point(-half,-half),point(half,-half),point(half,half),point(-half,half),
                im.ImVec2(0,0),im.ImVec2(1,0),im.ImVec2(1,1),im.ImVec2(0,1),color)
        end
        -- Tint shifted copies of the original transparent sprite to outline it.
        local outline=math.max(1.25,size/20)
        for _,offset in ipairs({{-1,-1},{0,-1},{1,-1},{-1,0},{1,0},{-1,1},{0,1},{1,1}}) do
            draw(offset[1]*outline,offset[2]*outline,im.U32(.02,.02,.02,1))
        end
        draw(0,0,im.U32(1,1,1,1))
    else
        local dx,dy=-s,-c
        local function triangle(front,back,side,color)
            dl:AddTriangleFilled(im.ImVec2(x+dx*front,y+dy*front),
                im.ImVec2(x-dx*back+dy*side,y-dy*back-dx*side),
                im.ImVec2(x-dx*back-dy*side,y-dy*back+dx*side),color)
        end
        triangle(14,10,9,im.U32(.02,.02,.02,1))
        triangle(11,7,6,im.U32(1,1,1,1))
    end
end

function M:bar(dl,x,y,w,h,value,color,label,background)
    local im=self.im;local scale=self.hudScale or 1
    local insetX,insetY=3*scale,3*scale
    dl:AddRectFilled(im.ImVec2(x,y),im.ImVec2(x+w,y+h),im.U32(0,0,0,1),0)
    dl:AddRectFilled(im.ImVec2(x+insetX,y+insetY),im.ImVec2(x+w-insetX,y+h-insetY),background or im.U32(.16,.16,.18,1),0)
    value=logic.clamp(value,0,1)
    if value>0 then
        dl:AddRectFilled(im.ImVec2(x+insetX,y+insetY),im.ImVec2(x+insetX+(w-2*insetX)*value,y+h-insetY),color,0)
    end
    if label then self:text(dl,im.ImVec2(x,y-(hudStyle.fontSize+hudStyle.labelGap)*scale),im.U32(.94,.95,.96,1),label,scale) end
end

function M:nativeText(dl,pos,color,text,height,kind,outline,slant)
    if self.bitmap:draw(dl,text,pos.x,pos.y,height,kind,color,outline,slant) then return end
    -- Keep a readable outlined fallback when optional local glyph assets are absent.
    text=self.bitmap:normalize(text,kind)
    local im=self.im
    for _,v in ipairs({{-1,-1},{0,-1},{1,-1},{-1,0},{1,0},{-1,1},{0,1},{1,1}})do
        dl:AddTextFontPtr(im.GetFont(),height,im.ImVec2(pos.x+v[1]*outline,pos.y+v[2]*outline),im.U32(0,0,0,1),text)
    end
    dl:AddTextFontPtr(im.GetFont(),height,pos,color,text)
end

function M:text(dl,pos,color,text,scale)
    self:nativeText(dl,pos,color,text,hudStyle.fontSize*(scale or 1),'gothic',2*(scale or 1))
end

function M:playerNumberSize()
    local available=hudStyle.playerWidth-2*hudStyle.padding-142-8
    return math.min(48,available/self.bitmap:width('00:00',1,'pricedown'))
end

function M:textWidth(text)
    return self.bitmap:width(text,hudStyle.fontSize,'gothic')
end

-- Wrap dashboard labels using the bitmap font advances.
function M:wrap(text,width,fontHeight)
    local im=self.im;local lines={};local line=''
    local function fits(value) return self:textWidth(value)<=width end
    for word in tostring(text):gmatch('%S+') do
        local nextLine=line=='' and word or line..' '..word
        if line~='' and not fits(nextLine) then lines[#lines+1]=line;line='';nextLine=word end
        if not fits(nextLine) then
            for i=1,#word do
                local nextChar=line..word:sub(i,i)
                if line~='' and not fits(nextChar) then lines[#lines+1]=line;line='' end
                line=line..word:sub(i,i)
            end
        else line=nextLine end
    end
    if line~='' then lines[#lines+1]=line end
    return lines
end

function M:dashboard(dl,s,scale,w,h,stamina,oxygen)
    require('horizonbase.dashboard').draw(self,dl,s,scale,w,h,stamina,oxygen)
end

function M:restoreNative(contextLost)
    -- A new server may reuse the old IDs. Discard their saved positions rather
    -- than writing Horizon coordinates into another server's textdraw pool.
    if contextLost then self.serverHud:forget() else self.serverHud:restore() end
    if self.nativeHidden then displayHud(true);displayRadar(true);self.nativeHidden=false end
end

function M:updateNative(active)
    self.serverHud:update(active,self.server.horizon,getGameTimer())
    if active then
        -- SA-MP can reset this flag; enforce it while LuaHZ owns the HUD.
        displayHud(false);displayRadar(true);self.nativeHidden=true
    elseif self.nativeHidden then self:restoreNative() end
end

function M:hudGeometry(w,h)
    local s=self.game.sample
    local fitHeight=264
    if s.vehicle and self.config.settings.vdb>0 then
        fitHeight=(self.config.settings.vdb==2 and 146 or 232)+130+
            (self.config.settings.oxygen and s.underwater and 94 or 0)
    end
    return logic.hudLayout(w,h,self.config.hud,264,hudStyle.playerWidth,fitHeight,s.vehicle and self.config.settings.vdb>0 and 448 or hudStyle.playerWidth),
        self.config.settings.stamina and not s.vehicle and (s.running or (s.stamina or 1)<.995),
        self.config.settings.oxygen and s.underwater
end
function M:energyPanelLayout(w,h)
    local layout=self:hudGeometry(w,h)
    return require('horizonbase.dashboard').layout(w,h,layout.scale,'energy'),layout.scale
end
function M:lowerHudBounds(w,h)
    if not self.game.sample.ready then return {}end
    local layout,stamina,oxygen=self:hudGeometry(w,h)
    return require('horizonbase.dashboard').bounds(self.config.settings,self.game.sample,layout.scale,w,h,stamina,oxygen)
end
function M:hud()
    local s=self.game.sample;local im=self.im;local dl=im.GetBackgroundDrawList()
    if not s.ready then self:restoreNative();return end
    -- Keep the vanilla radar; the custom panel replaces health, weapon, money and wanted indicators.
    self:updateNative(true)
    local w,h=getScreenResolution()
    local layout,staminaShown,oxygenShown=self:hudGeometry(w,h)
    local innerWidth=hudStyle.playerWidth-2*hudStyle.padding
    local scale=layout.scale;self.hudScale=scale
    local x,y=layout.x+hudStyle.padding*scale,layout.y+hudStyle.padding*scale
    local right=x+innerWidth*scale
    local icon=self:texture('weaponicons/'..s.weapon..'.png')
    if icon then dl:AddImage(icon,im.ImVec2(x,y),im.ImVec2(x+128*scale,y+128*scale)) end
    local barX=x+142*scale;local barWidth=(innerWidth-142)*scale
    local clock=s.hour and s.minute and ('%02d:%02d'):format(s.hour,s.minute) or '--:--'
    local clockHeight=self:playerNumberSize()*scale
    local clockWidth=self.bitmap:width(clock,clockHeight,'pricedown')
    self:nativeText(dl,im.ImVec2(right-clockWidth,y),im.U32(1,1,1,1),clock,clockHeight,'pricedown',3*scale)
    self:bar(dl,barX,y+64*scale,barWidth,22*scale,(s.armour or 0)/100,im.U32(1,1,1,1),nil,im.U32(.52,.51,.55,1))
    self:bar(dl,barX,y+104*scale,barWidth,22*scale,(s.health or 0)/100,im.U32(.73,.12,.16,1))
    local money=math.floor(s.money or 0)
    local cash=(money<0 and '-$' or '$')..('%08d'):format(math.abs(money))
    local cashHeight=math.min(48,(innerWidth-8)/self.bitmap:width(cash,1,'pricedown'))*scale
    local cashWidth=self.bitmap:width(cash,cashHeight,'pricedown')
    self:nativeText(dl,im.ImVec2(right-cashWidth,y+148*scale),im.U32(.20,.46,.13,1),cash,cashHeight,'pricedown',4*scale)
    local wanted=logic.clamp(math.floor(s.wanted or 0),0,6)
    local star=self:texture('hud-v0218/wanted-star.png')
    if star then
        local function image(sx,sy,tint)
            dl:AddImage(star,im.ImVec2(sx,sy),im.ImVec2(sx+32*scale,sy+32*scale),im.ImVec2(0,0),im.ImVec2(1,1),tint)
        end
        for i=1,wanted do
            local sx=right-(wanted-i+1)*36*scale;local sy=y+214*scale
            for _,v in ipairs({{-1,-1},{0,-1},{1,-1},{-1,0},{1,0},{-1,1},{0,1},{1,1}})do
                image(sx+v[1]*2*scale,sy+v[2]*2*scale,im.U32(0,0,0,1))
            end
            image(sx,sy,im.U32(1,.86,.10,1))
        end
    end
    self:dashboard(dl,s,scale,w,h,staminaShown,oxygenShown)
    if self.server.find.active then
        dl:AddText(im.ImVec2(30,h-130),im.U32(1,.70,.18,1),'Tracking '..self.server.find.name)
        dl:AddText(im.ImVec2(30,h-109),im.U32(.95,.95,.95,1),self.server.find.description or 'Requesting location...')
    end
    if self.server.track.active then dl:AddText(im.ImVec2(30,h-82),im.U32(1,.70,.18,1),'Vehicle tracker active') end
end

function M:map()
    local im=self.im;local dl=im.GetBackgroundDrawList()
    local w,h=getScreenResolution();local size=math.min(w,h)-24;local left,top=(w-size)/2,(h-size)/2
    local alpha=self.config.quickmap.opacity/100
    dl:AddRectFilled(im.ImVec2(0,0),im.ImVec2(w,h),im.U32(.02,.03,.04,.70*alpha))
    local cell=size/6;local complete=true
    for i=1,36 do
        local row,col=math.floor((i-1)/6),(i-1)%6
        local tex=self.tiles[i]
        if tex then
            dl:AddImage(tex,im.ImVec2(left+col*cell,top+row*cell),im.ImVec2(left+(col+1)*cell+.5,top+(row+1)*cell+.5),im.ImVec2(0,0),im.ImVec2(1,1),im.U32(1,1,1,alpha))
        else complete=false end
    end
    dl:PushClipRect(im.ImVec2(left,top),im.ImVec2(left+size,top+size),true)
    if self.config.quickmap.gangzones then
        for _,z in pairs(self.server.zones) do
            local x1,y1=logic.worldToMap(z.min.x,z.max.y,left,top,size)
            local x2,y2=logic.worldToMap(z.max.x,z.min.y,left,top,size)
            local r,g,b,a=require('horizonbase.gang_zones').color(z,getGameTimer(),1)
            dl:AddRectFilled(im.ImVec2(x1,y1),im.ImVec2(x2,y2),im.U32(r,g,b,a*alpha*.7))
        end
    end
    local saved={};local catalog=self.server.catalog
    if catalog and self.config.quickmap.rememberLocations then
        saved=catalog:savedOnly(self.server.icons,self.server.iconsRevision)
        for _,icon in ipairs(saved) do
            local x,y=logic.worldToMap(icon.position.x,icon.position.y,left,top,size)
            self:serverMapIcon(dl,icon,x,y,22*logic.clamp(size/1056,.75,1.5),alpha)
        end
    end
    for _,icon in pairs(self.server.icons) do
        local x,y=logic.worldToMap(icon.position.x,icon.position.y,left,top,size)
        self:serverMapIcon(dl,icon,x,y,22*logic.clamp(size/1056,.75,1.5),alpha)
    end
    local cp=self.server.checkpoint
    if cp then
        local x,y=logic.worldToMap(cp.x,cp.y,left,top,size)
        dl:AddCircleFilled(im.ImVec2(x,y),7,im.U32(1,.25,.19,1),20)
        dl:AddCircle(im.ImVec2(x,y),10,im.U32(1,.85,.85,1),20,2)
    end
    local s=self.game.sample
    if s.ready then
        local x,y=logic.worldToMap(s.x,s.y,left,top,size)
        self:playerMapIcon(dl,x,y,s.heading,32*logic.clamp(size/1056,.75,1.5))
    end
    dl:PopClipRect()
    dl:AddText(im.ImVec2(20,14),im.U32(1,1,1,1),self.preview and 'Live map preview - adjust opacity in the menu' or 'Quickmap - press your map key or Escape to close')
    if not complete then dl:AddText(im.ImVec2(20,38),im.U32(1,.7,.2,1),'Map images missing. Check the local resource installation.') end
end

function M:cleanup()
    self:restoreNative()
    if self.im.IsInitialized() then
        for _,texture in pairs(self.textures) do if texture then pcall(self.im.ReleaseTexture,texture) end end
    end
    self.textures={};self.mapOpen=false
end
return M
