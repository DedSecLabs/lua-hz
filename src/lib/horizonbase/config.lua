-- LuaHZ configuration and migration. No MoonLoader dependency in this module.
local M = {}

M.defaults = {
    settings = {stamina = true, oxygen = true, vdb = 1},
    quickmap = {gangzones = true, opacity = 100, rememberLocations = true, nativeLocations = true},
    togs = {repair = false, lawyer = false, whore = false, drugs = false, taxi = false,
            repairMax = 1, lawyerMax = 200, whoreMax = 1, drugsMax = 1},
    autofind = {cohort = false},
    keybinds = {settingsPanel = 120, quickmap = 77, siren = 74, reload = 82, characterStatus = 73,quickActions=85,vehicleMenu=75},
    cruisecontrol = {toggleKey = 88, preset1Key = 97, preset2Key = 98, preset3Key = 99,
                     preset1Speed = 50, preset2Speed = 80, preset3Speed = 120},
    fps = {onfoot = 0, invehicle = 0, swimming = 0, inboat = 0},
    interface = {scale = 100},
    appearance = {theme = 'graphite'},
    hud = {scale = 100, x = 100, y = 5},
    modifiers = {settingsPanel=0, quickmap=0, siren=0, reload=0, characterStatus=0,quickActions=0,vehicleMenu=0, toggleKey=0, preset1Key=0, preset2Key=0, preset3Key=0},
    custombinds = {},
}

function M.command(text)
    if type(text)~='string' or text:find('[%c]') then return nil end
    text=text:match('^%s*(.-)%s*$')
    if #text<2 or #text>144 or not text:match('^/[%w_]+') then return nil end
    return text
end

function M.modifier(value)
    value=tonumber(value) or 0
    if value~=value or math.abs(value)==math.huge then return 0 end
    return math.floor(math.max(0,math.min(15,value)))
end

function M.binding(raw,index)
    if type(raw)~='table' then return nil end
    local command=M.command(raw.command)
    if not command then return nil end
    local command2
    if raw.command2~=nil and raw.command2~='' then
        command2=M.command(raw.command2)
        if not command2 then return nil end
    end
    local name=type(raw.name)=='string' and raw.name:gsub('[%c]',''):match('^%s*(.-)%s*$') or ''
    local key=tonumber(raw.key) or 0
    if key~=key or math.abs(key)==math.huge then key=0 end
    return {name=(name~='' and name or 'Command '..index):sub(1,64),command=command,
        key=math.floor(math.max(0,math.min(255,key))), mods=M.modifier(raw.mods),command2=command2}
end

function M.keyConflict(prefs,key,exceptIndex,mods,exceptSection,exceptKey)
    if key==0 then return nil end
    mods=mods or 0
    for _,section in ipairs({'keybinds','cruisecontrol'}) do
        for name,value in pairs(prefs[section]) do
            if (section=='keybinds' or name:match('Key$')) and value==key and
                (prefs.modifiers[name] or 0)==mods and not (section==exceptSection and name==exceptKey) then return name end
        end
    end
    if mods==0 and (key==107 or key==109 or key==187 or key==189) then return 'Cruise adjustment' end
    if mods==0 and key==27 then return 'Close menu/map' end
    for i,binding in ipairs(prefs.custombinds) do
        if i~=exceptIndex and binding.key==key and (binding.mods or 0)==mods then return binding.name end
    end
end

function M.copy(t)
    local out = {}
    for k, v in pairs(t) do out[k] = type(v) == 'table' and M.copy(v) or v end
    return out
end

function M.parse(text)
    local out, section = {}, nil
    for line in (text .. '\n'):gmatch('(.-)\r?\n') do
        local heading = line:match('^%s*%[([^%]]+)%]%s*$')
        if heading then
            section = heading
            out[section] = out[section] or {}
        elseif section and not line:match('^%s*[;#]') then
            local k, v = line:match('^%s*([^=]+)%s*=%s*(.-)%s*$')
            if k then
                k = k:gsub('%s+$', '')
                if section:match('^custombind%d+$') and (k=='name' or k=='command' or k=='command2') then
                    -- Names such as "123" are text, not numeric preference values.
                elseif v == 'true' then v = true elseif v == 'false' then v = false
                else v = tonumber(v) or v end
                out[section][k] = v
            end
        end
    end
    return out
end

function M.validate(raw)
    local out = M.copy(M.defaults)
    for section, values in pairs(out) do
        for k, default in pairs(values) do
            local v = raw and raw[section] and raw[section][k]
            if type(v) == type(default) then
                if type(v) == 'number' and (v ~= v or math.abs(v) == math.huge) then v = default end
                out[section][k] = v
            end
        end
    end
    local function number(section, key, lo, hi)
        out[section][key] = math.floor(math.max(lo, math.min(hi, out[section][key])))
    end
    number('settings', 'vdb', 0, 2)
    number('quickmap', 'opacity', 0, 100)
    number('interface', 'scale', 80, 200)
    if out.appearance.theme~='graphite' and out.appearance.theme~='midnight' and out.appearance.theme~='carbon' then
        out.appearance.theme=M.defaults.appearance.theme
    end
    number('hud', 'scale', 50, 200)
    number('hud', 'x', 0, 100)
    number('hud', 'y', 0, 100)
    for k in pairs(out.keybinds) do number('keybinds', k, 0, 255) end
    for k in pairs(out.modifiers) do number('modifiers', k, 0, 15) end
    for k in pairs(out.cruisecontrol) do
        number('cruisecontrol', k, 0, k:match('Key$') and 255 or 200)
    end
    for k in pairs(out.togs) do if k:match('Max$') then number('togs', k, 0, 1000000) end end
    for k, v in pairs(out.fps) do
        out.fps[k] = v == 0 and 0 or math.floor(math.max(20, math.min(300, v)))
    end
    -- A new default must not steal an existing user's I binding during migration.
    if raw and not (raw.keybinds and raw.keybinds.characterStatus~=nil) then
        local conflict=false
        for _,section in ipairs({'keybinds','cruisecontrol'}) do
            for key,value in pairs(raw[section] or {}) do
                if (section=='keybinds' or key:match('Key$')) and value==73 and
                    ((raw.modifiers or {})[key] or 0)==0 then conflict=true end
            end
        end
        for i=1,20 do
            local item=(raw.custombinds and raw.custombinds[i]) or raw['custombind'..i]
            if type(item)=='table' and tonumber(item.key)==73 and M.modifier(item.mods)==0 then conflict=true end
        end
        if conflict then out.keybinds.characterStatus=0 end
    end
    if raw and not (raw.keybinds and raw.keybinds.quickActions~=nil) then
        local conflict=false
        for _,section in ipairs({'keybinds','cruisecontrol'})do
            for key,value in pairs(raw[section] or {})do
                if (section=='keybinds' or key:match('Key$')) and value==85 and ((raw.modifiers or {})[key]or 0)==0 then conflict=true end
            end
        end
        for i=1,20 do
            local item=(raw.custombinds and raw.custombinds[i]) or raw['custombind'..i]
            if type(item)=='table' and tonumber(item.key)==85 and M.modifier(item.mods)==0 then conflict=true end
        end
        if conflict then out.keybinds.quickActions=0 end
    end
    if raw and not (raw.keybinds and raw.keybinds.vehicleMenu~=nil) then
        local conflict=false
        for _,section in ipairs({'keybinds','cruisecontrol'})do
            for key,value in pairs(raw[section] or {})do
                if (section=='keybinds' or key:match('Key$')) and value==75 and ((raw.modifiers or {})[key]or 0)==0 then conflict=true end
            end
        end
        for i=1,20 do
            local item=(raw.custombinds and raw.custombinds[i]) or raw['custombind'..i]
            if type(item)=='table' and tonumber(item.key)==75 and M.modifier(item.mods)==0 then conflict=true end
        end
        if conflict then out.keybinds.vehicleMenu=0 end
    end
    for i=1,20 do
        local item=raw and ((raw.custombinds and raw.custombinds[i]) or raw['custombind'..i])
        local binding=M.binding(item,i)
        if binding then
            if M.keyConflict(out,binding.key,nil,binding.mods) then binding.key=0 end
            out.custombinds[#out.custombinds+1]=binding
        end
    end
    return out
end

function M.serialize(config)
    local lines = {'; LuaHZ preferences. 0 FPS = no additional cap.'}
    local sections = {}
    for k in pairs(M.defaults) do if k~='custombinds' then sections[#sections + 1] = k end end
    table.sort(sections)
    for _, section in ipairs(sections) do
        lines[#lines + 1] = '[' .. section .. ']'
        local keys = {}
        for k in pairs(M.defaults[section]) do keys[#keys + 1] = k end
        table.sort(keys)
        for _, k in ipairs(keys) do lines[#lines + 1] = k .. '=' .. tostring(config[section][k]) end
        lines[#lines + 1] = ''
    end
    for i,binding in ipairs(config.custombinds or {}) do
        lines[#lines+1]='[custombind'..i..']'
        lines[#lines+1]='name='..binding.name
        lines[#lines+1]='key='..binding.key
        lines[#lines+1]='mods='..(binding.mods or 0)
        lines[#lines+1]='command='..binding.command
        if binding.command2 then lines[#lines+1]='command2='..binding.command2 end
        lines[#lines+1]=''
    end
    return table.concat(lines, '\n')
end

function M.read(path)
    local f = io.open(path, 'r')
    if not f then return nil end
    local text = f:read('*a'); f:close()
    return M.parse(text)
end

function M.save(path, config)
    local f, err = io.open(path, 'w')
    if not f then return nil, err end
    local ok, why = f:write(M.serialize(M.validate(config)))
    local closed, closeErr = f:close()
    if not ok or not closed then return nil, why or closeErr end
    return true
end

return M
