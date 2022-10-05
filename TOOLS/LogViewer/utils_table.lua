local M =  {}

local m_log = require("./LogViewer/utils_log")

function M.tprint(t, s)
    for k, v in pairs(t) do
        local kfmt = '["' .. tostring(k) .. '"]'
        if type(k) ~= 'string' then
            kfmt = '[' .. k .. ']'
        end
        local vfmt = '"' .. tostring(v) .. '"'
        if type(v) == 'table' then
            tprint(v, (s or '') .. kfmt)
        else
            if type(v) ~= 'string' then
                vfmt = tostring(v)
            end
            print(type(t) .. (s or '') .. kfmt .. ' = ' .. vfmt)
        end
    end
end

function M.table_clear(tbl)
    -- clean without creating a new list
    for i = 0, #tbl do
        table.remove(tbl, 1)
    end
end

function M.table_print(prefix, tbl)
    m_log.log("-------------")
    m_log.log1("table_print(%s)", prefix)
    for i = 1, #tbl, 1 do
        local val = tbl[i]
        if type(val) ~= "table" then
            m_log.log(string.format("%d. %s: %s", i, prefix, val))
        else
            local t_val = val
            m_log.log2("-++++------------ %d %s", #val, type(t_val))
            for j = 1, #t_val, 1 do
                local val = t_val[j]
                 m_log.log(string.format("%d. %s: %s", i, prefix, val))
            end
        end
    end
    m_log.log("------------- table_print end")
end

return M
