local M = {}

--local m_tables = require("./LogViewer/utils_table")
--local m_log = require("./LogViewer/lib_log")
--local m_lib_file_parser = require("LogViewer/lib_file_parser")
--local m_utils = require("LogViewer/utils")

M.idx_file_name = "/LOGS/log-viewer.csv"

M.log_files_index_info = {}

function M.indexInit()
    m_tables.table_clear(M.log_files_index_info)
end

local function updateFile(file_name, start_time, end_time, total_seconds, total_lines, start_index, col_with_data_str, all_col_str)
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
    m_tables.list_ordered_insert(M.log_files_index_info, new_file, m_tables.compare_file_names, 1)
    --m_log.info("22222222222: %d - %s", #M.log_files_index_info, file_name)
end

function M.show(prefix)
    local tbl = M.log_files_index_info
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

function M.indexRead()
    m_log.info("indexRead()")
    m_tables.table_clear(M.log_files_index_info)
    local hFile = io.open(M.idx_file_name, "r")
    if hFile == nil then
        return
    end

    -- read Header
    local data1 = io.read(hFile, 2048)
    local index = string.find(data1, "\n")
    if index == nil then
        m_log.info("Index header could not be found, file: %s", M.idx_file_name)
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

    --M.show("indexRead-should-be-empty")
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
            updateFile(file_name, start_time, end_time, total_seconds, total_lines, start_index, col_with_data_str, all_col_str)
        end
    end

    io.close(hFile)
    --M.show("indexRead-should-with-data")
end

function M.getFileDataInfo(file_name)
    m_log.info("getFileDataInfo(%s)", file_name)
    --M.show("M.getFileDataInfo-start")

    for i = 1, #M.log_files_index_info do
        local f_info = M.log_files_index_info[i]
        --m_log.info("getFileDataInfo: %s ?= %s", file_name, f_info.file_name)
        if file_name == f_info.file_name then
            m_log.info("getFileDataInfo: info from cache %s", file_name)
            return false, f_info.start_time, f_info.end_time, f_info.total_seconds, f_info.total_lines, f_info.start_index, f_info.col_with_data_str, f_info.all_col_str
        end
    end

    m_log.info("getFileDataInfo: file not in index, indexing... %s", file_name)

    local start_time, end_time, total_seconds, total_lines, start_index, col_with_data_str, all_col_str = m_lib_file_parser.getFileDataInfo(file_name)

    if start_time == nil then
        return false, nil, nil, nil, nil, nil, nil, nil
    end

    updateFile(
        file_name,
        start_time, end_time, total_seconds,
        total_lines,
        start_index,
        col_with_data_str,
        all_col_str)

    M.indexSave()
    return true, start_time, end_time, total_seconds, total_lines, start_index, col_with_data_str, all_col_str
end

function M.indexSave()
    m_log.info("indexSave()")
    --local is_exist = is_file_exists(M.idx_file_name)
    local hFile = io.open(M.idx_file_name, "w")

    -- header
    local line_format = "%-42s,%-10s,%-10s,%-13s,%-11s,%-11s,%s,   %s\n"
    local headline = string.format(line_format, "file_name", "start_time", "end_time", "total_seconds", "total_lines", "start_index", "col_with_data_str", "all_col_str")
    io.write(hFile, headline)
    local ver_line = "# api_ver=3\n"
    io.write(hFile, ver_line)

    --M.show("M.log_files_index_info")
    m_log.info("#M.log_files_index_info: %d", #M.log_files_index_info)
    for i = 1, #M.log_files_index_info, 1 do
        local info = M.log_files_index_info[i]

        local line = string.format( line_format,
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


--function M.getFileColumns(file_name)
--    m_log.info("getFileColumns(%s)", file_name)
--    local start_time, total_seconds, total_lines, col_with_data_str = M.getFileDataInfo(file_name)
--    m_log.info("getFileColumns4(%s)", file_name)
--    m_log.info("getFileColumns(%s) --> %s", file_name, col_with_data_str)
--    return col_with_data_str
--end

return M

