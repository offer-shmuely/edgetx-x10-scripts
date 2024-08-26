-- args: x, y, w, h, f, fieldsInfo, onDone, onCancel

function ctl_number_editor(panel, id, args)
    panel.log("number_as_button ctl_number_editor(): panel=%s, id=%s, [%s]=%s, min:%s, max:%s, steps:%s", panel, args.id, args.text, args.value, args.min, args.max, args.steps)

    local self = {
        -- flags = bit32.bor(flags or panel.flags, CENTER, VCENTER),
        flags = bit32.bor(panel.flags or panel.default_flags),
        disabled = false,
        editable = true,
        hidden = false,

        panel = panel,
        id = id,
        val = args.value or -1,
        val_min = args.min or 0,
        val_max = args.max or 100,
        steps = args.steps or 1,
        text = args.text or "",
        help = args.help or "",
        fieldsInfo = args.fieldsInfo,
        onDone = args.onDone or panel.doNothing,
        onCancel = args.onCancel or panel.doNothing,

        x = 20,
        y = 45,
        w = 430,
        h = 210,
        h_header = 30,
        val_org = args.initiatedValue or args.value,

        editing = true,
        drawingMenu = false,
    }

    local btn_list = {
        {x=340, y=80,   w=60, h=35, txt="+10", step=10},
        {x=370, y=125,  w=60, h=35, txt="+1", step=1},
        {x=370, y=170,  w=60, h=35, txt="-1", step=-1},
        {x=340, y=215,  w=60, h=35, txt="-10", step=-10},
    }

    function self.get_value()
        -- log("[%s] get_value() - scroll_offset_y is nil", self.id)
        return self.val
    end

    function self.set_value(v)
        -- log("set_value(%s)", v)
        self.val = v
    end

    function self.format_val(v)
        local txt
        if self.steps < 0.1 then
            txt = string.format("%.2f", v)
        elseif self.steps < 1 then
            txt = string.format("%.1f", v)
        else
            txt = string.format("%d", v)
        end
        -- log("n_val(%s) = %s", v, txt)
        return txt
    end

    function self.inc_value(step)
        local n_val = self.val + step
        scale = 5
        mult =1
        print("n_val 1", n_val)
        n_val = math.floor(n_val/self.steps + 0.5)*self.steps
        -- panel.log("n_val 2, %s, steps=%s, %s, %s",n_val,self.steps,
        --     math.floor(n_val/self.steps + 0.5),
        --     math.floor(n_val/self.steps + 0.5)*self.steps)
        n_val = math.min(n_val, self.val_max)
        n_val = math.max(n_val, self.val_min)
        self.val = n_val
        return
    end

    function self.covers(tsx, tsy)
        panel.log("ctl_number_editor::covers() ?")
        if (tsx >= self.x and tsx <= self.x + self.w and tsy >= self.y and tsy <= self.y + self.h) then
            panel.log("ctl_number_editor::covers() true")
            return true
        end

        panel.log("ctl_number_editor::covers() - false")
        return false
    end

    function self.fullScreenRefresh()
        local x,y,w,h = self.x, self.y, self.w,self.h
        panel.log("ctl_number_editor.fullScreenRefresh() - editing: %d", self.editing)
        -- if not menuPanel.editing then
            --     dismissMenu()
            --     return
            -- end

        if self.editing then
            -- menu background
            panel.log("ctl_number_editor.fullScreenRefresh() EDITING")
            panel.drawFilledRectangle(x, y, w, h, panel.colors.list.bg)
            panel.drawRectangle(x-2, y-2, w+4, h+4, panel.colors.list.border)
            self.drawingMenu = true
        else
            dismissMenu()
            return
        end
    end

    function self.draw(focused)
        local x,y,w,h,f = self.x, self.y, self.w,self.h,self.f
        local f_val = self.val or 77

        panel.drawFilledRectangle(0, 30, LCD_W, LCD_H - self.h_header, LIGHTGREY, 6) -- obfuscate main page
        panel.drawFilledRectangle(x, y, w, h, GREY, 2)                           -- edit window bkg
        panel.drawFilledRectangle(x, y, w, self.h_header, BLACK, 2)               -- header
        panel.drawRectangle(x + 5, y + 2, 10, 10, WHITE, 0)                        -- x exit symbol

        panel.drawText(x + w - 20, y + 5, "X", panel.FONT_SIZES.FONT_8 + BOLD + WHITE)
        panel.drawText(x + 20, y + 6, "OK", panel.FONT_SIZES.FONT_8 + BOLD + WHITE)

        panel.drawRectangle(x, y, w, h, GREY, 0)                                 -- border
        -- lcd.drawText(x + 5, y + h_header, field_name, FONT_SIZES.FONT_12 + BOLD + CUSTOM_COLOR)

        -- title
        panel.drawText((x + w) / 2, y + 5, self.text, panel.FONT_SIZES.FONT_8 + BOLD + WHITE + CENTER)

        -- additional info
        -- lcd.drawText(x + w - 5, y + h_header + 2, string.format("max: \n%s", f.min), FONT_SIZES.FONT_8 + BLACK + RIGHT)
        -- lcd.drawText(x + w - 5, y + h - 45, string.format("max: \n%s", f.max), FONT_SIZES.FONT_8 + BLACK + RIGHT)
        -- lcd.drawText(x + 20, y1 + h_header + 20, string.format("%s", f.t2 or f.t), FONT_SIZES.FONT_8 + WHITE)
        panel.drawText(x+20, y + h -40, string.format("min: %s", self.val_min), panel.FONT_SIZES.FONT_8 + WHITE)
        panel.drawText(x+200, y + h -40, string.format("max: %s", self.val_max), panel.FONT_SIZES.FONT_8 + WHITE)
        -- panel.drawText(x+20, y + self.h_header + 70, string.format("steps: %s", self.steps), panel.FONT_SIZES.FONT_8 + WHITE)
        if self.help ~= nil and self.help ~= "" then
            panel.drawText(x + 20, y + self.h_header + 5, "Info: \n" .. self.help, panel.FONT_SIZES.FONT_8 + WHITE)
        end

        -- buttons
        for i, btn in ipairs(btn_list) do
            panel.drawFilledRectangle(btn.x, btn.y, btn.w, btn.h, BLACK, 2)
            panel.drawText(btn.x + 10, btn.y + 7, btn.txt, panel.FONT_SIZES.FONT_8 + BOLD + WHITE)
        end

        -- value
        local val_txt = self.format_val(f_val)
        local units_txt = self.units or ""
        lcd.drawText((x + w) / 2 + 80, y + 30, val_txt, panel.FONT_SIZES.FONT_16 + BOLD + BLUE + RIGHT)
        panel.drawText((x + w) / 2 + 85, y + 60, units_txt, panel.FONT_SIZES.FONT_12 + BOLD + BLUE)
        if self.val_org ~= f_val then
            lcd.drawText((x + w) / 2 + 80, y + 60 + 35, string.format("current: %s %s", self.val_org, units_txt), panel.FONT_SIZES.FONT_8 + WHITE + RIGHT)
        end

        -- progress bar
        f_val = tonumber(f_val)
        local f_min = self.val_min
        local f_max = self.val_max
        local percent = (f_val - f_min) / (f_max - f_min)

        -- local fg_col = lcd.RGB(0x00, 0xB0, 0xDC)
        local w1 = 250 -- w1-30
        local h1 = 8
        local x1 = x + 15
        local y1 = y + h - 20
        local r1 = 8
        local px = (w1 - 2) * percent

        panel.drawFilledRectangle(x1, y1 + 2, w1, h1, LIGHTGREY)
        panel.drawFilledRectangle(x1, y1 + 2, px, h1, lcd.RGB(0x00, 0xB0, 0xDC))
        -- panel.drawFilledCircle(x + px - r/2, y + r/2, r, lcd.RGB(0x00, 0xB0, 0xDC))
        panel.drawFilledCircle(x1 + px - r1/2, y1 + r1/2, r1, BLUE)

    end


    function self.onEvent(event, touchState)
        panel.log("[%s] fancy  self.onEvent(%s) (event:%s, touchState:%s)", self.id, self.text, event, touchState)

        if event == EVT_TOUCH_FIRST then
            -- buttons
            local tsx,tsy = touchState.x, touchState.y
            for i, btn in ipairs(btn_list) do
                if (tsx >= btn.x and tsx <= btn.x + btn.w and tsy >= btn.y and tsy <= btn.y + btn.h) then
                    panel.log("onEvent::pressed(%s)", btn.txt)
                    self.inc_value(btn.step)
                    killEvents(event)   -- X10/T16 issue: pageUp is a long press
                    return
                end
            end

            -- exit on X click
            local tsx,tsy = touchState.x, touchState.y

            if (tsx >= self.x+self.w/2 and tsx <= self.x + self.w and tsy >= self.y and tsy <= self.y + self.h_header) then
                -- revert value
                self.set_value(self.val_org)
                self.onCancel()
            end
            killEvents(event)   -- X10/T16 issue: pageUp is a long press

            -- save on click
            local tsx,tsy = touchState.x, touchState.y
            if (tsx >= self.x and tsx <= self.x + self.w/2 and tsy >= self.y and tsy <= self.y + self.h_header) then
                -- save value
                self.onDone(self.get_value())
            end


        elseif event == EVT_VIRTUAL_NEXT then
            self.inc_value(self.steps)
            log("[%s] fancy EVT_VIRTUAL_NEXT, val=%s", self.id, self.get_value())

        elseif event == EVT_VIRTUAL_PREV then
            self.inc_value(0-self.steps)
            log("[%s] fancy EVT_VIRTUAL_PREV, val=%s", self.id, self.get_value())

        elseif event == EVT_VIRTUAL_ENTER and touchState==nil then
            log("[%s] fancy EVT_VIRTUAL_ENTER, val=%s", self.id, self.get_value())
            self.onDone(self.get_value())

        elseif event == EVT_VIRTUAL_ENTER_LONG then
            log("[%s] fancy EVT_VIRTUAL_ENTER_LONG, val=%s", self.id, self.get_value())
            self.onDone(self.get_value())
            killEvents(event)   -- X10/T16 issue: pageUp is a long press

        elseif event == EVT_VIRTUAL_EXIT then
            log("[%s] fancy EVT_VIRTUAL_EXIT, val=%s", self.id, self.get_value())
            -- revert value
            self.set_value(self.val_org)
            self.onCancel()

        end


    end

    if panel~=nil then
        panel.addCustomElement(self)
    end

    return self
end

return ctl_number_editor

