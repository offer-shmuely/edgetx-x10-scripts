-----------------------------------------------------------------------------------------------
-- args: x, y, w, h, start_val, min, max, onChangeCallBack
function measureTape(panel, id, args, flags)
    local self = {
        -- flags = bit32.bor(flags or gui.flags, CENTER, VCENTER),
        flags = bit32.bor(flags or 0, CENTER, VCENTER),
        disabled = false,
        editable = true,
        hidden = false,

        panel = panel,
        id = id,
        x = args.x,
        y = args.y,
        w = args.w,
        h = args.h,
        val_min = args.min,
        val_max = args.max,
        val_steps = args.steps or 1,
        callback = args.onChangeCallBack or panel.doNothing,

        dy = 6,
        num_vals = nil,

        scrolling = false,
        scroll_offset_y = nil,
        scrolling_base_y = nil,
        val = args.start_val,
        val_on_start_sliding = nil,
        lastValReported = nil,
    }

    local function log(fmt, ...)
        print(string.format("mtrt: " .. fmt, ...))
    end

    function self.get_value()
        if self.scroll_offset_y == nil then
            -- log("[%s] get_value() - scroll_offset_y is nil", self.id)
            return self.val
        end
        local d_val = math.floor(self.scroll_offset_y / self.dy)
        -- local n_val = self.val + d_val
        local n_val = self.val_on_start_sliding + (d_val * self.val_steps)
        n_val = math.min(n_val, self.val_max)
        n_val = math.max(n_val, self.val_min)
        n_val = math.floor(n_val/self.val_steps + 0.5)*self.val_steps
        -- log("[%s] get_value() - scroll_offset_y=%s,%s val=%s, d_val=%s, ==> new_val=%s", self.id, self.scroll_offset_y, self.dy, self.val, d_val, n_val)
        return n_val
    end

    function self.format_val(v)
        local txt
        if self.val_steps < 0.1 then
            txt = string.format("%.2f", v)
        elseif self.val_steps < 1 then
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
        n_val = math.floor(n_val/self.val_steps + 0.5)*self.val_steps
        -- panel.log("n_val 2, %s, steps=%s, %s, %s",n_val,self.val_steps,
        --     math.floor(n_val/self.val_steps + 0.5),
        --     math.floor(n_val/self.val_steps + 0.5)*self.val_steps)
        n_val = math.min(n_val, self.val_max)
        n_val = math.max(n_val, self.val_min)
        self.val = n_val
        return
    end

    function self.set_value(v)
        -- log("set_value(%s)", v)
        self.val = v
    end

    function self.covers(tsx, tsy)
        -- log("::covers() ?")
        if (tsx >= self.x
            and tsx <= self.x + self.w
            and tsy >= self.y - self.h
            and tsy <= self.y + self.h)
            then
                -- log("::covers() true")
                return true
        end

        -- log("::covers() - false")
        return false
    end

    function self.draw(focused)
        local x,y,w,h = self.x, self.y, self.w,self.h
        local new_val = self.get_value()
        if self.scrolling then
            -- log("[%s] scrolling scroll_offset_y=%s, val=%s, d_val=%s, ==> new_val=%s", self.id, self.scroll_offset_y,self.val, d_val, self.get_value())
        end

        if focused then
            self.panel.drawFocus(x, y-h, w, h*2, border)
        end

        -- lcd.drawFilledRectangle(x, y, w, h, GREEN)
        -- if self.scrolling then
        --     lcd.drawFilledRectangle(x - 4, y - 4, w + 8, h + 8, GREY)
        -- else
        --     lcd.drawFilledRectangle(x, y, w + 5, h + 4, BLUE, 10)
        -- end

        lcd.drawFilledTriangle(x - 20, y - 10, x - 20, y + 10, x, y + 0, flags)
        if self.scrolling then
            lcd.drawFilledRectangle(x, y - h, w, h*2, lcd.RGB(0xFF, 0xE5, 0x00))
        else
            lcd.drawFilledRectangle(x, y - h, w, h*2, YELLOW)
        end
        -- lcd.drawFilledRectangle(x, y, w, h, YELLOW)
        -- lcd.drawFilledRectangle(x + w - 4, y - h, 4, h, ORANGE)

        local num_vals = math.floor(self.h / self.dy)

        -- log("scrolling num_vals: %s", num_vals)
        for i = 0, num_vals, 1 do
            local v1 = new_val + (i * self.val_steps)
            local y1 = y + i * self.dy
            if v1 >= self.val_min and v1 <= self.val_max then
                if v1 % (10*self.val_steps) == 0 then
                    lcd.drawFilledRectangle(x, y1, 20, 2, BLACK)
                    lcd.drawText(x + 25, y1 - 10, self.format_val(v1), panel.FONT_SIZES.FONT_8 + BLACK)
                elseif v1 %(5*self.val_steps) == 0 then
                    lcd.drawFilledRectangle(x, y1, 15, 2, BLACK)
                else
                    lcd.drawFilledRectangle(x, y1, 10, 2, RED)
                end
            end
        end
        for i = 0, 0 - num_vals, -1 do
            local v1 = new_val + (i * self.val_steps)
            local y1 = y + i * self.dy
            if v1 >= self.val_min and v1 <= self.val_max then
                if math.fmod(v1, 10*self.val_steps) == 0 then
                    lcd.drawFilledRectangle(x, y1, 20, 2, BLACK)
                    lcd.drawText(x + 25, y1 - 10, self.format_val(v1), panel.FONT_SIZES.FONT_8 + BLACK)
                elseif math.fmod(v1, 5*self.val_steps) == 0 then
                    lcd.drawFilledRectangle(x, y1, 15, 2, BLACK)
                else
                    lcd.drawFilledRectangle(x, y1, 12, 2, RED)
                end
            end
        end

        if self.disabled then
            panel.drawFilledRectangle(x, y, w, h, GREY, 7)
        end
    end

    function self.onEvent(event, touchState)

        -- "Pre-processing" of touch events to simplify subsequent handling and support scrolling etc.
        if event == EVT_TOUCH_FIRST and self.covers(touchState.x, touchState.y) then
            lcd.drawFilledCircle(touchState.x, touchState.y, 10, GREY, 10)
            if self.scrolling == false then
                self.scrolling = true
                self.scrolling_base_y = touchState.y
                self.scroll_offset_y = 0 -- self.scrolling_base_y - touchState.y
                self.val_on_start_sliding = self.val
                -- log("[%s] scrolling EVT_TOUCH_FIRST, val=%s, new_val=%s", self.id, self.val, self.get_value())
                -- log("start scrolling y=%s", self.scrolling_base_y)
            end

            -- If we put a finger down on a menu item and immediately slide, then we can scroll
        elseif event == EVT_TOUCH_SLIDE and self.covers(touchState.x, touchState.y) then
            -- lcd.drawFilledCircle(touchState.x, touchState.y, 10, GREEN, 10)
            if self.scrolling then
                self.scroll_offset_y = self.scrolling_base_y - touchState.y
                -- log("[%s] scrolling y1=%s, y2=%s, dy=%s", self.id, self.scrolling_base_y, touchState.y, self.dy)
                self.val = self.get_value()
            end

        elseif event == EVT_TOUCH_BREAK and self.covers(touchState.x, touchState.y) then
            if self.scrolling_base_y then
                self.scroll_offset_y = self.scrolling_base_y - touchState.y
            end
            -- log("[%s] scrolling EVT_TOUCH_BREAK, val=%s, new_val=%s", self.id, self.val, self.get_value())
            self.val = self.get_value()
            self.scrolling = false
            self.scrolling_base_y = nil
            self.scroll_offset_y = nil
            -- log("[%s] scrolling EVT_TOUCH_BREAK, val=%s", self.id, self.val)
        else
            self.scrolling = false
        end

        local v = self.get_value()
        if v ~= self.lastValReported then
            self.lastValReported = v
            return self.callback(self)
        end

    end


    if panel~=nil then
        panel.addCustomElement(self)
    end
    return self
end


return measureTape

