local args = {...}
local APP_DIR = args[1]
local m_log = args[2]
local app_name = args[3]
local m_utils = args[4]
local m_tables = args[5]
local m_lib_file_parser = args[6]


-- local table_explorer = assert(loadScript("/WIDGETS/_libs/table_explorer.lua"))()

local M = {
    kind = "clz_sens_data",
    m_log = m_log,
    app_name = app_name,
    m_tables = m_tables,
    m_utils = m_utils,
    m_lib_file_parser = m_lib_file_parser,

    colId = nil, -- column id in the log file
    idx = -1,

    min = 9999,
    max = -9999,
    minpos = 0,
    maxpos = 0,
    sensorName = "---",
    name = "---",
    unit = "---",
    conversionProgress = 0,

    raw_values = {},
    -- points = {},
    line_points = {},

    -- for graph use
    xStep = 1,
    graphConfigSens = nil,
    yScale = 100,
    DEFAULT_CENTER_Y = 120,
    empty_line_y = -1,
    cursor_y = -1,
    visible = true,
}

--function cache
local math_floor = math.floor
local math_fmod = math.fmod
local math_abs = math.abs
local string_gmatch = string.gmatch
local string_gsub = string.gsub
local string_len = string.len
local string_sub = string.sub
local string_char = string.char
local string_byte = string.byte

local function log(fmt, ...)
    M.m_log.info(string.format("[%s-%d]", M.kind, M.idx) .. fmt, ...)
end

function M.init(sensIdx, colId, columnName)
    log("init(idx: %s, colId: %s, columnName: %s)", sensIdx, colId, columnName)

    M.colId = -1
    M.idx = -1

    M.min = 9999
    M.max = -9999
    M.minpos = 0
    M.maxpos = 0
    M.sensorName = "---"
    M.name = "---"
    M.unit = "---"
    M.conversionProgress = -1

    M.raw_values = {}
    M.line_points = {}

    if colId == -1 then
        return
    end

    M.idx = sensIdx
    M.colId = colId
    log("columnName: %s", columnName)
    local i = string.find(columnName, "%(")
    if (i ~= nil) then
        M.sensorName = string.sub(columnName, 0, i - 1)
        M.unit = string.sub(columnName, i + 1, #columnName - 1)
    else
        M.sensorName = columnName
        M.unit = ""
    end
    M.conversionProgress = 1
    M.empty_line_y = M.DEFAULT_CENTER_Y + 5*sensIdx
    log("init(%s, colId: %s, %s, unit: %s)", M.idx, M.colId, M.sensorName, M.unit)

end

function M.setConfig(cfg)
    M.graphConfigSens = cfg
end

function M.valsCount()
    return #(M.raw_values)
end

function M.isUsed()
    return (M.colId > -1)
end
function M.isNotUsed()
    return (M.colId == -1)
end

function M.isUsedAndReady()
    return M.isUsed() and (M.min ~= 0 or M.max ~= 0)
end

function M.clearLinePoints()
    M.line_points = {}
end

function M.addValFromLine(lineVals)
    if M.colId == -1 then
        return
    end
    -- log("addValFromLine(idx:%s, colId: %s)", M.idx, M.colId)

    local idx = #M.raw_values + 1

    M.raw_values[idx] = tonumber(lineVals[M.colId])

    -- log("addValFromLine(idx:%s, colId: %s, values: %s)", M.idx, M.colId, M.raw_values[idx])
    assert(M.raw_values[idx] ~= nil, "addValFromLine: colId is nil")

    -- table_explorer.print(M.raw_values, string.format("M.raw_values (%d)", idx))
end

function M.calcMinMax()
    if M.colId == -1 then
        return
    end

    local cnt = 0
    for i = M.conversionProgress, #M.raw_values, 1 do
        -- assert(M.raw_values[i], "fillMorePoints: values[i] is nil")
        local val = M.raw_values[i]

        M.conversionProgress = M.conversionProgress + 1
        cnt = cnt + 1

        if val < M.min then
            M.min = val
            M.minpos = i
        elseif val > M.max then
            M.max = val
            M.maxpos = i
        end

        if cnt > 100 then
            -- temporary return to avoid long loop, will continue in the next call
            return false
        end
    end
    return true
end

------------------------------------------------------------------------------------------------

function M.calc_graph_line(graphConfig)
    if M.isUsedAndReady() == false then
        return
    end

    local yScale = (M.max - M.min) / graphConfig.height

    M.line_points = {}
    for i = 1, #M.raw_values do
        local x1 = graphConfig.valPos2x(i)
        local y = graphConfig.y_end - ((M.raw_values[i] - M.min) / yScale)
        if M.min == M.max then
            y = M.empty_line_y
        end

        y = math.min(math.max(y, graphConfig.y_start), graphConfig.y_end)
        M.line_points[i] = {x1, y}
    end
end

function M.build_ui_line(box)
    if M.isUsed() == false then
        return
    end

    box:line({
        pts=function() return M.line_points end,
        color=function() return M.graphConfigSens.color end,
        thickness=2,
        visible=function() return M.isUsed() and M.visible==true end
    })
end

return M

