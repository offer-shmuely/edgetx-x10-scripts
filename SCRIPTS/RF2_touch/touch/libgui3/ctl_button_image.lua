-- Create a button to trigger a function

-- args: x,y,w,h,text, onPress, isActive
function button(panel, id, args, flags)
    local self = {
        text = args.text,
        callback = args.onPress or panel.doNothing,
        -- flags = bit32.bor(flags or panel.flags, CENTER, VCENTER),
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
        bgColor = args.bgColor or panel.colors.btn.bg,
        img = Bitmap.open("images/" .. args.img)
    }

    function self.draw(focused)
        local x, y, w, h = self.x, self.y, self.w, self.h
        if focused then
            panel.drawFocus(x, y, w, h)
        end

        panel.drawFilledRectangle(x, y, w, h, self.bgColor)
        panel.drawFilledRectangle(x+w-h, y, h, h, GREY, 11)
        -- panel.drawFilledRectangle(x, y, w, h, lcd.RGB(0x49,0xD6,0x47))
        -- panel.drawFilledRectangle(x+w-h, y, h, h, lcd.RGB(0x3D,0xB2,0x3D))
        panel.drawFilledRectangle(x, y, w, h, lcd.RGB(0x6E,0xB3,0xFF))
        panel.drawFilledRectangle(x+w-h, y, h, h, lcd.RGB(0x2E,0x7D,0xF1))
        panel.drawRectangle(x, y, w, h, panel.colors.btn.border)
        panel.drawBitmap(self.img, x+w-h+8, y+8, 22)

        -- panel.drawText(x + w / 2, y + h / 2, self.text, bit32.bor(panel.colors.btn.txt, self.flags))
        -- panel.drawText(x + w / 2, y + h / 2, self.text, bit32.bor(WHITE, self.flags))
        panel.drawText(x+ 10, y + h / 2, self.text, bit32.bor(WHITE, self.flags))

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




