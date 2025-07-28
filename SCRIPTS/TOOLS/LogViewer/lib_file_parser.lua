local m_log, app_name, m_utils = ...

local M = {}
M.m_log = m_log
M.app_name = app_name
M.m_utils = m_utils

--function cache
local math_floor = math.floor
local math_fmod = math.fmod
local string_gmatch = string.gmatch
local string_gsub = string.gsub
local string_len = string.len
local string_sub = string.sub
local string_char = string.char
local string_byte = string.byte

function M.getTotalSeconds(time)
    local total = tonumber(string.sub(time, 1, 2)) * 3600
    total = total + tonumber(string.sub(time, 4, 5)) * 60
    total = total + tonumber(string.sub(time, 7, 8))
    return total
end

function M.getFileDataInfo(fileName)
    M.m_log.info("getFileDataInfo(%s)", fileName)

    --local t1_model =getTime()

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
    local all_col_str = ""

    local columns_by_header = {}
    local columns_is_have_data = {}
    local columns_with_data = {}
    
    -- check file size
    local max_log_size_MB = 2
    io.seek(hFile, max_log_size_MB * 1024 * 1024)
    local s = io.read(hFile, 2)
    io.seek(hFile,0)
    if string.len(s) > 0 then
        io.close(hFile)
        return nil, nil, nil, nil, nil, nil
    end

    -- read Header
    local data1 = io.read(hFile, 2048)
    local index = string.find(data1, "\n")
    if index == nil then
        M.m_log.info("Header could not be found, file: %s", fileName)
        return nil, nil, nil, nil, nil, nil
    end

    -- get header line
    local headerLine = string.sub(data1, 1, index)
    --M.m_log.info("header-line: [%s]", headerLine)

    -- get columns
    columns_by_header = M.m_utils.split(headerLine)

    start_index = index
    io.seek(hFile, index)

    -- stop after 2M (1000x2028)
    local sample_col_data = nil
    for i = 1, 50000 do
        --M.m_log.info("profiler: start")
        --local t1 =getTime()
        local data2 = io.read(hFile, 2048)
        --M.m_utils.timeProfilerAdd('read()', t1);

        -- file read done
        if data2 == "" then
            -- done reading file
            io.close(hFile)

            -- calculate data
            local first_time_sec = M.getTotalSeconds(start_time)
            local last_time_sec = M.getTotalSeconds(end_time)
            local total_seconds = last_time_sec - first_time_sec
            M.m_log.info("parser:getFileDataInfo: done - [%s] lines: %d, duration: %dsec", fileName, total_lines, total_seconds)

            --for idxCol = 1, #columns_by_header do
            --    local col_name = columns_by_header[idxCol]
            --    M.m_log.info("getFileDataInfo %s: %s", col_name, columns_is_have_data[idxCol])
            --end

            for idxCol = 1, #columns_by_header do
                local col_name = columns_by_header[idxCol]
                col_name = string_gsub(col_name, "\n", "")
                col_name = M.m_utils.trim_safe(col_name)
                if columns_is_have_data[idxCol] == true and col_name ~= "Date" and col_name ~= "Time" then
                    columns_with_data[#columns_with_data + 1] = col_name
                    if string_len(col_with_data_str) == 0 then
                        col_with_data_str = col_name
                    else
                        col_with_data_str = col_with_data_str .. "|" .. col_name
                    end
                end

                if string_len(all_col_str) == 0 then
                    all_col_str = col_name
                else
                    all_col_str = all_col_str .. "|" .. col_name
                end
            end

            --M.m_log.info("parser:getFileDataInfo: done - col_with_data_str: %s", col_with_data_str)
            --for idxCol = 1, #columns_with_data do
            --    M.m_log.info("getFileDataInfo@ %d: %s", idxCol, columns_with_data[idxCol])
            --end

            --M.m_utils.timeProfilerAdd(fileName, t1_model); -- total model parsing time
            --M.m_utils.timeProfilerShow(true)
            return start_time, end_time, total_seconds, total_lines, start_index, col_with_data_str, all_col_str
        end

        buffer = buffer .. data2
        local idx_buff = 0

        --M.m_utils.timeProfilerAdd('pre-line1');
        local line_list = string_gmatch(buffer, "([^\n]+)\n")
        --M.m_utils.timeProfilerAdd('pre-line2');
        for line in line_list do
            --local t2 =getTime()
            total_lines = total_lines + 1
            --M.m_log.info("getFileDataInfo: %d. line: %s", total_lines, line)
            --M.m_log.info("getFileDataInfo2: line: %d", total_lines)
            local time = string.sub(line, 12, 19)
            --M.m_log.info("getFileDataInfo: %d. time: %s", total_lines, time)
            if start_time == nil then
                start_time = time
            end
            end_time = time
            --M.m_utils.timeProfilerAdd('in-line1', t2);
            local vals = M.m_utils.split(line) -- hot
            --M.m_utils.timeProfilerAdd('in-line2b');

            -- find columns with data
            if sample_col_data == nil then
                sample_col_data = vals
                for idxCol = 1, #columns_by_header, 1 do
                    columns_is_have_data[idxCol] = false
                end
            end

            --M.m_utils.timeProfilerAdd('in-line3');
            for idxCol = 1, #columns_by_header, 1 do -- hot (whole loop)
                local curr_col = columns_by_header[idxCol]

                local have_data = vals[idxCol] ~= sample_col_data[idxCol]
                if have_data == true then
                    -- always ignore
                    if curr_col == "GPS"     then have_data = false end
                    if curr_col == "LSW"     then have_data = false end
                else
                    -- always show
                    if curr_col == "RQly(%)"  then have_data = true end
                    if curr_col == "TQly(%)"  then have_data = true end
                    if curr_col == "TPWR(mW)" then have_data = true end
                    if curr_col == "RSNR(dB)" then have_data = true end
                    if curr_col == "VFR(%)"   then have_data = true end
                end

                if have_data then
                    columns_is_have_data[idxCol] = true
                    --M.m_log.info("find-col-with-d: %s=true", columns_by_header[idxCol])
                --else
                --    M.m_log.info("find-col-with-d: %s =false (%s <> %s)", columns_by_header[idxCol], vals[idxCol] , sample_col_data[idxCol])
                end
            end
            --M.m_utils.timeProfilerAdd('in-line4');

            idx_buff = idx_buff + string.len(line) + 1 -- dont forget the newline
            --M.m_utils.timeProfilerAdd('im-line5');
        end

        buffer = string.sub(buffer, idx_buff + 1) -- dont forget the newline
        --M.m_utils.timeProfilerAdd('after-line1', t1);
    end

    io.close(hFile)

    M.m_log.info("error: file too long, %s", fileName)
    return nil, nil, nil, nil, nil, nil
end


return M
