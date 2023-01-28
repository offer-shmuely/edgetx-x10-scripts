local M =  {}

--local m_log = require("./LogViewer/lib_log")

function M.tprint(t, s)
    for k, v in pairs(t) do
        local kfmt = '["' .. tostring(k) .. '"]'
        if type(k) ~= 'string' then
            kfmt = '[' .. k .. ']'
        end
        local vfmt = '"' .. tostring(v) .. '"'
        if type(v) == 'table' then
            M.tprint(v, (s or '') .. kfmt)
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
    m_log.info("-------------")
    m_log.info("table_print(%s)", prefix)
    for i = 1, #tbl, 1 do
        local val = tbl[i]
        if type(val) ~= "table" then
            m_log.info(string.format("%d. %s: %s", i, prefix, val))
        else
            local t_val = val
            m_log.info("-++++------------ %d %s", #val, type(t_val))
            for j = 1, #t_val, 1 do
                local val = t_val[j]
                 m_log.info(string.format("%d. %s: %s", i, prefix, val))
            end
        end
    end
    m_log.info("------------- table_print end")
end

function M.compare_file_names(a, b)
    a1 = string.sub(a.file_name, -21, -5)
    b1 = string.sub(b.file_name, -21, -5)
    --m_log.info("ab, %s ? %s", a, b)
    --m_log.info("a1b1, %s ? %s", a1, b1)
    return a1 > b1
end


function M.list_ordered_insert(lst, newVal, cmp, firstValAt)
    -- sort
    for i = firstValAt, #lst, 1 do
        -- remove duplication
        --m_log.info("list_ordered_insert - %s ? %s",  newVal, lst[i] )
        if newVal == lst[i] then
            --print_table("list_ordered_insert - duplicated", lst)
            return
        end

        if cmp(newVal, lst[i]) == true then
            table.insert(lst, i, newVal)
            --print_table("list_ordered_insert - inserted", lst)
            return
        end
        --print_table("list_ordered_insert-loop", lst)
    end
    table.insert(lst, newVal)
    --print_table("list_ordered_insert-inserted-to-end", lst)
end


return M
