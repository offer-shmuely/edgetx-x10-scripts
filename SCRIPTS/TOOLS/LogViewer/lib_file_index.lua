local m_log, app_name, m_utils, m_tables, m_lib_file_parser = ...

local M = {}
M.m_log = m_log
M.app_name = app_name
M.m_tables = m_tables
M.m_utils = m_utils
M.m_lib_file_parser = m_lib_file_parser

M.idx_file_name = "/LOGS/log-viewer.csv"

M.log_files_index_info = {}

function M.compare_file_names_inc(a, b)
    local a1 = string.sub(a.file_name, -21, -5)
    local b1 = string.sub(b.file_name, -21, -5)
    --M.m_log.info("ab, %s ? %s", a, b)
    --M.m_log.info("a1b1, %s ? %s", a1, b1)
    return a1 < b1
end

function M.compare_file_names_dec(a, b)
    local a1 = string.sub(a.file_name, -21, -5)
    local b1 = string.sub(b.file_name, -21, -5)
    --M.m_log.info("ab, %s ? %s", a, b)
    --M.m_log.info("a1b1, %s ? %s", a1, b1)
    return a1 > b1
end

function M.indexInit()
    M.m_log.info("indexInit()")
    M.m_tables.table_clear(M.log_files_index_info)
end

local function updateFile(file_name, start_time, end_time, total_seconds, total_lines, start_index, col_with_data_str, all_col_str)
    --M.m_log.info("updateFile(%s)", file_name)

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
    M.m_tables.list_ordered_insert(M.log_files_index_info, new_file, M.compare_file_names_inc, 1)
end

function M.indexPrint(prefix)
    local tbl = M.log_files_index_info
    M.m_log.info("-------------show start (%s)", prefix)
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

        M.m_log.info(s)
    end
    M.m_log.info("------------- show end")
end

function M.indexRead()
    M.m_log.info("indexRead()")
    M.m_tables.table_clear(M.log_files_index_info)
    local hFile = io.open(M.idx_file_name, "r")
    if hFile == nil then
        return
    end

    -- read Header
    local data1 = io.read(hFile, 2048)
    local index = string.find(data1, "\n")
    if index == nil then
        M.m_log.info("Index header could not be found, file: %s", M.idx_file_name)
        return
    end

    -- check that index file is correct version
    local api_ver = string.match(data1, "# api_ver=(%d*)")
    M.m_log.info("api_ver: %s", api_ver)
    if api_ver ~= "3" then
        M.m_log.info("api_ver of index files is not updated (api_ver=%d)", api_ver)
        return
    end

    -- list actual files on disk
    local files_on_disk = {}
    for fn in dir("/LOGS") do
        --m_log.info("files_on_disk fn: %s", fn)
        files_on_disk[fn] = "OK"
    end
    m_tables.table_print("files_on_disk", files_on_disk)

    -- get header line
    local headerLine = string.sub(data1, 1, index)
    M.m_log.info("indexRead: header: %s", headerLine)

    io.seek(hFile, index)
    local data2 = io.read(hFile, 2048 * 32)

    --M.indexPrint("indexRead-should-be-empty")
    local is_index_have_deleted_files = false
    for line in string.gmatch(data2, "([^\n]+)\n") do

        if string.sub(line, 1, 1) ~= "#" then
            --M.m_log.info("indexRead: index-line: %s", line)
            local values = m_utils.split(line)

            local file_name = m_utils.trim(values[1])
            local start_time = m_utils.trim(values[2])
            local end_time = m_utils.trim(values[3])
            local total_seconds = m_utils.trim(values[4])
            local total_lines = m_utils.trim(values[5])
            local start_index = m_utils.trim(values[6])
            local col_with_data_str = m_utils.trim_safe(values[7])
            local all_col_str = m_utils.trim_safe(values[8])
            --M.m_log.info(string.format("indexRead: got: file_name: %s, start_time: %s, end_time: %s, total_seconds: %s, total_lines: %s, start_index: %s, col_with_data_str: %s, all_col_str: %s", file_name, start_time, end_time, total_seconds, total_lines, start_index, col_with_data_str, all_col_str))

            -- if file from index file, still exist on disk?
            if files_on_disk[file_name] == "OK" then
                --m_log.info("files_on_disk exist: %s", file_name)
                updateFile(file_name, start_time, end_time, total_seconds, total_lines, start_index, col_with_data_str, all_col_str)
            else
                m_log.info("files_on_disk not exist: %s", file_name)
                is_index_have_deleted_files = true
            end
        end
    end

    io.close(hFile)
    if is_index_have_deleted_files == true then
        M.indexSave()
    end

    --M.indexPrint("end of indexRead")
end

function M.getFileDataInfo(file_name)
    --M.m_log.info("getFileDataInfo(%s)", file_name)
    --M.indexPrint("M.getFileDataInfo-start")

    for i = 1, #M.log_files_index_info do
        local f_info = M.log_files_index_info[i]
        --M.m_log.info("getFileDataInfo: %s ?= %s", file_name, f_info.file_name)
        if file_name == f_info.file_name then
            --M.m_log.info("getFileDataInfo: info from cache %s", file_name)
            return false, f_info.start_time, f_info.end_time, f_info.total_seconds, f_info.total_lines, f_info.start_index, f_info.col_with_data_str, f_info.all_col_str
        end
    end

    M.m_log.info("getFileDataInfo: file not in index, indexing... %s", file_name)

    local start_time, end_time, total_seconds, total_lines, start_index, col_with_data_str, all_col_str = M.m_lib_file_parser.getFileDataInfo(file_name)

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

function M.getFileListDec()
    local log_files_index_info_dec = {}
    for i = 1, #M.log_files_index_info, 1 do
        local info = M.log_files_index_info[i]
        --M.m_log.info("getFileListDec(): adding f: %s", info.file_name)
        M.m_tables.list_ordered_insert(log_files_index_info_dec, info, M.compare_file_names_dec, 1)
    end
    return log_files_index_info_dec
end

function M.indexSave()
    M.m_log.info("indexSave()")
    --local is_exist = is_file_exists(M.idx_file_name)

    -- header
    local line_format = "%-42s,%-10s,%-10s,%-13s,%-11s,%-11s,%s,   %s\n"
    local headline = string.format(line_format, "file_name", "start_time", "end_time", "total_seconds", "total_lines", "start_index", "col_with_data_str", "all_col_str")

    local hFile = io.open(M.idx_file_name, "w")
    io.write(hFile, headline)
    local ver_line = "# api_ver=3\n"
    io.write(hFile, ver_line)

    --M.indexPrint("M.log_files_index_info")
    M.m_log.info("#M.log_files_index_info: %d", #M.log_files_index_info)
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
--    M.m_log.info("getFileColumns(%s)", file_name)
--    local start_time, total_seconds, total_lines, col_with_data_str = M.getFileDataInfo(file_name)
--    M.m_log.info("getFileColumns4(%s)", file_name)
--    M.m_log.info("getFileColumns(%s) --> %s", file_name, col_with_data_str)
--    return col_with_data_str
--end

return M

