local args = {...}
local APP_DIR = args[1]
local m_log = args[2]
local app_name = args[3]
local m_utils = args[4]
local m_tables = args[5]
local m_lib_file_parser = args[6]
local m_index_file = args[7]

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
-- Date: 2023-2026

-- to get help:
-- change in lib_log.lua to "ENABLE_LOG_FILE=true"
-- change in lib_log.lua to "ENABLE_LOG_TO_FILE= false"
-- run the script ...
-- send me the log file that will be created on: /SCRIPTS/TOOLS/LogViewer/app.log


local app_ver = "2.0"

local lvSCALE = lvgl.LCD_SCALE or 1
local is800 = (LCD_W==800)

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

local log_file_list_raw = {}
local log_file_list_raw_idx = -1

local log_file_list_fullinfo = {}
local log_file_list_friendly_names = {}
local filter_model_name
local filter_model_name_idx = 1
local filter_date
local filter_date_idx = 1
local model_name_list = { "-- all --" }
local date_list = { "-- all --" }
local ddModel = nil
local bddLogFile2 = nil

local INDEX_TYPE = {ALL=1, LAST_10=2, TODAY=3, LAST_ONE=4}
local index_type = INDEX_TYPE.TODAY

local filename
local filename_idx = 1
local accuracy_idx = 1

local columns_by_header = {}
local columns_with_data = {}
local current_session = nil
local FIRST_VALID_COL = 2

-- state machine
local STATE = {
    SPLASH_INIT = 0,
    SPLASH = 1,
    SELECT_INDEX_TYPE_INIT = 2,
    SELECT_INDEX_TYPE = 3,
    INDEX_FILES_INIT = 4,
    INDEX_FILES = 5,
    SELECT_FILE_INIT = 6,
    SELECT_FILE = 7,

    SELECT_SENSORS_INIT = 8,
    SELECT_SENSORS = 9,

    READ_FILE_DATA_INIT = 10,
    READ_FILE_DATA = 11,
    PARSE_DATA = 12,

    SHOW_GRAPH_INIT = 13,
    SHOW_GRAPH = 14,
}

local state = STATE.SPLASH_INIT
--Graph data
local conversionSensorId = 0
local conversionSensorProgress = 0
local _clz_sens_data = {nil,nil,nil,nil}
local _clz_graph

--File reading data
local valPos = 0
local skipLines = 0
local lines = 0
local index = 0
local buffer = ""

local current_option = 1

local sensorsComboProp = {
    { y =  80, label = "Field 1", values = {}, idx = 1, colId = 0, min = 0 },
    { y = 105, label = "Field 2", values = {}, idx = 1, colId = 0, min = 0 },
    { y = 130, label = "Field 3", values = {}, idx = 1, colId = 0, min = 0 },
    { y = 155, label = "Field 4", values = {}, idx = 1, colId = 0, min = 0 }
}

local select_file_gui_init = false

-- better font size names
local FS={FONT_38=XXLSIZE,FONT_16=DBLSIZE,FONT_12=MIDSIZE,FONT_8=0,FONT_6=SMLSIZE}

--------------------------------------------------------------
local function log(fmt, ...)
    m_log.info(fmt, ...)
end
--------------------------------------------------------------


-- ---------------------------------------------------------------------------------------------------------

local function compare_dates_inc(a, b)
    return a < b
end
local function compare_dates_dec(a, b)
    return a < b
end

local function compare_names(a, b)
    return a < b
end

local function get_log_files_last_fly_date()
    -- find latest log and latest day
    local last_day = "1970-01-01"
    local on_disk_date_list = {}
    local last_log_day_time = "1970-01-01-00-00-00"
    for fn in dir("/LOGS") do
        local modelName, year, month, day, hour, min, sec, m, d, y = string.match(fn, "^(.*)-(%d+)-(%d+)-(%d+)-(%d%d)(%d%d)(%d%d).csv$")
        if year~=nil and month~=nil and day~=nil then
            local log_day = string.format("%s-%s-%s", year, month, day)
            local log_day_time = string.format("%s-%s-%s-%s-%s-%s", year, month, day, hour, min, sec)
            --log("log_day: %s", log_day)
            if log_day > last_day then
                last_day = log_day
                --log("last_day: %s", last_day)
            end
            if log_day_time > last_log_day_time then
                last_log_day_time = log_day_time
                --log("last_log: %s", last_log)
            end

            m_tables.list_ordered_insert(on_disk_date_list, log_day, compare_dates_inc, 2)
            --m_tables.print(on_disk_date_list, "on_disk_date_list")
        end
    end

    log("latest day: %s, last_log_day_time: %s", last_day, last_log_day_time)
    -- m_tables.print(on_disk_date_list, "on_disk_date_list")
    -- assert(loadScript("/WIDGETS/_libs/table_explorer.lua"))().print(on_disk_date_list, "on_disk_date_list")
    return last_day, last_log_day_time
end

local function get_log_files_list()
    local last_day, last_log_day_time = get_log_files_last_fly_date()
    local log_files_list_all = {}
    local log_files_list_last_10 = {}
    local log_files_list_today = {}
    local log_files_list_latest = {}

    local cnt = 0
    for fn in dir("/LOGS") do
        --log("fn: %s", fn)

        local modelName, year, month, day, hour, min, sec, m, d, y = string.match(fn, "^(.*)-(%d+)-(%d+)-(%d+)-(%d%d)(%d%d)(%d%d).csv$")
        local log_day = string.format("%s-%s-%s", year, month, day)
        local log_day_time = string.format("%s-%s-%s-%s-%s-%s", year, month, day, hour, min, sec)

        log_files_list_all[#log_files_list_all+1] = fn

        if log_day==last_day then
            log_files_list_today[#log_files_list_today+1] = fn
        end

        cnt = cnt +1
        if cnt <= 10 then
            log_files_list_last_10[#log_files_list_last_10+1] = fn
        end

        if log_day_time==last_log_day_time then
            log_files_list_latest[#log_files_list_latest+1] = fn
        end
    end
    -- m_tables.print(log_files_list_all, "log_files_list_all")
    -- m_tables.print(log_files_list_today, "log_files_list_today")
    -- m_tables.print(log_files_list_latest, "log_files_list_latest")

    if index_type == INDEX_TYPE.ALL then
        log("using files for index of type ALL")
        return log_files_list_all
    elseif index_type == INDEX_TYPE.LAST_10 then
        log("using files for index of type LAST_10")
        return log_files_list_last_10
    elseif index_type == INDEX_TYPE.TODAY then
        log("using files for index of type TODAY")
        return log_files_list_today
    elseif index_type == INDEX_TYPE.LAST_ONE then
        log("using files for index of type LAST_ONE")
        return log_files_list_latest
    end

    log("internal error, unknown index_type: %s", index_type)
    return nil
end

local function onLogFileChange(i)
    filename_idx = i
    filename = log_file_list_fullinfo[i].file_name
    log("Selected file index: %d, filename: %s", i, filename)
end

local function onAccuracyChange(i)
    local accuracy = i
    log("Selected accuracy: (%d)", i)

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

local function create_log_file_list()
    m_tables.table_clear(log_file_list_fullinfo)
    m_tables.table_clear(log_file_list_friendly_names)

    local log_files_index_info = m_index_file.getFileListDec()

    table.insert(log_file_list_fullinfo, {
        total_seconds = 0,
        col_with_data_str = "",
        total_lines = 1,
        end_time = "00:00:00",
        start_time = "00:00:00",
        file_name = "---",
        all_col_str = "",
        start_index = 0,
    })
    table.insert(log_file_list_friendly_names, "---")

    for i = 1, #log_files_index_info do
        local log_file_info = log_files_index_info[i]
        local modelName, year, month, day, hour, min, sec, m, d, y = string.match(log_file_info.file_name, "^(.*)-(%d+)-(%d+)-(%d+)-(%d%d)(%d%d)(%d%d).csv$")

        local is_duration_ok = (log_file_info.total_seconds >= min_log_sec_to_show)
        local is_have_data_ok = (log_file_info.col_with_data_str ~= nil) and (log_file_info.col_with_data_str ~= "")

        if is_duration_ok and is_have_data_ok then
            log_file_info.freindly_name = string.format("%s (%.0fmin)", log_file_info.file_name, log_file_info.total_seconds/60)
            table.insert(log_file_list_fullinfo, log_file_info)
            table.insert(log_file_list_friendly_names, log_file_info.freindly_name)
        else
            log("create_log_file_list: [%s] - FILTERED-OUT (filters:%s,%s) (is_duration_ok:%s) (have_data_ok:%s)", log_file_info.file_name, filter_model_name, filter_date, is_duration_ok, is_have_data_ok)
        end
    end

    if #log_file_list_friendly_names == 0 then
        table.insert(log_file_list_friendly_names, "not found")
    end

    -- m_tables.print2(log_files_index_info, "getFileListDec")
    -- assert(loadScript("/WIDGETS/_libs/table_explorer.lua"))().print(log_files_index_info, "getFileListDec")
    -- m_tables.print(log_file_list_friendly_names, "log_file_list_friendly_names")
    -- assert(loadScript("/WIDGETS/_libs/table_explorer.lua"))().print(log_file_list_friendly_names, "log_file_list_friendly_names")
    -- m_tables.print(log_file_list_fullinfo, "log_file_list_fullinfo")
    -- assert(loadScript("/WIDGETS/_libs/table_explorer.lua"))().print(log_file_list_fullinfo, "log_file_list_fullinfo")
end

local function filter_log_file_list(filter_model_name, filter_date, need_update)
    log("need to filter by: [%s] [%s] [%s]", filter_model_name, filter_date, need_update)

    local have_visibles = false
    log_file_list_fullinfo[1].is_visible = false

    for i = 1, #log_file_list_fullinfo do
        local log_file_info = log_file_list_fullinfo[i]
        local modelName, year, month, day, hour, min, sec, m, d, y = string.match(log_file_info.file_name, "^(.*)-(%d+)-(%d+)-(%d+)-(%d%d)(%d%d)(%d%d).csv$")

        local is_model_name_needed
        if filter_model_name == nil or string.sub(filter_model_name, 1, 2) == "--" then
            is_model_name_needed = true
        else
            is_model_name_needed = (modelName == filter_model_name)
        end

        local is_date_needed
        if filter_date == nil or string.sub(filter_date, 1, 2) == "--" then
            is_date_needed = true
        else
            local model_day = string.format("%s-%s-%s", year, month, day)
            is_date_needed = (model_day == filter_date)
        end

        if is_model_name_needed and is_date_needed and log_file_info.file_name~="---" then
            log("filter_log_file_list: [%s] - OK (%s,%s)", log_file_info.file_name, filter_model_name, filter_date)
            log_file_info.is_visible = true
            have_visibles = true
        else
            log("filter_log_file_list: [%s] - FILTERED-OUT (filters:%s,%s) (model_name_ok:%s,date_ok:%s)", log_file_info.file_name, filter_model_name, filter_date, is_model_name_needed, is_date_needed)
            log_file_info.is_visible = false
        end

    end

    log_file_list_fullinfo[1].is_visible = (have_visibles==false)
end


local splash_start_time = 0

local function state_SPLASH_INIT(event, touchState)
    log("creating new window gui")
    lvgl.clear()

    lvgl.build({
        {type="image", x=0, y=0, w=LCD_W, h=LCD_H, file=APP_DIR.."/img/bg3.png"},
    })

    state = STATE.SPLASH
    return 0
end

local function build_ui_topbar()
    lvgl.clear()
    local mainBox = lvgl.box({x=0, y=0, w=LCD_W, h=LCD_H, scrollDir=lvgl.SCROLL_OFF})
    mainBox:build({
        {type="rectangle", x=0, y=0, w=LCD_W, h=20*lvSCALE, color=COLOR_THEME_SECONDARY1, filled=true},
        -- {type="label", x=5, y=1, text="Flight History Viewer", color=WHITE, font=FS.FONT_6},

        {type="label", x=30*lvSCALE, y=1*lvSCALE, text=function() return filename or "---" end, color=WHITE, font=FS.FONT_6, visible=function() return filename~=nil end},
        {type="label", x=LCD_W-70*lvSCALE, y=1*lvSCALE, text="v" .. app_ver, color=WHITE, font=FS.FONT_6},
    })
    return mainBox
end

local function buildUiProgress(panel, x,y, w, h, percentFunc)
    local bProg = panel.box({x=x, y=y})
    -- bProg:label({ x=5, y=0, text=function() return string.format("Parsing Field %d: ", i) end})
    bProg:rectangle({ x=1, y=1, size=function() return (w -2) * percentFunc(), h-2 end, rounded=5, filled=true, color=TEXT_INVERTED_BGCOLOR })
    bProg:rectangle({ x=0, y=0, w=w, h=h, rounded=5, filled=false, color=TEXT_COLOR})
end

local function state_SPLASH(event, touchState)

    if splash_start_time == 0 then
        splash_start_time = getTime()
    end
    local elapsed = getTime() - splash_start_time;
    --log('elapsed: %d (t.durationMili: %d)', elapsed, splash_start_time)
    local elapsedMili = elapsed * 10;
    -- was 1500, but most the time will go anyway from the load of the scripts
    if (elapsedMili >= 500) then
        state = STATE.SELECT_INDEX_TYPE_INIT
    end

    return 0
end

local function state_SELECT_INDEX_TYPE_INIT(event, touchState)
    log("state_SELECT_INDEX_TYPE_init()")
    log("creating new window gui")

    local mainBox = build_ui_topbar()

    -- lvgl.build({
    --     {   type="file",
    --         x=40, y=180,
    --         w=100,
    --         title="flight logs",
    --         -- h=LCD_H,
    --         folder="/LOGS",
    --         extension=".csv",
    --         hideExtension=true,
    --     },
    -- })

    mainBox:build({
        {type="label", x=LCD_W/2-100*lvSCALE, y=1*lvSCALE, text="Flight History Viewer", color=WHITE, font=FS.FONT_6},
        {type="label", x=10*lvSCALE, y=30*lvSCALE, text="Indexing selection"},

        {type="button", x=90*lvSCALE, y=60*lvSCALE, w=320*lvSCALE, h=45*lvSCALE, text="Last flight (fast)", press=
            function()
                log("onButtonIndexTypeLastFlight")
                index_type = INDEX_TYPE.LAST_ONE
                state = STATE.INDEX_FILES_INIT
            end
        },
        {type="button", x=90*lvSCALE, y=110*lvSCALE, w=320*lvSCALE, h=45*lvSCALE, text="Last Day", press=
            function()
                log("onButtonIndexTypeToday")
                index_type = INDEX_TYPE.TODAY;
                state = STATE.INDEX_FILES_INIT;
            end
        },
        {type="button", x=90*lvSCALE, y=160*lvSCALE, w=320*lvSCALE, h=45*lvSCALE, text="Last 10 Flights", press=
            function()
                log("onButtonIndexTypeLast10Flights")
                index_type = INDEX_TYPE.LAST_10
                state = STATE.INDEX_FILES_INIT;
            end
        },
        {type="button", x=90*lvSCALE, y= 210*lvSCALE, w=320*lvSCALE, h=45*lvSCALE, text="All Flights (slow)", press=
            function()
                log("onButtonIndexTypeAll")
                index_type = INDEX_TYPE.ALL
                state = STATE.INDEX_FILES_INIT
            end
        },

    })

    log_file_list_raw = {}
    state = STATE.SELECT_INDEX_TYPE
    return 0
end

local function state_SELECT_INDEX_TYPE(event, touchState)
    if event == EVT_VIRTUAL_NEXT_PAGE then
        state = STATE.INDEX_FILES_INIT
        return 0
    end

    return 0
end

-- build csv file
local function state_INDEX_FILES_INIT(event, touchState)
    log("state_INDEX_FILES_INIT()")

    local mainBox = build_ui_topbar()

    mainBox:build({
        {type="label", x=5, y=30, font=BOLD+FS.FONT_8, text="Analyzing & indexing files"},
        {type="label", x=5, y=60, font=FS.FONT_8, text=function() return string.format("indexing files: (%d/%d)", log_file_list_raw_idx, #log_file_list_raw) end},
        {type="label", x=5, y=120, font=FS.FONT_8, text=function() return string.format("* %s", filename) end},
    })

    buildUiProgress(mainBox, 40,90, 470-40, 16,
        function()
            local current = log_file_list_raw_idx
            local total = #log_file_list_raw
            local pct = (total>0) and (current / total) or 0
            log("buildUiProgress: %d / %d = %.2f", current, total, pct)
            return pct
        end
    )

    state = STATE.INDEX_FILES
    return 0
end

local function state_INDEX_FILES(event, touchState)
    if event == EVT_VIRTUAL_EXIT or event == EVT_VIRTUAL_PREV_PAGE then
        state = STATE.SELECT_INDEX_TYPE
        return 0
    end

    -- start init
    --log("read_and_index_file_list(%d, %d)", log_file_list_raw_idx, #log_file_list_raw)
    if (#log_file_list_raw == 0) then
        log("state_INDEX_FILES: init")
        m_index_file.indexInit()
        log_file_list_raw = get_log_files_list()
        log_file_list_raw_idx = 0
        m_index_file.indexRead(log_file_list_raw)
    end

    for i = 1, 10, 1 do
        log_file_list_raw_idx = log_file_list_raw_idx + 1
        filename = log_file_list_raw[log_file_list_raw_idx]
        if filename ~= nil then

            log("log file: (%d/%d) %s (detecting...)", log_file_list_raw_idx, #log_file_list_raw, filename)

            local modelName, year, month, day, hour, min, sec, m, d, y = string.match(filename, "^(.*)-(%d+)-(%d+)-(%d+)-(%d%d)(%d%d)(%d%d).csv$")
            if modelName == nil then
                goto continue
            end
            --log("log file: %s (is csv)", fileName)
            local model_day = string.format("%s-%s-%s", year, month, day)

            -- read file
            local is_new, start_time, end_time, total_seconds, total_lines, start_index, col_with_data_str, all_col_str = m_index_file.getFileDataInfo(filename)

            --log("read_and_index_file_list: total_lines: %s, total_seconds: %s, col_with_data_str: [%s], all_col_str: [%s]", total_lines, total_seconds, col_with_data_str, all_col_str)
            log("read_and_index_file_list: total_seconds: %s", total_seconds)
            m_tables.list_ordered_insert(model_name_list, modelName, compare_names, 2)
            m_tables.list_ordered_insert(date_list, model_day, compare_dates_inc, 2)

            -- due to cpu load, early exit
            if is_new then
                collectgarbage("collect")
                return 0
            end
        end

        if log_file_list_raw_idx >= #log_file_list_raw then
            collectgarbage("collect")
            state = STATE.SELECT_FILE_INIT
            return 0
        end
        :: continue ::
    end

    collectgarbage("collect")
    return 0
end

local function state_SELECT_FILE_INIT(event, touchState)
    create_log_file_list()
    filter_log_file_list(nil, nil, false)

    -- if select_file_gui_init == false then
        -- select_file_gui_init = true
        -- creating new window gui
    log("creating new window gui")

    local mainBox = build_ui_topbar()

    mainBox:build({
        {type="label", x=10*lvSCALE, y=25*lvSCALE, text="log file...", font=BOLD},

        { type="setting", x=0, y=60*lvSCALE,
            children={
                { type="label", x=5*lvSCALE, y=0, text="Model" },
                { type = "choice", x=90*lvSCALE, w=380*lvSCALE, title = "Model",
                    values = model_name_list,
                    get = function() return filter_model_name_idx; end,
                    set = function(i)
                        log("Selected model-summary: %d", i)
                        log("Selected model-summary: %s", model_name_list[i])
                        filter_model_name = model_name_list[i]
                        filter_model_name_idx = i
                        log("Selected model-name: " .. filter_model_name)
                        filter_log_file_list(filter_model_name, filter_date, true)
                    end ,
                },
            }
        }
    })

    mainBox:build({
        { type="setting", x=0, y=100*lvSCALE,
            children={
                { type="label", x=5*lvSCALE, y=0, text="Date" },
                { type = "choice", x=90*lvSCALE, w=380*lvSCALE, title = "Date",
                    values = date_list,
                    get = function() return filter_date_idx; end,
                    set = function(i)
                        log("Selected filter_date: %d", i)
                        log("Selected filter_date: %s", date_list[i])
                        filter_date = date_list[i]
                        filter_date_idx = i
                        log("Selected filter_date: " .. filter_date)
                        filter_log_file_list(filter_model_name, filter_date, true)

                    end ,
                },
            }
        },
    })

    -- file
    local st = lvgl.setting({x=0, y=140*lvSCALE})
    st:label({ x=5*lvSCALE, y=0, text="Log file" })
    bddLogFile2 = st:box({ x=90*lvSCALE, w=380*lvSCALE})
    bddLogFile2:choice({x=0, w=380*lvSCALE, title = "Log file",
        values = log_file_list_friendly_names,
        get = function()
            -- log("filename_idx: %s, %s", filename_idx, log_file_list_fullinfo[filename_idx].file_name)
            return filename_idx
        end,
        set = function(i)
            -- filename_idx = i
            onLogFileChange(i)
        end,
        filter=function(n)
            local is_visible = log_file_list_fullinfo[n].is_visible
            log("dd-filter: %d, %s --> %s", n, log_file_list_friendly_names[n], is_visible)
            return is_visible
        end
    })
    onLogFileChange(2)

    -- Accuracy
    lvgl.build({
        { type="setting", x=0, y=180*lvSCALE,
            children={
                { type="label", x=5*lvSCALE, y=0, text="Accuracy" },
                { type = "choice", x=90*lvSCALE, w=380*lvSCALE, title = "Accuracy",
                    values = {
                        "1/1 (read every line)",
                        "1/2 (every 2nd line)",
                        "1/5 (every 5th line)",
                        "1/10 (every 10th line)"
                    },
                    get = function() return accuracy_idx end,
                    set = function(i)
                        accuracy_idx = i
                        onAccuracyChange(i)
                    end ,
                },
            }
        },
    })
    accuracy_idx = 1
    onAccuracyChange(1)

    filter_log_file_list(filter_model_name, filter_date, true)

    state = STATE.SELECT_FILE
    return 0
end

local function state_SELECT_FILE(event, touchState)
    -- ## file selected
    if event == EVT_VIRTUAL_EXIT or event == EVT_VIRTUAL_PREV_PAGE then
        log("state_SELECT_SENSORS_refresh EVT_VIRTUAL_PREV_PAGE")
        filename = nil
        state = STATE.SELECT_INDEX_TYPE_INIT
        return 0

    elseif event == EVT_VIRTUAL_NEXT_PAGE or index_type == INDEX_TYPE.LAST_ONE then
        log("state_SELECT_FILE_refresh --> EVT_VIRTUAL_NEXT_PAGE: filename: %s", filename)
        if filename == "not found" or filename == "---" then
            m_log.warn("state_SELECT_FILE_refresh: trying to next-page, but no logfile available, ignoring.")
            return 0
        end

        --Reset file load data
        log("Reset file load data")
        buffer = ""
        lines = 0
        heap = 2048 * 12

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
        log("state_SELECT_FILE_refresh: #col: %d", cnt)
        m_tables.table_clear(columns_with_data)
        columns_with_data[1] = "---"
        for i = 1, #columns_temp, 1 do
            local col = columns_temp[i]
            if m_utils.trim_safe(col) ~= "" then
                columns_with_data[#columns_with_data + 1] = col
                log("state_SELECT_FILE_refresh: col: [%s]", col)
            end
        end

        --log("state_SELECT_FILE_refresh: #columns_with_data: %d", #columns_with_data)
        --for i = #columns_temp, 4, 1 do
        --    columns_with_data[#columns_with_data + 1] = "---"
        --    log("state_SELECT_FILE_refresh: add empty field: %d", i)
        --end
        --m_tables.print(columns_with_data, "state_SELECT_FILE_refresh columns_with_data")

        local columns_temp, cnt = m_utils.split_pipe(all_col_str)
        log("state_SELECT_FILE_refresh: #col: %d", cnt)
        m_tables.table_clear(columns_by_header)
        for i = 1, #columns_temp, 1 do
            local col = columns_temp[i]
            columns_by_header[#columns_by_header + 1] = col
            -- log("state_SELECT_FILE_refresh: col: %s", col)
        end

        state = STATE.SELECT_SENSORS_INIT
        return 0
    end

    return 0
end

local function colWithData2ColByHeader(colWithDataIdx)
    local sensorName = columns_with_data[colWithDataIdx]
    local colByHeaderId = 0

    log("colWithData2ColByHeader: byData     - idx: %d, name: %s", colWithDataIdx, sensorName)

    log("#columns_by_header: %d", #columns_by_header)
    for i = 1, #columns_by_header do
        if columns_by_header[i] == sensorName then
            colByHeaderId = i
            log("colWithData2ColByHeader: byHeader - colId: %d, name: %s", colByHeaderId, columns_by_header[colByHeaderId])
            return colByHeaderId
        end
    end

    log("colWithData2ColByHeader(%s) failed to find entry", colWithDataIdx)
    return -1
end

local function prepare_sensors_combo_data()
    if sensorsComboProp[1].idx ~= 1 or sensorsComboProp[2].idx ~= 1 or sensorsComboProp[3].idx ~= 1 or sensorsComboProp[4].idx ~= 1 then
        return -- keep the last selection
    end

    for i = 1, 4, 1 do
        if i < #columns_with_data then
            sensorsComboProp[i].idx = i + 1
            log("Field %d. sensors is: %s", i, columns_with_data[i])
            sensorsComboProp[i].values[i-1] = columns_with_data[i]
        else
            sensorsComboProp[i].idx = 1
            sensorsComboProp[i].values[0] = "---"
        end
        log("state_SELECT_SENSORS_INIT [%d]=%d (total-sens: %d)", i , sensorsComboProp[i].idx, #columns_with_data)
    end
end

local function get_combo_idx_by_name(sensor_name)
    for i = 1, #columns_with_data do
        if string.sub(columns_with_data[i], 1, #sensor_name) == sensor_name then
            return i
        end
    end
    log("get_combo_idx_by_name(%s): not found", sensor_name)
    return 1 -- fallback to "---"
end

local function set_field_by_id(field_num, sensor_idx)
    log("setting filed[%s] <-- %s %s", field_num, sensor_idx, "aa")
    sensorsComboProp[field_num].idx = sensor_idx
    sensorsComboProp[field_num].colId = colWithData2ColByHeader(sensorsComboProp[field_num].idx)
end

local function set_field(field_num, sensor)
    if type(sensor) == "number" then
        set_field_by_id(field_num, sensor)
    else
        -- set_field_by_sensor_name
        local sensor_name = sensor
        log("setting filed[%s], name:%s", field_num, sensor_name)
        local idx = get_combo_idx_by_name(sensor_name)
        set_field_by_id(field_num, idx)
    end
end

local function state_SELECT_SENSORS_INIT()
    log("state_SELECT_SENSORS_INIT")

    -- select default sensor
    prepare_sensors_combo_data()

    current_option = 1

    -- creating new window gui
    log("creating new window gui")

    local mainBox = build_ui_topbar()

    mainBox:build({
        {type="label", x=10*lvSCALE, y=25*lvSCALE, text="Select sensors...", font=BOLD},

        { type="setting", x=0, y=60*lvSCALE,
            children={
                { type="label", x=5*lvSCALE, y=3*lvSCALE, text="Field 1" },
                { type = "choice", x=70*lvSCALE, y=0, w=120*lvSCALE, title = "Field 1",
                    values = columns_with_data,
                    get = function() return sensorsComboProp[1].idx; end,
                    set = function(i)
                        log("Selected model-summary: i=%s, name=%s", i, columns_with_data[i])
                        local var1 = columns_with_data[i]
                        log("Selected var1: %s", var1)
                        -- sensorsComboProp[1].idx = i
                        -- sensorsComboProp[1].colId = colWithData2ColByHeader(i)
                        set_field_by_id(1, i)
                    end ,
                },
            }
        },
        { type="setting", x=0, y=100*lvSCALE,
            children={
                { type="label", x=5*lvSCALE, y=3*lvSCALE, text="Field 2" },
                { type = "choice", x=70*lvSCALE, y=0, w=120*lvSCALE, title = "Field 2",
                    values = columns_with_data,
                    get = function() return sensorsComboProp[2].idx; end,
                    set = function(i)
                        log("Selected model-summary: i=%s, name=%s", i, columns_with_data[i])
                        local var1 = columns_with_data[i]
                        log("Selected var1: %s", var1)
                        set_field_by_id(2, i)
                    end ,
                },
            }
        },
        { type="setting", x=0, y=140*lvSCALE,
            children={
                { type="label", x=5*lvSCALE, y=3*lvSCALE, text="Field 3" },
                { type = "choice", x=70*lvSCALE, y=0, w=120*lvSCALE, title = "Field 3",
                    values = columns_with_data,
                    get = function() return sensorsComboProp[3].idx; end,
                    set = function(i)
                        log("Selected model-summary: i=%s, name=%s", i, columns_with_data[i])
                        local var1 = columns_with_data[i]
                        log("Selected var1: %s", var1)
                        set_field_by_id(3, i)
                    end ,
                },
            }
        },
        { type="setting", x=0, y=180*lvSCALE,
            children={
                { type="label", x=5*lvSCALE, y=3*lvSCALE, text="Field 4" },
                { type = "choice", x=70*lvSCALE, y=0, w=120*lvSCALE, title = "Field 4",
                    values = columns_with_data,
                    get = function() return sensorsComboProp[4].idx; end,
                    set = function(i)
                        log("Selected model-summary: i=%s, name=%s", i, columns_with_data[i])
                        local var1 = columns_with_data[i]
                        log("Selected var1: %s", var1)
                        set_field_by_id(4, i)
                    end ,
                },
            }
        },

    })

    local preset_w = LCD_W/2 + 20*lvSCALE

    lvgl.label({x=LCD_W-preset_w-10*lvSCALE, y=25*lvSCALE, text="Presets...", font=BOLD})


    -- local b = lvgl.rectangle({x=LCD_W-preset_w-10*lvSCALE, y=25*lvSCALE, w=preset_w, h=(30+#presets*60)*lvSCALE, filled=false, rounded=6, scrollDir=lvgl.SCROLL_VER,
    local b = lvgl.rectangle({x=LCD_W-preset_w-5*lvSCALE, y=50*lvSCALE, w=preset_w, h=LCD_H - 50*lvSCALE, filled=false, rounded=6, scrollDir=lvgl.SCROLL_VER,
        -- children={
        --      {type="label", x=10*lvSCALE, y=5*lvSCALE, text="Presets...", font=BOLD},
        -- }
    })

    local fields_presets = loadScript(APP_DIR .. "/presets.lua", "btd")()

    for i = 1, #fields_presets do
        local p = fields_presets[i]
        b:button({
            x=10, y=10*lvSCALE+(i-1)*50*lvSCALE,
            w=preset_w-20*lvSCALE, h=45*lvSCALE, text=p.text,
            press=function()
                set_field(1, p.fields[1])
                set_field(2, p.fields[2])
                set_field(3, p.fields[3])
                set_field(4, p.fields[4])
                -- for f = 1, 4 do
                --     if type(p.fields[f]) == "number" then
                --         set_field_by_id(f, p.fields[f])
                --     else
                --         set_field_by_sensor_name(f, p.fields[f])
                --     end
                -- end
            end
        })
    end

    -- default preset (4 first fields)
    set_field_by_id(1, 2)
    set_field_by_id(2, 3)
    set_field_by_id(3, 4)
    set_field_by_id(4, 5)

    state = STATE.SELECT_SENSORS
    return 0
end

local function state_SELECT_SENSORS(event, touchState)
    if event == EVT_VIRTUAL_EXIT or event == EVT_VIRTUAL_PREV_PAGE then
        log("state_SELECT_SENSORS_refresh EVT_VIRTUAL_PREV_PAGE")
        state = STATE.SELECT_FILE_INIT
        return 0

    elseif event == EVT_VIRTUAL_NEXT_PAGE then
        state = STATE.READ_FILE_DATA_INIT
        return 0
    end

    return 0
end

local function state_READ_FILE_DATA_INIT(event, touchState)
    log("creating new window gui")

    local mainBox = build_ui_topbar()

    mainBox:build({
        {type="label", x=5*lvSCALE, y=25*lvSCALE, text="Reading data from file...", font=BOLD},
        {type="label", x=5*lvSCALE, y=60*lvSCALE, text=function() return string.format("Reading line: %s", lines) end},
    })
    buildUiProgress(mainBox, 140*lvSCALE,60*lvSCALE, 470*lvSCALE-140*lvSCALE, 16*lvSCALE,
        function()
            local current = lines
            local total = current_session.total_lines
            local pct = (total>0) and (current / total) or 0
            log("buildUiProgress: %d / %d = %.2f", current, total, pct)
            return pct
        end
    )

    -- log("state_READ_FILE_DATA_INIT: %d / %d = %.2f", lines, current_session.total_lines, pct)

    -- local y = 85
    -- local dy = 25
    -- for i = 1, 4, 1 do
    --     local bField = mainBox:box({x=0, y=y+dy*(i-1), })
    --     bField:label({ x=5, y=0, text=function() return string.format("Parsing Field %d: ", i) end})
    --     buildUiProgress(bField, 140,0, 470-140, 16,
    --         function()
    --             local pct
    --             -- log("conversionSensorId: %s == i:%s",conversionSensorId, i)
    --             if conversionSensorId == i then
    --                 local current = log_file_list_raw_idx
    --                 local total = #log_file_list_raw
    --                 pct = (total>0) and (current / total) or 0
    --                 log("buildUiProgress: %d / %d = %.2f", current, total, pct)
    --             elseif conversionSensorId > i then
    --                 pct = 1
    --             else
    --                 pct = 0
    --             end
    --             log("buildUiProgress: conversionSensorId: %s, pct:  / %.2f", conversionSensorId, pct)
    --             return pct
    --         end
    --     )
    -- end

    for sensIdx = 1, 4, 1 do
        _clz_sens_data[sensIdx] = assert(loadScript(APP_DIR.."/clz_sens_data.lua", "btd"))(APP_DIR, m_log, app_name, m_utils, m_tables, m_lib_file_parser)
        -- _clz_sens_data[sensIdx] = require(APP_DIR.."/clz_sens_data.lua")(m_log, app_name, m_utils, m_tables, m_lib_file_parser)
        log("_lineData1: %s", _clz_sens_data[sensIdx].kind)

        _clz_sens_data[sensIdx].init(
                sensIdx,
                sensorsComboProp[sensIdx].colId,
                columns_with_data[sensorsComboProp[sensIdx].idx]
        )

    end

    state = STATE.READ_FILE_DATA
    return 0
end

local function readFilesToValues()
    if hFile == nil then
        buffer = ""
        hFile = io.open("/LOGS/" .. filename, "r")
        io.seek(hFile, current_session.startIndex)
        index = current_session.startIndex
        valPos = 0
        lines = 0
        log(string.format("current_session.total_lines: %d", current_session.total_lines))
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
            local lineVals = m_utils.split(line)
            --log(string.format("readFilesToValue: 1: %s, 2: %s, 3: %s, 4: %s, line: %s", vals[1], vals[2], vals[3], vals[4], line))

            for sensIdx = 1, 4, 1 do
                conversionSensorId = sensIdx
                _clz_sens_data[sensIdx].addValFromLine(lineVals)
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

local function state_READ_FILE_DATA(event, touchState)
    if event == EVT_VIRTUAL_EXIT or event == EVT_VIRTUAL_PREV_PAGE then
        state = STATE.SELECT_SENSORS_INIT
        return 0
    end

    -- fill sens_data values[]
    local is_done = readFilesToValues()
    if is_done then
        conversionSensorId = 0
        state = STATE.PARSE_DATA
    end

    return 0
end

local function state_PARSE_DATA(event, touchState)
    if event == EVT_VIRTUAL_EXIT or event == EVT_VIRTUAL_PREV_PAGE then
        state = STATE.SELECT_SENSORS_INIT
        return 0
    end

    local cnt = 0

    -- prepare
    log("state_PARSE_DATA_refresh: conversionSensorId: %d", conversionSensorId)
    --log("PARSE_DATA: %d. %s >= %s", conversionSensorId, sensorsComboProp[conversionSensorId].idx, FIRST_VALID_COL)

    local isDone1 = _clz_sens_data[1].calcMinMax()
    local isDone2 = _clz_sens_data[2].calcMinMax()
    local isDone3 = _clz_sens_data[3].calcMinMax()
    local isDone4 = _clz_sens_data[4].calcMinMax()
    if isDone1 == false or isDone2 == false or isDone3 == false or isDone4 == false then
        log("state_PARSE_DATA_refresh: isDone1 == false")
        return 0
    end
    log("state_PARSE_DATA_refresh: isDone1 == true")

    local fileTime = m_lib_file_parser.getTotalSeconds(current_session.endTime) - m_lib_file_parser.getTotalSeconds(current_session.startTime)
    local graphTimeBase = valPos / fileTime

    _clz_graph = assert(loadScript(APP_DIR.."/clz_graph.lua", "btd"))(APP_DIR, m_log, app_name, m_utils, m_tables, m_lib_file_parser, app_ver)
    -- _clz_graph = require(APP_DIR.."/clz_graph.lua")(m_log, app_name, m_utils, m_tables, m_lib_file_parser, app_ver)
    log("_clz_graph: %s", _clz_graph.kind)

    _clz_graph.init( graphTimeBase, _clz_sens_data[1], _clz_sens_data[2], _clz_sens_data[3], _clz_sens_data[4], string.format("%s", filename or "---") )

    state = STATE.SHOW_GRAPH_INIT
    return 0
end

local function state_SHOW_GRAPH_INIT()
    _clz_graph.state_SHOW_GRAPH_INIT()
    state = STATE.SHOW_GRAPH
    return 0
end

local function state_SHOW_GRAPH(event, touchState)
    if event == EVT_VIRTUAL_EXIT or event == EVT_VIRTUAL_PREV_PAGE then
        state = STATE.SELECT_SENSORS_INIT
        return 0
    end

    _clz_graph.state_SHOW_GRAPH(event, touchState)
    return 0
end

function M.init()
end

function M.run(event, touchState)
    if event == nil then
        error("Cannot be run as a model script!")
        return 2
    end

    --log("run() ---------------------------")
    --log("event: %s", event)


    if state == STATE.SPLASH_INIT then
        --log("STATE.SPLASH")
        return state_SPLASH_INIT()
    elseif state == STATE.SPLASH then
        --log("STATE.SPLASH")
        return state_SPLASH()

    elseif state == STATE.SELECT_INDEX_TYPE_INIT then
        log("STATE.SELECT_INDEX_TYPE_INIT")
        return state_SELECT_INDEX_TYPE_INIT(event, touchState)

    elseif state == STATE.SELECT_INDEX_TYPE then
        -- log("STATE.state_SELECT_INDEX_TYPE")
        return state_SELECT_INDEX_TYPE(event, touchState)

    elseif state == STATE.INDEX_FILES_INIT then
        log("STATE.INDEX_FILES_INIT")
        return state_INDEX_FILES_INIT(event, touchState)

    elseif state == STATE.INDEX_FILES then
        log("STATE.INDEX_FILES")
        return state_INDEX_FILES(event, touchState)

    elseif state == STATE.SELECT_FILE_INIT then
        log("STATE.SELECT_FILE_INIT")
        return state_SELECT_FILE_INIT(event, touchState)

    elseif state == STATE.SELECT_FILE then
        -- log("STATE.state_SELECT_FILE_refresh")
        return state_SELECT_FILE(event, touchState)

    elseif state == STATE.SELECT_SENSORS_INIT then
        log("STATE.SELECT_SENSORS_INIT")
        return state_SELECT_SENSORS_INIT()

    elseif state == STATE.SELECT_SENSORS then
        -- log("STATE.SELECT_SENSORS")
        return state_SELECT_SENSORS(event, touchState)

    elseif state == STATE.READ_FILE_DATA_INIT then
        log("STATE.READ_FILE_DATA")
        return state_READ_FILE_DATA_INIT(event, touchState)

    elseif state == STATE.READ_FILE_DATA then
        log("STATE.READ_FILE_DATA")
        return state_READ_FILE_DATA(event, touchState)

    elseif state == STATE.PARSE_DATA then
        log("STATE.PARSE_DATA")
        return state_PARSE_DATA(event, touchState)

    elseif state == STATE.SHOW_GRAPH_INIT then
        log("STATE.SHOW_GRAPH_INIT")
        return state_SHOW_GRAPH_INIT()
    elseif state == STATE.SHOW_GRAPH then
        -- log("STATE.SHOW_GRAPH")
        return state_SHOW_GRAPH(event, touchState)

    end

    --impossible state
    error("Something went wrong with the script!")
    lvgl.box({x=0, y=0, w=LCD_W, h=LCD_H, color=RED, filled=true})
    return 2
end

return M
