local m_log, app_name, m_utils, m_tables = ...

local M = {}
M.m_log = m_log
M.app_name = app_name
M.m_tables = m_tables
M.m_utils = m_utils

--M.idx_file_name = "/app_data/flights/flights-history.csv"
M.idx_file_name = "/flights-history.csv"

M.log_files_index_info = {}

local log = M.m_log.info

function M.indexInit()
    M.m_tables.table_clear(M.log_files_index_info)
end

local function compare_by_dates(a, b)
    --local a1 = string.sub(a.flight_date, -21, -5)
    --local b1 = string.sub(b.flight_date, -21, -5)
    local a1 = a.flight_date
    local b1 = b.flight_date
    --log("ab, %s ? %s", a, b)
    --log("a1b1, %s ? %s", a1, b1)
    return a1 < b1
end

local function insertFlight(flight_date, model_name, flight_count, duration, model_id)
    log("updateFlight(%s)", flight_date)

    local key = string.format("key:%s", m_utils.trim(flight_date))
    local desc = string.format("%s - %s #%d (%d min)", flight_date, model_name, flight_count, duration/60)
    --desc = string.format("#%d %s - %s (%d min)", flight_count, flight_date, model_name, duration/60)
    --desc = string.format("%s - #%d %s (%d min)", flight_date, flight_count,model_name, duration/60)

    local f_info = M.getFlightInfoByKey(key)

    if f_info ~= nil then
        f_info.duration = tonumber(m_utils.trim(duration))
        f_info.desc = desc
    else
        local new_fight = {
            key = key,
            flight_date = m_utils.trim(flight_date),
            model_name = m_utils.trim(model_name),
            flight_count = tonumber(m_utils.trim(flight_count)),
            duration = tonumber(m_utils.trim(duration)),
            model_id = m_utils.trim(model_id),
            desc = desc
        }
        log("4 updateFlight(%s) - ==%d== %s", key, new_fight.duration, new_fight.desc)
        M.m_tables.list_ordered_insert(M.log_files_index_info, new_fight, compare_by_dates, 1)
    end
end

function M.getFlightInfoByKey(key)
    --log("------------- getFlightInfoByKey start")
    local tbl = M.log_files_index_info
    for i = 1, #tbl, 1 do
        local f_info = tbl[i]
        -- log("getFlightInfoByKey-" .. f_info.key)

        if f_info.key == key then
            log("getFlightInfoByKey- found key: " .. f_info.key)
            return f_info
        end
    end
    --log("------------- getFlightInfoByKey end")
end

function M.indexPrint(prefix)
    local tbl = M.log_files_index_info
    log("-------------show start (%s)", prefix)
    for i = 1, #tbl, 1 do
        local f_info = tbl[i]
        local s = string.format("%d. flight_date: %s, model_name: %s, flight_count: %s, duration: %s, model_id: %s",
            i,
            f_info.flight_date, f_info.model_name, f_info.flight_count, f_info.duration, f_info.model_id)

        log(s)
    end
    log("------------- show end")
end

function M.historyFileRead()
    log("historyFileRead()")
    M.m_tables.table_clear(M.log_files_index_info)
    local hFile = io.open(M.idx_file_name, "r")
    if hFile == nil then
        return
    end

    -- read Header
    local data1 = io.read(hFile, 2048)
    local index = string.find(data1, "\n")
    if index == nil then
        log("Index header could not be found, file: %s", M.idx_file_name)
        return
    end

    -- check that index file is correct version
    local api_ver = string.match(data1, "# api_ver=(%d*)")
    log("api_ver: %s", api_ver)
    if api_ver ~= "1" then
        log("api_ver of index files is not updated (api_ver=%d)", api_ver)
        return
    end

    -- get header line
    local headerLine = string.sub(data1, 1, index)
    log("indexRead: header: %s", headerLine)

    io.seek(hFile, index)
    local data2 = io.read(hFile, 2048 * 32)

    --M.indexPrint("indexRead-should-be-empty")
    local is_index_have_deleted_files = false
    for line in string.gmatch(data2, "([^\n]+)\n") do

        if string.sub(line, 1, 1) ~= "#" then
            log("indexRead: index-line: %s", line)
            local values = m_utils.split(line)

            local flight_date = m_utils.trim(values[1])
            local model_name = m_utils.trim(values[2])
            local flight_count = m_utils.trim(values[3])
            local duration = m_utils.trim(values[4])
            local model_id = m_utils.trim(values[5])

            -- if not a number, set to -1
            if not tonumber(duration) then
                duration = -1
                log("indexRead: duration is NOT a number")
            end

            log(
                "indexRead: line: flight_date: %s, model_name: %s, flight_count: %s, duration: %s, model_id: %s",
                flight_date, model_name, flight_count, duration, model_id)

            --m_log.info("files_on_disk exist: %s", file_name)
            insertFlight(flight_date, model_name, flight_count, duration, model_id)
        else
            --# /models/model4.yml/duration=100.0
            --# /models/model4.yml/flight_count=15

            log("indexRead: comment: [%s]", line)
            --local model_id, duration = string.match(line, "# /models/(%s*)/duration=(%d*)")
            local mid = string.match(line, "(%s*)")
            log("indexRead: # model_id: (%s), duration: [%s]", mid, "555")
        end
    end

    io.close(hFile)

    M.indexPrint("end of indexRead")
end

function M.getFileDataInfo(flight_date)
    --log("getFileDataInfo(%s)", file_name)
    --M.indexPrint("M.getFileDataInfo-start")

    for i = 1, #M.log_files_index_info do
        local f_info = M.log_files_index_info[i]
        --log("getFileDataInfo: %s ?= %s", file_name, f_info.file_name)
        if flight_date == f_info.flight_date then
            --log("getFileDataInfo: info from cache %s", flight_date)
            return f_info
        end
    end

    log("getFileDataInfo: file not in index... %s", flight_date)
    return false, nil, nil, nil, nil, nil, nil, nil
end


return M

