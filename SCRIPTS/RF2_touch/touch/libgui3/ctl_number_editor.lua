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
        value = args.value or -1,
        min = args.min or 0,
        max = args.max or 100,
        units = args.units or "",
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
        measureTape = nil,
        val_org = args.initiatedValue or args.value,

        editing = true,
        drawingMenu = false,
    }
    -- function self.onMeasureTapeValueChange(obj) --????
    --     panel.log("ctl_number_editor onMeasureTapeValueChange: %s", obj.val)
    --     self.value = obj.val   --???
    -- end

    self.measureTape = nil


    function self.get_value()
        return self.measureTape.get_value()
    end

    function self.set_value(v)
        return self.measureTape.set_value(v)
    end

    function self.split_into_lines(str, max_chars, large_line_no, max_chars2)
        if str == nil or str == "" then
            return {""}
        end

        panel.log("ctl_number_editor::split_into_lines(%s, %s)", str, max_chars)

        local words = {}
        for word in string.gmatch(str, "%S+") do
            table.insert(words, word)
            panel.log("ctl_number_editor::found word: %s", word)
        end

        panel.log("ctl_number_editor::lines...")
        local lines = {""}
        for i, word in ipairs(words) do
            if #lines == large_line_no then
                max_chars = max_chars2
            end

            if #lines[#lines] + #word <= max_chars then
                if #lines[#lines] > 0 then
                    lines[#lines] = lines[#lines] .. " " .. word
                else
                    lines[#lines] = word
                end
            else
                panel.log("ctl_number_editor::line: %s", lines[#lines])
                table.insert(lines, word)
            end
        end

        return lines
    end

    -- calculate help lines
    self.font_size = panel.FONT_SIZES.FONT_8
    self.font_space = 18
    self.help_lines = self.split_into_lines(self.help, 20, 5, 40)
    if #self.help_lines > 7 then
        self.help_lines = self.split_into_lines(self.help, 25, 6, 50)
        self.font_size = panel.FONT_SIZES.FONT_6
        self.font_space = 15
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
        local f_val = self.measureTape.val or 77

        panel.drawFilledRectangle(0, 30, LCD_W, LCD_H - self.h_header, LIGHTGREY, 6)   -- obfuscate main page
        -- panel.drawFilledRectangle(x, y, w, h, GREY, 2)                              -- edit window bkg
        panel.drawFilledRectangle(x, y, w, h, lcd.RGB(0x22,0x22,0x22), 1)              -- edit window bkg
        --panel.drawFilledRectangle(x, y, w, self.h_header, BLACK, 2)                  -- header
        panel.drawRectangle(x + 5, y + 2, 10, 10, WHITE, 0)                            -- x exit symbol
        panel.drawText(x + w - 20, y + 5, "x", panel.FONT_SIZES.FONT_8 + BOLD + WHITE)
        panel.drawRectangle(x, y, w, h, GREY, 0)                                     -- border
        -- lcd.drawText(x + 5, y + h_header, field_name, FONT_SIZES.FONT_12 + BOLD + CUSTOM_COLOR)

        -- title
        -- panel.drawText((x + w) / 2, y + 5, self.text, panel.FONT_SIZES.FONT_8 + BOLD + WHITE + CENTER)
        panel.drawText(x +12 , y +10, self.text, panel.FONT_SIZES.FONT_8 + BOLD + WHITE)
        panel.drawFilledRectangle(x+10, y+30, 260, 1, WHITE, 12)              -- separation line

        -- help text
        -- lcd.drawText(x + w - 5, y + h_header + 2, string.format("max: \n%s", f.min), FONT_SIZES.FONT_8 + BLACK + RIGHT)
        -- lcd.drawText(x + w - 5, y + h - 45, string.format("max: \n%s", f.max), FONT_SIZES.FONT_8 + BLACK + RIGHT)
        -- lcd.drawText(x + 20, y1 + h_header + 20, string.format("%s", f.t2 or f.t), FONT_SIZES.FONT_8 + WHITE)
        -- panel.drawText(x+20, y + self.h_header + 70, string.format("steps: %s", self.steps), panel.FONT_SIZES.FONT_8 + WHITE)
        if self.help ~= nil and self.help ~= "" then
            --panel.drawText(x + 10, y + self.h_header + 5, self.help, panel.FONT_SIZES.FONT_8 + WHITE)
            -- local font_size = panel.FONT_SIZES.FONT_8
            -- local font_space = 18
            -- if #self.help_lines > 7 then
            --     font_size = panel.FONT_SIZES.FONT_6
            --     local font_space = 13
            -- end

            for i, line in ipairs(self.help_lines) do
                panel.drawText(x + 10, y + self.h_header +5 + (i-1)*self.font_space, line, self.font_size + WHITE)
            end
        end

        -- value
        local val_txt = self.measureTape.format_val(f_val)
        panel.drawText((x + w) / 2 + 80, y + 30, val_txt, panel.FONT_SIZES.FONT_16 + BOLD + BLUE + RIGHT)
        panel.drawText((x + w) / 2 + 85, y + 60, self.units, panel.FONT_SIZES.FONT_12 + BOLD + BLUE)
        if self.val_org ~= f_val then
            panel.drawText((x + w) / 2 + 80, y + 60 + 35, string.format("current: %s %s", self.val_org, units_txt), panel.FONT_SIZES.FONT_8 + WHITE + RIGHT)
        end

        -- progress bar
        panel.drawText(x+20,  y +  h -40, string.format("min: %s", self.min), panel.FONT_SIZES.FONT_6 + WHITE)
        panel.drawText(x+200, y +  h -40, string.format("max: %s", self.max), panel.FONT_SIZES.FONT_6 + WHITE)
        f_val = tonumber(f_val)
        local f_min = self.min
        local f_max = self.max
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

        -- exit on header click
        if event == EVT_TOUCH_FIRST then
            local tsx,tsy = touchState.x, touchState.y
            if (tsx >= self.x and tsx <= self.x + self.w and tsy >= self.y and tsy <= self.y + self.h_header) then
                -- revert value
                self.measureTape.set_value(self.val_org)
                self.onCancel()
            end
        end

        if event == EVT_VIRTUAL_NEXT then
            self.scrolling = false
            self.measureTape.inc_value(self.steps)
            log("[%s] fancy EVT_VIRTUAL_NEXT, val=%s", self.id, self.measureTape.get_value())

        elseif event == EVT_VIRTUAL_PREV then
            self.scrolling = false
            self.measureTape.inc_value(0-self.steps)
            log("[%s] fancy EVT_VIRTUAL_PREV, val=%s", self.id, self.measureTape.get_value())

        elseif event == EVT_VIRTUAL_ENTER then
            log("[%s] fancy EVT_VIRTUAL_ENTER, val=%s", self.id, self.measureTape.get_value())
            self.onDone(self.measureTape.get_value())

        elseif event == EVT_VIRTUAL_EXIT then
            log("[%s] fancy EVT_VIRTUAL_EXIT, val=%s", self.id, self.measureTape.get_value())
            -- revert value
            self.measureTape.set_value(self.val_org)
            self.onCancel()

        end


        self.measureTape.onEvent(event, touchState)
    end

    if panel~=nil then
        panel.addCustomElement(self)
    end

    if self.measureTape == nil then
        self.measureTape = panel.newControl.ctl_number_measure_tape(panel, "mt1",
            {x=360, y=self.y + self.h_header + (self.h - self.h_header) / 2,w=70,h=(self.h - self.h_header) / 2 - 5,
            start_val=self.value, min=self.min, max=self.max,
            steps=self.steps,
            -- onChangeCallBack=self.onMeasureTapeValueChange
        })

    end

    return self
end

return ctl_number_editor

