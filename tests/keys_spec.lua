package.path='tests/?.lua;src/lib/?.lua;'..package.path
local Config=require 'horizonbase.config'
local Keys=require 'horizonbase.keys'
local p=Config.validate({keybinds={siren=83},custombinds={
    {name='Stats',command='/stats',key=83,mods=4},
    {name='Duplicate',command='/stats',key=83,mods=4},
    {name='Legacy',command='/help',key=65}}})
assert(p.custombinds[1].key==83 and p.custombinds[2].key==0 and p.custombinds[3].mods==0)
p.modifiers.settingsPanel=5
local r=Config.validate(Config.parse(Config.serialize(p)))
assert(r.custombinds[1].mods==4 and r.custombinds[1].key==83 and r.modifiers.settingsPanel==5)
assert(Config.keyConflict(r,83,nil,4)=='Stats')
assert(Config.keyConflict(r,83,nil,0)=='siren')
assert(not Config.keyConflict(r,83,nil,5))
print('PASS chord migration, persistence, and duplicate detection')
local sequence=Config.validate({custombinds={{name='Vehicle locks',command='/pvl',command2='/gvl',key=76,mods=2}}})
local round=Config.validate(Config.parse(Config.serialize(sequence)))
assert(round.custombinds[1].command=='/pvl' and round.custombinds[1].command2=='/gvl' and round.custombinds[1].mods==2)
assert(not Config.binding({command='/pvl',command2='/gvl\n/kill'},1),'Second commands cannot contain control characters')
assert(not Config.binding({command='/pvl',command2=123},1))
assert(Config.binding({command='/stats',command2=''},1).command2==nil)
assert(not p.custombinds[1].command2,'Legacy bindings must remain single commands')
print('PASS optional second-command persistence, validation and legacy single-command compatibility')
local migration=Config.validate({custombinds={{name='Existing U',command='/stats',key=85}}})
assert(migration.keybinds.quickActions==0 and migration.custombinds[1].key==85,'A new U default must not steal an existing binding')
assert(Config.validate({keybinds={siren=85}}).keybinds.quickActions==0)
assert(Config.validate({}).keybinds.quickActions==85)
assert(Config.validate(Config.parse(Config.serialize(migration))).keybinds.quickActions==0)
print('PASS Quick Actions default U migration preserves existing built-in/custom shortcuts')
local down={}
function isKeyDown(code)return down[code] or false end
function isKeyJustPressed(code)return code==83 end
assert(Keys.pressed(83,0));assert(not Keys.pressed(83,4))
down[165]=true;assert(Keys.modifiers()==4)
assert(Keys.pressed(83,4));assert(not Keys.pressed(83,0));assert(not Keys.pressed(83,5))
down[162]=true;assert(Keys.modifiers()==5)
assert(Keys.pressed(83,5));assert(not Keys.pressed(83,4))
print('PASS left/right modifiers and exact combos suppress plain-key actions')
local im=require 'fake_imgui'
package.preload.vkeys=function()return {id_to_name=function(id)return id==83 and 'VK_S' or 'Key '..id end}end
local ui=require('horizonbase.ui').new(im,r,function()end,function()end)
ui.capture={draft=true}
assert(ui:captureKey(18,500,4) and ui.capture)
assert(ui:captureKey(83,510,4) and not ui.capture)
assert(ui.draft.key==83 and ui.draft.mods==4 and ui:keyName(83,5)=='Ctrl + Alt + S')
ui.capture={custom=1};ui:captureKey(46,900,0)
assert(r.custombinds[1].key==0 and r.custombinds[1].mods==0)
ui.capture={section='keybinds',key='quickmap'};ui:captureKey(83,1000,5)
assert(r.keybinds.quickmap==83 and r.modifiers.quickmap==5)
ui.capture={section='keybinds',key='settingsPanel'};ui:captureKey(83,1500,5)
assert(r.keybinds.settingsPanel==120) -- Existing chord collision rejected.
print('PASS capture waits through modifiers, formats combo, unsets and rejects collisions')
