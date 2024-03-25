--- - #########################################################################
---- #                                                                       #
---- # Copyright (C) OpenTX                                                  #
---- #                                                                       #
---- # License GPLv2: http://www.gnu.org/licenses/gpl-2.0.html               #
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

chdir("/SCRIPTS/TOOLS/FrSky_S8R_S6R")

-- based on FrSky version 2.01
local version = "v2.06-etx"

local VALUE = 0
local COMBO = 1
local HEADER = 2

local COLUMN_2 = 300

local edit = false
local page = 1
local current = 1
local refreshState = 0
local refreshIndex = 0
local calibrationState = 0
local pageOffset = 0
local calibrationStep = 0
local pages = {}
local fields = {}
local modifications = {}
local wingBitmaps = {}
local mountBitmaps = {}
local margin = 10
local spacing = 22
local numberPerPage = 11
local touch_d0 = 0
local is_gyro_enabled = 1

local FieldsGroup1 = {
    --{"Enable/Disable Gyro", COMBO, 0x9C, nil, {"Gyro Disabled", "Gyro Enabled" }                               , nil, 1 },
    {"Enable/Disable Gyro", COMBO, 0x9C, nil, {"OFF", "ON" }                                                   , nil, 1 },
    { "Wing type"         , COMBO, 0x80, nil, {"Normal", "Delta", "VTail" }                                    , nil, 1 },
    { "Mounting type"     , COMBO, 0x81, nil, {"Horizon", "Horizon Reversed", "Vertical", "Vertical Reversed" }, nil, 1 },
}

local wingBitmapsFile = { "bmp/plane.bmp", "bmp/delta.bmp", "bmp/vtail.bmp" }
local mountBitmapsFile = { "bmp/horz.bmp", "bmp/horz-r.bmp", "bmp/vert.bmp", "bmp/vert-r.bmp" }

local FieldsGroup2 = {
    --{"Receiver Gyro Functions", COMBO, 0x9C, nil, { "Disabled", "Enabled" } },
    {"Modes", HEADER},
    {"    Mode (Quick Mode):", COMBO, 0xAA, nil, {"Full (with hover & knife)", "Simple (no hover, no knife)"} },
    {"    CH5 mode"          , COMBO, 0xA8, nil, {"CH5 as AIL2", "CH5 not control by gyro"}                 },
    {"    CH6 mode"          , COMBO, 0xA9, nil, {"CH6 as ELE2", "CH6 not control by gyro"}                 },

    {"Main stabilization", HEADER},
    {"    Gain: AIL", VALUE, 0x85, nil, 0, 200, 1, "%"},
    {"    Gain: ELE", VALUE, 0x86, nil, 0, 200, 1, "%"},
    {"    Gain: RUD", VALUE, 0x87, nil, 0, 200, 1, "%"},

    {"Directions", HEADER},
    {"    Directions: AIL" , COMBO, 0x82, nil, {"Normal", "Inverted"}, {255, 0}, 1 },
    {"    Directions: ELE" , COMBO, 0x83, nil, {"Normal", "Inverted"}, {255, 0}, 1 },
    {"    Directions: RUD" , COMBO, 0x84, nil, {"Normal", "Inverted"}, {255, 0}, 1 },
    {"    Directions: AIL2", COMBO, 0x9A, nil, {"Normal", "Inverted"}, {255, 0}, 1 },
    {"    Directions: ELE2", COMBO, 0x9B, nil, {"Normal", "Inverted"}, {255, 0}, 1 },

    {"Auto Level:", HEADER},
    {"    Gain: AIL"  , VALUE, 0x88, nil,   0, 200, 1, "%"},
    {"    Gain: ELE"  , VALUE, 0x89, nil,   0, 200, 1, "%"},
    {"    Offset: AIL", VALUE, 0x91, nil, -20,  20, 1, "%", 0x6C},
    {"    Offset: ELE", VALUE, 0x92, nil, -20,  20, 1, "%", 0x6C},

    {"Hover:", HEADER},
    {"    Gain: ELE"  , VALUE, 0x8C, nil,   0, 200, 1, "%"},
    {"    Gain: RUD"  , VALUE, 0x8D, nil,   0, 200, 1, "%"},
    {"    Offset: ELE", VALUE, 0x95, nil, -20,  20, 1, "%", 0x6C},
    {"    Offset: RUD", VALUE, 0x96, nil, -20,  20, 1, "%", 0x6C},

    {"Knife Edge:"   , HEADER},
    {"    Gain: AIL"  , VALUE, 0x8E, nil,   0, 200, 1, "%"},
    {"    Gain: RUD"  , VALUE, 0x90, nil,   0, 200, 1, "%"},
    {"    Offset: AIL", VALUE, 0x97, nil, -20,  20, 1, "%", 0x6C},
    {"    Offset: RUD", VALUE, 0x99, nil, -20,  20, 1, "%", 0x6C},
}

local function is_simulator()
    local _, rv = getVersion()
    return string.sub(rv, -5) == "-simu"
end

local function drawScreenTitle(title, page, pages)
    --if math.fmod(math.floor(getTime() / 100), 10) == 0 then
    --    title = version
    --end
    lcd.drawFilledRectangle(0, 0, LCD_W, 30, TITLE_BGCOLOR)
    lcd.drawText(50, 5, title.. " - "..version, MENU_TITLE_COLOR)
    lcd.drawText(LCD_W - 40, 5, page .. "/" .. pages, MENU_TITLE_COLOR)
end

-- Change display attribute to current field
local function addField(step)
    local field = fields[current]
    local min, max
    if field[2] == VALUE then
        min = field[5]
        max = field[6]
    elseif field[2] == COMBO then
        min = 0
        max = #(field[5]) - 1
    elseif field[2] == HEADER then
        min = 0
        max = 0
    end
    if (step < 0 and field[4] > min) or (step > 0 and field[4] < max) then
        field[4] = field[4] + step
    end
end

-- Select the next or previous page
local function selectPage(step)
    if page == 1 and step < 0 then
        return
    end
    if page + step > #pages then
        return
    end
    page = page + step
    refreshIndex = 0
    calibrationStep = 0
    pageOffset = 0
end

-- Select the next or previous editable field
local function selectField(step)
    if step < 0 and current+step >= 1 then
        current = current + step
    elseif step > 0 and current+step <= #fields then
        current = current + step
    end

    if current > numberPerPage + pageOffset then
        pageOffset = current - numberPerPage
    elseif current <= pageOffset then
        pageOffset = current - 1
    end
end

local function drawProgressBar()
    local width = (100 * refreshIndex) / #fields
    lcd.drawRectangle(330, 12, 100, 8, GREY)
    lcd.drawFilledRectangle(331, 12, width, 6, GREY)
end

-- Redraw the current page
local function redrawFieldsPage(event, touchState)
    lcd.clear()
    lcd.drawFilledRectangle(0,0, LCD_W, LCD_H, LIGHTWHITE);
    drawScreenTitle("FrSky S8R/S6R Gyro setup", page, #pages)

    if refreshIndex < #fields then
        drawProgressBar()
    end

    for index = 1, numberPerPage, 1 do
        local field = fields[pageOffset + index]
        if field == nil then
            break
        end

        local attr = current == (pageOffset + index) and ((edit == true and BLINK or 0) + INVERS) or 0

        -- debugging in simulator
        if is_simulator() and field[4] == nil then
            if field[2] == VALUE then
                field[4] = field[5]
            elseif field[2] == COMBO then
                field[4] = 0
            end
        end

        if field[2] == HEADER then
            attr = attr + BOLD
        end

        if field[7] == nil or field[7] == 1 then
            lcd.drawText(10, margin + spacing * index, field[1], attr)

            if field[4] == nil and field[2] ~= HEADER then
                lcd.drawText(280, margin + spacing * index, "---", attr)
            else
                if field[2] == VALUE then
                    lcd.drawNumber(280, margin + spacing * index, field[4], attr)
                elseif field[2] == COMBO then
                    if field[4] >= 0 and field[4] < #(field[5]) then
                        lcd.drawText(280, margin + spacing * index, field[5][1 + field[4]], attr)
                    end
                end
            end
        end

        if index == 1 and is_gyro_enabled == 0 then
            lcd.drawText(120, 120, "Gyro Disabled", DBLSIZE + GREY)
            lcd.drawText(20, 160, "Receiver operate as simple RX", DBLSIZE + GREY)
        end

    end
end

local function telemetryRead(field)
    return sportTelemetryPush(0x17, 0x30, 0x0C30, field)
end

local function telemetryWrite(field, value)
    return sportTelemetryPush(0x17, 0x31, 0x0C30, field + value * 256)
end

local telemetryPopTimeout = 0
local function refreshNext()
    if refreshState == 0 then
        if #modifications > 0 then
            telemetryWrite(modifications[1][1], modifications[1][2])
            modifications[1] = nil
        elseif refreshIndex < #fields then
            local field = fields[refreshIndex + 1]
            if field[2] == HEADER then
                refreshIndex = refreshIndex + 1
                field = fields[refreshIndex + 1]
            end

            if field[4] == nil then
                if telemetryRead(field[3]) == true then
                    refreshState = 1
                    telemetryPopTimeout = getTime() + 500 -- normal delay is 500ms
                end
            else
                refreshIndex = refreshIndex + 1
                refreshState = 0
            end
        else
            refreshIndex = 0
            refreshState = 0
        end
    elseif refreshState == 1 then
        local physicalId, primId, dataId, value = sportTelemetryPop()
        if physicalId == 0x1A and primId == 0x32 and dataId == 0x0C30 then
            local fieldId = value % 256
            if calibrationState == 2 then
                if fieldId == 0x9D then
                    refreshState = 0
                    calibrationState = 0
                    calibrationStep = (calibrationStep + 1) % 7
                end
            else
                local field = fields[refreshIndex + 1]
                if fieldId == field[3] then
                    value = math.floor(value / 256)
                    if field[3] == 0xAA then
                        value = bit32.band(value, 0x0001)
                    end
                    if field[3] >= 0x9E and field[3] <= 0xA0 then
                        local b1 = value % 256
                        local b2 = math.floor(value / 256)
                        value = b1 * 256 + b2
                        value = value - bit32.band(value, 0x8000) * 2
                    end
                    if field[2] == COMBO and #field >= 6 and field[6] ~= nil then
                        for index = 1, #(field[6]), 1 do
                            if value == field[6][index] then
                                value = index - 1
                                break
                            else
                                value = 0
                            end
                        end
                    elseif field[2] == COMBO then
                        if value >= #field[5] then
                            value = #field[5] - 1
                        end
                    elseif field[2] == VALUE and #field >= 9 and field[9] then
                        value = value - field[9] + field[5]
                    end
                    fields[refreshIndex + 1][4] = value
                    refreshIndex = refreshIndex + 1
                    refreshState = 0
                end
            end
        elseif getTime() > telemetryPopTimeout then
            fields[refreshIndex + 1][4] = nil
            refreshIndex = refreshIndex + 1
            refreshState = 0
            calibrationState = 0
        end
    end
end

local function updateField(field)
    local value = field[4]
    if field[2] == COMBO and #field >= 6 and field[6] ~= nil  then
        value = field[6][1 + value]
    elseif field[2] == VALUE and #field >= 9 and field[9] then
        value = value + field[9] - field[5]
    end
    modifications[#modifications + 1] = { field[3], value }
end

-- Main
local function runFieldsPage(event, touchState)
    if event == EVT_VIRTUAL_EXIT then -- exit script
        return 2
    elseif event == EVT_VIRTUAL_ENTER then -- toggle editing/selecting current field
        if fields[current][4] ~= nil then
            edit = not edit
            if edit == false then
                updateField(fields[current])
            end
        end
    elseif edit then
        if event == EVT_VIRTUAL_INC or event == EVT_VIRTUAL_INC_REPT then
            addField(1)
        elseif event == EVT_VIRTUAL_DEC or event == EVT_VIRTUAL_DEC_REPT then
            addField(-1)
        end
    else
        if event == EVT_VIRTUAL_NEXT then
            selectField(1)
        elseif event == EVT_VIRTUAL_PREV then
            selectField(-1)
        elseif event == EVT_TOUCH_FIRST then
            touch_d0 = 0
        elseif event == EVT_TOUCH_SLIDE and page==2 then
            local d = math.floor((touchState.startY - touchState.y) / 20 + 0.5)
            if d < touch_d0 then
                if pageOffset > 0 then
                    pageOffset = pageOffset -1
                end
                touch_d0 = d
            elseif d > touch_d0 then
                if pageOffset < #fields - numberPerPage then
                    pageOffset = pageOffset +1
                end
                touch_d0 = d
            end
        end

    end
    redrawFieldsPage(event, touchState)
    return 0
end

local function runConfigPage(event, touchState)
    fields = FieldsGroup1

    if fields[1][4] == 1 then
        is_gyro_enabled = 1
        fields[1][7] = 1
        fields[2][7] = 1
        fields[3][7] = 1
    else
        is_gyro_enabled = 0
        fields[1][7] = 1
        fields[2][7] = 0
        fields[3][7] = 0
    end

    local result = runFieldsPage(event, touchState)

    if is_gyro_enabled == 1 then
        if fields[2][4] ~= nil then
            if wingBitmaps[1 + fields[2][4]] == nil then
                wingBitmaps[1 + fields[2][4]] = Bitmap.open(wingBitmapsFile[1 + fields[2][4]])
            end
            lcd.drawBitmap(wingBitmaps[1 + fields[2][4]], 10, 90)
        end
        if fields[3][4] ~= nil then
            if mountBitmaps[1 + fields[3][4]] == nil then
                mountBitmaps[1 + fields[3][4]] = Bitmap.open(mountBitmapsFile[1 + fields[3][4]])
            end
            lcd.drawBitmap(mountBitmaps[1 + fields[3][4]], 190, 110)
        end
    end

    return result
end

local function runSettingsPage(event, touchState)
    fields = FieldsGroup2
    return runFieldsPage(event, touchState)
end

local function runInfoPage(event, touchState)
    lcd.clear()
    lcd.drawFilledRectangle(0,0, LCD_W, LCD_H, LIGHTWHITE);
    drawScreenTitle("FrSky S8R/S6R Gyro setup", page, #pages)
    lcd.drawText(80, 30, "Switches Reminder", DBLSIZE)
    lcd.drawText(20, 70, "CH9: Gain", BLACK)
    lcd.drawText(20, 90, "CH10: +100 => stability disabled", BLACK)
    lcd.drawText(20, 110, "CH10: 0 => wind rejection", BLACK)
    lcd.drawText(20, 130, "CH10: -100 => self level", BLACK)
    lcd.drawText(20, 150, "CH12: SW down => panic mode", BLACK)
    lcd.drawText(20, 170, "CH12 x3 times: activate self-check ", BLACK)
    return 0
end

-- Init
local function init()
    current, edit, refreshState, refreshIndex = 1, false, 0, 0
    wingBitmapsFile = { "img/plane_b.png", "img/delta_b.png", "img/planev_b.png" }
    mountBitmapsFile = { "img/up.png", "img/down.png", "img/vert.png", "img/vert-r.png" }

    pages = {
        runConfigPage,
        runSettingsPage,
        runInfoPage,
    }
end

-- Main
local function run(event, touchState)
    if event == nil then
        error("Cannot be run as a model script!")
        return 2
    elseif event == EVT_VIRTUAL_NEXT_PAGE and is_gyro_enabled == 1 then
        selectPage(1)
    elseif event == EVT_VIRTUAL_PREV_PAGE then
        killEvents(event)
        selectPage(-1)
    end

    local result = pages[page](event, touchState)
    refreshNext()

    return result
end

return { init = init, run = run }

