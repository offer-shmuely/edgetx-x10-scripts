local toolName = "TNS|Log Viewer v1.7|TNE"

---- #########################################################################
---- #                                                                       #
---- # License GPLv3: https://www.gnu.org/licenses/gpl-3.0.html              #
---- #                                                                       #
---- # This program is free software; you can redistribute it and/or modify  #
---- # it under the terms of the GNU General Public License version 2 as     #
---- # published by the Free Software Foundation.                            #
---- #                                                                       #
---- # This program is distributed in the hope that it will be useful        #
---- # but WITHOUT ANY WARRANTY; without even the implied warranty of        #
---- # MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         #
---- # GNU General Public License for more details.                          #
---- #                                                                       #
---- #########################################################################

-- This script display a log file as a graph
-- Original Author: Herman Kruisman (RealTadango) (original version: https://raw.githubusercontent.com/RealTadango/FrSky/master/OpenTX/LView/LView.lua)
-- Current Author: Offer Shmuely
-- Date: 2022
-- ver: 1.5


-- to get help:
-- change to "ENABLE_LOG_FILE=true"
-- run the script again,
-- and send me the log file that will be created
-- /SCRIPTS/TOOLS/LogViewer/app.log
local ENABLE_LOG_FILE=false

local error_desc = nil


local m_log = {}
local m_log_parser = {}
local m_utils = {}
local m_tables = {}
local m_index_file = {}

--function cache
local math_floor = math.floor
local math_fmod = math.fmod
local string_gmatch = string.gmatch
local string_gsub = string.gsub
local string_len = string.len
local string_sub = string.sub
local string_char = string.char
local string_byte = string.byte

local heap = 2048
local hFile
local min_log_sec_to_show = 60

-- read_and_index_file_list()
local log_file_list_raw = {}
local log_file_list_raw_idx = -1

local log_file_list_filtered = {}
local filter_model_name
local filter_date
local model_name_list = { "-- all --" }
local date_list = { "-- all --" }
local accuracy_list = { "1/1 (read every line)", "1/2 (every 2nd line)", "1/5 (every 5th line)", "1/10 (every 10th line)" }
local ddLogFile = nil -- log-file dropDown object

local filename
local filename_idx = 1

local columns_by_header = {}
local columns_with_data = {}
local current_session = nil
local FIRST_VALID_COL = 2

-- state machine
local STATE = {
    INIT = 0,
    SELECT_FILE_INIT = 1,
    SELECT_FILE = 2,

    SELECT_SENSORS_INIT = 3,
    SELECT_SENSORS = 4,

    READ_FILE_DATA = 5,
    PARSE_DATA = 6,

    SHOW_GRAPH = 7
}

local state = STATE.INIT
--Graph data
local _values = {}
local _points = {}
local conversionSensorId = 0
local conversionSensorProgress = 0

--File reading data
local valPos = 0
local skipLines = 0
local lines = 0
local index = 0
local buffer = ""
--local prevTotalSeconds = 0

--Option data
--local maxLines
local current_option = 1

local sensorSelection = {
    { y = 80, label = "Field 1", values = {}, idx = 2, colId = 0, min = 0 },
    { y = 105, label = "Field 2", values = {}, idx = 3, colId = 0, min = 0 },
    { y = 130, label = "Field 3", values = {}, idx = 4, colId = 0, min = 0 },
    { y = 155, label = "Field 4", values = {}, idx = 1, colId = 0, min = 0 }
}

local graphConfig = {
    --x_start = 60,
    x_start = 0,
    --x_end = 420,
    x_end = LCD_W,
    y_start = 40,
    y_end = 240,
    { color = GREEN, valx = 20, valy = 249, minx = 5, miny = 220, maxx = 5, maxy = 30 },
    { color = RED, valx = 130, valy = 249, minx = 5, miny = 205, maxx = 5, maxy = 45 },
    { color = WHITE, valx = 250, valy = 249, minx = 5, miny = 190, maxx = 5, maxy = 60 },
    { color = BLUE, valx = 370, valy = 249, minx = 5, miny = 175, maxx = 5, maxy = 75 }
}

local xStep = (graphConfig.x_end - graphConfig.x_start) / 100

local cursor = 0

local GRAPH_MODE = {
    CURSOR = 0,
    ZOOM = 1,
    SCROLL = 2,
    GRAPH_MINMAX = 3
}
local graphMode = GRAPH_MODE.CURSOR
local graphStart = 0
local graphSize = 0
local graphTimeBase = 0
local graphMinMaxEditorIndex = 0

local img_bg1 = Bitmap.open("/SCRIPTS/TOOLS/LogViewer/bg1.png")
local img_bg2 = Bitmap.open("/SCRIPTS/TOOLS/LogViewer/bg2.png")

-- GUI library
--local libGUI = loadScript("/SCRIPTS/TOOLS/LogViewer/libgui.lua")()
local libGUI = nil



-- Instantiate a new GUI object
local ctx1 = nil
local ctx2 = nil



---- #########################################################################
---- ###########  m_log              #########################################
--region m_log
--local m_log = {}
m_log.log = {
    outfile = "/SCRIPTS/TOOLS/LogViewer/app.log",
    enable_file = ENABLE_LOG_FILE,
    level = "info",

    -- func
    trace = nil,
    debug = nil,
    info = nil,
    warn = nil,
    error = nil,
    fatal = nil,
}

m_log.levels = {
    trace = 1,
    debug = 2,
    info = 3,
    warn = 4,
    error = 5,
    fatal = 6
}

function m_log.round(x, increment)
    increment = increment or 1
    x = x / increment
    return (x > 0 and math.floor(x + .5) or math.ceil(x - .5)) * increment
end

m_log._tostring = m_log.tostring

function m_log.tostring(...)
    local t = {}
    for i = 1, select('#', ...) do
        local x = select(i, ...)
        if type(x) == "number" then
            x = m_log.round(x, .01)
        end
        t[#t + 1] = m_log._tostring(x)
    end
    return table.concat(t, " ")
end

function m_log.do_log(iLevel, ulevel, fmt, ...)
    if iLevel < m_log.levels[m_log.log.level] then
        --below the log level
        return
    end

    local num_arg = #{ ... }
    local msg
    if num_arg > 0 then
        msg = string.format(fmt, ...)
    else
        msg = fmt
    end

    local lineinfo = "f.lua:0"
    local msg2 = string.format("[%-4s] %s: %s", ulevel, lineinfo, msg)

    -- output to console
    print(msg2)

    -- Output to log file
    if m_log.log.enable_file == true and m_log.log.outfile then
        local fp = io.open(m_log.log.outfile, "a")
        io.write(fp, msg2 .. "\n")
        io.close(fp)
    end
end

function m_log.trace(fmt, ...)
    m_log.do_log(m_log.levels.trace, "TRACE", fmt, ...)
end
function m_log.debug(fmt, ...)
    m_log.do_log(m_log.levels.debug, "DEBUG", fmt, ...)
end
function m_log.info(fmt, ...)
    --print(fmt)
    m_log.do_log(m_log.levels.info, "INFO", fmt, ...)
end
function m_log.warn(fmt, ...)
    m_log.do_log(m_log.levels.warn, "WARN", fmt, ...)
end
function m_log.error(fmt, ...)
    m_log.do_log(m_log.levels.error, "ERROR", fmt, ...)
end
function m_log.fatal(fmt, ...)
    m_log.do_log(m_log.levels.fatal, "FATAL", fmt, ...)
end

--endregion


---- #########################################################################
---- ###########  m_utils              #########################################
--region m_utils

--local m_utils = {}
function m_utils.split(text)
    local cnt = 0
    local result = {}
    --for val in string.gmatch(string.gsub(text, ",,", ", ,"), "([^,]+),?") do
    for val in string_gmatch(string_gsub(text, ",,", ", ,"), "([^,]+),?") do
        cnt = cnt + 1
        result[cnt] = val
    end
    --m_log.info("split: #col: %d (%s)", cnt, text)
    --m_log.info("split: #col: %d (1-%s, 2-%s)", cnt, result[1], result[2])
    return result, cnt
end

function m_utils.split_pipe(text)
    -- m_log.info("split_pipe(%s)", text)
    local cnt = 0
    local result = {}
    for val in string.gmatch(string.gsub(text, "||", "| |"), "([^|]+)|?") do
        cnt = cnt + 1
        result[cnt] = val
    end
    m_log.info("split_pipe: #col: %d (%s)", cnt, text)
    m_log.info("split_pipe: #col: %d (1-%s, 2-%s)", cnt, result[1], result[2])
    return result, cnt
end

-- remove trailing and leading whitespace from string.
-- http://en.wikipedia.org/wiki/Trim_(programming)
function m_utils.trim(s)
    if s == nil then
        return nil
    end
    return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

function m_utils.trim_safe(s)
    if s == nil then
        return ""
    end
    return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
    --string.gsub(text, ",,", ", ,")
end

--endregion


---- #########################################################################
---- ###########  m_tables           #########################################
--region m_tables

--local m_tables =  {}

function m_tables.tprint(t, s)
    for k, v in pairs(t) do
        local kfmt = '["' .. tostring(k) .. '"]'
        if type(k) ~= 'string' then
            kfmt = '[' .. k .. ']'
        end
        local vfmt = '"' .. tostring(v) .. '"'
        if type(v) == 'table' then
            m_tables.tprint(v, (s or '') .. kfmt)
        else
            if type(v) ~= 'string' then
                vfmt = tostring(v)
            end
            print(type(t) .. (s or '') .. kfmt .. ' = ' .. vfmt)
        end
    end
end

function m_tables.table_clear(tbl)
    -- clean without creating a new list
    for i = 0, #tbl do
        table.remove(tbl, 1)
    end
end

function m_tables.table_print(prefix, tbl)
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

function m_tables.compare_file_names(a, b)
    a1 = string.sub(a.file_name, -21, -5)
    b1 = string.sub(b.file_name, -21, -5)
    --m_log.info("ab, %s ? %s", a, b)
    --m_log.info("a1b1, %s ? %s", a1, b1)
    return a1 > b1
end


function m_tables.list_ordered_insert(lst, newVal, cmp, firstValAt)
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

--endregion


---- #########################################################################
---- ###########  log_parser         #########################################
--region m_log_parser

--local m_log_parser = {}

function m_log_parser.getTotalSeconds(time)
    local total = tonumber(string.sub(time, 1, 2)) * 3600
    total = total + tonumber(string.sub(time, 4, 5)) * 60
    total = total + tonumber(string.sub(time, 7, 8))
    return total
end

function m_log_parser.getFileDataInfo(fileName)

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

    -- read Header
    local data1 = io.read(hFile, 2048)
    local index = string.find(data1, "\n")
    if index == nil then
        m_log.info("Header could not be found, file: %s", fileName)
        return nil, nil, nil, nil, nil, nil
    end

    -- get header line
    local headerLine = string.sub(data1, 1, index)
    m_log.info("header-line: [%s]", headerLine)

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
            -- done reading file
            io.close(hFile)

            -- calculate data
            local first_time_sec = m_log_parser.getTotalSeconds(start_time)
            local last_time_sec = m_log_parser.getTotalSeconds(end_time)
            local total_seconds = last_time_sec - first_time_sec
            m_log.info("parser:getFileDataInfo: done - [%s] lines: %d, duration: %dsec", fileName, total_lines, total_seconds)

            --for idxCol = 1, #columns_by_header do
            --    local col_name = columns_by_header[idxCol]
            --    m_log.info("getFileDataInfo %s: %s", col_name, columns_is_have_data[idxCol])
            --end

            for idxCol = 1, #columns_by_header do
                local col_name = columns_by_header[idxCol]
                col_name = string.gsub(col_name, "\n", "")
                col_name = m_utils.trim_safe(col_name)
                if columns_is_have_data[idxCol] == true and col_name ~= "Date" and col_name ~= "Time" then
                    columns_with_data[#columns_with_data + 1] = col_name
                    if string.len(col_with_data_str) == 0 then
                        col_with_data_str = col_name
                    else
                        col_with_data_str = col_with_data_str .. "|" .. col_name
                    end
                end

                if string.len(all_col_str) == 0 then
                    all_col_str = col_name
                else
                    all_col_str = all_col_str .. "|" .. col_name
                end

            end

            m_log.info("parser:getFileDataInfo: done - col_with_data_str: %s", col_with_data_str)
            --for idxCol = 1, #columns_with_data do
            --    m_log.info("getFileDataInfo@ %d: %s", idxCol, columns_with_data[idxCol])
            --end

            return start_time, end_time, total_seconds, total_lines, start_index, col_with_data_str, all_col_str
        end

        buffer = buffer .. data2
        local idx_buff = 0

        for line in string_gmatch(buffer, "([^\n]+)\n") do
            total_lines = total_lines + 1
            --m_log.info("getFileDataInfo: %d. line: %s", total_lines, line)
            --m_log.info("getFileDataInfo2: line: %d", total_lines)
            local time = string.sub(line, 12, 19)
            --m_log.info("getFileDataInfo: %d. time: %s", total_lines, time)
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
                --if ("Thr" == columns_by_header[idxCol]) then
                --    m_log.info("find-col-with-d: %d. %s, %s, %s", total_lines, columns_by_header[idxCol], vals[idxCol], sample_col_data[idxCol])
                --end

                local have_data = vals[idxCol] ~= sample_col_data[idxCol]

                -- always show
                if columns_by_header[idxCol] == "RQly(%)" then have_data = true end
                if columns_by_header[idxCol] == "TQly(%)" then have_data = true end
                if columns_by_header[idxCol] == "VFR(%)"  then have_data = true end

                -- always ignore
                if columns_by_header[idxCol] == "GPS"     then have_data = false end
                if columns_by_header[idxCol] == "LSW"     then have_data = false end

                if have_data then
                    columns_is_have_data[idxCol] = true
                    --if ("Thr" == columns_by_header[idxCol]) then
                    --    m_log.info("find-col-with-d: %s =true", columns_by_header[idxCol])
                    --end
                    --m_log.info("find-col-with-d: %s=true", columns_by_header[idxCol])
                end

            end

            --local buf1 = ""
            --for idxCol = 1, #columns_by_header do
            --    buf1 = buf1 .. string.format("%s: %s\n", columns_by_header[idxCol], columns_with_data[idxCol])
            --end
            --m_log.info("getFileDataInfo %s", buf1)

            idx_buff = idx_buff + string.len(line) + 1 -- dont forget the newline
        end

        buffer = string.sub(buffer, idx_buff + 1) -- dont forget the newline
    end

    io.close(hFile)

    m_log.info("error: file too long, %s", fileName)
    return nil, nil, nil, nil, nil, nil
end

--endregion


---- #########################################################################
---- ###########  index file         #########################################
--region m_index_file

--local m_index_file = {}
m_index_file.idx_file_name = "/LOGS/log-viewer.csv"
--m_index_fileidx_file_name = "/SCRIPTS/TOOLS/LogViewer/log-viewer.csv"
m_index_file.log_files_index_info = {}

function m_index_file.indexInit()
    m_tables.table_clear(m_index_file.log_files_index_info)
    --log_files_index_info = {}
end

function m_index_file.updateFile(file_name, start_time, end_time, total_seconds, total_lines, start_index, col_with_data_str, all_col_str)
    m_log.info("updateFile(%s)", file_name)

    local new_file = {
        file_name = m_utils.trim(file_name),
        start_time = m_utils.trim(start_time),
        end_time = m_utils.trim(end_time),
        total_seconds = tonumber(m_utils.trim(total_seconds)),
        total_lines = tonumber(m_utils.trim(total_lines)),
        start_index = tonumber(m_utils.trim(start_index)),
        col_with_data_str = m_utils.trim(col_with_data_str),
        all_col_str = m_utils.trim(all_col_str)
    }

    m_tables.list_ordered_insert(m_index_file.log_files_index_info, new_file, m_tables.compare_file_names, 1)
    --m_log.info("22222222222: %d - %s", #log_files_index_info, file_name)
end

function m_index_file.show(prefix)
    local tbl = m_index_file.log_files_index_info
    m_log.info("-------------show start (%s)", prefix)
    for i = 1, #tbl, 1 do
        local f_info = tbl[i]
        local s = string.format("%d. file_name:%s, start_time: %s, end_time: %s, total_seconds: %s, total_lines: %s, start_index: %s, col_with_data_str: [%s], all_col_str: [%s]", i,
            f_info.file_name,
            f_info.start_time,
            f_info.end_time,
            f_info.total_seconds,
            f_info.total_lines,
            f_info.start_index,
            f_info.col_with_data_str,
            f_info.all_col_str
        )

        m_log.info(s)
    end
    m_log.info("------------- show end")
end

function m_index_file.indexRead()
    m_log.info("indexRead()")
    m_tables.table_clear(m_index_file.log_files_index_info)
    local hFile = io.open(m_index_file.idx_file_name, "r")
    if hFile == nil then
        return
    end

    -- read Header
    local data1 = io.read(hFile, 2048)
    local index = string.find(data1, "\n")
    if index == nil then
        m_log.info("Index header could not be found, file: %s", m_index_file.idx_file_name)
        return
    end

    -- check that index file is correct version
    local api_ver = string.match(data1, "# api_ver=(%d*)")
    m_log.info("api_ver: %s", api_ver)
    if api_ver ~= "3" then
        m_log.info("api_ver of index files is not updated (api_ver=%d)", api_ver)
        return
    end

    -- get header line
    local headerLine = string.sub(data1, 1, index)
    m_log.info("indexRead: header: %s", headerLine)

    io.seek(hFile, index)
    local data2 = io.read(hFile, 2048 * 32)

    --m_index_file.show("indexRead-should-be-empty")
    for line in string.gmatch(data2, "([^\n]+)\n") do

        if string.sub(line, 1, 1) ~= "#" then
            m_log.info("indexRead: index-line: %s", line)
            local values = m_utils.split(line)

            local file_name = m_utils.trim(values[1])
            local start_time = m_utils.trim(values[2])
            local end_time = m_utils.trim(values[3])
            local total_seconds = m_utils.trim(values[4])
            local total_lines = m_utils.trim(values[5])
            local start_index = m_utils.trim(values[6])
            local col_with_data_str = m_utils.trim_safe(values[7])
            local all_col_str = m_utils.trim_safe(values[8])
            --m_log.info(string.format("indexRead: got: file_name: %s, start_time: %s, end_time: %s, total_seconds: %s, total_lines: %s, start_index: %s, col_with_data_str: %s, all_col_str: %s", file_name, start_time, end_time, total_seconds, total_lines, start_index, col_with_data_str, all_col_str))
            m_index_file.updateFile(file_name, start_time, end_time, total_seconds, total_lines, start_index, col_with_data_str, all_col_str)
        end
    end

    io.close(hFile)
    --m_index_file.show("indexRead-should-with-data")
end

function m_index_file.getFileDataInfo(file_name)
    m_log.info("getFileDataInfo(%s)", file_name)
    --m_index_file.show("getFileDataInfo-start")

    for i = 1, #m_index_file.log_files_index_info do
        local f_info = m_index_file.log_files_index_info[i]
        --m_log.info("getFileDataInfo: %s ?= %s", file_name, f_info.file_name)
        if file_name == f_info.file_name then
            m_log.info("getFileDataInfo: info from cache %s", file_name)
            return false, f_info.start_time, f_info.end_time, f_info.total_seconds, f_info.total_lines, f_info.start_index, f_info.col_with_data_str, f_info.all_col_str
        end
    end

    m_log.info("getFileDataInfo: file not in index, indexing... %s", file_name)

    local start_time, end_time, total_seconds, total_lines, start_index, col_with_data_str, all_col_str = m_log_parser.getFileDataInfo(file_name)

    if start_time == nil then
        return false, nil, nil, nil, nil, nil, nil, nil
    end

    m_index_file.updateFile(
        file_name,
        start_time, end_time, total_seconds,
        total_lines,
        start_index,
        col_with_data_str,
        all_col_str)

    m_index_file.indexSave()
    return true, start_time, end_time, total_seconds, total_lines, start_index, col_with_data_str, all_col_str
end

function m_index_file.indexSave()
    m_log.info("indexSave()")
    --local is_exist = is_file_exists(idx_file_name)
    local hFile = io.open(m_index_file.idx_file_name, "w")

    -- header
    local line_format = "%-42s,%-10s,%-10s,%-13s,%-11s,%-11s,%s,   %s\n"
    local headline = string.format(line_format, "file_name", "start_time", "end_time", "total_seconds", "total_lines", "start_index", "col_with_data_str", "all_col_str")
    io.write(hFile, headline)
    local ver_line = "# api_ver=3\n"
    io.write(hFile, ver_line)

    --m_index_file.show("log_files_index_info")
    m_log.info("#log_files_index_info: %d", #m_index_file.log_files_index_info)
    for i = 1, #m_index_file.log_files_index_info, 1 do
        local info = m_index_file.log_files_index_info[i]

        local line = string.format(line_format,
            info.file_name,
            info.start_time,
            info.end_time,
            info.total_seconds,
            info.total_lines,
            info.start_index,
            info.col_with_data_str,
            info.all_col_str)

        io.write(hFile, line)
    end

    io.close(hFile)
end

--endregion

---- #########################################################################


local function doubleDigits(value)
    if value < 10 then
        return "0" .. value
    else
        return value
    end
end

local function toDuration1(totalSeconds)
    local hours = math_floor(totalSeconds / 3600)
    totalSeconds = totalSeconds - (hours * 3600)
    local minutes = math_floor(totalSeconds / 60)
    local seconds = totalSeconds - (minutes * 60)

    return doubleDigits(hours) .. ":" .. doubleDigits(minutes) .. ":" .. doubleDigits(seconds);
end

local function toDuration2(totalSeconds)
    local minutes = math_floor(totalSeconds / 60)
    local seconds = totalSeconds - (minutes * 60)

    return doubleDigits(minutes) .. "." .. doubleDigits(seconds) .. "min";
end

local function getTotalSeconds(time)
    local total = tonumber(string.sub(time, 1, 2)) * 3600
    total = total + tonumber(string.sub(time, 4, 5)) * 60
    total = total + tonumber(string.sub(time, 7, 8))
    return total
end

local function collectData()
    if hFile == nil then
        buffer = ""
        hFile = io.open("/LOGS/" .. filename, "r")
        io.seek(hFile, current_session.startIndex)
        index = current_session.startIndex

        valPos = 0
        lines = 0
        m_log.info(string.format("current_session.total_lines: %d", current_session.total_lines))

        _points = {}
        _values = {}

        for varIndex = 1, 4, 1 do
            if sensorSelection[varIndex].idx >= FIRST_VALID_COL then
                _points[varIndex] = {}
                _values[varIndex] = {}
            end
        end
    end

    local read = io.read(hFile, heap)
    if read == "" then
        io.close(hFile)
        hFile = nil
        return true
    end

    buffer = buffer .. read
    local i = 0

    for line in string_gmatch(buffer, "([^\n]+)\n") do
        if math.fmod(lines, skipLines) == 0 then
            local vals = m_utils.split(line)
            --m_log.info(string.format("collectData: 1: %s, 2: %s, 3: %s, 4: %s, line: %s", vals[1], vals[2], vals[3], vals[4], line))

            for varIndex = 1, 4, 1 do
                if sensorSelection[varIndex].idx >= FIRST_VALID_COL then
                    local colId = sensorSelection[varIndex].colId
                    --m_log.info(string.format("collectData: varIndex: %d, sensorSelectionId: %d, colId: %d, val: %d", varIndex, sensorSelection[varIndex].colId, colId, vals[colId]))
                    _values[varIndex][valPos] = vals[colId]
                end
            end

            valPos = valPos + 1
        end

        lines = lines + 1

        if lines > current_session.total_lines then
            io.close(hFile)
            hFile = nil
            return true
        end

        i = i + string.len(line) + 1 --dont forget the newline ;)
    end

    buffer = string.sub(buffer, i + 1) --dont forget the newline ;
    index = index + heap
    io.seek(hFile, index)
    return false
end

-- ---------------------------------------------------------------------------------------------------------

local function compare_dates(a, b)
    return a > b
end

local function compare_names(a, b)
    return a < b
end

local function drawProgress(y, current, total)
    --m_log.info(string.format("drawProgress(%d. %d, %d)", y, current, total))
    local x = 140
    local pct = current / total
    lcd.drawFilledRectangle(x + 1, y + 1, (470 - x - 2) * pct, 14, TEXT_INVERTED_BGCOLOR)
    lcd.drawRectangle(x, y, 470 - x, 16, TEXT_COLOR)
end

-- read log file list
local function read_and_index_file_list()

    --m_log.info("read_and_index_file_list(%d, %d)", log_file_list_raw_idx, #log_file_list_raw)

    if (#log_file_list_raw == 0) then
        m_log.info("read_and_index_file_list: init")
        m_index_file.indexInit()
        --log_file_list_raw = dir("/LOGS")
        log_file_list_raw_idx = 0
        for fn in dir("/LOGS") do
            --print_table("log_file_list_raw", log_file_list_raw)
            m_log.info("fn: %s", fn)
            log_file_list_raw[log_file_list_raw_idx + 1] = fn
            log_file_list_raw_idx = log_file_list_raw_idx + 1
        end
        log_file_list_raw_idx = 0
        --m_tables.table_print("log_file_list_raw", log_file_list_raw)
        m_index_file.indexRead()
    end

    for i = 1, 10, 1 do
        log_file_list_raw_idx = log_file_list_raw_idx + 1
        local fileName = log_file_list_raw[log_file_list_raw_idx]
        if fileName ~= nil then
            lcd.clear()
            lcd.drawText(5, 30, "Analyzing & indexing files", TEXT_COLOR + BOLD)
            lcd.drawText(5, 60, string.format("indexing files: (%d/%d)", log_file_list_raw_idx, #log_file_list_raw), TEXT_COLOR + SMLSIZE)
            drawProgress(60, log_file_list_raw_idx, #log_file_list_raw)

            m_log.info("log file: (%d/%d) %s (detecting...)", log_file_list_raw_idx, #log_file_list_raw, fileName)

            local modelName, year, month, day, hour, min, sec, m, d, y = string.match(fileName, "^(.*)-(%d+)-(%d+)-(%d+)-(%d%d)(%d%d)(%d%d).csv$")
            if modelName == nil then
                goto continue
            end
            --m_log.info("log file: %s (is csv)", fileName)
            local model_day = string.format("%s-%s-%s", year, month, day)

            -- read file
            local is_new, start_time, end_time, total_seconds, total_lines, start_index, col_with_data_str, all_col_str = m_index_file.getFileDataInfo(fileName)

            --m_log.info("read_and_index_file_list: total_lines: %s, total_seconds: %s, col_with_data_str: [%s], all_col_str: [%s]", total_lines, total_seconds, col_with_data_str, all_col_str)
            m_log.info("read_and_index_file_list: total_seconds: %s", total_seconds)
            m_tables.list_ordered_insert(model_name_list, modelName, compare_names, 2)
            m_tables.list_ordered_insert(date_list, model_day, compare_dates, 2)

            -- due to cpu load, early exit
            if is_new then
                return false
            end
        end

        if log_file_list_raw_idx >= #log_file_list_raw then
            return true
        end
        :: continue ::
    end

    return false

end

local function onLogFileChange(obj)
    --m_tables.table_print("log_file_list_filtered", log_file_list_filtered)

    local i = obj.selected
    -- Todo: maybe the i is grater then num of fields when paging backward
    --labelDropDown.title = "Selected switch: " .. dropDownItems[i] .. " [" .. dropDownIndices[i] .. "]"
    m_log.info("Selected switch: " .. i)
    m_log.info("Selected switch: " .. log_file_list_filtered[i])
    filename = log_file_list_filtered[i]
    filename = log_file_list_filtered[i]
    filename_idx = i
    m_log.info("filename: " .. filename)
end

local function onAccuracyChange(obj)
    local i = obj.selected
    accuracy = i
    m_log.info("Selected accuracy: %s (%d)", accuracy_list[i], i)

    if accuracy == 4 then
        skipLines = 10
        heap = 2048 * 16
    elseif accuracy == 3 then
        skipLines = 5
        heap = 2048 * 16
    elseif accuracy == 2 then
        skipLines = 2
        heap = 2048 * 8
    else
        skipLines = 1
        heap = 2048 * 4
    end
end

local function filter_log_file_list(filter_model_name, filter_date, need_update)
    m_log.info("need to filter by: [%s] [%s]", filter_model_name, filter_date)

    m_tables.table_clear(log_file_list_filtered)

    for i = 1, #m_index_file.log_files_index_info do
        local log_file_info = m_index_file.log_files_index_info[i]

        --m_log.info("filter_log_file_list: %d. %s", i, log_file_info.file_name)

        local modelName, year, month, day, hour, min, sec, m, d, y = string.match(log_file_info.file_name, "^(.*)-(%d+)-(%d+)-(%d+)-(%d%d)(%d%d)(%d%d).csv$")

        local is_model_name_ok
        if filter_model_name == nil or string.sub(filter_model_name, 1, 2) == "--" then
            is_model_name_ok = true
        else
            is_model_name_ok = (modelName == filter_model_name)
        end

        local is_date_ok
        if filter_date == nil or string.sub(filter_date, 1, 2) == "--" then
            is_date_ok = true
        else
            local model_day = string.format("%s-%s-%s", year, month, day)
            is_date_ok = (model_day == filter_date)
        end

        local is_duration_ok = true
        if log_file_info.total_seconds < min_log_sec_to_show then
            is_duration_ok = false
        end

        local is_have_data_ok = true
        if log_file_info.col_with_data_str == nil or log_file_info.col_with_data_str == "" then
            is_have_data_ok = false
        end

        if is_model_name_ok and is_date_ok and is_duration_ok and is_have_data_ok then
            m_log.info("filter_log_file_list: [%s] - OK (%s,%s)", log_file_info.file_name, filter_model_name, filter_date)
            table.insert(log_file_list_filtered, log_file_info.file_name)
        else
            m_log.info("filter_log_file_list: [%s] - FILTERED-OUT (filters:%s,%s) (model_name_ok:%s,date_ok:%s,duration_ok:%s,have_data_ok:%s)", log_file_info.file_name, filter_model_name, filter_date, is_model_name_ok, is_date_ok, is_duration_ok, is_have_data_ok)
        end

    end

    if #log_file_list_filtered == 0 then
        table.insert(log_file_list_filtered, "not found")
    end
    m_tables.table_print("filter_log_file_list", log_file_list_filtered)

    -- update the log combo to first
    if need_update == true then
        onLogFileChange(ddLogFile)
        ddLogFile.selected = 1
    end
end

local function stop_on_fail(new_error_desc)
    error_desc = new_error_desc
    print(error_desc)

    lcd.clear()
    lcd.drawText(5, 30, "Error:", TEXT_COLOR + BOLD)
    lcd.drawText(5, 60, error_desc, TEXT_COLOR + BOLD)
    m_log.info("after assert")

    return 0
end

local function state_INIT(event, touchState)
    -- skip if already in error mode
    if error_desc ~= nil then
        print(".")
        return stop_on_fail(error_desc)
    end

    -- validate bg1
    local w, h = Bitmap.getSize(img_bg1)
    if w == 0 and h == 0  then
        return stop_on_fail("File not found: /SCRIPTS/TOOLS/LogViewer/bg1.png")
    end

    -- validate bg2
    w, h = Bitmap.getSize(img_bg2)
    if w == 0 and h == 0 then
        return stop_on_fail("File not found: /SCRIPTS/TOOLS/LogViewer/bg2.png")
    end

    -- validate libgui exist
    local libGUI_chunk = loadScript("/SCRIPTS/TOOLS/LogViewer/libgui.lua")
    print("222")
    if libGUI_chunk == nil then
        return stop_on_fail("File not found: /SCRIPTS/TOOLS/LogViewer/libgui.lua")
    end

    -- validate libgui version
    libGUI = libGUI_chunk()
    local lib_gui_ver_func = libGUI.getVer
    if lib_gui_ver_func == nil then
        return stop_on_fail("incorrect version of file:\n /SCRIPTS/TOOLS/LogViewer/libgui.lua")
    end

    local lib_gui_ver = libGUI.getVer()
    print("lib_gui_Ver: " .. lib_gui_ver)
    if lib_gui_ver ~= "1.0.1" then
        return stop_on_fail("incorrect version of file:\n /SCRIPTS/TOOLS/LogViewer/libgui.lua (" .. lib_gui_ver .. " <> 1.0.1)")
    end


    -- start init
    local is_done = read_and_index_file_list()

    if (is_done == true) then
        state = STATE.SELECT_FILE_INIT
    end

    return 0
end

local function state_SELECT_FILE_init(event, touchState)
    m_tables.table_clear(log_file_list_filtered)
    filter_log_file_list(nil, nil, false)

    m_log.info("++++++++++++++++++++++++++++++++")
    if ctx1 == nil then
        -- creating new window gui
        m_log.info("creating new window gui")
        ctx1 = libGUI.newGUI()

        ctx1.label(10, 25, 120, 24, "log file...", BOLD)

        m_log.info("setting model filter...")
        ctx1.label(10, 55, 60, 24, "Model")
        ctx1.dropDown(90, 55, 380, 24, model_name_list, 1,
            function(obj)
                local i = obj.selected
                filter_model_name = model_name_list[i]
                m_log.info("Selected model-name: " .. filter_model_name)
                filter_log_file_list(filter_model_name, filter_date, true)
            end
        )

        m_log.info("setting date filter...")
        ctx1.label(10, 80, 60, 24, "Date")
        ctx1.dropDown(90, 80, 380, 24, date_list, 1,
            function(obj)
                local i = obj.selected
                filter_date = date_list[i]
                m_log.info("Selected filter_date: " .. filter_date)
                filter_log_file_list(filter_model_name, filter_date, true)
            end
        )

        m_log.info("setting file combo...")
        ctx1.label(10, 105, 60, 24, "Log file")
        ddLogFile = ctx1.dropDown(90, 105, 380, 24, log_file_list_filtered, filename_idx,
            onLogFileChange
        )
        onLogFileChange(ddLogFile)

        ctx1.label(10, 130, 60, 24, "Accuracy")
        dd4 = ctx1.dropDown(90, 130, 380, 24, accuracy_list, 1, onAccuracyChange)
        onAccuracyChange(dd4)

    end

    state = STATE.SELECT_FILE
    return 0
end

local function colWithData2ColByHeader(colWithDataId)
    local sensorName = columns_with_data[colWithDataId]
    local colByHeaderId = 0

    m_log.info("colWithData2ColByHeader: byData     - idx: %d, name: %s", colWithDataId, sensorName)

    for i = 1, #columns_by_header do
        if columns_by_header[i] == sensorName then
            colByHeaderId = i
            m_log.info("colWithData2ColByHeader: byHeader - colId: %d, name: %s", colByHeaderId, columns_by_header[colByHeaderId])
            return colByHeaderId
        end
    end

    return -1
end

local function state_SELECT_SENSORS_INIT(event, touchState)
    m_log.info("state_SELECT_SENSORS_INIT")
    m_tables.table_print("sensors-init columns", columns_with_data)
    for varIndex = 1, 4, 1 do
        sensorSelection[varIndex].values[0] = "---"
        for i = 2, #columns_with_data, 1 do
            sensorSelection[varIndex].values[i - 1] = columns_with_data[i]
        end
        m_tables.table_print("sensors-init sensorSelection", sensorSelection[varIndex].values)
    end

    current_option = 1

    if ctx2 == nil then
        -- creating new window gui
        m_log.info("creating new window gui")
        ctx2 = libGUI.newGUI()

        ctx2.label(10, 25, 120, 24, "Select sensors...", BOLD)

        m_log.info("setting field1...")
        ctx2.label(10, 55, 60, 24, "Field 1")
        ctx2.dropDown(90, 55, 380, 24, columns_with_data, sensorSelection[1].idx,
            function(obj)
                local i = obj.selected
                local var1 = columns_with_data[i]
                m_log.info("Selected var1: " .. var1)
                sensorSelection[1].idx = i
                sensorSelection[1].colId = colWithData2ColByHeader(i)
            end
        )

        ctx2.label(10, 80, 60, 24, "Field 2")
        ctx2.dropDown(90, 80, 380, 24, columns_with_data, sensorSelection[2].idx,
            function(obj)
                local i = obj.selected
                local var2 = columns_with_data[i]
                m_log.info("Selected var2: " .. var2)
                sensorSelection[2].idx = i
                sensorSelection[2].colId = colWithData2ColByHeader(i)
            end
        )

        ctx2.label(10, 105, 60, 24, "Field 3")
        ctx2.dropDown(90, 105, 380, 24, columns_with_data, sensorSelection[3].idx,
            function(obj)
                local i = obj.selected
                local var3 = columns_with_data[i]
                m_log.info("Selected var3: " .. var3)
                sensorSelection[3].idx = i
                sensorSelection[3].colId = colWithData2ColByHeader(i)
            end
        )

        ctx2.label(10, 130, 60, 24, "Field 4")
        ctx2.dropDown(90, 130, 380, 24, columns_with_data, sensorSelection[4].idx,
            function(obj)
                local i = obj.selected
                local var4 = columns_with_data[i]
                m_log.info("Selected var4: " .. var4)
                sensorSelection[4].idx = i
                sensorSelection[4].colId = colWithData2ColByHeader(i)
            end
        )

        sensorSelection[1].colId = colWithData2ColByHeader(sensorSelection[1].idx)
        sensorSelection[2].colId = colWithData2ColByHeader(sensorSelection[2].idx)
        sensorSelection[3].colId = colWithData2ColByHeader(sensorSelection[3].idx)
        sensorSelection[4].colId = colWithData2ColByHeader(sensorSelection[4].idx)

    end

    state = STATE.SELECT_SENSORS
    return 0
end

local function state_SELECT_FILE_refresh(event, touchState)
    -- ## file selected
    if event == EVT_VIRTUAL_NEXT_PAGE then
        m_log.info("state_SELECT_FILE_refresh --> EVT_VIRTUAL_NEXT_PAGE: filename: %s", filename)
        if filename == "not found" then
            m_log.warn("state_SELECT_FILE_refresh: trying to next-page, but no logfile available, ignoring.")
            return 0
        end

        --Reset file load data
        m_log.info("Reset file load data")
        buffer = ""
        lines = 0
        heap = 2048 * 12
        --prevTotalSeconds = 0

        local is_new, start_time, end_time, total_seconds, total_lines, start_index, col_with_data_str, all_col_str = m_index_file.getFileDataInfo(filename)

        current_session = {
            startTime = start_time,
            endTime = end_time,
            total_seconds = total_seconds,
            total_lines = total_lines,
            startIndex = start_index,
            col_with_data_str = col_with_data_str,
            all_col_str = all_col_str
        }

        -- update columns
        local columns_temp, cnt = m_utils.split_pipe(col_with_data_str)
        m_log.info("state_SELECT_FILE_refresh: #col: %d", cnt)
        m_tables.table_clear(columns_with_data)
        columns_with_data[1] = "---"
        for i = 1, #columns_temp, 1 do
            local col = columns_temp[i]
            columns_with_data[#columns_with_data + 1] = col
            --m_log.info("state_SELECT_FILE_refresh: col: %s", col)
        end

        local columns_temp, cnt = m_utils.split_pipe(all_col_str)
        m_log.info("state_SELECT_FILE_refresh: #col: %d", cnt)
        m_tables.table_clear(columns_by_header)
        for i = 1, #columns_temp, 1 do
            local col = columns_temp[i]
            columns_by_header[#columns_by_header + 1] = col
            -- m_log.info("state_SELECT_FILE_refresh: col: %s", col)
        end

        state = STATE.SELECT_SENSORS_INIT
        return 0
    end

    -- --color test
    --local dx = 250
    --local dy = 50
    --lcd.drawText(dx, dy, "COLOR_THEME_PRIMARY1", COLOR_THEME_PRIMARY1)
    --dy = dy +20
    --lcd.drawText(dx, dy, "COLOR_THEME_PRIMARY2", COLOR_THEME_PRIMARY2)
    --dy = dy +20
    --lcd.drawText(dx, dy, "COLOR_THEME_PRIMARY3", COLOR_THEME_PRIMARY3)
    --dy = dy +20
    --lcd.drawText(dx, dy, "COLOR_THEME_SECONDARY1", COLOR_THEME_SECONDARY1)
    --dy = dy +20
    --lcd.drawText(dx, dy, "COLOR_THEME_SECONDARY2", COLOR_THEME_SECONDARY2)
    --dy = dy +20
    --lcd.drawText(dx, dy, "COLOR_THEME_SECONDARY3", COLOR_THEME_SECONDARY3)
    --dy = dy +20
    --lcd.drawText(dx, dy, "COLOR_THEME_FOCUS", COLOR_THEME_FOCUS)
    --dy = dy +20
    --lcd.drawText(dx, dy, "COLOR_THEME_EDIT", COLOR_THEME_EDIT)
    --dy = dy +20
    --lcd.drawText(dx, dy, "COLOR_THEME_ACTIVE", COLOR_THEME_ACTIVE)
    --dy = dy +20
    --lcd.drawText(dx, dy, "COLOR_THEME_WARNING", COLOR_THEME_WARNING)
    --dy = dy +20
    --lcd.drawText(dx, dy, "COLOR_THEME_DISABLED", COLOR_THEME_DISABLED)

    ctx1.run(event, touchState)

    return 0
end

local function state_SELECT_SENSORS_refresh(event, touchState)
    if event == EVT_VIRTUAL_EXIT or event == EVT_VIRTUAL_PREV_PAGE then
        state = STATE.SELECT_FILE_INIT
        return 0

    elseif event == EVT_VIRTUAL_NEXT_PAGE then
        state = STATE.READ_FILE_DATA
        return 0
    end

    ctx2.run(event, touchState)

    return 0
end

local function display_read_data_progress(conversionSensorId, conversionSensorProgress)
    --m_log.info("display_read_data_progress(%d, %d)", conversionSensorId, conversionSensorProgress)
    lcd.drawText(5, 25, "Reading data from file...", TEXT_COLOR)

    lcd.drawText(5, 60, "Reading line: " .. lines, TEXT_COLOR)
    drawProgress(60, lines, current_session.total_lines)

    local done_var_1 = 0
    local done_var_2 = 0
    local done_var_3 = 0
    local done_var_4 = 0
    if conversionSensorId == 1 then
        done_var_1 = conversionSensorProgress
    end
    if conversionSensorId == 2 then
        done_var_1 = valPos
        done_var_2 = conversionSensorProgress
    end
    if conversionSensorId == 3 then
        done_var_1 = valPos
        done_var_2 = valPos
        done_var_3 = conversionSensorProgress
    end
    if conversionSensorId == 4 then
        done_var_1 = valPos
        done_var_2 = valPos
        done_var_3 = valPos
        done_var_4 = conversionSensorProgress
    end
    local y = 85
    local dy = 25
    lcd.drawText(5, y, "Parsing Field 1: ", TEXT_COLOR)
    drawProgress(y, done_var_1, valPos)
    y = y + dy
    lcd.drawText(5, y, "Parsing Field 2: ", TEXT_COLOR)
    drawProgress(y, done_var_2, valPos)
    y = y + dy
    lcd.drawText(5, y, "Parsing Field 3: ", TEXT_COLOR)
    drawProgress(y, done_var_3, valPos)
    y = y + dy
    lcd.drawText(5, y, "Parsing Field 4: ", TEXT_COLOR)
    drawProgress(y, done_var_4, valPos)

end

local function state_READ_FILE_DATA_refresh(event, touchState)
    if event == EVT_VIRTUAL_EXIT or event == EVT_VIRTUAL_PREV_PAGE then
        state = STATE.SELECT_SENSORS_INIT
        return 0
    end

    display_read_data_progress(0, 0)

    local is_done = collectData()
    if is_done then
        conversionSensorId = 0
        state = STATE.PARSE_DATA
    end

    return 0
end

local function state_PARSE_DATA_refresh(event, touchState)
    if event == EVT_VIRTUAL_EXIT then
        return 2

    elseif event == EVT_VIRTUAL_EXIT or event == EVT_VIRTUAL_PREV_PAGE then
        state = STATE.SELECT_SENSORS_INIT
        return 0
    end

    display_read_data_progress(conversionSensorId, conversionSensorProgress)

    local cnt = 0

    -- prepare
    if conversionSensorId == 0 then
        conversionSensorId = 1
        conversionSensorProgress = 0
        local fileTime = getTotalSeconds(current_session.endTime) - getTotalSeconds(current_session.startTime)
        graphTimeBase = valPos / fileTime

        for varIndex = 1, 4, 1 do
            if sensorSelection[varIndex].idx >= FIRST_VALID_COL then
                local columnName = columns_with_data[sensorSelection[varIndex].idx]
                -- remove column units if exist
                local i = string.find(columnName, "%(")
                local unit = ""

                if i ~= nil then
                    --m_log.info("read-header: %d, %s", i, unit)
                    unit = string.sub(columnName, i + 1, #columnName - 1)
                    columnName = string.sub(columnName, 0, i - 1)
                end
                --m_log.info("state_PARSE_DATA_refresh: col-name: %d. %s", varIndex, columnName)
                _points[varIndex] = {
                    min = 9999,
                    max = -9999,
                    minpos = 0,
                    maxpos = 0,
                    points = {},
                    name = columnName,
                    unit = unit
                }
            end
        end
        return 0
    end

    --
    if sensorSelection[conversionSensorId].idx >= FIRST_VALID_COL then
        for i = conversionSensorProgress, valPos - 1, 1 do
            local val = tonumber(_values[conversionSensorId][i])
            _values[conversionSensorId][i] = val
            conversionSensorProgress = conversionSensorProgress + 1
            cnt = cnt + 1
            --m_log.info("PARSE_DATA: %d. %s %d %d min:%d max:%d", conversionSensorId, _points[conversionSensorId].name, val, #_points[conversionSensorId].points, _points[conversionSensorId].min, _points[conversionSensorId].max)

            if val > _points[conversionSensorId].max then
                _points[conversionSensorId].max = val
                _points[conversionSensorId].maxpos = i
            elseif val < _points[conversionSensorId].min then
                _points[conversionSensorId].min = val
                _points[conversionSensorId].minpos = i
            end

            if cnt > 100 then
                return 0
            end
        end
    end

    if conversionSensorId == 4 then
        graphStart = 0
        graphSize = valPos
        cursor = 50
        graphMinMaxEditorIndex = 0
        graphMode = GRAPH_MODE.CURSOR
        state = STATE.SHOW_GRAPH
    else
        conversionSensorProgress = 0
        conversionSensorId = conversionSensorId + 1
    end

    return 0
end

local function drawMain()
    lcd.clear()

    -- draw background
    if state == STATE.SHOW_GRAPH then
        --    lcd.drawFilledRectangle(0, 0, LCD_W, LCD_H, BLACK)
        --lcd.drawText(LCD_W - 85, LCD_H - 18, "Offer Shmuely", SMLSIZE + GREEN)
        lcd.drawBitmap(img_bg2, 0, 0)
    else
        -- lcd.drawFilledRectangle(0, 0, LCD_W, LCD_H, WHITE)

        -- draw top-bar
        lcd.drawFilledRectangle(0, 0, LCD_W, 20, TITLE_BGCOLOR)
        --lcd.drawText(LCD_W - 95, LCD_H - 18, "Offer Shmuely", SMLSIZE)
        lcd.drawBitmap(img_bg1, 0, 0)
    end

    --draw top-bar
    --lcd.drawFilledRectangle(0, 0, LCD_W, 20, TITLE_BGCOLOR)
    --lcd.setColor(CUSTOM_COLOR, lcd.RGB(193, 198, 215))

    if filename ~= nil then
        lcd.drawText(30, 1, "/LOGS/" .. filename, WHITE + SMLSIZE)
    end

end

local function run_GRAPH_Adjust(amount, mode)
    local scroll_due_cursor = 0

    if mode == GRAPH_MODE.CURSOR then
        cursor = cursor + math.floor(amount)
        if cursor > 100 then
            cursor = 100
            scroll_due_cursor = 1
        elseif cursor < 0 then
            cursor = 0
            scroll_due_cursor = -1
        end
    end

    if mode == GRAPH_MODE.ZOOM then
        if amount > 40 then
            amount = 40
        elseif amount < -40 then
            amount = -40
        end

        local oldGraphSize = graphSize
        graphSize = math.floor(graphSize / (1 + (amount * 0.02)))

        -- max zoom control
        if graphSize < 31 then
            graphSize = 31
        elseif graphSize > valPos then
            graphSize = valPos
        end

        if graphSize > (valPos - graphStart) then
            if amount > 0 then
                graphSize = valPos - graphStart
            else
                graphStart = valPos - graphSize
            end
        else
            local delta = oldGraphSize - graphSize
            graphStart = graphStart + math_floor((delta * (cursor / 100)))

            if graphStart < 0 then
                graphStart = 0
            elseif graphStart + graphSize > valPos then
                graphStart = valPos - graphSize
            end
        end

        graphSize = math_floor(graphSize)

        for varIndex = 1, 4, 1 do
            if sensorSelection[varIndex].idx >= FIRST_VALID_COL then
                _points[varIndex].points = {}
            end
        end
    end

    if mode == GRAPH_MODE.MINMAX then
        local point = _points[(math.floor(graphMinMaxEditorIndex / 2)) + 1]
        local delta = math.floor((point.max - point.min) / 50 * amount)
        if amount > 0 and delta < 1 then
            delta = 1
        elseif amount < 0 and delta > -1 then
            delta = -1
        end

        if graphMinMaxEditorIndex % 2 == 0 then
            point.max = point.max + delta
            if point.max < point.min then
                point.max = point.min + 1
            end
        else
            point.min = point.min + delta
            if point.min > point.max then
                point.min = point.max - 1
            end
        end
    end

    if mode == GRAPH_MODE.SCROLL or scroll_due_cursor ~= 0 then

        if mode == GRAPH_MODE.CURSOR then
            amount = scroll_due_cursor
        end

        graphStart = graphStart + math.floor((graphSize / 100) * amount)
        if graphStart + graphSize > valPos then
            graphStart = valPos - graphSize
        elseif graphStart < 0 then
            graphStart = 0
        end

        graphStart = math_floor(graphStart)

        for varIndex = 1, 4, 1 do
            if sensorSelection[varIndex].idx >= FIRST_VALID_COL then
                _points[varIndex].points = {}
            end
        end
    end
end

local function drawGraph_base()
    local txt
    if graphMode == GRAPH_MODE.CURSOR then
        txt = "Cursor"
    elseif graphMode == GRAPH_MODE.ZOOM then
        txt = "Zoom"
    elseif graphMode == GRAPH_MODE.MINMAX then
        txt = "min/max"
    else
        txt = "Scroll"
    end

    --lcd.drawFilledRectangle(390, 1, 100, 18, DARKGREEN)
    lcd.drawText(380, 3, "Mode: " .. txt, SMLSIZE + BLACK)
    --lcd.drawText(LCD_W - 85, LCD_H - 18, "Offer Shmuely", SMLSIZE + GREEN)
end

local function drawGraph_var_is_visible(varIndex)
    --m_log.info("drawGraph_var_is_visible: varIndex: %d, ,min: %d, max: %d", varIndex, _points[varIndex].min, _points[varIndex].max)
    return (sensorSelection[varIndex].idx >= FIRST_VALID_COL) and (_points[varIndex].min ~= 0 or _points[varIndex].max ~= 0)
end

local function drawGraph_graph_lines_single_line(points, min, max)
    if min == max then
        return
    end

    local yScale = (max - min) / 200
    local prevY = graphConfig.y_end - ((points[0] - min) / yScale)
    prevY = math.min(math.max(prevY, graphConfig.y_start), graphConfig.y_end)
    --if prevY > graphConfig.y_end then
    --    prevY = graphConfig.y_end
    --elseif prevY < graphConfig.y_start then
    --    prevY = graphConfig.y_start
    --end

    for i = 0, #points - 1, 1 do
        local x1 = graphConfig.x_start + (xStep * i)
        local y = graphConfig.y_end - ((points[i + 1] - min) / yScale)

        y = math.min(math.max(y, graphConfig.y_start), graphConfig.y_end)
        --if y > graphConfig.y_end then
        --    y = graphConfig.y_end
        --elseif y < graphConfig.y_start then
        --    y = graphConfig.y_start
        --end

        lcd.drawLine(x1, prevY, x1 + xStep, y, SOLID, CUSTOM_COLOR)
        prevY = y
    end
end

local function drawGraph_graph_lines()
    local skip = graphSize / 101

    for varIndex = 1, 4, 1 do
        if drawGraph_var_is_visible(varIndex) then
            local varPoints = _points[varIndex]
            local varCfg = graphConfig[varIndex]
            --m_log.info(string.format("drawGraph: %d.%s %d min:%d max:%d", varIndex, varPoints.name, #varPoints.points, varPoints.min, varPoints.max))
            --m_log.info("drawGraph: %d. %s", varIndex, varPoints.columnName)
            if #varPoints.points == 0 then
                for i = 0, 100, 1 do
                    varPoints.points[i] = _values[varIndex][math_floor(graphStart + (i * skip))]
                    if varPoints.points[i] == nil then
                        varPoints.points[i] = 0
                    end
                end
            end

            -- points
            lcd.setColor(CUSTOM_COLOR, varCfg.color)
            drawGraph_graph_lines_single_line(varPoints.points, varPoints.min, varPoints.max)

        end
    end
end

local function drawGraph_bottom_session_line()
    local viewScale = valPos / 479
    local viewStart = math.floor(graphStart / viewScale)
    local viewEnd = math.floor((graphStart + graphSize) / viewScale)
    lcd.drawLine(viewStart, 269, viewEnd, 269, SOLID, RED)
    lcd.drawLine(viewStart, 270, viewEnd, 270, SOLID, RED)
    lcd.drawLine(viewStart, 271, viewEnd, 271, SOLID, RED)
end

local function drawGraph_status_line_values()
    local curr_status_txt_x = 50
    for varIndex = 1, 4, 1 do
        if drawGraph_var_is_visible(varIndex) == false then
            goto continue -- poor man continue
        end

        local varPoints = _points[varIndex]
        local varCfg = graphConfig[varIndex]

        if varPoints.points[cursor] == nil then
            goto continue -- poor man continue
        end

        lcd.setColor(CUSTOM_COLOR, varCfg.color)

        -- cursor values & status line values
        -- status line values
        local status_txt = varPoints.name .. "=" .. varPoints.points[cursor] .. varPoints.unit
        local status_txt_w, status_txt_h = lcd.sizeText(status_txt)
        lcd.drawText(curr_status_txt_x, varCfg.valy, status_txt, CUSTOM_COLOR)
        curr_status_txt_x = curr_status_txt_x + status_txt_w + 10
        :: continue ::
    end
end

local function drawGraph_min_max()
    local skip = graphSize / 101
    for varIndex = 1, 4, 1 do
        if drawGraph_var_is_visible(varIndex) == false then
            goto continue -- poor man continue
        end

        local varPoints = _points[varIndex]
        local varCfg = graphConfig[varIndex]
        lcd.setColor(CUSTOM_COLOR, varCfg.color)

        -- draw min/max
        local minPos = math_floor((varPoints.minpos + 1 - graphStart) / skip)
        local maxPos = math_floor((varPoints.maxpos + 1 - graphStart) / skip)
        minPos = math.min(math.max(minPos, 0), 100)
        maxPos = math.min(math.max(maxPos, 0), 100)

        local x = graphConfig.x_start + (minPos * xStep)
        lcd.drawLine(x, 240, x, 250, SOLID, CUSTOM_COLOR)

        local x = graphConfig.x_start + (maxPos * xStep)
        lcd.drawLine(x, 30, x, graphConfig.y_start, SOLID, CUSTOM_COLOR)

        -- draw max
        lcd.drawFilledRectangle(varCfg.maxx - 5, varCfg.maxy, 35, 14, GREY, 5)
        lcd.drawText(varCfg.maxx, varCfg.maxy, varPoints.max, SMLSIZE + CUSTOM_COLOR)

        -- draw min
        lcd.drawFilledRectangle(varCfg.minx - 5, varCfg.miny, 35, 14, GREY, 5)
        lcd.drawText(varCfg.minx, varCfg.miny, varPoints.min, SMLSIZE + CUSTOM_COLOR)

        :: continue ::
    end
end

local function drawGraph_cursor()
    local skip = graphSize / 101

    ---- draw cursor
    local cursor_x = graphConfig.x_start + (xStep * cursor)
    lcd.drawLine(cursor_x, graphConfig.y_start, cursor_x, graphConfig.y_end, DOTTED, WHITE)

    local cursorLine = math_floor((graphStart + (cursor * skip)) / graphTimeBase)
    local cursorTime = toDuration1(cursorLine)

    if cursorLine < 3600 then
        cursorTime = string.sub(cursorTime, 4)
    end

    -- draw cursor time
    lcd.drawText(cursor_x, 20, cursorTime, WHITE)

    -- draw cursor values
    for varIndex = 1, 4, 1 do
        if drawGraph_var_is_visible(varIndex) == false then
            goto continue -- poor man continue
        end

        local varPoints = _points[varIndex]
        local varCfg = graphConfig[varIndex]
        lcd.setColor(CUSTOM_COLOR, varCfg.color)

        if varPoints.points[cursor] == nil then
            goto continue -- poor man continue
        end

        -- cursor values
        local yScale = (varPoints.max - varPoints.min) / 200
        local cursor_y = graphConfig.y_end - ((varPoints.points[cursor] - varPoints.min) / yScale)
        local x1 = cursor_x + 30
        local y1 = 120 + 25 * varIndex
        local v_txt = varPoints.points[cursor] .. varPoints.unit
        local txt_w, txt_h = lcd.sizeText(v_txt)
        txt_w = math.max(txt_w, 40)

        --lcd.drawFilledRectangle(x1, y1, 40, 20, CUSTOM_COLOR)
        lcd.drawFilledRectangle(x1 + 2, y1, txt_w + 4, 19, CUSTOM_COLOR)
        lcd.drawLine(x1, y1 + 10, cursor_x, cursor_y, DOTTED, CUSTOM_COLOR)
        lcd.drawFilledCircle(cursor_x, cursor_y, 4, CUSTOM_COLOR)
        --lcd.drawText(x1 + 40, y1, v_txt, BLACK + RIGHT)
        lcd.drawText(x1 + 4, y1, v_txt, BLACK)

        :: continue ::
    end
end

local function drawGraph_min_max_editor()
    -- min/max editor
    for varIndex = 1, 4, 1 do
        if drawGraph_var_is_visible(varIndex) == true then
            local varPoints = _points[varIndex]
            local varCfg = graphConfig[varIndex]
            lcd.setColor(CUSTOM_COLOR, varCfg.color)

            -- min/max editor
            if graphMode ~= GRAPH_MODE.MINMAX then
                goto continue -- poor man continue
            end

            if ((graphMinMaxEditorIndex == (varIndex - 1) * 2) or (graphMinMaxEditorIndex == ((varIndex - 1) * 2) + 1)) then
                local min_max_prefix
                local txt
                if graphMinMaxEditorIndex == (varIndex - 1) * 2 then
                    min_max_prefix = "Max"
                    txt = string.format("%d %s", varPoints.max, varPoints.unit)
                else
                    txt = string.format("%d %s", varPoints.min, varPoints.unit)
                    min_max_prefix = "Min"
                end

                local w, h = lcd.sizeText(txt, MIDSIZE + BOLD)
                w = math.max(w + 10, 170)
                local edt_x = 150
                local edt_y = 100
                lcd.drawFilledRectangle(edt_x, edt_y, w + 4, h + 30, GREY, 2)
                lcd.drawRectangle(edt_x, edt_y, w + 4, h + 30, GREY, 0)

                lcd.drawText(edt_x + 5, edt_y + 5, string.format("%s - %s", varPoints.name, min_max_prefix), BOLD + CUSTOM_COLOR)
                lcd.drawText(edt_x + 5, edt_y + 25, txt, MIDSIZE + BOLD + CUSTOM_COLOR)
            end
        end
        :: continue ::
    end
end

local function drawGraph()
    drawGraph_base()
    drawGraph_graph_lines()
    drawGraph_bottom_session_line()
    drawGraph_status_line_values()
    drawGraph_min_max()
    drawGraph_cursor()
    drawGraph_min_max_editor()
end

local function state_SHOW_GRAPH_refresh(event, touchState)
    if event == EVT_VIRTUAL_EXIT or event == EVT_VIRTUAL_PREV_PAGE then
        state = STATE.SELECT_SENSORS_INIT
        return 0
    end

    --if graphMode == GRAPH_MODE.MINMAX and event == EVT_PAGEDN_FIRST then
    if graphMode == GRAPH_MODE.MINMAX and event == EVT_ROT_RIGHT then
        graphMinMaxEditorIndex = graphMinMaxEditorIndex + 1

        if graphMinMaxEditorIndex == 8 then
            graphMinMaxEditorIndex = 0
        end
        if graphMinMaxEditorIndex == 2 and sensorSelection[2].idx == 0 then
            graphMinMaxEditorIndex = 4
        end
        if graphMinMaxEditorIndex == 4 and sensorSelection[3].idx == 0 then
            graphMinMaxEditorIndex = 6
        end
        if graphMinMaxEditorIndex == 6 and sensorSelection[4].idx == 0 then
            graphMinMaxEditorIndex = 0
        end
        if graphMinMaxEditorIndex == 0 and sensorSelection[1].idx == 0 then
            graphMinMaxEditorIndex = 2
        end
        --elseif graphMode == GRAPH_MODE.MINMAX and event == EVT_PAGEUP_FIRST then
    elseif graphMode == GRAPH_MODE.MINMAX and event == EVT_ROT_LEFT then
        graphMinMaxEditorIndex = graphMinMaxEditorIndex - 1

        if graphMinMaxEditorIndex < 0 then
            graphMinMaxEditorIndex = 7
        end
        if graphMinMaxEditorIndex == 7 and sensorSelection[4].idx == 0 then
            graphMinMaxEditorIndex = 5
        end
        if graphMinMaxEditorIndex == 5 and sensorSelection[3].idx == 0 then
            graphMinMaxEditorIndex = 3
        end
        if graphMinMaxEditorIndex == 3 and sensorSelection[2].idx == 0 then
            graphMinMaxEditorIndex = 1
        end
        if graphMinMaxEditorIndex == 1 and sensorSelection[1].idx == 0 then
            graphMinMaxEditorIndex = 7
        end
    elseif event == EVT_VIRTUAL_ENTER or event == EVT_ROT_BREAK then
        -- mode state machine
        --if graphMode == GRAPH_MODE.CURSOR then
        --    graphMode = GRAPH_MODE.ZOOM
        --elseif graphMode == GRAPH_MODE.ZOOM then
        --    graphMode = GRAPH_MODE.SCROLL
        --elseif graphMode == GRAPH_MODE.SCROLL then
        --    graphMode = GRAPH_MODE.MINMAX
        --else
        --    graphMode = GRAPH_MODE.CURSOR
        --end

        -- mode state machine
        if graphMode == GRAPH_MODE.CURSOR then
            graphMode = GRAPH_MODE.MINMAX
        else
            graphMode = GRAPH_MODE.CURSOR
        end

    elseif event == EVT_PLUS_FIRST or event == EVT_ROT_RIGHT or event == EVT_PLUS_REPT then
        run_GRAPH_Adjust(1, graphMode)
    elseif event == EVT_MINUS_FIRST or event == EVT_ROT_LEFT or event == EVT_MINUS_REPT then
        run_GRAPH_Adjust(-1, graphMode)
    end

    if event == EVT_TOUCH_SLIDE then
        m_log.info("EVT_TOUCH_SLIDE")
        m_log.info("EVT_TOUCH_SLIDE, startX:%d   x:%d", touchState.startX, touchState.x)
        m_log.info("EVT_TOUCH_SLIDE, startY:%d   y:%d", touchState.startY, touchState.y)
        local dx = touchState.startX - touchState.x
        local adjust = math.floor(dx / 100)
        m_log.info("EVT_TOUCH_SLIDE, dx:%d,   adjust:%d", dx, adjust)
        run_GRAPH_Adjust(adjust, GRAPH_MODE.SCROLL)
    end

    local adjust = getValue('ail')
    if math.abs(adjust) > 100 then
        if math.abs(adjust) < 800 then
            adjust = adjust / 100
        else
            adjust = adjust / 50
        end
        if graphMode ~= GRAPH_MODE.MINMAX then
            run_GRAPH_Adjust(adjust, GRAPH_MODE.SCROLL)
        end
    end

    adjust = getValue('ele') / 200
    if math.abs(adjust) > 0.5 then
        if graphMode ~= GRAPH_MODE.MINMAX then
            run_GRAPH_Adjust(adjust, GRAPH_MODE.ZOOM)
        else
            run_GRAPH_Adjust(-adjust, GRAPH_MODE.MINMAX)
        end
    end

    adjust = getValue('rud') / 200
    if math.abs(adjust) > 0.5 then
        run_GRAPH_Adjust(adjust, GRAPH_MODE.CURSOR)
    end

    drawGraph()

    return 0
end

local function init()
end

local function main(event, touchState)
    if event == nil then
        error("Cannot be run as a model script!")
        return 2
    end

    --m_log.info("run() ---------------------------")
    --m_log.info("event: %s", event)

    --if event == EVT_TOUCH_SLIDE then
    --    m_log.info("EVT_TOUCH_SLIDE")
    --    m_log.info("EVT_TOUCH_SLIDE, startX:%d   x:%d", touchState.startX, touchState.x)
    --    m_log.info("EVT_TOUCH_SLIDE, startY:%d   y:%d", touchState.startY, touchState.y)
    --    local d = math.floor((touchState.startY - touchState.y) / 20 + 0.5)
    --end

    drawMain()

    if state == STATE.INIT then
        m_log.info("STATE.INIT")
        return state_INIT()

    elseif state == STATE.SELECT_FILE_INIT then
        m_log.info("STATE.SELECT_FILE_INIT")
        return state_SELECT_FILE_init(event, touchState)

    elseif state == STATE.SELECT_FILE then
        --m_log.info("STATE.state_SELECT_FILE_refresh")
        return state_SELECT_FILE_refresh(event, touchState)

    elseif state == STATE.SELECT_SENSORS_INIT then
        m_log.info("STATE.SELECT_SENSORS_INIT")
        return state_SELECT_SENSORS_INIT(event, touchState)

    elseif state == STATE.SELECT_SENSORS then
        --m_log.info("STATE.SELECT_SENSORS")
        return state_SELECT_SENSORS_refresh(event, touchState)

    elseif state == STATE.READ_FILE_DATA then
        m_log.info("STATE.READ_FILE_DATA")
        return state_READ_FILE_DATA_refresh(event, touchState)

    elseif state == STATE.PARSE_DATA then
        m_log.info("STATE.PARSE_DATA")
        return state_PARSE_DATA_refresh(event, touchState)

    elseif state == STATE.SHOW_GRAPH then
        return state_SHOW_GRAPH_refresh(event, touchState)

    end

    --impossible state
    error("Something went wrong with the script!")
    return 2
end

return { init = init, run = main }
