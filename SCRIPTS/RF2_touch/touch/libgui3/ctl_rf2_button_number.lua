-- Create a number button that can be edited
-- args: x, y, w, h, text, text_long, f, units, steps

function ctl_rf2_button_number(panel, id, args, flags)
    panel.log("number_as_button.new(%s, min:%s, max:%s, steps:%s)", id, args.min, args.max, args.steps)
    local self = {
        disabled = false,
        editable = true,
        hidden= false,

        panel = panel,
        id = id,
        x = args.x,
        y = args.y,
        w = args.w,
        h = args.h,
        text = args.text,
        text_long = args.text_long,
        help = args.help,
        min = args.min or 0,
        max = args.max or 100,
        value = args.value or -1,
        initiatedValue = args.value or -1,
        units = args.units,
        steps = args.steps or 1,
        -- bg_color = args.bg_color,
        onValueUpdated = args.onValueUpdated or panel.doNothing,
        callbackOnModalActive = args.callbackOnModalActive or panel.doNothing,
        callbackOnModalInactive = args.callbackOnModalInactive or panel.doNothing,

        modalPanel = nil,
        ctlNumberEditing = nil,
        showingEditor = false,
    }

    function self.isDirty()
        return self.value ~= self.initiatedValue
    end

    local function drawButton()
        local x,y,w,h = self.x, self.y, self.w,self.h
        panel.drawFilledRectangle(x, y, w, h, panel.colors.btn.bg)
        panel.drawRectangle(x, y, w, h, panel.colors.secondary2)
        local y1 = y+6
        if self.text then
            panel.drawText(x + w / 2, y1, self.text, panel.colors.btn.txt + CENTER)
            y1 = y1 + 20
        end
        local val_txt = string.format("%s%s", self.value, self.units)
        panel.drawText(x + w / 2, y1, val_txt, panel.colors.secondary1 + CENTER)

        -- draw progress bar
        local f_min = self.min
        local f_max = self.max
        local percent = (self.value - f_min) / (f_max - f_min)
        local bkg_col = LIGHTGREY
        local fg_col = lcd.RGB(0x00, 0xB0, 0xDC)
        local prg_w = w - 20
        local prg_h = 5
        local px = (prg_w - 2) * percent
        local r = 5
        -- panel.log("drawButton111(%s) - percent:%s, px:%s/%s  (%s - %s) / (%s - %s)", self.text, percent, px, w, self.value,f_min,f_max,f_min)

        -- level slider
        panel.drawFilledRectangle(x+10, y+h-11, px-r-2, prg_h, fg_col)
        panel.drawFilledRectangle(x+10+px+r/2, y+h-11, prg_w-px, prg_h, bkg_col)
        panel.drawCircle(x+10 + px - r/2, y+h-12 + r/2, r, fg_col, 1)

        if self.isDirty() then
            panel.drawFilledCircle(x+w-10, y+10, 4, RED, 1)
        end
    end

    function self.draw(focused)
        local x,y,w,h = self.x,self.y,self.w,self.h
        -- panel.log("[%s] number_as_button:draw(%s)", self.id, self.text)
        -- panel.log("ctl_number_editor.draw(%s) - isEditorOpen:%s", self.text, self.isEditorOpen)

        drawButton()

        if self.showingEditor then
            panel.drawRectangle(x, y, w, h, RED, 4)
        else
            if focused then
                -- panel.log("drawFocus: %s", self.text)
                panel.drawFocus(x, y, w, h)
            end

            if self.disabled then
                panel.drawFilledRectangle(x, y, w, h, GREY, 7)
            end
        end
    end

    function self.start_number_editor()
        panel.log("[%s] number_as_button::start_number_editor(%s) v:%s,min:%s,max:%s", self.id, self.value, self.text, self.min, self.max)
        panel.log("[%s] number_as_button::66, f(%s)", self.id, args.aaa)

        self.modalPanel = panel.newPanel("modal-fancy-editor")
        self.ctlNumberEditing = self.modalPanel.newControl.ctl_number_editor(self.modalPanel, "numEditor1", {
            steps=self.steps,
            value=self.value,min=self.min,max=self.max,
            initiatedValue=self.initiatedValue,
            text=self.text_long or self.text,
            units=self.units,
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
                    self.value = newVal
                    self.showingEditor = false
                    self.ctlNumberEditing = nil
                    panel.dismissPrompt()
                    self.modalPanel = nil
                    self.callbackOnModalInactive(self)
                    self.onValueUpdated(self, self.value)
                end,

        })
        self.modalPanel.editing = true
        self.showingEditor = true
        panel.showPrompt(self.modalPanel) --???

        self.callbackOnModalActive(self)
    end

    function self.onEvent(event, touchState)
        panel.log("[%s] number_as_button:onEvent(%s)", self.id, self.text)
        if self.showingEditor == false then
            if event == EVT_VIRTUAL_ENTER then
                killEvents(event)   -- X10/T16 issue: pageUp is a long press
                self.start_number_editor()
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

return ctl_rf2_button_number

