-- TNS|Log Viewer 2 (LVGL)|TNE

local app_name = "LogViewer2"
local APP_DIR = "/SCRIPTS/TOOLS/LogViewer/"

-- enable require
table.insert(package.searchers, function(filepath)
    local f = loadScript(filepath, "btd")
    if f == nil then
        return "\n--not on SD card: [" .. filepath .. "]--"
    end
    return function() return f end
end)

local function my_load_script(file_name, ...)
    local code_chunk = assert(loadScript(APP_DIR .. file_name, "btd"))
    return code_chunk(...)
end

local tool = nil

local function init()
    local m_log             = my_load_script("lib_log", app_name, APP_DIR)
    local m_utils           = my_load_script("lib_utils",       m_log, app_name)
    local m_tables          = my_load_script("lib_tables",      m_log, app_name)
    local m_lib_file_parser = my_load_script("lib_file_parser", m_log, app_name, m_utils)
    local m_index_file      = my_load_script("lib_file_index",  m_log, app_name, m_utils, m_tables, m_lib_file_parser)
    tool = my_load_script("app", APP_DIR, m_log, app_name, m_utils,m_tables,m_lib_file_parser,m_index_file)

    -- local m_log             = require(script_folder .. "lib_log")(app_name, APP_DIR)
    -- local m_utils           = require(script_folder .. "lib_utils")(m_log, app_name)
    -- local m_tables          = require(script_folder .. "lib_tables")(m_log, app_name)
    -- local m_lib_file_parser = require(script_folder .. "lib_file_parser")(m_log, app_name, m_utils)
    -- local m_index_file      = require(script_folder .. "lib_file_index")(m_log, app_name, m_utils, m_tables, m_lib_file_parser)
    -- tool = require(script_folder .. "app")(m_log, app_name, m_utils,m_tables,m_lib_file_parser,m_index_file)

    return tool.init()
end

local function run(event, touchState)
    return tool.run(event, touchState)
end

return { init=init, run=run, useLvgl=true }

