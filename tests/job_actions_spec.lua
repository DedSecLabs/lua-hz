package.path='tests/?.lua;src/lib/?.lua;'..package.path
local Jobs=require 'horizonbase.job_actions'
local c={fields={Job='None [lvl: 0]',['Job 2']='None [lvl: 0]'}}
assert(#Jobs.list(c)==0 and not Jobs.has(c,'detective'))
c.fields.Job='Detective [lvl: 5]';c.fields['Job 2']='Car Mechanic [lvl: 2]'
assert(Jobs.has(c,'detective') and Jobs.has(c,'mechanic') and not Jobs.has(c,'lawyer'))
assert(Jobs.command(c,'fix')=='/fix' and Jobs.command(c,'cohort',18)=='/cohort 18')
assert(not Jobs.command(c,'guard',18,'200') and not Jobs.command(c,'cohort','18\n/deletecar'))
c.fields.Job='Bodyguard';c.fields['Job 2']='Taxi Driver'
assert(Jobs.command(c,'guard',18,'200')=='/guard 18 200')
assert(Jobs.command(c,'fare',nil,'50')=='/fare 50')
for _,value in ipairs({'0','1001','1e3','200\n/sellmycar','200.5','-200'})do assert(not Jobs.command(c,'guard',18,value))end
assert(not Jobs.command(c,'fare',nil,'51'))
c.fields.Job='Drug Smuggler';c.fields['Job 2']='None'
assert(Jobs.command(c,'getcrate',nil,'pot')=='/getcrate pot')
assert(Jobs.command(c,'getcrate',nil,'crack')=='/getcrate crack')
assert(not Jobs.command(c,'getcrate',nil,'pot /sellgun'))
c.fields.Job='Former Detective';assert(not Jobs.has(c,'detective'),'Job matching cannot use substring guesses')
c.fields.Job='Lawyer';assert(Jobs.command(c,'defend',18,'1000')=='/defend 18 1000')
c.fields.Job=nil;c.fields['Job 2']=nil;assert(not Jobs.command(c,'defend',18,'1000'),'A changed or unknown job must revoke actions')
print('PASS current primary/secondary jobs, aliases, no jobless inference, command allowlists and strict player/amount/option validation')
