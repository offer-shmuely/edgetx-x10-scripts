local M = {}

--function cache
--local math_floor = math.floor
--local math_fmod = math.fmod
local string_gmatch = string.gmatch
local string_gsub = string.gsub
local string_len = string.len

local m_log = require("./LogViewer/utils_log")
local m_utils = require("LogViewer/utils")

local function getTotalSeconds(time)
    local total = tonumber(string.sub(time, 1, 2)) * 3600
    total = total + tonumber(string.sub(time, 4, 5)) * 60
    total = total + tonumber(string.sub(time, 7, 8))
    return total
end

function M.getFileDataInfo(fileName)
    local hFile = io.open("/LOGS/" .. fileName, "r")
    if hFile == nil then
        return nil, nil, nil, nil, nil
    end

    local buffer = ""
    local start_time
    local end_time
    local total_lines = 0
    local start_index
    local col_with_data_str = ""

    local columns_by_header = {}
    local columns_is_have_data = {}
    local columns_with_data = {}

    -- read Header
    local data1 = io.read(hFile, 2048)
    local index = string.find(data1, "\n")
    if index == nil then
        m_log.log1("Header could not be found, file: %s", fileName)
        return nil, nil, nil, nil, nil, nil
    end

    -- get header line
    local headerLine = string.sub(data1, 1, index)
    m_log.log1("header-line: [%s]", headerLine)

    -- get columns
    columns_by_header = m_utils.split(headerLine)

    start_index = index
    io.seek(hFile, index)

    -- stop after 2M (1000x2028)
    local sample_col_data = nil
    for i = 1, 1000 do
        local data2 = io.read(hFile, 2048)


        -- file read done
        if data2 == "" then
            io.close(hFile)

            -- calculate data
            local first_time_sec = getTotalSeconds(start_time)
            local last_time_sec = getTotalSeconds(end_time)
            local total_seconds = last_time_sec - first_time_sec
            m_log.log3("getFileDataInfo: [%s] lines: %d, duration: %dsec", fileName, total_lines, total_seconds)

            --for idxCol = 1, #columns_by_header do
            --    local col_name = columns_by_header[idxCol]
            --    m_log.log2("getFileDataInfo %s: %s", col_name, columns_is_have_data[idxCol])
            --end

            for idxCol = 1, #columns_by_header do
                local col_name = columns_by_header[idxCol]
                col_name = string.gsub(col_name, "\n", "")
                --col_name = string.gsub(col_name, "\r", "")
                if columns_is_have_data[idxCol] == true and col_name ~= "Date" and col_name ~= "Time" then
                    columns_with_data[#columns_with_data+1] = col_name

                    if string.len(col_with_data_str) == 0 then
                        col_with_data_str = col_name
                    else
                        col_with_data_str = col_with_data_str .. "|" .. col_name
                    end
                end
            end

            m_log.log1("getFileDataInfo: col_with_data_str: %s", col_with_data_str)
            --for idxCol = 1, #columns_with_data do
            --    m_log.log2("getFileDataInfo@ %d: %s", idxCol, columns_with_data[idxCol])
            --end

            return start_time, end_time, total_seconds, total_lines, start_index, col_with_data_str
        end

        buffer = buffer .. data2
        local idx_buff = 0

        for line in string_gmatch(buffer, "([^\n]+)\n") do
            total_lines = total_lines + 1
            --m_log.log2("getFileDataInfo: %d. line: %s", total_lines, line)
            --m_log.log1("getFileDataInfo2: line: %d", total_lines)
            local time = string.sub(line, 12, 19)
            --m_log.log2("getFileDataInfo: %d. time: %s", total_lines, time)
            if start_time == nil then
                start_time = time
            end
            end_time = time

            -- find columns with data
            local vals = m_utils.split(line)
            if sample_col_data == nil then
                sample_col_data = vals
                for idxCol = 1, #columns_by_header, 1 do
                    columns_is_have_data[idxCol] = false
                end
            end

            for idxCol = 1, #columns_by_header, 1 do
                if vals[idxCol] ~= sample_col_data[idxCol] then
                    columns_is_have_data[idxCol] = true
                end
            end

            --local buf1 = ""
            --for idxCol = 1, #columns_by_header do
            --    buf1 = buf1 .. string.format("%s: %s\n", columns_by_header[idxCol], columns_with_data[idxCol])
            --end
            --m_log.log2("getFileDataInfo %s", buf1)

            idx_buff = idx_buff + string_len(line) + 1 -- dont forget the newline
        end

        buffer = string.sub(buffer, idx_buff + 1) -- dont forget the newline
    end

    io.close(hFile)
    --local first_time_sec = getTotalSeconds(start_time)
    --local last_time_sec = getTotalSeconds(end_time)
    --local total_seconds = last_time_sec - first_time_sec
    --m_log.log3("getFileDataInfo: [%s] early exit! lines: %d, duration: %dsec", fileName, total_lines, total_seconds)
    --return total_lines, total_seconds, col_with_data_str, start_time, end_time -- startIndex, endIndex

    m_log.log1("error: file too long, %s", fileName)
    return nil, nil, nil, nil, nil, nil
end


return M
