local libgui_dir = ...

---------------------------------------------------------------------------
-- The dynamically loadable part of the shared Lua GUI library.          --
--                                                                       --
-- Author:  Jesper Frickmann                                             --
-- Version: 1.0.0   Date: 2021-12-20                                     --
-- Version: 1.0.1   Date: 2022-05-05                                     --
-- Version: 1.0.2   Date: 2022-11-20                                     --
-- Version: 1.0.2   Date: 2023-07                                        --
-- Version: 1.0.3   Date: 2023-12                                        --
-- Version: 2.0.0   Date: 2024-04                                        --
--                                                                       --
-- Copyright (C) EdgeTX                                                  --
--                                                                       --
-- License GPLv2: http://www.gnu.org/licenses/gpl-2.0.html               --
--                                                                       --
-- This program is free software; you can redistribute it and/or modify  --
-- it under the terms of the GNU General Public License version 2 as     --
-- published by the Free Software Foundation.                            --
--                                                                       --
-- This program is distributed in the hope that it will be useful        --
-- but WITHOUT ANY WARRANTY; without even the implied warranty of        --
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         --
-- GNU General Public License for more details.                          --
---------------------------------------------------------------------------

--
-- This file contains the implementation of the LibGUI-v3 library.
-- LibGUI-v3 is a GUI library for EdgeTX, a firmware for RC transmitters.
-- It provides various widgets and functions to create graphical user interfaces.
--
-- The code in this file is responsible for defining the LibGUI-v3 library and its components.
-- It includes the necessary functions and data structures to create and manage GUI elements.
--
-- This library is used by other modules in the EdgeTX firmware to create user interfaces for different features.
-- It is an integral part of the firmware and is essential for the proper functioning of the graphical interface.
--

local app_ver = "3.0.0-dev.1"

print(string.format("libgui_dir: %s, app_ver: %s", libgui_dir, app_ver))

local M = { }
M.libgui_dir = libgui_dir
M.newControl = {}
M.prompt = nil
M.showingPrompt = false

-- Show prompt
function M.showPrompt(prompt)
    M.prompt = prompt
end

-- Dismiss prompt
function M.dismissPrompt()
    M.prompt = nil
end

function M.getVer()
    return app_ver
end

function M.log(fmt, ...)
    if fmt == nil then return end
    print(string.format("111: " .. fmt, ...))
end
function log(fmt, ...)
    M.log(fmt, ...)
end

function M.isPrompt()
    return M.prompt ~= nil
end
function M.isNoPrompt()
    return M.prompt == nil
end
-- Load all controls
for ctl_name in dir(libgui_dir) do
    local file_name_short = string.match(ctl_name, "^(ctl_.+).lua$")
    if file_name_short ~= nil then
        M.log("loadControl(%s)", ctl_name)
        M.newControl[file_name_short] = assert(loadScript(M.libgui_dir .. "/" .. ctl_name, "tcd"))()
        M.log("ctl_file: %s, flie_name_short: %s", ctl_name, file_name_short)
    end
end


-- Create a new GUI object with interactive screen elements
function M.newPanel(id, args)
    -- args: enable_page_scroll

    M.log("creating new panel [%s]", id)
    local panel = {
        id = id,
        x = args and args.x or 0,
        y = args and args.y or 0,
        flags = 0,

        editable = true,
        enable_page_scroll = args and args.enable_page_scroll or false,

        _ = {} -- internal members
    }

    panel.newControl = M.newControl
    -- local _ = {} -- internal members
    panel._.handles = { }
    panel._.elements = { }
    panel._.focus = 1 -- default flags, can be changed by client
    panel._.scrolling = false
    panel._.lastEvent = 0
    panel._.org_y = panel.y
    panel._.libgui_dir = M.libgui_dir
    -- print(string.format("libgui_dir: %s", panel._.libgui_dir))


    -- default colors, can be changed by client
    panel.colors = {
        primary1 = COLOR_THEME_PRIMARY1,
        primary2 = COLOR_THEME_PRIMARY2,     -- button background / topbar text
        primary3 = COLOR_THEME_PRIMARY3,     -- button text
        secondary1 = COLOR_THEME_SECONDARY1, -- topbar background, btn-text
        secondary2 = COLOR_THEME_SECONDARY2, -- button border
        secondary3 = COLOR_THEME_SECONDARY3, -- screen background
        focus = COLOR_THEME_FOCUS,
        edit = COLOR_THEME_EDIT,
        active = COLOR_THEME_ACTIVE,

        -- high level definitions
        txt = COLOR_THEME_PRIMARY3,
        btn = {
            txt = COLOR_THEME_PRIMARY3,      -- COLOR_THEME_SECONDARY1,
            bg = COLOR_THEME_PRIMARY2,       -- button background / topbar text
            border = COLOR_THEME_SECONDARY2,
            -- focused = {
            --     txt = COLOR_THEME_PRIMARY2,
            --     bg = COLOR_THEME_PRIMARY2, -- button background / topbar text
            --     border = COLOR_THEME_SECONDARY2,
            -- },
            pressed = {
                txt = COLOR_THEME_SECONDARY3,
                bg = COLOR_THEME_SECONDARY1,
                border = COLOR_THEME_FOCUS,
            },
        },
        topbar = {
            txt = COLOR_THEME_PRIMARY2,
            bg = COLOR_THEME_SECONDARY1,
        },
        list = {
            txt = COLOR_THEME_PRIMARY1,
            bg = COLOR_THEME_PRIMARY2,
            border = COLOR_THEME_SECONDARY2,
            selected = {
                txt = COLOR_THEME_PRIMARY2,
                bg = COLOR_THEME_FOCUS,
            },
        },
    }

    -- better font size names
    panel.FONT_SIZES = {
        FONT_38 = XXLSIZE, -- 38px
        FONT_16 = DBLSIZE, -- 16px
        FONT_12 = MIDSIZE, -- 12px
        FONT_8  = 0,       -- Default 8px
        FONT_6  = SMLSIZE, -- 6px
    }

    -----------------------------------------------------------------------------------------------
    function panel.log(fmt, ...)
        print(string.format("111: " .. fmt, ...))
    end


    function panel._.lcdSizeTextFixed(txt, font_size)
        local ts_w, ts_h = lcd.sizeText(txt, font_size)

        local v_offset = 0
        if font_size == panel.FONT_SIZES.FONT_38 then
            v_offset = -11
        elseif font_size == panel.FONT_SIZES.FONT_16 then
            v_offset = -5
        elseif font_size == panel.FONT_SIZES.FONT_12 then
            v_offset = -4
        elseif font_size == panel.FONT_SIZES.FONT_8 then
            v_offset = -3
        elseif font_size == panel.FONT_SIZES.FONT_6 then
            v_offset = 0
        end
        return ts_w, ts_h +2*v_offset, v_offset
    end

    -- Return true if the first arg matches any of the following args
    function panel.match(x, ...)
        for i, y in ipairs({ ... }) do
            if x == y then
                return true
            end
        end
        return false
    end

    -- Translate coordinates for sub-GUIs
    function panel.translate(x, y)
        if panel.parent then
            x, y = panel.parent.translate(x, y)
        end
        return panel.x + x, panel.y + y
    end
    function panel.translateY(y)
        if panel.parent then
            y = panel.parent.translateY(y)
        end
        return panel.y + y
    end

    -- Replace lcd functions to translate by gui offset
    function panel.drawCircle(x, y, r, flags, thickness)
        x, y = panel.translate(x, y)
        if thickness == nil then
            lcd.drawCircle(x, y, r, flags)
        else
            for i = thickness, 0, -1 do
                lcd.drawCircle(x, y, r-i, flags)
            end
        end
    end

    function panel.drawFilledCircle(x, y, r, flags)
        x, y = panel.translate(x, y)
        lcd.drawFilledCircle(x, y, r, flags)
    end

    function panel.drawLine(x1, y1, x2, y2, pattern, flags)
        x1, y1 = panel.translate(x1, y1)
        x2, y2 = panel.translate(x2, y2)
        lcd.drawLine(x1, y1, x2, y2, pattern, flags)
    end

    function panel.drawRectangle(x, y, w, h, flags, t)
        x, y = panel.translate(x, y)
        lcd.drawRectangle(x, y, w, h, flags, t)
    end

    function panel.drawFilledRectangle(x, y, w, h, flags, opacity)
        x, y = panel.translate(x, y)
        lcd.drawFilledRectangle(x, y, w, h, flags, opacity)
    end

    function panel.drawTriangle(x1, y1, x2, y2, x3, y3, flags)
        x1, y1 = panel.translate(x1, y1)
        x2, y2 = panel.translate(x2, y2)
        x3, y3 = panel.translate(x3, y3)
        lcd.drawTriangle(x1, y1, x2, y2, x3, y3, flags)
    end

    function panel.drawFilledTriangle(x1, y1, x2, y2, x3, y3, flags)
        x1, y1 = panel.translate(x1, y1)
        x2, y2 = panel.translate(x2, y2)
        x3, y3 = panel.translate(x3, y3)
        lcd.drawFilledTriangle(x1, y1, x2, y2, x3, y3, flags)
    end

    function panel.drawBitmap(img, x, y, scale)
        x, y = panel.translate(x, y)
        lcd.drawBitmap(img, x, y, scale)
    end

    function panel.drawText(x, y, text, flags, inversColor)
        x, y = panel.translate(x, y)
        -- local is_center_horz = bit32.btest(flags, CENTER)
        -- flags = bit32.bnot(flags, CENTER)
        local is_center_vert = bit32.btest(flags, VCENTER)
        flags = bit32.band(flags, bit32.bnot(VCENTER))

        local ts_w, ts_h, v_offset = panel._.lcdSizeTextFixed(text, panel.FONT_SIZES.FONT_8)
        if is_center_vert then
            y = y - ts_h / 2
        end
        lcd.drawText(x, y + v_offset, text, flags, inversColor)
        -- lcd.drawRectangle(x, y, ts_w, ts_h, RED)--???
    end

    function panel.drawTextLines(x, y, w, h, text, flags)
        x, y = panel.translate(x, y)
        lcd.drawTextLines(x, y, w, h, text, flags)
    end

    function panel.drawNumber(x, y, value, flags, inversColor)
        x, y = panel.translate(x, y)
        lcd.drawNumber(x, y, value, flags, inversColor)
    end

    function panel.drawTimer(x, y, value, flags, inversColor)
        x, y = panel.translate(x, y)
        lcd.drawTimer(x, y, value, flags, inversColor)
    end

    -- The default callBack
    function panel.doNothing()
    end

    -- The default onChangeValue
    function panel._.onChangeDefault(delta, self)
        return self.value + delta
    end


    -----------------------------------------------------------------------------------------------
    function panel._.tableBasedX_convertTableTo1Based(tbl)
        local is_0_based = (tbl[0]~=nil)
        if is_0_based == false then
            return tbl, is_0_based
        end

        local tbl1 = {}
        for i=0, #tbl do
            tbl1[i+1] = tbl[i]
            -- print(string.format("   items0[%s]=%s", i, tbl0[i]))
        end
        return tbl1, is_0_based
    end
    function panel._.tableBasedX_convertSelectedTo1Based(selected, tbl)
        local is_0_based = (tbl[0]~=nil)
        if is_0_based == false then
            return selected
        end
        return selected + 1
    end
    function panel._.tableBasedX_convertSelectedTo0or1Based(selected, tbl)
        local is_0_based = (tbl[0]~=nil)
        if is_0_based == false then
            return selected
        end
        return selected-1
    end

    function panel._.tableBasedX_getValue(i, orgTable)
        local is_0_based = (orgTable[0]~=nil)
        if is_0_based == false then
            return i
        else
            return i-1
        end
    end

    function panel._.tableBasedX_getLength(tbl)
        local is_0_based = (tbl[0]~=nil)
        if is_0_based == false then
            return #tbl
        else
            return #tbl + 1
        end
    end

    -----------------------------------------------------------------------------------------------

    -- Adjust text according to horizontal alignment
    function panel._.align_w(x, w, flags)
        if bit32.btest(flags, RIGHT) then
            return x + w
        elseif bit32.btest(flags, CENTER) then
            return x + w / 2
        else
            return x
        end
    end
    -- Adjust text according to vertical alignment
    function panel._.align_h(y, h, flags)
        if bit32.btest(flags, VCENTER) then
            return y + h / 2
        else
            return y
        end
    end

    -- Draw border around focused elements
    function panel.drawFocus(x, y, w, h, color)
        -- Not necessary if there is only one element...

        if #panel._.elements == 1 then
            return
        end
        color = color or panel.colors.focus
        panel.drawRectangle(x - 2, y - 2, w + 4, h + 4, color, 2)
    end

    -- Move focus to another element
    local function moveFocus(delta)
        local count = 0 -- Prevent infinite loop
        if panel._.focus == nil then
            panel._.focus = 1
            -- ??? on scrolling we need to find the first visible element
            return
        end

        repeat
            panel._.focus = panel._.focus + delta
            if panel._.focus > #panel._.elements then
                panel._.focus = 1
            elseif panel._.focus < 1 then
                panel._.focus = #panel._.elements
            end
            count = count + 1
        until not (panel._.elements[panel._.focus].disabled or panel._.elements[panel._.focus].editable==false or panel._.elements[panel._.focus].hidden) or count > #panel._.elements
    end

    -- Moved the focused element
    function panel.moveFocused(delta)
        if delta > 0 then
            delta = 1
        elseif delta < 0 then
            delta = -1
        end
        local idx = panel._.focus + delta
        if idx >= 1 and idx <= #panel._.elements then
            panel._.elements[panel._.focus], panel._.elements[idx] = panel._.elements[idx], panel._.elements[panel._.focus]
            panel._.focus = idx
        end
    end

    -- Add an element and return it to the client
    local function addElement(element, x, y, w, h)
        assert(element)
        assert(x)
        assert(y)

        if not element.covers then
            function element.covers(p, q)
                return (x <= p and p <= x + w and y <= q and q <= y + h)
            end
        end

        panel._.elements[#panel._.elements+1] = element
        return element
    end

    -- Add temporary BLINK or INVERS flags
    function panel.getFlags(element)
        local flags = element.flags
        if element.blink then flags = bit32.bor(flags or 0, BLINK) end
        if element.invers then flags = bit32.bor(flags or 0, INVERS) end
        return flags
    end

    -- Set an event handler
    function panel.setEventHandler(event, f)
        panel._.handles[event] = f
    end

    -- Show prompt
    function panel.showPrompt(prompt)
        M.showPrompt(prompt)
    end

    -- Dismiss prompt
    function panel.dismissPrompt()
        M.dismissPrompt()
    end

    -----------------------------------------------------------------------------------------------

    -- Run an event cycle
    function panel.run(event, touchState)
        panel.draw(false)
        if event ~= nil then
            panel.onEvent(event, touchState)
        end
        panel._.lastEvent = event
    end

    -----------------------------------------------------------------------------------------------

    function panel.draw(focused)
        if panel.fullScreenRefresh then
            panel.fullScreenRefresh()
        end
        if focused then
            if panel.parent.editing then
                panel.drawFocus(0, 0, panel.w, panel.h, panel.colors.edit)
            else
                panel.drawFocus(0, 0, panel.w, panel.h)
            end
        end
        local guiFocus = not panel.parent or (focused and panel.parent.editing)
        for idx, element in ipairs(panel._.elements) do
            -- Clients may provide an update function for elements
            if element.onUpdate then
                element.onUpdate(element)
            end
            if not element.hidden then
                element.draw(panel._.focus == idx and guiFocus)
            end
        end
    end

    -----------------------------------------------------------------------------------------------

    function panel.onEvent(event, touchState)
        -- Make sure that focused element is active
        -- log("[%s] libgui3 panel.onEvent() focus: %s", panel.id, panel._.focus)
        -- panel.log("[%s] addElement(%s, %s-->%s)", panel.id, element.id, oldNumOfElements, #panel._.elements)

        -- local t4 = ""
        -- for idx, element in ipairs(panel._.elements) do
        --     t4 = t4..string.format("(%s, %s) ", idx, element.id)
        -- end
        -- log("[%s] fancy addElement controls A7: %s", panel.id, t4)


        if panel._.focus then
            local ctl = panel._.elements[panel._.focus]
            if ctl then -- do we have controls on panel?
                if (ctl.disabled or ctl.editable==false or ctl.hidden) then
                    moveFocus(1)
                    return
                end
            end
        end

        -- Is there an active prompt?
        if M.prompt and not M.showingPrompt then
            M.showingPrompt = true
            M.prompt.run(event, touchState)
            M.showingPrompt = false
            return
        end

        if event == 0 then
            return
        end

        -- Is there an active prompt, send onEvent to the main control of the modal panel
        -- log("[%s] libgui3 - onEvent --> prompt::onEvent 1 (%s, %s)", panel.id, M.prompt, M.showingPrompt)
        if M.prompt and M.showingPrompt and touchState==nil then
            -- log("[%s] libgui3 - onEvent --> prompt::onEvent (prompt.id: %s)2", panel.id, M.prompt.id)
            local ctl = panel._.elements[panel._.focus]
            -- log("[%s] libgui3 panel.onEvent() ctl:%s, focus: %s <<<<<", panel.id, ctl.id, panel._.focus)
            ctl.onEvent(event, touchState)
            return
        end

        if panel.parent and not panel.parent.editing then
            if event == EVT_VIRTUAL_ENTER then
                panel.parent.editing = true
            end
            return
        end

        -- non-zero event; process it
        -- Translate touch coordinates if offset
        if touchState then
            touchState.x = touchState.x - panel.x
            touchState.y = touchState.y - panel.y
            if touchState.startX then
                touchState.startX = touchState.startX - panel.x
                touchState.startY = touchState.startY - panel.y
            end
            -- "Un-convert" ENTER to TAP
            if event == EVT_VIRTUAL_ENTER then
                event = EVT_TOUCH_TAP
            end
        end

        -- ETX 2.8 rc 4 bug fix
        if panel._.scrolling and event == EVT_VIRTUAL_ENTER_LONG then
            return
        end
        -- If we put a finger down on a menu item and immediately slide, then we can scroll
        if event == EVT_TOUCH_SLIDE then
            if not panel._.scrolling then
                --return
            end
        else
            panel._.scrolling = false
            log("scrolling - END org_y: %s", panel._.org_y)
            panel._.org_y = panel.y
        end

        -- "Pre-processing" of touch events to simplify subsequent handling and support scrolling etc.
        if event == EVT_TOUCH_FIRST then
            if panel._.focus and panel._.elements[panel._.focus].covers(touchState.x, touchState.y) then
                panel._.scrolling = true
                log("scrolling - START org_y: %s", panel._.org_y)
            else
                if panel.editing then
                    return
                else
                    -- Did we touch another element?
                    for idx, element in ipairs(panel._.elements) do
                        if not (element.disabled or element.hidden) and element.covers(touchState.x, touchState.y) then
                            panel._.focus = idx
                            panel._.scrolling = true
                            log("scrolling2 - START org_y: %s", panel._.org_y)
                        end
                    end
                end
            end
        elseif event == EVT_TOUCH_TAP or (event == EVT_TOUCH_BREAK and panel._.lastEvent == EVT_TOUCH_FIRST) then
            log("onEvent(%s, %s)",event, touchState)
            if panel._.focus and panel._.elements[panel._.focus].covers(touchState.x, touchState.y) then
                -- Convert TAP on focused element to ENTER
                event = EVT_VIRTUAL_ENTER
            elseif panel.editing then
                -- Convert a TAP off the element being edited to EXIT
                event = EVT_VIRTUAL_EXIT
            end
        end

        if panel.editing then -- Send the event directly to the element being edited
            panel._.elements[panel._.focus].onEvent(event, touchState)
        elseif event == EVT_VIRTUAL_NEXT then -- Move focus
            moveFocus(1)
        elseif event == EVT_VIRTUAL_PREV then
            moveFocus(-1)
        elseif event == EVT_VIRTUAL_EXIT and panel.parent then
            panel.parent.editing = false
        else
            if panel._.handles[event] then
                -- Is it being handled? Handler can modify event
                event = panel._.handles[event](event, touchState)
                -- If handler returned false or nil, then we are done
                if not event then
                    return
                end
            end


            -- slide up/down the main window
            log("onEvent(%sd, %s)",event, touchState)
            if panel.enable_page_scroll and event == EVT_TOUCH_SLIDE then
                panel._.focus = nil
                local dY = touchState.startY - touchState.y
                panel.y = math.min(panel._.org_y - dY, 0)

                log("EVT_TOUCH_SLIDE (scrolling) %d, %d, start-y: %s, orgY: %s", dY, panel.y,touchState.startY, panel._.org_y)
            end

            if panel._.focus then
                local ctl = panel._.elements[panel._.focus]
                if ctl then
                    log("[%s] libgui3 panel.onEvent() ctl:%s, focus: %s <<<<<", panel.id, ctl.id, panel._.focus)
                    ctl.onEvent(event, touchState)
                end
            end
        end
    end -- onEvent(...)



    -----------------------------------------------------------------------------------------------
    -----------------------------------------------------------------------------------------------

    -- Create a custom element
    function panel.addCustomElement(self, x, y, w, h)
        assert(self)
        self.panel = panel
        self.lib = M

        function self.drawFocus(color)
            panel.drawFocus(self.x or x, self.y or y, self.w or w, self.h or h, color)
        end

        -- Must be implemented by the client
        if not self.draw then
            function self.draw(focused)
                panel.drawText(x, y, "draw(focused) missing")
                if focused then
                    panel.drawFocus(x, y, w, h)
                end
            end
        end

        -- Must be implemented by the client
        if not self.onEvent then
            function self.onEvent()
                playTone(200, 200, 0, PLAY_NOW)
            end
        end

        addElement(self, self.x or x, self.y or y, self.w or w, self.h or h)
        return self
    end

    -----------------------------------------------------------------------------------------------

    -- Create a gui
    function panel.newPanel(id, args)
        return M.newPanel(id, args)
    end

    -- Create a nested gui
    function panel.subPanel(id, args)
        panel.log("adding subPanel[%s] to panel[%s]", id, panel.id)
        assert(args.x)
        assert(args.y)
        assert(args.w)
        assert(args.h)
        local self = M.newPanel()
        self.parent = panel
        self.editing = false
        self.x, self.y, self.w, self.h = args.x, args.y, args.w, args.h

        function self.covers(p, q)
            return (self.x <= p and p <= self.x + self.w and self.y <= q and q <= self.y + self.h)
        end

        addElement(self, args.x, args.y, args.w, args.h)
        return self
    end

    -- -- Create a nested gui
    -- function panel.addNewSubPanel(id, args)
    --     -- args: x, y, w, h
    --     assert(args.x)
    --     assert(args.y)
    --     assert(args.w)
    --     assert(args.h)
    --     local subPanel = M.newPanel()

    --     subPanel = panel.addSubPanel(subPanel, args)
    --     return subPanel
    -- end

    -- -- Create a nested gui
    -- function panel.addSubPanel(subPanel, args)
    --     subPanel.parent = panel
    --     subPanel.editing = false
    --     -- subPanel.x, subPanel.y, subPanel.w, subPanel.h = args.x, args.y, args.w, args.h
    --     subPanel.x, subPanel.y, subPanel.w, subPanel.h = 0,0,0,0

    --     function subPanel.covers(p, q)
    --         return (subPanel.x <= p and p <= subPanel.x + subPanel.w and subPanel.y <= q and q <= subPanel.y + subPanel.h)
    --     end

    --     -- addElement(subPanel, args.x, args.y, args.w, args.h)
    --     addElement(subPanel)
    --     return subPanel
    -- end

    -----------------------------------------------------------------------------------------------

    return panel

end -- panel(...)

return M
