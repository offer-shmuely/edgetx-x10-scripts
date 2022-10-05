local M = {}

local m_tables = require("./LogViewer/utils_table")
local m_log = require("./LogViewer/utils_log")
local m_log_parser = require("LogViewer/log_parser")
local m_utils = require("LogViewer/utils")

local idx_file_name = "/LOGS/log-viewer.csv"
--local idx_file_name = "/SCRIPTS/TOOLS/LogViewer/log-viewer.csv"

local log_files_index_info = {}

function M.indexInit()
    m_tables.table_clear(log_files_index_info)
    --log_files_index_info = {}
end

local function updateFile(file_name, start_time, end_time, total_seconds, total_lines, start_index, col_with_data_str)
    m_log.log1("updateFile(%s)", file_name)

    log_files_index_info[#log_files_index_info + 1] = {
        file_name = m_utils.trim(file_name),
        start_time = m_utils.trim(start_time),
        end_time = m_utils.trim(end_time),
        total_seconds = tonumber(m_utils.trim(total_seconds)),
        total_lines = tonumber(m_utils.trim(total_lines)),
        start_index = tonumber(m_utils.trim(start_index)),
        col_with_data_str = m_utils.trim(col_with_data_str)
    }
    --m_log.log2("22222222222: %d - %s", #log_files_index_info, file_name)
end

function M.show(prefix)
    local tbl = log_files_index_info
    m_log.log1("-------------show start (%s)", prefix)
    for i = 1, #tbl, 1 do
        local f_info = tbl[i]
        local s = string.format("%d. file_name:%s, start_time: %s, end_time: %s, total_seconds: %s, total_lines: %s, start_index: %s, col_with_data_str: [%s]", i,
            f_info.file_name,
            f_info.start_time,
            f_info.end_time,
            f_info.total_seconds,
            f_info.total_lines,
            f_info.start_index,
            f_info.col_with_data_str
        )
        m_log.log(s)
    end
    m_log.log("------------- show end")
end

function M.indexRead()
    m_log.log("indexRead()")
    m_tables.table_clear(log_files_index_info)
    local hFile = io.open(idx_file_name, "r")
    if hFile == nil then
        return
    end

    -- read Header
    local data1 = io.read(hFile, 2048)
    local index = string.find(data1, "\n")
    if index == nil then
        m_log.log("Index header could not be found, file: %s", idx_file_name)
        return
    end

    -- get header line
    local headerLine = string.sub(data1, 1, index)
    m_log.log1("indexRead: header: %s", headerLine)

    io.seek(hFile, index)
    local data2 = io.read(hFile, 2048 * 32)

    --M.show("indexRead-should-be-empty")
    for line in string.gmatch(data2, "([^\n]+)\n") do

        if string.sub(line,1,1) ~= "#" then
            --m_log.log1("indexRead: index-line: %s", line)
            local values = m_utils.split(line)

            local file_name = values[1]
            local start_time = values[2]
            local end_time = values[3]
            local total_seconds = values[4]
            local total_lines = values[5]
            local start_index = values[6]
            local col_with_data_str = values[7]
            --m_log.log(string.format("indexRead: got: file_name: %s, start_time: %s, end_time: %s, total_seconds: %s, total_lines: %s, start_index: %s, col_with_data_str: %s", file_name, start_time, end_time, total_seconds, total_lines, start_index, col_with_data_str))
            updateFile(file_name, start_time, end_time, total_seconds, total_lines, start_index, col_with_data_str)
        end
    end

    io.close(hFile)
    M.show("indexRead-should-with-data")
end

function M.getFileDataInfo(file_name)
    m_log.log1("getFileDataInfo(%s)", file_name)
    --M.show("M.getFileDataInfo-start")

    for i = 1, #log_files_index_info do
        local f_info = log_files_index_info[i]
        --m_log.log2("getFileDataInfo: %s ?= %s", file_name, f_info.file_name)
        if file_name == f_info.file_name then
            m_log.log1("getFileDataInfo: info from cache %s", file_name)
            return f_info.start_time, f_info.end_time, f_info.total_seconds, f_info.total_lines, f_info.start_index, f_info.col_with_data_str
        --else
        --    m_log.log2("getFileDataInfo: not found yet %s~=%s", file_name, f_info.file_name)
        end
    end

    m_log.log2("M.getFileDataInfo: error: failed to find: %s", file_name)
    --M.show("M.getFileDataInfo-2")

    local start_time, end_time, total_seconds, total_lines, start_index, col_with_data_str
            = m_log_parser.getFileDataInfo(file_name)

    if start_time == nil then
        return nil, nil, nil, nil, nil, nil
    end

    --M.show("M.getFileDataInfo-2.5")

    updateFile(
        file_name,
        start_time, end_time, total_seconds,
        total_lines,
        start_index,
        col_with_data_str)

    --M.show("M.getFileDataInfo-3")
    return start_time, end_time, total_seconds, total_lines, start_index, col_with_data_str
    --return nil, nil, nil, nil
end

function M.indexSave()
    m_log.log("indexSave()")
    --local is_exist = is_file_exists(idx_file_name)
    local hFile = io.open(idx_file_name, "w")

    -- header
    local line_format = "%-42s,%-10s,%-10s,%-13s,%-11s,%-11s,%s\n"
    local headline = string.format(line_format, "file_name", "start_time", "end_time", "total_seconds", "total_lines", "start_index", "col_with_data_str")
    io.write(hFile, headline)
    local ver_line = "# api_ver=1\n"
    io.write(hFile, ver_line)

    M.show("log_files_index_info")
    m_log.log1("#log_files_index_info: %d", #log_files_index_info)
    for i = 1, #log_files_index_info, 1 do
        local info = log_files_index_info[i]

        local line = string.format( line_format,
            info.file_name,
            info.start_time,
            info.end_time,
            info.total_seconds,
            info.total_lines,
            info.start_index,
            info.col_with_data_str)

        io.write(hFile, line)
    end

    io.close(hFile)
end


--function M.getFileColumns(file_name)
--    m_log.log1("getFileColumns(%s)", file_name)
--    local start_time, total_seconds, total_lines, col_with_data_str = M.getFileDataInfo(file_name)
--    m_log.log1("getFileColumns4(%s)", file_name)
--    m_log.log2("getFileColumns(%s) --> %s", file_name, col_with_data_str)
--    return col_with_data_str
--end

return M

