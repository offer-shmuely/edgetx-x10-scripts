local my_loading_flag = ...

local M = {}

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
-- Date: 2023
local ver = "1.9"

function M.getVer()
    return ver
end

local app_name = "LogViewer"

--m_log = require("LogViewer/lib_log")
--m_lib_file_parser = require("LogViewer/lib_file_parser")
--m_utils = require("LogViewer/lib_utils")
--m_tables = require("LogViewer/lib_tables")
--local m_index_file = require("LogViewer/lib_file_index")
--local m_libgui = require("LogViewer/libgui")

local m_log = loadScript("/SCRIPTS/TOOLS/LogViewer/lib_log", my_loading_flag)(app_name, "/SCRIPTS/TOOLS/" .. app_name)
local m_utils = loadScript("/SCRIPTS/TOOLS/LogViewer/lib_utils", my_loading_flag)(m_log, app_name)
local m_tables = loadScript("/SCRIPTS/TOOLS/LogViewer/lib_tables", my_loading_flag)(m_log, app_name)
local m_lib_file_parser = loadScript("/SCRIPTS/TOOLS/LogViewer/lib_file_parser", my_loading_flag)(m_log, app_name, m_utils)
local m_index_file = loadScript("/SCRIPTS/TOOLS/LogViewer/lib_file_index", my_loading_flag)(m_log, app_name, m_utils, m_tables, m_lib_file_parser)
local m_libgui = loadScript("/SCRIPTS/TOOLS/LogViewer/libgui", my_loading_flag)(m_log, app_name)

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
local filter_model_name_idx = 1
local filter_date
local filter_date_idx = 1
local model_name_list = { "-- all --" }
local date_list = { "-- all --" }
local accuracy_list = { "1/1 (read every line)", "1/2 (every 2nd line)", "1/5 (every 5th line)", "1/10 (every 10th line)" }
local ddModel = nil
local ddLogFile = nil -- log-file dropDown object

local filename
local filename_idx = 1

local columns_by_header = {}
local columns_with_data = {}
local current_session = nil
local FIRST_VALID_COL = 2

-- state machine
local STATE = {
    SPLASH = 0,
    INIT = 1,
    SELECT_FILE_INIT = 2,
    SELECT_FILE = 3,

    SELECT_SENSORS_INIT = 4,
    SELECT_SENSORS = 5,

    READ_FILE_DATA = 6,
    PARSE_DATA = 7,

    SHOW_GRAPH = 8
}

local state = STATE.SPLASH
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
    { y = 80, label = "Field 1", values = {}, idx = 1, colId = 0, min = 0 },
    { y = 105, label = "Field 2", values = {}, idx = 1, colId = 0, min = 0 },
    { y = 130, label = "Field 3", values = {}, idx = 1, colId = 0, min = 0 },
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
local img_bg3 = Bitmap.open("/SCRIPTS/TOOLS/LogViewer/bg3.png")

-- Instantiate a new GUI object
local ctx1 = m_libgui.newGUI()
local ctx2 = m_libgui.newGUI()
local select_file_gui_init = false

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

local function drawProgress(x, y, current, total)
    --m_log.info(string.format("drawProgress(%d. %d, %d)", y, current, total))
    --local x = 140
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
            --m_tables.table_print("log_file_list_raw", log_file_list_raw)
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
        local filename = log_file_list_raw[log_file_list_raw_idx]
        if filename ~= nil then

            -- draw top-bar
            lcd.clear()
            lcd.drawFilledRectangle(0, 0, LCD_W, 20, TITLE_BGCOLOR)
            lcd.drawBitmap(img_bg2, 0, 0)

            -- draw state
            lcd.drawText(5, 30, "Analyzing & indexing files", TEXT_COLOR + BOLD)
            lcd.drawText(5, 60, string.format("indexing files: (%d/%d)", log_file_list_raw_idx, #log_file_list_raw), TEXT_COLOR + SMLSIZE)
            lcd.drawText(5, 90, string.format("* %s", filename), TEXT_COLOR + SMLSIZE)
            lcd.drawText(30, 1, "/LOGS/" .. filename, WHITE + SMLSIZE)

            drawProgress(160, 60, log_file_list_raw_idx, #log_file_list_raw)

            m_log.info("log file: (%d/%d) %s (detecting...)", log_file_list_raw_idx, #log_file_list_raw, filename)

            local modelName, year, month, day, hour, min, sec, m, d, y = string.match(filename, "^(.*)-(%d+)-(%d+)-(%d+)-(%d%d)(%d%d)(%d%d).csv$")
            if modelName == nil then
                goto continue
            end
            --m_log.info("log file: %s (is csv)", fileName)
            local model_day = string.format("%s-%s-%s", year, month, day)

            -- read file
            local is_new, start_time, end_time, total_seconds, total_lines, start_index, col_with_data_str, all_col_str = m_index_file.getFileDataInfo(filename)

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
    local accuracy = i
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

local splash_start_time = 0
local function state_SPLASH(event, touchState)

    if splash_start_time == 0 then
        splash_start_time = getTime()
    end
    local elapsed = getTime() - splash_start_time;
    m_log.info('elapsed: %d (t.durationMili: %d)', elapsed, splash_start_time)
    local elapsedMili = elapsed * 10;
    -- was 1500, but most the time will go anyway from the load of the scripts
    if (elapsedMili >= 500) then
        state = STATE.INIT
    end

    return 0
end

local function state_INIT(event, touchState)
    -- start init
    local is_done = read_and_index_file_list()

    collectgarbage("collect")

    if (is_done == true) then
        state = STATE.SELECT_FILE_INIT
    end

    return 0
end

local function state_SELECT_FILE_init(event, touchState)
    m_tables.table_clear(log_file_list_filtered)
    filter_log_file_list(nil, nil, false)

    m_log.info("++++++++++++++++++++++++++++++++")
    if select_file_gui_init == false then
        select_file_gui_init = true
        -- creating new window gui
        m_log.info("creating new window gui")
        --ctx1 = libGUI.newGUI()

        ctx1.label(10, 25, 120, 24, "log file...", BOLD)

        m_log.info("setting model filter...")
        ctx1.label(10, 55, 60, 24, "Model")
        ddModel = ctx1.dropDown(90, 55, 380, 24, model_name_list, 1,
            function(obj)
                local i = obj.selected
                filter_model_name = model_name_list[i]
                filter_model_name_idx = i
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
                filter_date_idx = i
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

    --filter_model_name_i
    ddModel.selected = filter_model_name_idx
    --filter_date_i
    --ddLogFile.selected = filename_idx
    filter_log_file_list(filter_model_name, filter_date, true)

    ddLogFile.selected = filename_idx


    state = STATE.SELECT_FILE
    return 0
end

local function colWithData2ColByHeader(colWithDataId)
    local sensorName = columns_with_data[colWithDataId]
    local colByHeaderId = 0

    m_log.info("colWithData2ColByHeader: byData     - idx: %d, name: %s", colWithDataId, sensorName)

    m_log.info("#columns_by_header: %d", #columns_by_header)
    for i = 1, #columns_by_header do
        if columns_by_header[i] == sensorName then
            colByHeaderId = i
            m_log.info("colWithData2ColByHeader: byHeader - colId: %d, name: %s", colByHeaderId, columns_by_header[colByHeaderId])
            return colByHeaderId
        end
    end

    return -1
end

local function select_sensors_preset_first_4()
    for i = 1, 4, 1 do
        if i < #columns_with_data then
            sensorSelection[i].idx = i + 1
            m_log.info("%d. sensors is: %s", i, columns_with_data[i])
            sensorSelection[i].values[i - 1] = columns_with_data[i]
        else
            sensorSelection[i].idx = 1
            sensorSelection[i].values[0] = "---"
        end
        m_log.info("state_SELECT_SENSORS_INIT %d. <= %d (%d)", i , sensorSelection[i].idx, #columns_with_data)
    end
end

local function state_SELECT_SENSORS_INIT(event, touchState)
    m_log.info("state_SELECT_SENSORS_INIT")
    m_tables.table_print("sensors-init columns_with_data", columns_with_data)

    -- select default sensor
    select_sensors_preset_first_4()

    m_tables.table_print("sensors-init columns_with_data", columns_with_data)

    current_option = 1

    -- creating new window gui
    m_log.info("creating new window gui")
    ctx2 = nil
    ctx2 = m_libgui.newGUI()

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
            m_log.info("state_SELECT_FILE_refresh: col: %s", col)
        end

        --m_log.info("state_SELECT_FILE_refresh: #columns_with_data: %d", #columns_with_data)
        --for i = #columns_temp, 4, 1 do
        --    columns_with_data[#columns_with_data + 1] = "---"
        --    m_log.info("state_SELECT_FILE_refresh: add empty field: %d", i)
        --end
        --m_tables.table_print("state_SELECT_FILE_refresh columns_with_data", columns_with_data)

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
    drawProgress(140, 60, lines, current_session.total_lines)

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
    drawProgress(140, y, done_var_1, valPos)
    y = y + dy
    lcd.drawText(5, y, "Parsing Field 2: ", TEXT_COLOR)
    drawProgress(140, y, done_var_2, valPos)
    y = y + dy
    lcd.drawText(5, y, "Parsing Field 3: ", TEXT_COLOR)
    drawProgress(140, y, done_var_3, valPos)
    y = y + dy
    lcd.drawText(5, y, "Parsing Field 4: ", TEXT_COLOR)
    drawProgress(140, y, done_var_4, valPos)

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
        local fileTime = m_lib_file_parser.getTotalSeconds(current_session.endTime) - m_lib_file_parser.getTotalSeconds(current_session.startTime)
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
    --m_log.info("PARSE_DATA: %d. %s >= %s", conversionSensorId, sensorSelection[conversionSensorId].idx, FIRST_VALID_COL)
    if sensorSelection[conversionSensorId].idx >= FIRST_VALID_COL then
        for i = conversionSensorProgress, valPos - 1, 1 do
            local val = tonumber(_values[conversionSensorId][i])
            _values[conversionSensorId][i] = val
            conversionSensorProgress = conversionSensorProgress + 1
            cnt = cnt + 1
            m_log.info("PARSE_DATA: %d. %s %s", conversionSensorId, val, _values[conversionSensorId][i])
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
    if state == STATE.SPLASH then
        lcd.drawBitmap(img_bg1, 0, 0)
    elseif state == STATE.SHOW_GRAPH then
        lcd.drawBitmap(img_bg3, 0, 0)
    else
        -- draw top-bar
        lcd.drawFilledRectangle(0, 0, LCD_W, 20, TITLE_BGCOLOR)
        lcd.drawBitmap(img_bg2, 0, 0)
    end

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

function M.init()
end

function M.run(event, touchState)
    if event == nil then
        error("Cannot be run as a model script!")
        return 2
    end

    --m_log.info("run() ---------------------------")
    --m_log.info("event: %s", event)


    drawMain()


    if state == STATE.SPLASH then
        m_log.info("STATE.SPLASH")
        return state_SPLASH()

    elseif state == STATE.INIT then
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

return M
