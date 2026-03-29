local args = {...}
local APP_DIR = args[1]
local m_log = args[2]
local app_name = args[3]
local m_utils = args[4]
local m_tables = args[5]
local m_lib_file_parser = args[6]
local app_ver = args[7]


-- local tap_count = 0
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

local timeline_marks = {}

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
    needReLayout = false,
}

local cursor_data = {
    cursor_x = LCD_W / 2,
    cursor_time_sec = 0,
    cursor_pos_idx = 2, -- 1: left, 2: center, 3: right
    vals = {
        {x1 = 0, y1 = 0, v_txt = "---", txt_w = 0, rank = 0},
        {x1 = 0, y1 = 0, v_txt = "---", txt_w = 0, rank = 1},
        {x1 = 0, y1 = 0, v_txt = "---", txt_w = 0, rank = 2},
        {x1 = 0, y1 = 0, v_txt = "---", txt_w = 0, rank = 3},
    },
    visible = true,
    -- is_dragging = false,
    labels_box = {
        dx = 40*lvSCALE, -- x + 40*lvSCALE,
        y = 130*lvSCALE,
        w = 130*lvSCALE,
        h = 105*lvSCALE,
    }

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
    -- log("calc_graph_cursor cursor_time_sec: %s, cursorValPos: %s, cursorFrac: %.2f", cursor_data.cursor_time_sec, cursorValPos, cursorFrac)

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

    -- sort sensor labels vertically by value: higher value (smaller cursor_y) ? smaller rank ? higher on screen
    local active_sens = {}
    for i = 1, 4 do
        if sens_data[i].isUsedAndReady() then
            active_sens[#active_sens + 1] = i
        end
    end
    table.sort(active_sens, function(a, b)
        return (sens_data[a].cursor_y or 9999) < (sens_data[b].cursor_y or 9999)
    end)
    for rank_0 = 1, #active_sens do
        cursor_data.vals[active_sens[rank_0]].rank = rank_0 - 1
    end
    for i = 1, 4 do
        if not sens_data[i].isUsedAndReady() then
            cursor_data.vals[i].rank = i - 1
        end
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

local function calc_timeline(graphConfig)
    log("draw_timeline() timeline_marks count: %d", #timeline_marks)
    local px_per_sec = graphConfig.xStep * graphTimeBase
    -- adaptive tick: start at 10s, widen x3 until pixel spacing is readable
    local MIN_TICK_PX = 12 * lvSCALE
    local tick_sec = 10
    if px_per_sec > 0 then
        while tick_sec * px_per_sec < MIN_TICK_PX do
            tick_sec = tick_sec * 3
        end
    end
    -- find total data length (use longest active sensor)
    local data_count = 0
    for i = 1, 4 do
        if sens_data[i].isUsed() then
            data_count = math.max(data_count, sens_data[i].valsCount())
        end
    end
    -- fill marks for the entire graph
    timeline_marks = {}
    if px_per_sec <= 0 or graphTimeBase <= 0 or data_count <= 0 then return end
    local total_sec = data_count / graphTimeBase
    local MIN_LABEL_PX = 40 * lvSCALE
    local label_on_minor = (tick_sec * px_per_sec >= MIN_LABEL_PX)
    local t = 0
    local tick_idx = 0
    while t <= total_sec + tick_sec do
        timeline_marks[#timeline_marks + 1] = {
            x          = math.floor(t * px_per_sec),
            t          = math.floor(t + 0.5),
            is_major   = (tick_idx % 3 == 0),
            show_label = (tick_idx % 3 == 0) or label_on_minor,
        }
        t = t + tick_sec
        tick_idx = tick_idx + 1
    end
end

local function recalculateGraph()
    log("recalculateGraph()")
    calc_graph_params()

    for sensIdx = 1, 4, 1 do
        sens_data[sensIdx].calc_graph_line(graphConfig) -- include clearLinePoints
    end
    calc_graph_cursor()
    calculate_scale_info()
    calc_timeline(graphConfig)

    graphConfig.needReLayout = false
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

            -- zoom button
            {type="button", x=LCD_W-160*lvSCALE, w=50*lvSCALE, y=2, h=33*lvSCALE, text=" + + + ",
                press=function()
                    log("zoom button + pressed")
                    filter_zoom_level_idx = filter_zoom_level_idx + 1
                    filter_zoom_level_idx = math.min(filter_zoom_level_idx, #zoom_list)
                    filter_zoom_level = zoom_list[filter_zoom_level_idx]
                    log("Selected zoom-level: %s", filter_zoom_level)
                    graphConfig.reset_to_time = cursor_data.cursor_time_sec
                    graphConfig.zoomLevel = zoom_scale[filter_zoom_level_idx]
                    graphConfig.needReLayout = true
                end
            },
            {type="button", x=LCD_W-220*lvSCALE, w=50*lvSCALE, y=2, h=33*lvSCALE, text=" - - - ",
                press=function()
                    log("zoom button - pressed")
                    filter_zoom_level_idx = filter_zoom_level_idx - 1
                    filter_zoom_level_idx = math.max(filter_zoom_level_idx, 1)
                    filter_zoom_level = zoom_list[filter_zoom_level_idx]
                    log("Selected zoom-level: %s", filter_zoom_level)
                    graphConfig.reset_to_time = cursor_data.cursor_time_sec
                    graphConfig.zoomLevel = zoom_scale[filter_zoom_level_idx]
                    graphConfig.needReLayout = true
                end
            },
            {type="button", x=LCD_W-310*lvSCALE, w=80*lvSCALE, y=2, h=33*lvSCALE, text="cursor off",
                press=function()
                    log("cursor button pressed")
                    cursor_data.visible = false
                    cursor_data.cursor_x = LCD_W /2 -- reset to center so the zoom will be around the center
                    log("cursor_data.visible: %s", cursor_data.visible)
                end
            },

            -- -- cusror position
            -- {type="choice", x=LCD_W-220*lvSCALE, y=2, w=75*lvSCALE, h=32*lvSCALE, title="Cursor Position",
            --     popupWidth = 30*lvSCALE,
            --     values = {"<<<", "Center", ">>>"},
            --     get = function() return cursor_data.cursor_pos_idx; end,
            --     set = function(i)
            --         log("Selected cursor position index: i=%d", i)
            --         cursor_data.cursor_pos_idx = i

            --         if i == 1 then
            --             cursor_data.cursor_x = 20*lvSCALE
            --         elseif i == 2 then
            --             cursor_data.cursor_x = LCD_W /2
            --         elseif i == 3 then
            --             cursor_data.cursor_x = LCD_W - 30*lvSCALE
            --         end
            --         calc_graph_cursor()
            --     end ,
            -- },

            -- -- zoom level
            -- {type="choice", x=LCD_W-137*lvSCALE, y=2, w=50*lvSCALE, h=32*lvSCALE, title="Zoom",
            --     popupWidth = 30*lvSCALE,
            --     values = zoom_list,
            --     get = function() return filter_zoom_level_idx; end,
            --     set = function(i)
            --         log("Selected zoom-level index: i=%d", i)
            --         log("Selected zoom-level: %s", zoom_list[i])
            --         filter_zoom_level = zoom_list[i]
            --         filter_zoom_level_idx = i
            --         log("Selected zoom-level: %s", filter_zoom_level)
            --         graphConfig.reset_to_time = cursor_data.cursor_time_sec
            --         graphConfig.zoomLevel = zoom_scale[i]
            --         graphConfig.needReLayout = true
            --     end ,
            -- },

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


    bGraph = lvgl.box({x=0, y=gArea_y,w=LCD_W, h=gArea_h,
        scrollDir=lvgl.SCROLL_HOR,
        scrolled = function(x, y)
            -- scrolling occurs
            -- log("Scrolled: x,y=%sx%s", x,y)
            -- graphConfig.x_scrool = x
            calc_graph_cursor()
        end,
        scrollTo = function()
            -- if cursor_data.is_dragging then
            --     return cursor_data.last_non_scroll_x, cursor_data.last_non_scroll_y
            -- end
            local x, y = bGraph:getScrollPos()
            graphConfig.center_pos.x = x
            graphConfig.center_pos.y = y
            -- cursor_data.last_non_scroll_x = x
            -- cursor_data.last_non_scroll_y = y

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



    -- -- dynamic scale indicator (like google maps)
    -- lvgl.box({x=math.floor(LCD_W/2 - LCD_W/7), y=TIMELINE_Y - 30 * lvSCALE,
    --     children={
    --         {type="label", font=FS.FONT_6, color=LIGHTGREY, text=function() return scale_info.label end,
    --             pos=function() return scale_info.w/2 -20, 0 end
    --         },
    --         {type="hline", color=LIGHTGREY,
    --             pos=function() return 0, 18*lvSCALE end,
    --             size=function() return scale_info.w, 2*lvSCALE end
    --         },
    --         {type="vline", color=LIGHTGREY,
    --             pos=function() return 0, 11*lvSCALE end,
    --             size=function() return 2 * lvSCALE, 12*lvSCALE end
    --         },
    --         {type="vline", color=LIGHTGREY,
    --             pos=function() return scale_info.w, 11*lvSCALE end,
    --             size=function() return 2 * lvSCALE, 12*lvSCALE end
    --         },
    --     }
    -- })

    -- timeline ticks & labels
    -- timeline
    local TIMELINE_H = 28*lvSCALE
    local TIMELINE_Y = LCD_H - TIMELINE_H

    calc_timeline(graphConfig)
    local timeline_slot_count = #timeline_marks
    -- lvgl.rectangle({x=0, y=TIMELINE_Y, w=LCD_W, h=TIMELINE_H, color=BLACK, filled=true, opacity=130})
    lvgl.rectangle({x=0, y=TIMELINE_Y, w=LCD_W, h=1*lvSCALE, color=GREY, filled=true})
    for s = 1, timeline_slot_count do
        local slot = s
        bGraph:vline({
            pos=function()
                local m = timeline_marks[slot]
                if not m then return -9999, gArea_h - TIMELINE_H end
                -- local tick_y = m.is_major and (gArea_h - TIMELINE_H + 2*lvSCALE) or (gArea_h - TIMELINE_H + 5*lvSCALE)
                local tick_y = gArea_h - TIMELINE_H
                return m.x, tick_y
            end,
            size=function()
                local m = timeline_marks[slot]
                if not m then return 1*lvSCALE, 8*lvSCALE end
                local tick_h = m.is_major and 10*lvSCALE or 4*lvSCALE
                return 1*lvSCALE, tick_h
            end,
            color=LIGHTGREY,
        })
        bGraph:label({
            pos=function()
                local m = timeline_marks[slot]
                if not m or not m.show_label then
                    return -9999, gArea_h - TIMELINE_H
                end
                return m.x - 15*lvSCALE, gArea_h - 24*lvSCALE
            end,
            text=function()
                local m = timeline_marks[slot]
                if not m or not m.show_label then return "" end
                local str = toDuration1(m.t)
                if m.t < 3600 then str = string.sub(str, 4) end
                return str
            end,
            visible=function()
                local m = timeline_marks[slot]
                return m ~= nil and m.show_label == true
            end,
            color=LIGHTGREY,
            font=FS.FONT_6,
        })
    end

    -- lines
    for sensIdx = 1, 4, 1 do
        sens_data[sensIdx].build_ui_line(bGraph)
    end

    local bCursorLabels = lvgl.rectangle({
        pos=function() return cursor_data.cursor_x + cursor_data.labels_box.dx, cursor_data.labels_box.y end,
        w=cursor_data.labels_box.w, h=cursor_data.labels_box.h,
        filled=true, rounded=8 ,color=LIGHTGREY, opacity=150,
        visible=function() return cursor_data.visible end
    })

    -- cursor line
    local y_c_line = 20*lvSCALE
    lvgl.vline({w=1*lvSCALE, h=gArea_h-y_c_line-20*lvSCALE, dashGap=5, dashWidth=5, color=WHITE,
        pos=function() return cursor_data.cursor_x, gArea_y+y_c_line end,
        visible=function() return cursor_data.visible end
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
        end,
        visible=function() return cursor_data.visible end
    })

    -- cursor values
    for sensIdx = 1, 4, 1 do
        local valLabel_x = 30 + (sensIdx-1)*150*lvSCALE
        local valLabel_y = 2
        -- local valLabel_x = (sensIdx==1 or sensIdx==3) and LCD_W/2-100*lvSCALE-cursor_data.vals[sensIdx].txt_w or LCD_W/2+100*lvSCALE
        -- local valLabel_y = (sensIdx<=2) and 3*lvSCALE or gArea_h-30*lvSCALE

        local valLabel_x = cursor_data.cursor_x + 50*lvSCALE
        local valLabel_y_base = gArea_y + 100*lvSCALE

        if sens_data[sensIdx].isUsed() then
            lvgl.rectangle({
                pos=function()
                    return cursor_data.cursor_x + 50*lvSCALE, valLabel_y_base + cursor_data.vals[sensIdx].rank * 25*lvSCALE
                end,
                size=function() return cursor_data.vals[sensIdx].txt_w + 4*lvSCALE, 19*lvSCALE end,
                color=graphConfigSens[sensIdx].color,
                filled=true,
                rounded=3,
                visible=function() return sens_data[sensIdx].visible and cursor_data.visible end
            })

            lvgl.label({
                pos=function()
                    return cursor_data.cursor_x + 50*lvSCALE + 2, valLabel_y_base + cursor_data.vals[sensIdx].rank * 25*lvSCALE
                end,
                color=BLACK, font=FS.FONT_8,
                text=function() return cursor_data.vals[sensIdx].v_txt or "--" end,
                visible=function() return sens_data[sensIdx].visible and cursor_data.visible end
            })

            lvgl.line({
                pts=function() return {
                    {cursor_data.cursor_x, gArea_y + sens_data[sensIdx].cursor_y or 0},  -- vline side
                    {cursor_data.cursor_x + 50*lvSCALE, valLabel_y_base + cursor_data.vals[sensIdx].rank * 25*lvSCALE + 12*lvSCALE}  -- label side
                }
                end,
                color=function() return graphConfigSens[sensIdx].color end,
                thickness=1,
                dashGap=5, dashWidth=5,
                visible=function() return sens_data[sensIdx].visible and cursor_data.visible end
            })

            lvgl.circle({
                pos=function()
                    return cursor_data.cursor_x, gArea_y + sens_data[sensIdx].cursor_y or 0
                end,
                radius=4*lvSCALE,
                color=graphConfigSens[sensIdx].color,
                filled=true,
                visible=function() return sens_data[sensIdx].visible and cursor_data.visible end
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

    lvgl.rectangle({x=LCD_W-100, y=LCD_H-16, w=100, h=16, filled=true, color=BLACK})
    lvgl.image({x=LCD_W-100, y=LCD_H-16, w=100, h=16, file=APP_DIR.."/img/bg4.png"})
    lvgl.label({x=5*lvSCALE, y=TIMELINE_Y-16*lvSCALE, text="v" .. app_ver, color=GREY, font=FS.FONT_6})

    -- debug info
    lvgl.box({x=10, y=150, visible=function() return show_dbg end,
        children={
            -- {type="label", x=0, y=0,  text=function() return string.format("graph: start: %d, graphSize: %d", graphStart, graphSize) end, font=FS.FONT_6, color=LIGHTGREY},
            {type="label", x=0, y=15*lvSCALE, text=function() return string.format("graph: zoomLevel: %.2f", graphConfig.zoomLevel) end, font=FS.FONT_6, color=LIGHTGREY},
            {type="label", x=0, y=30*lvSCALE, text=function() return string.format("graph: xStep: %.2f", sens_data[1].xStep) end, font=FS.FONT_6, color=LIGHTGREY},
            {type="label", x=0, y=45*lvSCALE, text=function() return string.format("load: %s%%", getUsage()) end, font=FS.FONT_6, color=LIGHTGREY},
            {type="label", x=0, y=60*lvSCALE, text=function() return string.format("cursor: x=%s, time=%s", cursor_data.cursor_pos_idx, cursor_data.cursor_time_sec) end, font=FS.FONT_6, color=LIGHTGREY},
            -- {type="label", x=0, y=75*lvSCALE, text=function() return string.format("cursor.visible=%s (tap: %d)",cursor_data.visible, tap_count) end, font=FS.FONT_6, color=LIGHTGREY},
        }
    })

    return 0
end

local last_tap_time = -999  -- getTime() of last processed tap (units = 10 ms)

function M.state_SHOW_GRAPH(event, touchState)
    -- log("state_SHOW_GRAPH event: %s, touchState.tapCount: %s", event, touchState and touchState.tapCount or "---")
    -- show debug
    local switch_val = getValue('SA')
    -- log("event: %s, adjust: %d", event, switch_val)
    show_dbg = switch_val > 1000

    -- if event == EVT_TOUCH_FIRST then -- When the finger first hits the screen
    --     -- If the finger hit the square, then stick to it!

    --     -- log("1=%s (%s %s)", (touchState.x > cursor_data.cursor_x), touchState.x, cursor_data.cursor_x)
    --     -- log("2=%s", (touchState.x < cursor_data.cursor_x + cursor_data.labels_box.dx + cursor_data.labels_box.w))
    --     -- log("3=%s", (touchState.y > cursor_data.labels_box.y))
    --     -- log("4=%s", (touchState.y < cursor_data.labels_box.y + cursor_data.labels_box.h))
    --     log("1=%s (%s %s)", (touchState.x > 0), touchState.x, cursor_data.cursor_x)
    --     log("2=%s", (touchState.x < cursor_data.cursor_x + cursor_data.labels_box.dx + cursor_data.labels_box.w))
    --     log("3=%s", (touchState.y > 0))
    --     log("4=%s", (touchState.y < cursor_data.labels_box.y + cursor_data.labels_box.h))


    --     if      (touchState.x > 0)
    --         and (touchState.x < cursor_data.cursor_x + cursor_data.labels_box.dx + cursor_data.labels_box.w)
    --         and (touchState.y > 0) and (touchState.y < cursor_data.labels_box.y + cursor_data.labels_box.h)
    --         then
    --             cursor_data.is_dragging = true
    --             log("touch near cursor: x=%d, y=%d", touchState.x, touchState.y)
    --     end
    --     -- stick = (math.abs(touchState.x - x) < 0.5 * s and math.abs(touchState.y - y) < 0.5 * s)
    -- end

    -- if event == EVT_TOUCH_SLIDE then
    --     cursor_data.cursor_x = touchState.x
    --     log("slide: x=%d, y=%d, slideX=%d, slideY=%d", touchState.x, touchState.y, touchState.slideX, touchState.slideY)
    -- end

    -- if event == EVT_TOUCH_BREAK then -- When the finger first hits the screen
    --     cursor_data.is_dragging = false
    -- end
    -- if cursor_data.is_dragging == true then
    --     log("cursor_data.is_dragging: %s", cursor_data.is_dragging)
    -- end

    -- detect tap on graph area
    -- if event == EVT_TOUCH_TAP and touchState and touchState.tapCount==1 then
    --     cursor_data.visible = not cursor_data.visible
    --     log("tap on graph: x=%d, y=%d, cursor-visible=%s", touchState.x, touchState.y, cursor_data.visible)
    -- end
















    -- -- track physical touch start (fires exactly once per finger-down)
    -- if event == EVT_TOUCH_FIRST then
    --     tap_count = tap_count + 1
    -- end
    -- -- detect tap on graph area - guarded by time to suppress duplicate CLICKEDs
    -- local TAP_DEBOUNCE = 100  -- 30 x 10 ms = 300 ms
    -- if event == EVT_TOUCH_TAP and touchState and (getTime() - last_tap_time) > TAP_DEBOUNCE then
    --     tap_count = tap_count + 10
    --     last_tap_time = getTime()
    --     cursor_data.visible = not cursor_data.visible
    --     cursor_data.cursor_x = touchState.x
    --     log("tap: time=%d, x=%d, y=%d, visible=%s", last_tap_time, touchState.x, touchState.y, cursor_data.visible)
    -- end

    if event == EVT_TOUCH_TAP then
        cursor_data.visible = true
        cursor_data.cursor_x = touchState.x
        log("tap: time=%d, x=%d, y=%d, visible=%s", last_tap_time, touchState.x, touchState.y, cursor_data.visible)
    end


    -- -- zoom graph
    -- local amount = 0 - getValue('ele')
    -- if math.abs(amount) > 100 then
    --     local scale
    --     if graphConfig.zoomLevel < 10 then
    --         scale = 0.4
    --     elseif graphConfig.zoomLevel < 30 then
    --         scale = 0.6
    --     else
    --         scale = math.max(graphConfig.zoomLevel / 10, 1)
    --     end
    --     local delta = amount / 1024 * scale
    --     graphConfig.zoomLevel = graphConfig.zoomLevel + delta
    --     graphConfig.zoomLevel = math.max(graphConfig.zoomLevel, 5)
    --     graphConfig.zoomLevel = math.min(graphConfig.zoomLevel, 100)
    --     log("zoomLevel: %d (amount: %d, delta: %d)", graphConfig.zoomLevel, amount, delta)

    --     graphConfig.reset_to_time = cursor_data.cursor_time_sec
    --     graphConfig.needReLayout = true
    -- end

    -- local adjust = getValue('ail')
    -- if math.abs(adjust) > 100 then
    --     graphConfig.reset_to_time = cursor_data.cursor_time_sec + adjust / 1000 --/ graphTimeBase
    --     graphConfig.needReLayout = true
    -- end

    -- local x, y = bGraph:getScrollPos()
    -- log("run_GRAPH_Adjust: scroll: %sx%s", x,y)

    if graphConfig.needReLayout then
        recalculateGraph()
    end

    -- log("load: %s%%", getUsage())

    return 0
end

return M

