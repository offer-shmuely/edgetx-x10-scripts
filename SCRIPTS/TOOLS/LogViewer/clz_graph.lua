local args = {...}
local APP_DIR = args[1]
local m_log = args[2]
local app_name = args[3]
local m_utils = args[4]
local m_tables = args[5]
local m_lib_file_parser = args[6]
local app_ver = args[7]

-- local table_explorer=assert(loadScript("/WIDGETS/_libs/table_explorer.lua"))()

-- better font size names
local FS={FONT_38=XXLSIZE,FONT_16=DBLSIZE,FONT_12=MIDSIZE,FONT_8=0,FONT_6=SMLSIZE}
local lvSCALE = lvgl.LCD_SCALE or 1
local is800 = (LCD_W==800)

local GRAPH_MODE = {
    CURSOR = 0,
    ZOOM = 1,
    SCROLL = 2,
    GRAPH_MINMAX = 3
}

local M = {
    kind="clz_graph",
    m_log = m_log,
    app_name = app_name,
    m_tables = m_tables,
    m_utils = m_utils,
    m_lib_file_parser = m_lib_file_parser,
    app_ver = app_ver,
}

local bGraph
-- local cursor = 50
-- local valsNum = 0 -- number of values per line
local graphTimeBase = 0
local sens_data = {}
local center_delay_start = nil
local graphMode = GRAPH_MODE.CURSOR
local graphMinMaxEditorIndex = 0
local filename = "---"
local show_dbg = false
local show_settings = false

local graphConfig = {
    x_scrool = 0,
    y_start = 40,
    y_end = is800 and 440 or 240,
    xStep = 1,
    zoomLevel = 30,
    height = is800 and 400 or 200,
    -- DEFAULT_CENTER_Y = 120,
    needReLayout = false,
}
graphConfig.valPos2x = function(valPos)
    return (valPos - 1) * graphConfig.xStep
end
graphConfig.x2valPos = function(x)
    return math.floor(x / graphConfig.xStep) + 1
end

local graphConfigSens = {
    { color = GREEN, valx =  20, valy = 249, minx = 5, miny = 220, maxx = 5, maxy = 30 },
    { color = RED,   valx = 130, valy = 249, minx = 5, miny = 205, maxx = 5, maxy = 45 },
    { color = WHITE, valx = 250, valy = 249, minx = 5, miny = 190, maxx = 5, maxy = 60 },
    { color = BLUE,  valx = 370, valy = 249, minx = 5, miny = 175, maxx = 5, maxy = 75 }
}

local cursor_data = {
    cursor_x = LCD_W / 2,
    cursor_y = 0,
    cursor_time = 0,
    cursor_value = 0,
    vals = {
        {x1 = 0,y1 = 0,v_txt = "---", txt_w = 0},
        {x1 = 0,y1 = 0,v_txt = "---", txt_w = 0},
        {x1 = 0,y1 = 0,v_txt = "---", txt_w = 0},
        {x1 = 0,y1 = 0,v_txt = "---", txt_w = 0},
    }
}

local function log(fmt, ...)
    M.m_log.info(string.format("[%s]", M.kind)..fmt, ...)
end

function M.init(graphTimeBase1, sens1, sens2, sens3, sens4, filename1)
    log("init()")
    graphTimeBase = graphTimeBase1
    filename = filename1
    sens_data = { sens1, sens2, sens3, sens4 }
    for sensIdx = 1, 4, 1 do
        sens_data[sensIdx].setConfig(graphConfigSens[sensIdx])
    end

    -- clear full-resolution points so calc_ graph_ line re-samples to 101 screen points
    for sensIdx = 1, 4, 1 do
        sens_data[sensIdx].clearLinePoints()
    end
    graphConfig.zoomLevel = 30 -- reset zoom level
end

local function doubleDigits(value)
    if value < 10 then
        return "0" .. value
    else
        return value
    end
end

local function toDuration1(totalSeconds)
    local hours = math.floor(totalSeconds / 3600)
    totalSeconds = totalSeconds - (hours * 3600)
    local minutes = math.floor(totalSeconds / 60)
    local seconds = totalSeconds - (minutes * 60)
    return doubleDigits(hours) .. ":" .. doubleDigits(minutes) .. ":" .. doubleDigits(seconds);
end

local function calc_graph_params()
    -- viewScale = valsNum / 479
    -- viewStart = math.floor(graphStart / viewScale)
    -- viewEnd = math.floor((graphStart + graphSize) / viewScale)

    local minStep = 0.3
    local maxStep = 10
    graphConfig.xStep = minStep + (graphConfig.zoomLevel - 1) * (maxStep - minStep) / 99
end

local function drawGraph_status_line_values(sensIdx)
    local curr_status_txt_x = 50

    if sens_data[sensIdx].isUsedAndReady() == false then
        return
    end

    local sens_data_info = sens_data[sensIdx]

    -- if sens_data_info.line_points[cursor] == nil then
    --     return
    -- end
    -- cursor values & status line values
    -- status line values
    -- local status_txt = sens_data_info.sensorName .. "=" .. sens_data_info.points[cursor] .. sens_data_info.unit
    -- local status_txt_w, status_txt_h = lcd.sizeText(status_txt)
    -- lcd.drawText(curr_status_txt_x, graphConfigSens[sensIdx].valy, status_txt, CUSTOM_COLOR)
    -- curr_status_txt_x = curr_status_txt_x + status_txt_w + 10
end

local function drawGraph_min_max(sensIdx)
    -- local skip = graphSize / 101
    if sens_data[sensIdx].isUsedAndReady() == false then
        return
    end

    local sens_data_info = sens_data[sensIdx]

    -- -- draw min/max
    -- local minPos = math.floor((sens_data_info.minpos + 1 - graphStart) / skip)
    -- local maxPos = math.floor((sens_data_info.maxpos + 1 - graphStart) / skip)
    -- minPos = math.min(math.max(minPos, 0), 100)
    -- maxPos = math.min(math.max(maxPos, 0), 100)

    -- local x = graphConfig.x_start + (minPos * xStep)
    -- lcd.drawLine(x, 240, x, 250, SOLID, CUSTOM_COLOR)

    -- local x = graphConfig.x_start + (maxPos * xStep)
    -- lcd.drawLine(x, 30, x, graphConfig.y_start, SOLID, CUSTOM_COLOR)

    -- -- draw max
    -- lcd.drawFilledRectangle(graphConfigSens[sensIdx].maxx - 5, graphConfigSens[sensIdx].maxy, 35, 14, GREY, 5)
    -- lcd.drawText(graphConfigSens[sensIdx].maxx, graphConfigSens[sensIdx].maxy, sens_data_info.max, FS.FONT_6 + CUSTOM_COLOR)

    -- -- draw min
    -- lcd.drawFilledRectangle(graphConfigSens[sensIdx].minx - 5, graphConfigSens[sensIdx].miny, 35, 14, GREY, 5)
    -- lcd.drawText(graphConfigSens[sensIdx].minx, graphConfigSens[sensIdx].miny, sens_data_info.min, FS.FONT_6 + CUSTOM_COLOR)

end

local function calc_graph_cursor()
    ---- draw cursor
    local cursorX = graphConfig.x_scrool + cursor_data.cursor_x
    local cursorValPos = graphConfig.x2valPos(cursorX)
    local cursorFrac = (cursorX - graphConfig.valPos2x(cursorValPos)) / graphConfig.xStep
    local cursorLineSec = math.floor(cursorValPos / graphTimeBase)
    cursor_data.cursorTime = toDuration1(cursorLineSec)
    if cursorLineSec < 3600 then
        cursor_data.cursorTime = string.sub(cursor_data.cursorTime, 4)
    end

    -- draw cursor values
    for sensIdx = 1, 4, 1 do
        if sens_data[sensIdx].isUsedAndReady() == false then
            goto continue -- poor man continue
        end

        if sens_data[sensIdx].line_points[cursorValPos] == nil then
            goto continue -- poor man continue
        end

        -- cursor values
        local y0 = sens_data[sensIdx].line_points[cursorValPos][2]
        local pt1 = sens_data[sensIdx].line_points[cursorValPos + 1]
        local c_y = pt1 and (y0 + cursorFrac * (pt1[2] - y0)) or y0

        sens_data[sensIdx].cursor_y = c_y

        cursor_data.vals[sensIdx].x1 = cursor_data.cursor_x + 30
        cursor_data.vals[sensIdx].y1 = 120 + 25 * sensIdx
        cursor_data.vals[sensIdx].v_txt = sens_data[sensIdx].sensorName .. ": " .. sens_data[sensIdx].raw_values[cursorValPos] .. sens_data[sensIdx].unit
        cursor_data.vals[sensIdx].txt_w, cursor_data.vals[sensIdx].txt_h = lcd.sizeText(cursor_data.vals[sensIdx].v_txt)
        cursor_data.vals[sensIdx].txt_w = math.max(cursor_data.vals[sensIdx].txt_w, 40)

        :: continue ::
    end

    -- table_explorer.print(cursor_data, "cursor_data")
end

local function drawGraph_min_max_editor()
    -- min/max editor
    for sensIdx = 1, 4, 1 do
        if sens_data[sensIdx].isUsedAndReady() == true then
            local sens_data_info = sens_data[sensIdx]

            -- min/max editor
            if graphMode ~= GRAPH_MODE.MINMAX then
                goto continue -- poor man continue
            end

            if ((graphMinMaxEditorIndex == (sensIdx - 1) * 2) or (graphMinMaxEditorIndex == ((sensIdx - 1) * 2) + 1)) then
                local min_max_prefix
                local txt
                if graphMinMaxEditorIndex == (sensIdx - 1) * 2 then
                    min_max_prefix = "Max"
                    txt = string.format("%d %s", sens_data_info.max, sens_data_info.unit)
                else
                    txt = string.format("%d %s", sens_data_info.min, sens_data_info.unit)
                    min_max_prefix = "Min"
                end

                local w, h = lcd.sizeText(txt, FS.FONT_12 + BOLD)
                w = math.max(w + 10, 170)
                local edt_x = 150
                local edt_y = 100
                lcd.drawFilledRectangle(edt_x, edt_y, w + 4, h + 30, GREY, 2)
                lcd.drawRectangle(edt_x, edt_y, w + 4, h + 30, GREY, 0)

                lcd.drawText(edt_x + 5, edt_y + 5, string.format("%s - %s", sens_data_info.sensorName, min_max_prefix), BOLD + CUSTOM_COLOR)
                lcd.drawText(edt_x + 5, edt_y + 25, txt, FS.FONT_12 + BOLD + CUSTOM_COLOR)
            end
        end
        :: continue ::
    end
end

local function recalculateGraph()
    log("recalculateGraph()")
    calc_graph_params()

    for sensIdx = 1, 4, 1 do
        -- sens_data[sensIdx].clearLinePoints()
        sens_data[sensIdx].calc_graph_line(graphConfig) -- include clearLinePoints
        drawGraph_status_line_values(sensIdx)
        drawGraph_min_max(sensIdx)
        drawGraph_min_max_editor(sensIdx)
    end
    calc_graph_cursor()

    graphConfig.needReLayout = false
end

local function run_GRAPH_adjust_coursor(amount)
    cursor_data.cursor_x = cursor_data.cursor_x + math.floor(amount)
    if cursor_data.cursor_x > LCD_W*0.8 then
        cursor_data.cursor_x = LCD_W*0.8
    elseif cursor_data.cursor_x < 0 then
        cursor_data.cursor_x = 0
    end

    -- log("Cursor move: cursor_x: %d ", cursor_data.cursor_x)
    calc_graph_cursor()
end

local function run_GRAPH_adjust_zoom(amount)

    local scale
    if graphConfig.zoomLevel < 10 then
        scale = 0.4
    elseif graphConfig.zoomLevel < 30 then
        scale = 0.6
    else
        scale = math.max(graphConfig.zoomLevel / 10, 1)
    end
    local delta = amount / 1024 * scale
    graphConfig.zoomLevel = graphConfig.zoomLevel + delta
    log("zoomLevel: %d (amount: %d, delta: %d)", graphConfig.zoomLevel, amount, delta)

    -- max zoom control
    if graphConfig.zoomLevel < 1 then
        graphConfig.zoomLevel = 1
    elseif graphConfig.zoomLevel > 100 then
        graphConfig.zoomLevel = 100
    end

    graphConfig.needReLayout = true
end

function M.state_SHOW_GRAPH_INIT()

    recalculateGraph()

    local header_h = 35*lvSCALE
    local gArea_x = 50*lvSCALE
    local gArea_y = header_h
    local gArea_w = 400*lvSCALE
    local gArea_h = LCD_H - gArea_y

    lvgl.clear()

    -- background
    lvgl.rectangle({x=0, y=0, w=LCD_W, h=LCD_H, color=BLACK, filled=true})
    -- lvgl.image({x=0, y=0, w=LCD_W, h=LCD_H, file=APP_DIR.."/img/bg3.png", scrollDir=lvgl.SCROLL_OFF})

    -- header
    local bHeader=lvgl.rectangle({x= 0, y=0, w=LCD_W, h=header_h, color=GREY, filled=true,
        children={
            -- filename
            {type="label", x=10*lvSCALE, y=7*lvSCALE, text=function() return string.format("/LOGS/%s", filename or "---") end, color=WHITE, font=FS.FONT_6}, --, visible=function() return filename~=nil end},

            -- controls
            {type="button", x=LCD_W-70*lvSCALE,  y=2*lvSCALE, h=30*lvSCALE, text="Setting", color=BLACK,
                press=function()
                    show_settings = not show_settings
                    log("settings button pressed: %s, show_settings: %s",i, show_settings)
                    return (show_settings==true) and 1 or 0
                end
            },
            -- {type="button", x=LCD_W-120*lvSCALE, y=2*lvSCALE, h=30*lvSCALE, text="Info", color=BLACK, press=function() log("info button pressed") return 0 end},

            {type="button", x=LCD_W-210*lvSCALE, y=2*lvSCALE, h=30*lvSCALE, text="<", color=BLACK,
                press=function()
                    cursor_data.cursor_x = 10*lvSCALE
                    calc_graph_cursor()
                end
            },
            {type="button", x=LCD_W-185*lvSCALE, y=2*lvSCALE, h=30*lvSCALE, text="  |  ", color=BLACK,
                press=function()
                    cursor_data.cursor_x = LCD_W/2
                    calc_graph_cursor()
                end
            },
            {type="button", x=LCD_W-150*lvSCALE, y=2*lvSCALE, h=30*lvSCALE, text=">", color=BLACK,
                press=function()
                    cursor_data.cursor_x = LCD_W*0.85
                    calc_graph_cursor()
                end
            },

        }
    })
    lvgl.image({x=LCD_W-100, y=LCD_H-24, w=100, h=16, file=APP_DIR.."/img/bg4.png"})
    lvgl.label({x=5*lvSCALE, y=LCD_H-24*lvSCALE, text="v" .. app_ver, color=GREY, font=FS.FONT_6})

    bGraph = lvgl.box({x=0, y=gArea_y,w=LCD_W, h=LCD_H-gArea_y,
        scrollDir=lvgl.SCROLL_HOR,
        scrolled = function(x, y)
            -- scrolling occurs
            log("Scrolled: x,y=%sx%s", x,y)
            graphConfig.x_scrool = x
            calc_graph_cursor()
        end
    })

    -- lines
    for sensIdx = 1, 4, 1 do
        sens_data[sensIdx].build_ui_line(bGraph)
    end

    -- cursor line
    local y_c_line = 20*lvSCALE
    lvgl.vline({x=cursor_data.cursor_x, y=gArea_y+y_c_line, w=1*lvSCALE, h=gArea_h-y_c_line-20*lvSCALE, dashGap=5, dashWidth=5, color=WHITE})

    -- cursor time
    lvgl.label({color=WHITE, font=FS.FONT_8,
        pos=function() return cursor_data.cursor_x-17*lvSCALE, gArea_y end,
        text=function() return cursor_data.cursorTime or "--" end
    })

    -- cursor values
    for sensIdx = 1, 4, 1 do
        local valLabel_x = 30 + (sensIdx-1)*150*lvSCALE
        local valLabel_y = 2
        local valLabel_x = (sensIdx==1 or sensIdx==3) and LCD_W/2-100*lvSCALE-cursor_data.vals[sensIdx].txt_w or LCD_W/2+100*lvSCALE
        local valLabel_y = (sensIdx<=2) and 3*lvSCALE or gArea_h-30*lvSCALE

        if sens_data[sensIdx].isUsed() then
            lvgl.rectangle({
                x=valLabel_x, y=gArea_y+valLabel_y,
                size=function() return cursor_data.vals[sensIdx].txt_w + 4*lvSCALE, 19*lvSCALE end,
                color=graphConfigSens[sensIdx].color,
                filled=true,
                rounded=3,
                visible=function() return sens_data[sensIdx].visible end
            })

            lvgl.label({x=valLabel_x+2, y=gArea_y+valLabel_y, color=BLACK, font=FS.FONT_8,
                text=function() return cursor_data.vals[sensIdx].v_txt or "--" end,
                visible=function() return sens_data[sensIdx].visible end
            })

            lvgl.line({
                pts=function() return {
                    {cursor_data.cursor_x, gArea_y + sens_data[sensIdx].cursor_y or 0},  -- vline side
                    {valLabel_x + 50*lvSCALE, gArea_y + valLabel_y + 12*lvSCALE}         -- label side
                }
                end,
                color=function() return graphConfigSens[sensIdx].color end,
                thickness=1,
                dashGap=5, dashWidth=5,
                visible=function() return sens_data[sensIdx].visible end
            })

            lvgl.circle({
                pos=function()
                    return cursor_data.cursor_x, gArea_y + sens_data[sensIdx].cursor_y or 0
                end,
                radius=4*lvSCALE,
                color=graphConfigSens[sensIdx].color,
                filled=true,
                visible=function() return sens_data[sensIdx].visible end
            })

        end
    end

    -- settings
    local settings_dx = 5*lvSCALE
    local settings_h = LCD_H - header_h
    local settings_w = 150*lvSCALE
    local h = 60*lvSCALE -- is800 and 100 or 55
    -- local bSettings=lvgl.rectangle({x=LCD_W-settings_w,  y=header_h, w=settings_w, h=settings_h, color=LIGHTGREY, filled=true, opacity=30, visible=function() return show_settings end})
    local bSettings=lvgl.box({x=LCD_W-settings_w, y=header_h, w=settings_w, h=settings_h, visible=function() return show_settings end})
    for sensIdx = 1, 4, 1 do
        local y_pos = 5*lvSCALE + (sensIdx-1)*(h+5*lvSCALE)

        bSettings:box({x=0, y=y_pos, w=settings_w, h=200,visible=function() return show_settings end,
            children={
                {type="rectangle", x=0, y=0, w=settings_w-2*settings_dx, h=h, color=graphConfigSens[sensIdx].color, filled=true, rounded=5, opacity=230},
                {type="label",     x=5*lvSCALE, y=2*lvSCALE, text=function() return string.format("[%s] %d-%d %s", sens_data[sensIdx].sensorName, sens_data[sensIdx].min, sens_data[sensIdx].max, sens_data[sensIdx].unit) end, color=BLACK, font=FS.FONT_8},

                {type="button", x=20*lvSCALE, y=25*lvSCALE, h=25*lvSCALE, text="-", color=BLACK,
                    press=function()
                        log("sens_data[sensIdx].max: %s", sens_data[sensIdx].max)
                        sens_data[sensIdx].max = sens_data[sensIdx].max - 1
                        graphConfig.needReLayout = true
                    end
                },
                {type="button", x=40*lvSCALE, y=25*lvSCALE, h=25*lvSCALE, text="+", color=BLACK,
                    press=function()
                        log("sens_data[sensIdx].max: %s", sens_data[sensIdx].max)
                        sens_data[sensIdx].max = sens_data[sensIdx].max + 1
                        graphConfig.needReLayout = true
                    end
                },
                {type="toggle", x=settings_w-65*lvSCALE, y=22*lvSCALE,
                    get = function()
                        -- log("get [%s] visible: %s", sens_data[sensIdx].sensorName, sens_data[sensIdx].visible)
                        return (sens_data[sensIdx].visible==true and 1 or 0)
                    end,
                    set = function(i)
                        -- log("Selected [%s] i: %s", sens_data[sensIdx].sensorName, i)
                        sens_data[sensIdx].visible = (i==1) and true or false
                    end ,
                    -- active=function() return sens_data[sensIdx].visible end
                },
             }
        })
    end


    -- debug info
    lvgl.box({x=10, y=40, visible=function() return show_dbg end,
        children={
            -- {type="label", x=0, y=0,  text=function() return string.format("graph: start: %d, graphSize: %d", graphStart, graphSize) end, font=FS.FONT_6, color=LIGHTGREY},
            {type="label", x=0, y=15*lvSCALE, text=function() return string.format("graph: zoomLevel: %.2f", graphConfig.zoomLevel) end, font=FS.FONT_6, color=LIGHTGREY},
            {type="label", x=0, y=30*lvSCALE, text=function() return string.format("graph: xStep: %.2f", sens_data[1].xStep) end, font=FS.FONT_6, color=LIGHTGREY},
            {type="label", x=0, y=45*lvSCALE, text=function() return string.format("load: %s%%", getUsage()) end, font=FS.FONT_6, color=LIGHTGREY},
        }
    })


    -- bGraph:rectangle({x= 0,  y=0, w=LCD_W,   h=LCD_H, color=YELLOW, filled=true, opacity=150})

    return 0
end

function M.state_SHOW_GRAPH(event, touchState)
    -- show debug
    local switch_val = getValue('SA')
    -- log("event: %s, adjust: %d", event, switch_val)
    show_dbg = switch_val > 1000

    -- zoom graph
    local adjust = 0 - getValue('ele')
    if math.abs(adjust) > 100 then
        run_GRAPH_adjust_zoom(adjust)
    end

    -- -- move cursor
    -- local adjust = getValue('rud') / 200
    -- if math.abs(adjust) > 0.5 then
    --     run_GRAPH_adjust_coursor(adjust)
    -- end
    -- move cursor
    -- local adjust = getValue('rud')
    -- if adjust > 1000 then
    --     cursor_data.cursor_x = LCD_W*0.85
    --     center_delay_start = nil
    -- elseif adjust<-1000 then
    --     cursor_data.cursor_x = 10*lvSCALE
    --     center_delay_start = nil
    -- elseif math.abs(adjust) > 100 and math.abs(adjust) <= 1000 then
    --     if center_delay_start == nil then
    --         center_delay_start = getTime()
    --     elseif getTime() - center_delay_start >= 100 then -- 100 * 10ms = 1 sec
    --         cursor_data.cursor_x = LCD_W/2
    --         center_delay_start = nil
    --     end
    -- else
    --     center_delay_start = nil
    -- end
    -- local switch_val = getValue('SB')
    -- local old_cursor_data = cursor_data.cursor_x
    -- if switch_val > 1000 then
    --     cursor_data.cursor_x = 10*lvSCALE
    -- elseif switch_val==0 then
    --     cursor_data.cursor_x = LCD_W/2
    -- elseif switch_val<-1000 then
    --     cursor_data.cursor_x = LCD_W*0.85
    -- end
    -- if old_cursor_data ~= cursor_data.cursor_x then
    --     calc_graph_cursor()
    -- end

    local x, y = bGraph:getScrollPos()
    -- log("run_GRAPH_Adjust: graphStart: %d, graphSize: %d, scroll: %sx%s", graphStart, graphSize, x,y)

    if graphConfig.needReLayout then
        recalculateGraph()
    end

    -- log("load: %s%%", getUsage())

    return 0
end

return M

