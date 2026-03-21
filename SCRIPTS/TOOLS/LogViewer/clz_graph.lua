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
local graphTimeBase = 0
local sens_data = {}
local filename = "---"
local show_dbg = false
local show_settings = false
local scale_info = {
    w = 40,
    label = "?"
}


local DEFAULT_ZOOM_IDX = 2

-- local zoom_list  = {"1x", "2x", "3x", "4x", "5x", "6x", "7x", "8x", "9x", "10x"}
-- local zoom_scale = {  10,   20,   30,   40,   50,   60,   70,   80,   90,   100}
local zoom_list  = {"1x", "2x", "4x", "6x", "8x", "10x"}
local zoom_scale = { 10 ,  20 ,  40 ,  60 ,  80 ,  100 }
local filter_zoom_level = zoom_list[DEFAULT_ZOOM_IDX]
local filter_zoom_level_idx = DEFAULT_ZOOM_IDX
local DEFAULT_ZOOM_LEVEL = zoom_scale[DEFAULT_ZOOM_IDX]


local graphConfig = {
    x_scrool = 0,
    center_pos = {x=0, y=0},
    y_start = 40,
    y_end = is800 and 430 or 230,
    xStep = 1,
    zoomLevel = DEFAULT_ZOOM_LEVEL,
    reset_to_time = nil,
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
    cursor_time_sec = 0,
    cursor_pos_idx = 2, -- 1: left, 2: center, 3: right
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
    log("init(graphTimeBase1: %s)", graphTimeBase1)
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
    graphConfig.zoomLevel = DEFAULT_ZOOM_LEVEL -- reset zoom level
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
    local minStep = 0.3
    local maxStep = 10
    graphConfig.xStep = minStep + (graphConfig.zoomLevel - 1) * (maxStep - minStep) / 99
end

local function calc_graph_cursor()
    ---- draw cursor
    local cursorX = graphConfig.x_scrool + cursor_data.cursor_x
    local cursorValPos = graphConfig.x2valPos(cursorX)
    local cursorFrac = (cursorX - graphConfig.valPos2x(cursorValPos)) / graphConfig.xStep

    if graphConfig.reset_to_time == nil then
        cursor_data.cursor_time_sec = math.floor(cursorValPos / graphTimeBase)
    end
    log("calc_graph_cursor cursor_time_sec: %s, cursorValPos: %s, cursorFrac: %.2f", cursor_data.cursor_time_sec, cursorValPos, cursorFrac)

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

local function calculate_scale_info()
    local max_w = math.floor(LCD_W / 3)
    local px_per_sec = graphConfig.xStep * graphTimeBase
    if px_per_sec <= 0 then
        scale_info.w = 40 * lvSCALE
        scale_info.label = "?"
        return
    end
    local nice_durations = {5, 10, 15, 20, 30, 60, 120, 180, 300, 600, 900, 1200, 1800, 3600}
    local chosen_sec = nice_durations[1]
    local chosen_w = math.floor(px_per_sec * chosen_sec)
    for i = 1, #nice_durations do
        local w = math.floor(px_per_sec * nice_durations[i])
        if w <= max_w then
            chosen_sec = nice_durations[i]
            chosen_w = w
        else
            break
        end
    end
    if chosen_sec < 60 then
        scale_info.label = string.format("%d sec", chosen_sec)
    else
        scale_info.label = string.format("%d min", chosen_sec / 60)
    end
    scale_info.w = math.max(chosen_w, 5 * lvSCALE)
end

local function recalculateGraph()
    log("recalculateGraph()")
    calc_graph_params()

    for sensIdx = 1, 4, 1 do
        sens_data[sensIdx].calc_graph_line(graphConfig) -- include clearLinePoints
    end
    calc_graph_cursor()
    calculate_scale_info()

    graphConfig.needReLayout = false
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
    lvgl.rectangle({x= 0, y=0, w=LCD_W, h=header_h, color=GREY, filled=true,
        children={
            -- filename
            {type="label", x=5*lvSCALE, y=10*lvSCALE, text=function() return string.format("%s", filename or "---") end, color=WHITE, font=FS.FONT_6},

            -- settings button
            {type="button", x=LCD_W-80*lvSCALE, w=75*lvSCALE, y=2, h=33*lvSCALE, text="Settings", --color=BLACK,
                press=function()
                    show_settings = not show_settings
                    log("settings button pressed: %s, show_settings: %s",i, show_settings)
                    return (show_settings==true) and 1 or 0
                end
            },

            -- cusror position
            {type="choice", x=LCD_W-220*lvSCALE, y=2, w=75*lvSCALE, h=32*lvSCALE, title="Cursor Position",
                popupWidth = 30*lvSCALE,
                values = {"<<<", "Center", ">>>"},
                get = function() return cursor_data.cursor_pos_idx; end,
                set = function(i)
                    log("Selected cursor position index: i=%d", i)
                    cursor_data.cursor_pos_idx = i

                    if i == 1 then
                        cursor_data.cursor_x = 20*lvSCALE
                    elseif i == 2 then
                        cursor_data.cursor_x = LCD_W /2
                    elseif i == 3 then
                        cursor_data.cursor_x = LCD_W - 30*lvSCALE
                    end
                    calc_graph_cursor()
                end ,
            },

            -- zoom level
            {type="choice", x=LCD_W-137*lvSCALE, y=2, w=50*lvSCALE, h=32*lvSCALE, title="Zoom",
                popupWidth = 30*lvSCALE,
                values = zoom_list,
                get = function() return filter_zoom_level_idx; end,
                set = function(i)
                    log("Selected zoom-level index: i=%d", i)
                    log("Selected zoom-level: %s", zoom_list[i])
                    filter_zoom_level = zoom_list[i]
                    filter_zoom_level_idx = i
                    log("Selected zoom-level: %s", filter_zoom_level)
                    graphConfig.reset_to_time = cursor_data.cursor_time_sec
                    graphConfig.zoomLevel = zoom_scale[i]
                    graphConfig.needReLayout = true
                end ,
            },

            -- {type="button", x=LCD_W-120*lvSCALE, y=2*lvSCALE, h=30*lvSCALE, text="Info", color=BLACK, press=function() log("info button pressed") return 0 end},

            -- {type="button", x=LCD_W-220*lvSCALE, y=2*lvSCALE, h=33*lvSCALE, text=" < ", color=BLACK,
            --     press=function()
            --         cursor_data.cursor_x = 15*lvSCALE
            --         calc_graph_cursor()
            --     end
            -- },
            -- {type="button", x=LCD_W-185*lvSCALE, y=2*lvSCALE, h=33*lvSCALE, text="  |  ", color=BLACK,
            --     press=function()
            --         cursor_data.cursor_x = LCD_W/2
            --         calc_graph_cursor()
            --     end
            -- },
            -- {type="button", x=LCD_W-145*lvSCALE, y=2*lvSCALE, h=33*lvSCALE, text=" > ", color=BLACK,
            --     press=function()
            --         cursor_data.cursor_x = LCD_W*0.85
            --         calc_graph_cursor()
            --     end
            -- },

        }
    })
    lvgl.image({x=LCD_W-100, y=LCD_H-24, w=100, h=16, file=APP_DIR.."/img/bg4.png"})
    lvgl.label({x=5*lvSCALE, y=LCD_H-24*lvSCALE, text="v" .. app_ver, color=GREY, font=FS.FONT_6})

    bGraph = lvgl.box({x=0, y=gArea_y,w=LCD_W, h=LCD_H-gArea_y,
        scrollDir=lvgl.SCROLL_HOR,
        scrolled = function(x, y)
            -- scrolling occurs
            log("Scrolled: x,y=%sx%s", x,y)
            -- graphConfig.x_scrool = x
            calc_graph_cursor()
        end,
        scrollTo = function()
            local x, y = bGraph:getScrollPos()
            graphConfig.center_pos.x = x
            graphConfig.center_pos.y = y

            if graphConfig.reset_to_time then
                local t = graphConfig.reset_to_time
                graphConfig.reset_to_time = nil -- reset after use
                -- scroll so that the cursor time stays under the cursor bar.
                -- add half a step to land in the middle of the target sample,
                -- avoiding float floor rounding to the previous sample.
                x = graphConfig.valPos2x(t * graphTimeBase) + graphConfig.xStep * 0.5 - cursor_data.cursor_x
                if x < 0 then x = 0 end
                log("scrollTo: reset_to_time: %s, cursor_x: %s, new_x: %s", t, cursor_data.cursor_x, x)
            end

            graphConfig.x_scrool = x
            return x, y
        end
    })

    -- lines
    for sensIdx = 1, 4, 1 do
        sens_data[sensIdx].build_ui_line(bGraph)
    end

    -- cursor line
    local y_c_line = 20*lvSCALE
    lvgl.vline({w=1*lvSCALE, h=gArea_h-y_c_line-20*lvSCALE, dashGap=5, dashWidth=5, color=WHITE,
        pos=function() return cursor_data.cursor_x, gArea_y+y_c_line end,
    })

    -- cursor time
    lvgl.label({color=WHITE, font=FS.FONT_8,
        pos=function() return cursor_data.cursor_x-17*lvSCALE, gArea_y end,
        text=function()
            local str_time = toDuration1(cursor_data.cursor_time_sec)
            if cursor_data.cursor_time_sec < 3600 then
                str_time = string.sub(str_time, 4)
            end
            return str_time or "--"
        end
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
    local h = 60*lvSCALE
    local bSettings=lvgl.box({x=LCD_W-settings_w, y=header_h, w=settings_w, h=settings_h, visible=function() return show_settings end})
    for sensIdx = 1, 4, 1 do
        local y_pos = 5*lvSCALE + (sensIdx-1)*(h+5*lvSCALE)

        bSettings:box({x=0, y=y_pos, w=settings_w, h=200,visible=function() return show_settings end,
            children={
                {type="rectangle", x=0, y=0, w=settings_w-2*settings_dx, h=h, color=graphConfigSens[sensIdx].color, filled=true, rounded=5, opacity=240},
                -- {type="label",     x=5*lvSCALE, y=2*lvSCALE, text=function() return string.format("[%s] %d-%d %s", sens_data[sensIdx].sensorName, sens_data[sensIdx].min, sens_data[sensIdx].max, sens_data[sensIdx].unit) end, color=BLACK, font=FS.FONT_8},
                {type="label",     x=5*lvSCALE, y=2*lvSCALE, text=function() return string.format("%s [%s]", sens_data[sensIdx].sensorName, sens_data[sensIdx].unit) end, color=BLACK, font=FS.FONT_8},
                {type="label",     x=5*lvSCALE, y=20*lvSCALE, text=function() return string.format("Max: %d %s", sens_data[sensIdx].max, sens_data[sensIdx].unit) end, color=BLACK, font=FS.FONT_6},
                {type="label",     x=5*lvSCALE, y=36*lvSCALE, text=function() return string.format("Min: %d %s", sens_data[sensIdx].min, sens_data[sensIdx].unit) end, color=BLACK, font=FS.FONT_6},

                -- {type="button", x=20*lvSCALE, y=25*lvSCALE, h=25*lvSCALE, text="-", color=BLACK,
                --     press=function()
                --         log("sens_data[sensIdx].max: %s", sens_data[sensIdx].max)
                --         sens_data[sensIdx].max = sens_data[sensIdx].max - 1
                --         graphConfig.needReLayout = true
                --     end
                -- },
                -- {type="button", x=40*lvSCALE, y=25*lvSCALE, h=25*lvSCALE, text="+", color=BLACK,
                --     press=function()
                --         log("sens_data[sensIdx].max: %s", sens_data[sensIdx].max)
                --         sens_data[sensIdx].max = sens_data[sensIdx].max + 1
                --         graphConfig.needReLayout = true
                --     end
                -- },
                {type="toggle", x=settings_w-65*lvSCALE, y=2*lvSCALE,
                    get = function()
                        return (sens_data[sensIdx].visible==true and 1 or 0)
                    end,
                    set = function(i)
                        sens_data[sensIdx].visible = (i==1) and true or false
                    end ,
                },
             }
        })
    end

    -- dynamic scale indicator (like google maps)
    lvgl.box({x=math.floor(LCD_W/2 - LCD_W/7), y=LCD_H - 30 * lvSCALE,
        children={
            {type="label", font=FS.FONT_6, color=LIGHTGREY, text=function() return scale_info.label end,
                pos=function() return scale_info.w/2 -20, 0 end
            },
            {type="hline", color=LIGHTGREY,
                pos=function() return 0, 18*lvSCALE end,
                size=function() return scale_info.w, 2*lvSCALE end
            },
            {type="vline", color=LIGHTGREY,
                pos=function() return 0, 11*lvSCALE end,
                size=function() return 2 * lvSCALE, 12*lvSCALE end
            },
            {type="vline", color=LIGHTGREY,
                pos=function() return scale_info.w, 11*lvSCALE end,
                size=function() return 2 * lvSCALE, 12*lvSCALE end
            },
        }
    })


    -- debug info
    lvgl.box({x=10, y=150, visible=function() return show_dbg end,
        children={
            -- {type="label", x=0, y=0,  text=function() return string.format("graph: start: %d, graphSize: %d", graphStart, graphSize) end, font=FS.FONT_6, color=LIGHTGREY},
            {type="label", x=0, y=15*lvSCALE, text=function() return string.format("graph: zoomLevel: %.2f", graphConfig.zoomLevel) end, font=FS.FONT_6, color=LIGHTGREY},
            {type="label", x=0, y=30*lvSCALE, text=function() return string.format("graph: xStep: %.2f", sens_data[1].xStep) end, font=FS.FONT_6, color=LIGHTGREY},
            {type="label", x=0, y=45*lvSCALE, text=function() return string.format("load: %s%%", getUsage()) end, font=FS.FONT_6, color=LIGHTGREY},
            {type="label", x=0, y=60*lvSCALE, text=function() return string.format("cursor: x=%s, time=%s", cursor_data.cursor_pos_idx, cursor_data.cursor_time_sec) end, font=FS.FONT_6, color=LIGHTGREY},
        }
    })

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

    local adjust = 0 - getValue('ail')
    if math.abs(adjust) > 100 then
        local x, y = bGraph:getScrollPos()
        log("scrollTo: scroll: %sx%s, adjust: %s", x,y,adjust//10)

        -- bGraph:scrollTo({x=x+adjust//10, y=y})
        -- bGraph:scrollTo(x+adjust//10, y)
        -- graphConfig.x_scrool = graphConfig.x_scrool + adjust//10
        -- run_GRAPH_adjust_zoom(adjust)
    end

    local x, y = bGraph:getScrollPos()
    -- log("run_GRAPH_Adjust: scroll: %sx%s", x,y)

    if graphConfig.needReLayout then
        recalculateGraph()
    end

    -- log("load: %s%%", getUsage())

    return 0
end

return M

