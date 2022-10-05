local M =  {}

local m_log = require("./LogViewer/utils_log")

function M.split(text)
    local cnt = 0
    local result = {}
    for val in string.gmatch(string.gsub(text, ",,", ", ,"), "([^,]+),?") do
        cnt = cnt + 1
        result[cnt] = val
    end
    --m_log.log2("split: #col: %d (%s)", cnt, text)
    --m_log.log3("split: #col: %d (1-%s, 2-%s)", cnt, result[1], result[2])
    return result, cnt
end

function M.split_pipe(text)
    local cnt = 0
    local result = {}
    for val in string.gmatch(string.gsub(text, "||", "| |"), "([^|]+)|?") do
        cnt = cnt + 1
        result[cnt] = val
    end
    m_log.log2("split: #col: %d (%s)", cnt, text)
    m_log.log3("split: #col: %d (1-%s, 2-%s)", cnt, result[1], result[2])
    return result, cnt
end

-- remove trailing and leading whitespace from string.
-- http://en.wikipedia.org/wiki/Trim_(programming)
function M.trim(s)
    return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
    --string.gsub(text, ",,", ", ,")
end

return M
