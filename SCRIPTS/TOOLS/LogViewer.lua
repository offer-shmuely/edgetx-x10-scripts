-- TNS|__LogViewer 1.8|TNE

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
local ver = "1.8"

-- to get help:
-- change in lib_log.lua to "ENABLE_LOG_FILE=true"
-- change in lib_log.lua to "ENABLE_LOG_TO_FILE= false"
-- run the script again,
-- and send me the log file that will be created
-- /SCRIPTS/TOOLS/LogViewer/app.log


my_loading_flag = "tcd"

local my_module = nil
local error_desc = nil
local script_folder = "/SCRIPTS/TOOLS/LogViewer/"

local function validate_image(file_name)

    -- validate bg1
    local img1 = Bitmap.open(script_folder .. file_name)
    local w, h = Bitmap.getSize(img1)
    if w == 0 and h == 0  then
        error_desc = "File not found: " .. script_folder .. file_name
    end
    img1 = nil

    collectgarbage("collect")
end

local function validate_script(file_name, expected_ver)

    -- validate libgui exist
    local code_chunk = loadScript(script_folder .. file_name, my_loading_flag)
    if code_chunk == nil then
        error_desc = "File not found: " .. script_folder .. file_name
        return
    end

    -- validate libgui version
    local m = code_chunk()
    local the_ver = m.getVer()
    print("the_ver: " .. the_ver)
    if the_ver ~= expected_ver then
        error_desc = "incorrect version of file:\n " .. script_folder .. file_name .. ".lua \n (" .. the_ver .. " <> " .. expected_ver .. ")"
        return
    end
    m = nil

    collectgarbage("collect")
end


local function validate_files()

    validate_image("bg1.png")
    if error_desc ~= nil then return end

    validate_image("bg2.png")
    if error_desc ~= nil then return end

    validate_script("LogViewer3", ver)
    if error_desc ~= nil then return end

    --validate_script("index_file", ver)
    --if error_desc ~= nil then return end
    --
    --validate_script("lib_file_parser", ver)
    --if error_desc ~= nil then return end
    --
    --validate_script("utils", ver)
    --if error_desc ~= nil then return end
    --
    --validate_script("lib_log", ver)
    --if error_desc ~= nil then return end
    --
    --validate_script("utils_table", ver)
    --if error_desc ~= nil then return end

    validate_script("libgui", "1.0.2")
    if error_desc ~= nil then return end


end


local function init()

    validate_files()
    if error_desc ~= nil then return end

    my_module = loadScript("/SCRIPTS/TOOLS/LogViewer/LogViewer3", my_loading_flag)()
    return my_module.init()
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

    return my_module.run(event, touchState)
end

return { init = init, run = run }
