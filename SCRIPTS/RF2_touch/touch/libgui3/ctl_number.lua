-- Create a number that can be edited
-- args: x, y, w, h, value, onChangeValue, flags, min, max
function number(panel, id, args, flags)
    panel.log("button.new(%s)", id)
    local self = {
        flags = bit32.bor(flags or panel.flags, VCENTER),
        disabled = false,
        editable = true,
        hidden= false,

        panel = panel,
        id = id,
        x = args.x,
        y = args.y,
        w = args.w,
        h = args.h,
        min_val = args.min or 0,
        max_val = args.max or 100,
        value = args.value or -1,
        units = args.units,
        bg_color = args.bg_color,
        onChangeValue = args.onChangeValue or panel._.onChangeDefault,
        callbackOnModalActive = args.callbackOnModalActive or panel.doNothing,
        callbackOnModalInactive = args.callbackOnModalInactive or panel.doNothing,

        modalPanel = nil,
        ctlNumberEditing = nil,
        showingEditor = false,
    }

    local d0

    function self.draw(focused)
        local x,y,w,h = self.x,self.y,self.w,self.h
        local flags = panel.getFlags(self)
        local fg = panel.colors.primary1

        if focused then
            panel.drawFocus(x, y, w, h)

            if panel.editing then
                fg = panel.colors.primary2
                panel.drawFilledRectangle(x, y, w, h, panel.colors.edit)
            end
        end
        if self.bg_color then
            panel.drawFilledRectangle(x, y, w, h, self.bg_color)
        end
        if type(self.value) == "string" then
            panel.drawText(panel._.align_w(x, w, flags), y + h / 2, self.value, bit32.bor(fg, flags))
        else
            panel.drawNumber(panel._.align_w(x, w, flags), y + h / 2, self.value, bit32.bor(fg, flags))
        end
        if self.min_val and self.max_val then
            local percent = (self.value - self.min_val) / (self.max_val - self.min_val)
            local px = (w - 2) * percent
            panel.drawFilledRectangle(x + 5, y+h-2-5, px, 5, BLUE)
        end

    end

    function self.onEventSimpleInPlace(event, touchState)
        if panel.editing then
            if event == EVT_VIRTUAL_ENTER then
                panel.editing = false
            elseif event == EVT_VIRTUAL_EXIT then
                self.value = value
                panel.editing = false
            elseif event == EVT_VIRTUAL_INC then
                if self.value < self.max_val then
                    self.value = self.onChangeValue(1, self)
                end
            elseif event == EVT_VIRTUAL_DEC then
                if self.value > self.min_val then
                    self.value = self.onChangeValue(-1, self)
                end
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
            value = self.value
            panel.editing = true
        end
    end

    function self.onEvent(event, touchState)
        -- panel.log("[%s] fancy  self.onEvent(%s)", self.id, self.text)
        if self.showingEditor == false then
            if event == EVT_VIRTUAL_ENTER then
                killEvents(event)   -- X10/T16 issue: pageUp is a long press
                self.modalPanel = panel.newPanel("modal-fancy-editor")
                self.ctlNumberEditing = self.modalPanel.newControl.ctl_number_editor(self.modalPanel, "numEditor1", {
                    value=self.value,min=self.min,max=self.max,
                    text=self.text,
                    help=self.help,
                        onCancel=function()
                            panel.log("[%s] number_as_button::onCancelCallback(%s)", self.id, self.value)
                            self.showingEditor = false
                            self.ctlNumberEditing = nil
                            panel.dismissPrompt()
                            self.modalPanel = nil
                            self.callbackOnModalInactive(self)
                        end,
                        onDone=function(newVal)
                            panel.log("[%s] number_as_button::onDoneCallback(%s)", self.id, self.value)
                            self.value = newVal
                            self.showingEditor = false
                            self.ctlNumberEditing = nil
                            panel.dismissPrompt()
                            self.modalPanel = nil
                            self.callbackOnModalInactive(self)
                        end,

                })
                self.showingEditor = true
                panel.showPrompt(self.modalPanel) --???

                self.callbackOnModalActive(self)
                return
            end
        else
            self.modalPanel.onEvent(event, touchState)
        end
    end

    if panel~=nil then
        panel.addCustomElement(self)
    end

    return self
end

return number

