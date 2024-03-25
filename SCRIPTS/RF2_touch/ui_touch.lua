local LUA_VERSION = "2.0 - 240229"

local uiStatus =
{
    init     = 1,
    mainMenu = 2,
    pages    = 3,
    confirm  = 4,
}

local pageStatus =
{
    display = 1,
    editing = 2,
    saving  = 3,
}

local uiMsp =
{
    reboot = 68,
    eepromWrite = 250,
}

local uiState = uiStatus.init
local prevUiState
local pageState = pageStatus.display
local requestTimeout = 80
local currentPage = 1
local currentField = 1
local saveTS = 0
local saveTimeout = protocol.saveTimeout
local saveRetries = 0
local saveMaxRetries = protocol.saveMaxRetries
local popupMenuActive = 1
local killEnterBreak = 0
local pageScrollY = 0
local mainMenuScrollY = 0
local PageFiles, Page, init, popupMenu

local backgroundFill = TEXT_BGCOLOR or ERASE
local foregroundColor = LINE_COLOR or SOLID

local globalTextOptions = TEXT_COLOR or 0
local isHighResolutionColor
rfglobals = {}

-- better font size names
local FONT_SIZES = {
    FONT_38 = XXLSIZE, -- 38px
    FONT_16 = DBLSIZE, -- 16px
    FONT_12 = MIDSIZE, -- 12px
    FONT_8  = 0,       -- Default 8px
    FONT_6  = SMLSIZE, -- 6px
}

local gui = {
    btns = {
        -- save =   {id="save",   t="Save",   x=140, y=0, w=70, h=29, is_visible=false, is_enable=false },
        -- reload = {id="reload", t="Reload", x=220, y=0, w=70, h=29, is_visible=false, is_enable=false },
        menu =   {id="menu",   t="Menu",   x=220, y=0, w=70, h=29, is_visible=true, is_enable=true },
        esc =    {id="esc",    t="Back",   x=310, y=0, w=70, h=29, is_visible=false, is_enable=false},
        enter =  {id="enter",  t="Enter",  x=400, y=0, w=70, h=29, is_visible=false, is_enable=false },
    }
}

-- ---------------------------------------------------------------------
local function log(fmt, ...)
    print(string.format(fmt, ...))
end

local function drawButton(btn)
    local textColor = btn.is_enable and WHITE or GREY
    local buttonColor = btn.is_enable and DARK_GREY or LIGHT_GREY
    local borderColor = btn.is_enable and GREEN or GREY
    local borderWidth = 2
    lcd.drawFilledRectangle(btn.x, btn.y, btn.w, btn.h, buttonColor)
    lcd.drawRectangle(btn.x, btn.y, btn.w, btn.h, borderColor, borderWidth)
    lcd.drawText(btn.x + (btn.w / 2), btn.y + 6, btn.t, textColor + FONT_SIZES.FONT_6 + CENTER)
end

local function displayAllButtons(btns)
    for _, btn in pairs(btns) do
        if btn.is_visible then
            drawButton(btn)
        end
    end
end

local function activateButtonIfPressed(x, y, btns, callbackMap)
    for _, btn in pairs(btns) do
        if btn.is_enable == true and btn.is_visible == true then
            local x2 =btn.x + btn.w
            local y2 =btn.y + btn.h

            log("touch: isPressed: %s,%s ?= %s,%s, %s,%s", x,y, btn.x, x2, btn.y, y2)
            if x >= btn.x and x <= x2 and y >= btn.y and y <= y2 then

                log("touch: Pressed: %s %s", btn.t, btn.id)
                local callback = callbackMap[btn.id]
                if callback and type(callback) == "function" then
                    callback() -- Call the callback function
                end
                return btn
            end
        end
    end
    return nil -- No button was pressed
end


-- -------------------------------------------------------------------

local function saveSettings()
    if Page.values then
        local payload = Page.values
        if Page.preSave then
            payload = Page.preSave(Page)
        end
        protocol.mspWrite(Page.write, payload)
        saveTS = getTime()
        if pageState == pageStatus.saving then
            saveRetries = saveRetries + 1
        else
            pageState = pageStatus.saving
            saveRetries = 0
        end
    end
end

local function invalidatePages()
    Page = nil
    pageState = pageStatus.display
    saveTS = 0
    collectgarbage()
end

local function rebootFc()
    protocol.mspRead(uiMsp.reboot)
    invalidatePages()
end

local function eepromWrite()
    protocol.mspRead(uiMsp.eepromWrite)
end

local function confirm(page)
    prevUiState = uiState
    uiState = uiStatus.confirm
    invalidatePages()
    currentField = 1
    Page = assert(loadScript(page))()
    collectgarbage()
end

local function createPopupMenu()
    popupMenuActive = 1
    popupMenu = {}
    if uiState == uiStatus.pages then
        popupMenu[#popupMenu + 1] = { t = "save page", f = saveSettings }
        popupMenu[#popupMenu + 1] = { t = "reload", f = invalidatePages }
    end
    popupMenu[#popupMenu + 1] = { t = "reboot", f = rebootFc }
    popupMenu[#popupMenu + 1] = { t = "acc cal", f = function() confirm("CONFIRM/acc_cal.lua") end }
    --[[if apiVersion >= 1.42 then
        popupMenu[#popupMenu + 1] = { t = "vtx tables", f = function() confirm("CONFIRM/vtx_tables.lua") end }
    end
    --]]
end

function dataBindFields()
    for i=1,#Page.fields do
        if #Page.values >= Page.minBytes then
            local f = Page.fields[i]
            if f.vals then
                f.value = 0
                for idx=1, #f.vals do
                    local raw_val = Page.values[f.vals[idx]] or 0
                    raw_val = bit32.lshift(raw_val, (idx-1)*8)
                    f.value = bit32.bor(f.value, raw_val)
                end
                local bits = #f.vals * 8
                if f.min and f.min < 0 and bit32.btest(f.value, bit32.lshift(1, bits - 1)) then
                    f.value = f.value - (2 ^ bits)
                end
                f.value = f.value/(f.scale or 1)
            end
        end
    end
end

local function processMspReply(cmd,rx_buf,err)
    if not Page or not rx_buf then
    elseif cmd == Page.write then
        if Page.eepromWrite then
            eepromWrite()
        else
            invalidatePages()
        end
    elseif cmd == uiMsp.eepromWrite then
        if Page.reboot then
            rebootFc()
        end
        invalidatePages()
    elseif cmd == Page.read and err then
        Page.fields = { { x = 6, y = radio.yMinLimit, value = "", ro = true } }
        Page.labels = { { x = 6, y = radio.yMinLimit, t = "N/A" } }
    elseif cmd == Page.read and #rx_buf > 0 then
        Page.values = rx_buf
        if Page.postRead then
            Page.postRead(Page)
        end
        dataBindFields()
        if Page.postLoad then
            Page.postLoad(Page)
        end
    end
end

local function incMax(val, inc, base)
    return ((val + inc + base - 1) % base) + 1
end

-- local function detectHighResolutionColor()
--     local ver, radio, maj, minor, rev, osname = getVersion()
--     print(osname .. " version: " .. ver)

--     if osname ~= "EdgeTX" then
--         print("enhance gui is supported only on EdgeTX: " .. osname)
--         return false
--     end
--     if LCD_W ~= 480 then
--         print("enhance gui is supported only on color high res color screen")
--         return false
--     end
--     return true
-- end

-- ---------------------------------------------------------------------

local function markMenuScreenLocation(menu, txt_x, txt_y, txt_str)
    txt_str = menu.title

    -- keep on screen location
    local ts_w, ts_h = lcd.sizeText(txt_str, 0) -- 0=FONT_8
    local touch_sens_h = 1
    menu.on_screen = {
        x1 = 0, 
        y1 = txt_y - touch_sens_h, 
        x2 = 150, 
        y2 = txt_y + touch_sens_h + ts_h 
    }
    -- log("[%s] %s,%s",field.t, field.on_screen.x1,field.on_screen.y1)
    -- lcd.drawRectangle(menu.on_screen.x1, menu.on_screen.y1, menu.on_screen.x2 - menu.on_screen.x1, menu.on_screen.y2 - menu.on_screen.y1, RED)
end

local function selectMenuByTouch(x,y)
    log("search: ------------")
    log("search: %s,%s", x,y)
    for i=1,#PageFiles do
        local p = PageFiles[i]

        if (p.on_screen) then
            -- log("search: %s - %s,%s,%s,%s", p.t, p.on_screen.x1, p.on_screen.y1, p.on_screen.x2, p.on_screen.y2 )
            if (x > p.on_screen.x1 and x < p.on_screen.x2) and (y > p.on_screen.y1 and y < p.on_screen.y2) then                
                log("search: found!!! %s", p.t)

                currentPage = i
                currentField = 1
                invalidatePages()
                return
            end
        else
            log("search: %s", p.t)
        end

    end
end


local function markFieldScreenLocation(field, txt_x, txt_y, txt_str)
    -- keep on screen location
    local ts_w, ts_h = lcd.sizeText(txt_str, 0) -- 0=FONT_8
    -- ts_w = math.max(ts_w, 40)
    local touch_sens_w = math.max(32 - ts_w, 0)
    local touch_sens_h = 0
    field.on_screen = {
        x1 = txt_x - touch_sens_w,
        y1 = txt_y - touch_sens_h,
        x2 = txt_x + touch_sens_w + ts_w, 
        y2 = txt_y + touch_sens_h + ts_h 
    }
    log("[%s] %s,%s",field.t, field.on_screen.x1,field.on_screen.y1)
    -- lcd.drawRectangle(txt_x, txt_y, ts_w, ts_h, RED)
    -- lcd.drawRectangle(field.on_screen.x1, field.on_screen.y1, field.on_screen.x2 - field.on_screen.x1, field.on_screen.y2 - field.on_screen.y1, RED)
end

local function selectFieldByTouch(x,y)
    log("search: ------------")
    log("search: %s,%s", x,y)
    for i=1,#Page.fields do
        local f = Page.fields[i]

        if (f.on_screen) then
            log("search: %s - %s,%s,%s,%s", f.t, f.on_screen.x1, f.on_screen.y1, f.on_screen.x2, f.on_screen.y2 )
            if (x > f.on_screen.x1 and x < f.on_screen.x2) and (y > f.on_screen.y1 and y < f.on_screen.y2) then                
                log("search: found!!! %s", f.t)
                currentField = i
                return
            end
        else
            log("search: %s", f.t)
        end

    end
end

local function drawButtons()

end

local function drawProgressBar(field, Y, f_val, isInEdit)
    -- log("drawProgressBar2 [%s] y=%s, %s min/max: %s/%s)", field.t, Y, val, field.min, field.max)

    -- can not show on table, since many field on the same height, so show only when edit
    if field.t == nil and isInEdit==false then 
        return 
    end

    f_val = tonumber(f_val)
    if (f_val==nil) then
        return
    end

    -- range text
    local txt = string.format("[ %s .. %s ]", field.min/(field.scale or 1), field.max/(field.scale or 1))
    lcd.drawText(LCD_W - 120, Y, txt, SMLSIZE + RIGHT + GREY)

    local f_min = field.min / (field.scale or 1)
    local f_max = field.max / (field.scale or 1)
    local percent = (f_val - f_min) / (f_max - f_min)
    -- log("percent=%s", percent)
    -- log("isInEdit=%s", isInEdit)

    local bkg_col = LIGHTGREY
    local fg_col = lcd.RGB(0x00, 0xB0, 0xDC)
    if (isInEdit) then
        -- bkg_col = GREY
        bkg_col = lcd.RGB(0x2A, 0x2B, 0x2F)
    end
    
    local w = 100
    local h = 5
    local x = LCD_W - w - 5
    local y = Y + 7
    local px = (w - 2) * percent

    lcd.drawFilledRectangle(x, y+2, w, h, bkg_col)

    
    local r = 6
    if (isInEdit) then
        r = 8
    end
        -- lcd.drawFilledCircle(x + px - r/2, y + r/2, r+2, BLACK)
    lcd.drawFilledCircle(x + px - r/2, y + r/2, r, fg_col)

end


function clipValue(val,min,max)
    if val < min then
        val = min
    elseif val > max then
        val = max
    end
    return val
end

local function incPage(inc)
    currentPage = incMax(currentPage, inc, #PageFiles)
    currentField = 1
    invalidatePages()
end

local function incField(inc)
    currentField = clipValue(currentField + inc, 1, #Page.fields)
end

local function incMainMenu(inc)
    currentPage = clipValue(currentPage + inc, 1, #PageFiles)
end

local function incPopupMenu(inc)
    popupMenuActive = clipValue(popupMenuActive + inc, 1, #popupMenu)
end

local function requestPage()
    if Page.read and ((not Page.reqTS) or (Page.reqTS + requestTimeout <= getTime())) then
        Page.reqTS = getTime()
        protocol.mspRead(Page.read)
    end
end

local function drawScreenTitle(screenTitle)
    if radio.highRes then
        lcd.drawFilledRectangle(0, 0, LCD_W, 30, TITLE_BGCOLOR)
        lcd.drawText(5,5,screenTitle, MENU_TITLE_COLOR)

        -- display the buttons
        displayAllButtons(gui.btns)

        
    else
        lcd.drawFilledRectangle(0, 0, LCD_W, 10, FORCE)
        lcd.drawText(1,1,screenTitle,INVERS)
    end
end

local function getLineSpacing()
    if radio.highRes then
        return 25
    end
    return 10
end

local function drawTextMultiline(x, y, text, options)
    local lines = {}
    for str in string.gmatch(text, "([^\n]+)") do
        lcd.drawText(x, y, str, options)
        y = y + getLineSpacing()
    end
end

local function drawScreen()
    local yMinLim = radio.yMinLimit
    local yMaxLim = radio.yMaxLimit
    local currentFieldY = Page.fields[currentField].y
    local textOptions = radio.textSize + globalTextOptions
    if currentFieldY <= Page.fields[1].y then
        pageScrollY = 0
    elseif currentFieldY - pageScrollY <= yMinLim then
        pageScrollY = currentFieldY - yMinLim
    elseif currentFieldY - pageScrollY >= yMaxLim then
        pageScrollY = currentFieldY - yMaxLim
    end
    for i=1,#Page.labels do
        local f = Page.labels[i]
        local y = f.y - pageScrollY
        if y >= 0 and y <= LCD_H then
            local txt = f.t
            if f.t2 ~= nil then
                txt = f.t2                
            end
            lcd.drawText(f.x, y, txt, textOptions)
        end
    end
    local val = "---"
    for i=1,#Page.fields do
        local f = Page.fields[i]
        local valueOptions = textOptions
        if i == currentField then
            valueOptions = valueOptions + INVERS
            if pageState == pageStatus.editing then
                valueOptions = valueOptions + BLINK
            end
        end
        if f.value then
            if f.upd and Page.values then
                f.upd(Page)
            end
            val = f.value
            if f.table and f.table[f.value] then
                val = f.table[f.value]
            end
        end
        local y = f.y - pageScrollY
        
        if runningInSimulator then 
            val = math.floor((f.max + f.min) / (f.scale or 1) * 0.2)
        end 

        if y >= 0 and y <= LCD_H then
            if f.t then
                lcd.drawText(f.x, y, f.t, textOptions)
            end
            lcd.drawText(f.sp or f.x, y, val, valueOptions)

            -- on big screen, display min/max
            drawProgressBar(f, y, val, i == currentField)
            markFieldScreenLocation(f, f.sp or f.x, y, val)
        end
    end
    drawScreenTitle("Rotorflight / "..Page.title)
end

local function incValue(inc)
    local f = Page.fields[currentField]
    local scale = f.scale or 1
    local mult = f.mult or 1

    if runningInSimulator and f.value == nil then
        f.value = 0
    end 

    f.value = clipValue(f.value + inc*mult/scale, (f.min or 0)/scale, (f.max or 255)/scale)
    f.value = math.floor(f.value*scale/mult + 0.5)*mult/scale
    for idx=1, #f.vals do
        Page.values[f.vals[idx]] = bit32.rshift(math.floor(f.value*scale + 0.5), (idx-1)*8)
    end
    if f.upd and Page.values then
        f.upd(Page)
    end
end

local function drawPopupMenu()
    local x = radio.MenuBox.x
    local y = radio.MenuBox.y
    local w = radio.MenuBox.w
    local h_line = radio.MenuBox.h_line
    local h_offset = radio.MenuBox.h_offset
    local h = #popupMenu * h_line + h_offset*2

    lcd.drawFilledRectangle(x,y,w,h,backgroundFill)
    lcd.drawRectangle(x,y,w-1,h-1,foregroundColor)
    lcd.drawText(x+h_line/2,y+h_offset,"Menu:",globalTextOptions)

    for i,e in ipairs(popupMenu) do
        local textOptions = globalTextOptions
        if popupMenuActive == i then
            textOptions = textOptions + INVERS
        end
        lcd.drawText(x+radio.MenuBox.x_offset,y+(i-1)*h_line+h_offset,e.t,textOptions)
    end
end

local callbackMapMenu = {
    esc = function()
        log("touch: pressed esc")
    end,
    enter = function()
        log("touch: pressed enter")
        uiState = uiStatus.pages
    end,
    menu = function()
        log("touch: pressed menu")
        createPopupMenu()
    end,
}

local callbackMapField = {
    esc = function()
        log("touch: pressed esc")
        invalidatePages()
        currentField = 1
        uiState = uiStatus.mainMenu
    end,
    enter = function()
        log("touch: pressed enter")
        
        if pageState == pageStatus.display then
            -- elseif event == EVT_VIRTUAL_ENTER then
            if Page then
                local f = Page.fields[currentField]
                if (Page.values and f.vals and Page.values[f.vals[#f.vals]] and not f.ro) or (runningInSimulator) then
                    pageState = pageStatus.editing
                end
            end
        elseif pageState == pageStatus.editing then
            if Page.fields[currentField].postEdit then
                Page.fields[currentField].postEdit(Page)
            end
            pageState = pageStatus.display
            
        end
    end,
    menu = function()
        log("touch: pressed menu")
        createPopupMenu()
    end,
}


local function run_ui(event, touchState)
    -- log("run_ui: [%s] [%s]", event, touchState)
    if popupMenu then
        drawPopupMenu()
        if event == EVT_VIRTUAL_EXIT then
            popupMenu = nil
        elseif event == EVT_VIRTUAL_PREV then
            incPopupMenu(-1)
        elseif event == EVT_VIRTUAL_NEXT then
            incPopupMenu(1)
        elseif event == EVT_VIRTUAL_ENTER then
            if killEnterBreak == 1 then
                killEnterBreak = 0
            else
                popupMenu[popupMenuActive].f()
                popupMenu = nil
            end
        end
    elseif uiState == uiStatus.init then
        lcd.clear()
        drawScreenTitle("Rotorflight "..LUA_VERSION)
        init = init or assert(loadScript("ui_init.lua"))()
        drawTextMultiline(4, radio.yMinLimit, init.t)
        if not init.f() then
            return 0
        end
        init = nil
        PageFiles = assert(loadScript("pages.lua"))()
        invalidatePages()
        uiState = prevUiState or uiStatus.mainMenu
        prevUiState = nil
    elseif uiState == uiStatus.mainMenu then
        --  buttons setting
        gui.btns.esc.is_visible=true
        gui.btns.esc.is_enable=false
        gui.btns.enter.is_visible=true
        gui.btns.enter.is_enable=true

        if event == EVT_VIRTUAL_EXIT then
            return 2
        elseif event == EVT_VIRTUAL_NEXT then
            incMainMenu(1)
        elseif event == EVT_VIRTUAL_PREV then
            incMainMenu(-1)
        elseif event == EVT_VIRTUAL_ENTER then
            uiState = uiStatus.pages
        elseif event == EVT_VIRTUAL_ENTER_LONG then
            killEnterBreak = 1
            createPopupMenu()
        elseif event == EVT_TOUCH_FIRST then
                log("EVT_TOUCH_FIRST: %s,%s", touchState.x, touchState.y)
                lcd.drawRectangle(touchState.x, touchState.y,20,20,SOLID)
                selectMenuByTouch(touchState.x, touchState.y)
                activateButtonIfPressed(touchState.x, touchState.y, gui.btns, callbackMapMenu)
        end
        lcd.clear()
        local yMinLim = radio.yMinLimit
        local yMaxLim = radio.yMaxLimit
        local lineSpacing = getLineSpacing()
        local currentFieldY = (currentPage-1)*lineSpacing + yMinLim
        if currentFieldY <= yMinLim then
            mainMenuScrollY = 0
        elseif currentFieldY - mainMenuScrollY <= yMinLim then
            mainMenuScrollY = currentFieldY - yMinLim
        elseif currentFieldY - mainMenuScrollY >= yMaxLim then
            mainMenuScrollY = currentFieldY - yMaxLim
        end
        for i=1, #PageFiles do
            local attr = currentPage == i and INVERS or 0
            local y = (i-1)*lineSpacing + yMinLim - mainMenuScrollY
            if y >= 0 and y <= LCD_H then
                lcd.drawText(6, y, PageFiles[i].title, attr)                
                markMenuScreenLocation(PageFiles[i], 6, y)
            end
        end
        drawScreenTitle("Rotorflight "..LUA_VERSION)
    
        -- ??? for testing
        if event == EVT_TOUCH_FIRST then
            log("EVT_TOUCH_FIRST: %s,%s", touchState.x, touchState.y)
            local touch_sens_r = 15
            lcd.drawFilledCircle(touchState.x, touchState.y, touch_sens_r,SOLID+GREY)
        end


    elseif uiState == uiStatus.pages then
        gui.btns.esc.is_visible=true
        gui.btns.esc.is_enable=true
        gui.btns.enter.is_visible=true
        gui.btns.enter.is_enable=true

        if pageState == pageStatus.saving then
            if saveTS + saveTimeout < getTime() then
                if saveRetries < saveMaxRetries then
                    saveSettings()
                else
                    pageState = pageStatus.display
                    invalidatePages()
                end
            end
        elseif pageState == pageStatus.display then
            if event == EVT_VIRTUAL_PREV_PAGE then
                incPage(-1)
                killEvents(event) -- X10/T16 issue: pageUp is a long press
            elseif event == EVT_VIRTUAL_NEXT_PAGE then
                incPage(1)
            elseif event == EVT_VIRTUAL_PREV or event == EVT_VIRTUAL_PREV_REPT then
                incField(-1)
            elseif event == EVT_VIRTUAL_NEXT or event == EVT_VIRTUAL_NEXT_REPT then
                incField(1)
            elseif event == EVT_VIRTUAL_ENTER then
                log("111 : a")
                if Page then
                    local f = Page.fields[currentField]
                    log("111 : b")
                    log("111 - Page.title: %s", Page.title)
                    -- log("111 - Page.values: %s", Page.values)
                    -- log("111 - f.vals: %s", f.vals) 
                    -- log("111 - Page.values[f.vals[#f.vals]]: %s", Page.values[f.vals[#f.vals]])
                    log("111 - f.ro: %s", f.ro)
                    -- if Page.values and f.vals and Page.values[f.vals[#f.vals]] and not f.ro then
                    if (Page.values and f.vals and Page.values[f.vals[#f.vals]] and not f.ro) or (runningInSimulator) then
                        log("111 : c")
                        pageState = pageStatus.editing
                    end
                end
            elseif event == EVT_VIRTUAL_ENTER_LONG then
                killEnterBreak = 1
                createPopupMenu()
            elseif event == EVT_VIRTUAL_EXIT then
                invalidatePages()
                currentField = 1
                uiState = uiStatus.mainMenu
                return 0
            elseif event == EVT_TOUCH_FIRST then
                log("EVT_TOUCH_FIRST: %s,%s", touchState.x, touchState.y)
                lcd.drawRectangle(touchState.x, touchState.y,20,20,SOLID)
                selectFieldByTouch(touchState.x, touchState.y)
                activateButtonIfPressed(touchState.x, touchState.y, gui.btns, callbackMapField)
            end
        elseif pageState == pageStatus.editing then
            if event == EVT_VIRTUAL_EXIT or event == EVT_VIRTUAL_ENTER then
                if Page.fields[currentField].postEdit then
                    Page.fields[currentField].postEdit(Page)
                end
                pageState = pageStatus.display
            elseif event == EVT_VIRTUAL_INC or event == EVT_VIRTUAL_INC_REPT then
                incValue(1)
            elseif event == EVT_VIRTUAL_DEC or event == EVT_VIRTUAL_DEC_REPT then
                incValue(-1)
            elseif event == EVT_TOUCH_FIRST then
                log("EVT_TOUCH_FIRST: %s,%s", touchState.x, touchState.y)
                lcd.drawRectangle(touchState.x, touchState.y,20,20,SOLID)
                activateButtonIfPressed(touchState.x, touchState.y, gui.btns, callbackMapField)
            end
        end
        if not Page then
            Page = assert(loadScript("PAGES/"..PageFiles[currentPage].script))()
            collectgarbage()
        end
        if not Page.values and pageState == pageStatus.display then
            requestPage()
        end
        lcd.clear()

        -- ??? for testing
        if event == EVT_TOUCH_FIRST then
            log("EVT_TOUCH_FIRST: %s,%s", touchState.x, touchState.y)
            local touch_sens_r = 15
            lcd.drawFilledCircle(touchState.x, touchState.y, touch_sens_r,SOLID+GREY)
        end

        drawScreen()

        if pageState == pageStatus.saving then
            local saveMsg = "Saving..."
            if saveRetries > 0 then
                saveMsg = "Retrying"
            end
            lcd.drawFilledRectangle(radio.SaveBox.x,radio.SaveBox.y,radio.SaveBox.w,radio.SaveBox.h,backgroundFill)
            lcd.drawRectangle(radio.SaveBox.x,radio.SaveBox.y,radio.SaveBox.w,radio.SaveBox.h,SOLID)
            lcd.drawText(radio.SaveBox.x+radio.SaveBox.x_offset,radio.SaveBox.y+radio.SaveBox.h_offset,saveMsg,DBLSIZE + globalTextOptions)
        end
    elseif uiState == uiStatus.confirm then
        lcd.clear()
        drawScreen()
        if event == EVT_VIRTUAL_ENTER then
            uiState = uiStatus.init
            init = Page.init
            invalidatePages()
        elseif event == EVT_VIRTUAL_EXIT then
            invalidatePages()
            uiState = prevUiState
            prevUiState = nil
        end
    end
    if getRSSI() == 0 then
        lcd.drawText(radio.NoTelem[1],radio.NoTelem[2],radio.NoTelem[3],radio.NoTelem[4])
    end
    mspProcessTxQ()
    processMspReply(mspPollReply())
    return 0
end

return run_ui
