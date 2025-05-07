-- Create a button to trigger a function

-- args: x,y,w,h,text, onPress, isActive
function button(panel, id, args, flags)
    local self = {
        text = args.text,
        flags = bit32.bor(flags or panel.flags, CENTER, VCENTER),
        disabled = false,
        editable = true,
        hidden= false,

        panel = panel,
        id = id,
        x = args.x,
        y = args.y,
        w = args.w,
        h = args.h,
        bgColor = args.bgColor or panel.colors.btn.bg,
        callback = args.onPress or panel.doNothing,
    }

    function self.draw(focused)
        local x, y, w, h = self.x, self.y, self.w, self.h
        if focused then
            panel.drawFocus(x, y, w, h)
        end

        panel.drawFilledRectangle(x, y, w, h, self.disabled and GREY or self.bgColor)
        panel.drawRectangle(x, y, w, h, panel.colors.btn.border)
        panel.drawText(x + w / 2, y + h / 2, self.text, bit32.bor(panel.colors.btn.txt, self.flags))

        if self.disabled then
            panel.drawFilledRectangle(x, y, w, h, GREY, 7)
        end
    end

    function self.onEvent(event, touchState)
        if event == EVT_VIRTUAL_ENTER then
            return self.callback(self)
        end
    end

    if panel~=nil then
        panel.addCustomElement(self)
    end
    return self
end

return button




