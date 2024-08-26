-- Create a display of current time on timer[tmr]
-- Set timer.value to show a different value
function timer(gui, id, x, y, w, h, tmr, onChangeValue, flags)
    local self = {
        tmr = tmr,
        onChangeValue = onChangeValue or _.onChangeDefault,
        flags = bit32.bor(flags or gui.flags, VCENTER),
        disabled = false,
        hidden= false,
        editable = true,

        gui = gui,
        id = id,
        x = x,
        y = y,
        w = w,
        h = h,

    }
    local value
    local d0

    function self.draw(focused)
        local flags = gui.getFlags(self)
        local fg = gui.colors.primary1
        -- self.value overrides the timer value
        local value = self.value or model.getTimer(self.tmr).value

        if focused then
            gui.drawFocus(x, y, w, h)

            if gui.editing then
                fg = gui.colors.primary2
                gui.drawFilledRectangle(x, y, w, h, gui.colors.edit)
            end
        end
        if type(value) == "string" then
            gui.drawText(gui._.align_w(x, w, flags), y + h / 2, value, bit32.bor(fg, flags))
        else
            gui.drawTimer(gui._.align_w(x, w, flags), y + h / 2, value, bit32.bor(fg, flags))
        end
    end

    function self.onEvent(event, touchState)
        if gui.editing then
            if event == EVT_VIRTUAL_ENTER then
                if not value and self.tmr then
                    local tblTmr = model.getTimer(self.tmr)
                    tblTmr.value = self.value
                    model.setTimer(self.tmr, tblTmr)
                    self.value = nil
                end
                gui.editing = false
            elseif event == EVT_VIRTUAL_EXIT then
                self.value = value
                gui.editing = false
            elseif event == EVT_VIRTUAL_INC then
                self.value = self.onChangeValue(1, self)
            elseif event == EVT_VIRTUAL_DEC then
                self.value = self.onChangeValue(-1, self)
            elseif event == EVT_TOUCH_FIRST then
                d0 = 0
            elseif event == EVT_TOUCH_SLIDE then
                local d = math.floor((touchState.startY - touchState.y) / 20 + 0.5)
                if d ~= d0 then
                    self.value = self.onChangeValue(d - d0, self)
                    d0 = d
                end
            end
        elseif event == EVT_VIRTUAL_ENTER then
            if self.value then
                value = self.value
            elseif self.tmr then
                self.value = model.getTimer(self.tmr).value
                value = nil
            end
            gui.editing = true
        end
    end -- onEvent(...)

    gui.addCustomElement(self)
    return self
end

return timer
