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
local app_ver = "1.14"

-- to get help:
-- change in lib_log.lua to "ENABLE_LOG_FILE=true"
-- change in lib_log.lua to "ENABLE_LOG_TO_FILE= false"
-- run the script ...
-- send me the log file that will be created on: /SCRIPTS/TOOLS/LogViewer/app.log

local app_name = "LogViewer"

local m_log = nil
local m_utils = nil
local m_tables = nil
local m_lib_file_parser = nil
local m_index_file = nil
local m_libgui = nil
local m_main_app = nil


local error_desc = nil
local script_folder = "/SCRIPTS/TOOLS/LogViewer/"
local libgui_dir = "/SCRIPTS/TOOLS/LogViewer/libgui3"

local function validate_image(file_name)
    local img1 = bitmap.open(script_folder .. file_name)
    local w, h = bitmap.getSize(img1)
    -- if w == 0 and h == 0  then
    --     error_desc = "Image file not found: " .. script_folder .. file_name
    -- end
    img1 = nil

    collectgarbage("collect")
end

local function validate_script(file_name, expected_ver, ...)
    -- validate module exist
    local my_loading_flag = "tcd"
    local code_chunk = loadScript(script_folder .. file_name, my_loading_flag)
    if code_chunk == nil then
        error_desc = "File not found: " .. script_folder .. file_name
        return
    end

    print(string.format("[%s] loading, num args: %d", file_name, #{...}))
    local m = code_chunk(...)
    print(string.format("[%s] loaded OK", file_name))
    if expected_ver == nil then
        return m -- file exist, no specific version needed
    end

    print("the_ver: ......................")
    local the_ver = m.getVer()
    print("the_ver: " .. the_ver)
    if the_ver ~= expected_ver then
        error_desc = "incorrect version of file:\n " .. script_folder .. file_name .. ".lua \n (" .. the_ver .. " <> " .. expected_ver .. ")"
        return nil
    end
    return m
    --collectgarbage("collect")
end

local function validate_files()
    m_log = validate_script("lib_log", nil, app_name, "/SCRIPTS/TOOLS/" .. app_name)
    if error_desc ~= nil then return end
    m_log.info("loaded")

    m_utils = validate_script("lib_utils", nil, m_log, app_name)
    if error_desc ~= nil then return end

    m_tables = validate_script("lib_tables", nil, m_log, app_name)
    if error_desc ~= nil then return end

    m_lib_file_parser = validate_script("lib_file_parser", nil, m_log, app_name, m_utils)
    if error_desc ~= nil then return end

    m_index_file = validate_script("lib_file_index", nil, m_log, app_name, m_utils, m_tables, m_lib_file_parser)
    if error_desc ~= nil then return end

    m_libgui = validate_script("libgui3/libgui3", "3.0.0-dev.1", libgui_dir)

    if error_desc ~= nil then return end

    m_main_app = validate_script("LogViewer3", app_ver, m_log, m_utils,m_tables,m_lib_file_parser,m_index_file,m_libgui)
    if error_desc ~= nil then return end


    validate_image("bg1.png")
    if error_desc ~= nil then return end

    validate_image("bg2.png")
    if error_desc ~= nil then return end
end

local function init()
    validate_files()
    if error_desc ~= nil then return end

    return m_main_app.init()
end

local function run(event, touchState)
    -- display if in error mode
    if error_desc ~= nil then
        print(error_desc)
        lcd.clear()
        lcd.drawText(5, 30, "Error:", TEXT_COLOR + BOLD)
        lcd.drawText(5, 60, error_desc, TEXT_COLOR + BOLD)
        return 0
    end

    return m_main_app.run(event, touchState)
end

return { init = init, run = run }
