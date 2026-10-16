local palette=require 'horizonbase.palette'
local ffi=require 'ffi'
local M={};M.__index=M
local Jobs=require 'horizonbase.job_actions'
local TILE_HEIGHT,ROW_STEP,HEADER_HEIGHT,SECTION_GAP=60,68,22,10
local JOB_TITLES={detective='Detective',lawyer='Lawyer',mechanic='Mechanic',bodyguard='Bodyguard',
    armsdealer='Arms Dealer',boxer='Boxer',drugsmuggler='Drug Smuggler',taxi='Taxi Driver',
    craftsman='Craftsman',trucker='Trucker',pizza='Pizza Delivery',pilot='Aircraft Pilot',farmer='Farmer',
    garbage='Garbage Collector',smuggler='Smuggler',lumberjack='Lumberjack',miner='Miner',
    forklift='Forklift Driver',drugdealer='Drug Dealer',prostitute='Prostitute'}
local function actionSections(server)
    local sections={{title='General',rows={
        {label='Clear navigation',hint='Also resets trackers and fares',icon='map-pin-off',kind='clear'},
        {label='Skills',hint='View your skill levels',icon='gauge',kind='general',arg='skills'},
        {label='Find a job',hint='Choose a job location',icon='search',kind='general',arg='findjob'},
        {label='Job help',hint='View your current job commands',icon='terminal',kind='general',arg='jobhelp'},
    }}}
    local jobs={}
    local function jobRows(key)
        if not jobs[key]then
            jobs[key]={title=JOB_TITLES[key]or 'Job actions',rows={}}
            sections[#sections+1]=jobs[key]
        end
        return jobs[key].rows
    end
    if Jobs.has(server.character,'detective') or server.find.active then
        local rows=jobRows('detective')
        rows[#rows+1]={label=server.find.active and 'Stop finding' or 'Find player',
            hint=server.find.active and server.find.name or 'Choose an online player',icon='search',find=true}
    end
    for _,a in ipairs(Jobs.list(server.character))do
        local rows=jobRows(a.job)
        rows[#rows+1]={label=a.label,hint=a.mode and 'Choose details before running' or 'Run once',icon='bot',job=a}
    end
    local height=0
    for i,section in ipairs(sections)do
        section.y=height
        local rows=math.ceil(#section.rows/2)
        height=height+HEADER_HEIGHT+rows*TILE_HEIGHT+math.max(0,rows-1)*(ROW_STEP-TILE_HEIGHT)
        if i<#sections then height=height+SECTION_GAP end
    end
    return sections,height
end
function M.new(im,ui,server,perform,players)
    return setmetatable({im=im,ui=ui,server=server,perform=perform,players=players,
        open=im.new.bool(false),query=im.new.char[65](''),value=im.new.char[33](''),targets={},findMode=false},M)
end
function M:reset()
    self.open[0]=false;self.findMode=false;self.jobAction=nil;self.notice=nil;self.targets={};self.im.StrCopy(self.query,'');self.im.StrCopy(self.value,'')
end
function M:submit(kind,arg)
    local ok,err=self.perform(kind,arg)
    if ok then self.open[0]=false;self.notice=nil
    else self.notice=err or 'Action unavailable. Try again during gameplay.'end
end
function M:tile(label,hint,icon,x,y,width,S,action)
    local im=self.im;im.SetCursorPos(im.ImVec2(x*S,y*S));local p=im.GetCursorScreenPos()
    local clicked=im.InvisibleButton(label..'##quickAction',im.ImVec2(width*S,TILE_HEIGHT*S))
    local hover=im.IsItemHovered();local dl=im.GetWindowDrawList()
    dl:AddRectFilled(p,im.ImVec2(p.x+width*S,p.y+TILE_HEIGHT*S),hover and palette.u32(im,'cardHover') or palette.u32(im,'card'),8*S)
    local tex=self.ui.overlay and self.ui.overlay:texture('ui-v0212/'..icon..'.png')
    if tex then dl:AddImage(tex,im.ImVec2(p.x+12*S,p.y+12*S),im.ImVec2(p.x+36*S,p.y+36*S),im.ImVec2(0,0),im.ImVec2(1,1),palette.u32(im,'accent'))end
    dl:AddTextFontPtr(im.GetFont(),16*S,im.ImVec2(p.x+46*S,p.y+10*S),palette.u32(im,'text'),label)
    dl:AddTextFontPtr(im.GetFont(),12*S,im.ImVec2(p.x+46*S,p.y+36*S),palette.u32(im,'muted'),hint)
    if clicked then action()end
end
function M:draw()
    local im=self.im;self.ui:theme()
    if self.findMode and not Jobs.has(self.server.character,'detective') and not self.server.find.active then self.findMode=false end
    local spec=self.jobAction and Jobs.get(self.server.character,self.jobAction)
    if self.jobAction and not spec then self.jobAction=nil end
    local detailMode=self.findMode or spec
    local sections,contentHeight
    if not self.findMode and not spec then sections,contentHeight=actionSections(self.server)end
    local gridHeight=contentHeight and contentHeight+12
    local height=(self.findMode or spec)and 400 or math.max(360,100+gridHeight+52)
    local w,h=getScreenResolution();local S=math.min(self.ui.scale,(w-24)/600,(h-24)/height)
    im.GetIO().FontGlobalScale=S*15/(im.FontBaseSize or 15)
    im.SetNextWindowSize(im.ImVec2(600*S,height*S),im.Cond.Always)
    im.SetNextWindowPos(im.ImVec2(w/2,h/2),im.Cond.Always,im.ImVec2(.5,.5))
    im.Begin('##LuaHZActions',self.open,im.WindowFlags.NoTitleBar+im.WindowFlags.NoCollapse+im.WindowFlags.NoResize+im.WindowFlags.NoScrollbar)
    local ok,err=pcall(function()
        im.SetCursorPos(im.ImVec2(22*S,18*S));self.ui:title('Quick Actions',palette.vec4(im,'accent'))
        im.SetCursorPos(im.ImVec2(565*S,10*S))
        local closePos=im.GetCursorScreenPos()
        if im.InvisibleButton('##closeActions',im.ImVec2(24*S,24*S))then self:reset()end
        local closeIcon=self.ui.overlay and self.ui.overlay:texture('ui-v0212/x.png')
        if closeIcon then im.GetWindowDrawList():AddImage(closeIcon,im.ImVec2(closePos.x+3*S,closePos.y+3*S),im.ImVec2(closePos.x+21*S,closePos.y+21*S),im.ImVec2(0,0),im.ImVec2(1,1),im.IsItemHovered()and palette.u32(im,'accent')or palette.u32(im,'muted'))end
        local server=self.server
        if spec then
            im.SetCursorPos(im.ImVec2(22*S,54*S));im.TextUnformatted(spec.label)
            im.SetCursorPos(im.ImVec2(22*S,82*S));im.TextDisabled('Runs once. The server checks access and requirements.')
            if spec.mode=='target' or spec.mode=='price'then
                im.SetCursorPos(im.ImVec2(22*S,112*S));im.TextUnformatted('Player name or ID')
                im.SetCursorPos(im.ImVec2(22*S,137*S));im.PushItemWidth(556*S);im.InputText('##jobTarget',self.query,65);im.PopItemWidth()
            end
            if spec.mode=='price' or spec.mode=='fare'then
                im.SetCursorPos(im.ImVec2(22*S,176*S));im.TextUnformatted(('Amount (%d–%d)'):format(spec.min,spec.max))
                im.SetCursorPos(im.ImVec2(22*S,202*S));im.PushItemWidth(556*S);im.InputText('##jobAmount',self.value,33);im.PopItemWidth()
            elseif spec.mode=='crate'then
                im.SetCursorPos(im.ImVec2(22*S,140*S));im.TextUnformatted('Choose crate contents')
                im.SetCursorPos(im.ImVec2(22*S,174*S));if im.Button('Pot##jobCrate')then im.StrCopy(self.value,'pot')end
                im.SetCursorPos(im.ImVec2(130*S,174*S));if im.Button('Crack##jobCrate')then im.StrCopy(self.value,'crack')end
                im.SetCursorPos(im.ImVec2(22*S,214*S));im.TextDisabled(ffi.string(self.value))
            end
            im.SetCursorPos(im.ImVec2(22*S,260*S));if im.Button('Run##jobSubmit',im.ImVec2(74*S,28*S))then
                self:submit('job',{id=spec.id,target=ffi.string(self.query),value=ffi.string(self.value)})
            end
            im.SetCursorPos(im.ImVec2(106*S,260*S));if im.Button('Back##jobBack',im.ImVec2(74*S,28*S))then self.jobAction=nil;self.notice=nil end
        elseif self.findMode then
            im.SetCursorPos(im.ImVec2(22*S,54*S));im.TextUnformatted('Find player')
            im.SetCursorPos(im.ImVec2(22*S,76*S))
            im.TextDisabled('Detective job required.')
            im.SetCursorPos(im.ImVec2(22*S,98*S));im.TextDisabled('Name or ID')
            im.SetCursorPos(im.ImVec2(22*S,118*S))
            im.PushItemWidth(556*S);im.InputText('##findTarget',self.query,65);im.PopItemWidth()
            im.SetCursorPos(im.ImVec2(22*S,154*S))
            if im.Button('Find##submitTarget',im.ImVec2(74*S,28*S))then self:submit('find',ffi.string(self.query))end
            im.SetCursorPos(im.ImVec2(106*S,154*S))
            if im.Button('Back##actions',im.ImVec2(74*S,28*S))then self.findMode=false;self.notice=nil end
            im.SetCursorPos(im.ImVec2(482*S,154*S))
            im.PushStyleColor(im.Col.Button,im.ImVec4(.12,.13,.15,1))
            im.PushStyleColor(im.Col.ButtonHovered,im.ImVec4(.18,.19,.22,1))
            im.PushStyleColor(im.Col.ButtonActive,im.ImVec4(.22,.23,.27,1))
            im.PushStyleColor(im.Col.Text,im.ImVec4(.72,.74,.78,1))
            local refresh=im.Button('Refresh##quickPlayers',im.ImVec2(96*S,28*S))
            im.PopStyleColor(4)
            if refresh then self.targets=self.players()end
            im.SetCursorPos(im.ImVec2(22*S,198*S))
            im.BeginChild('##quickTargets',im.ImVec2(556*S,130*S),false)
            local childOk,childErr=pcall(function()
            local query=require('horizonbase.logic').normalizeName(ffi.string(self.query))
            for _,row in ipairs(self.targets)do
                if tostring(row.id)==query or require('horizonbase.logic').normalizeName(row.name):find(query,1,true)then
                    if im.Button(row.name..' ('..row.id..')##quickTarget'..row.id)then self:submit('find',{id=row.id,name=row.name})end
                end
            end
            end)
            im.EndChild();if not childOk then error(childErr)end
        else
            im.SetCursorPos(im.ImVec2(22*S,56*S))
            im.TextUnformatted(server.clearNavigation and 'Clearing navigation...' or server.checkpoint and 'Checkpoint active' or 'No checkpoint received')
            im.SetCursorPos(im.ImVec2(22*S,76*S))
            im.TextDisabled(server.find.active and (server.find.paused and 'Waiting for ' or 'Finding ')..server.find.name or 'General actions and your current jobs')
            im.SetCursorPos(im.ImVec2(482*S,49*S))
            if im.Button('Refresh##quickJobs',im.ImVec2(96*S,28*S))then server:requestStats()end
            im.SetCursorPos(im.ImVec2(22*S,100*S));im.BeginChild('##quickActionGrid',im.ImVec2(556*S,gridHeight*S),false)
            local gridOk,gridErr=pcall(function()
                for _,section in ipairs(sections)do
                    im.SetCursorPos(im.ImVec2(0,section.y*S))
                    local pos=im.GetCursorScreenPos();local dl=im.GetWindowDrawList()
                    dl:AddTextFontPtr(im.GetFont(),14*S,pos,palette.u32(im,'accent'),section.title)
                    dl:AddLine(im.ImVec2(pos.x,pos.y+18*S),im.ImVec2(pos.x+556*S,pos.y+18*S),palette.u32(im,'border'),S)
                    for i,row in ipairs(section.rows)do
                        self:tile(row.label,row.hint,row.icon,((i-1)%2)*284,section.y+HEADER_HEIGHT+math.floor((i-1)/2)*ROW_STEP,272,S,function()
                        if row.find then
                            if server.find.active then self:submit('stopFind')else self.findMode=true;self.notice=nil;self.targets=self.players()end
                        elseif row.job then
                            if row.job.mode then self.jobAction=row.job.id;self.notice=nil;im.StrCopy(self.query,'');im.StrCopy(self.value,'')
                            else self:submit('job',{id=row.job.id})end
                        else self:submit(row.kind,row.arg)end
                    end)
                    end
                end
            end)
            im.EndChild();if not gridOk then error(gridErr)end
        end
        im.SetCursorPos(im.ImVec2(22*S,(detailMode and 340 or height-36)*S))
        if self.notice then im.TextWrapped(self.notice)else im.TextDisabled('Escape closes this panel.')end
    end)
    im.End();if not ok then error(err)end
end
return M
