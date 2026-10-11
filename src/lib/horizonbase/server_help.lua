-- The category-line layout already observed in Horizon /help. No command execution.
local logic=require 'horizonbase.logic'
local M={}
function M.row(text)
    if type(text)~='string' or #text>4096 then return end
    local clean=logic.strip(text):match('^%s*(.-)%s*$')
    local category,body=clean:match('^%*%*%* ([A-Z][A-Z /%-]+) %*%*%* (.+)$')
    if not category or #category>48 or #body>2048 or body:find('[%c{}]') or not body:find('/[%w_]+') then return end
    return {category=category,text=body}
end
return M
