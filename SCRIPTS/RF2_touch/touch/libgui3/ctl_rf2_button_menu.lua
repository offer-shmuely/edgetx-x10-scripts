-- args: x,y,w,h,text, onPress, isActive
function ctl_rf2_button_menu(panel, id, args, flags)
    local self = {
        text = args.text,
        callback = args.onPress or panel.doNothing,
        flags = bit32.bor(flags or panel.flags, VCENTER, CENTER),
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
        title_txt = args.title_txt or nil,
        img = Bitmap.open("IMAGES/" .. (args.img or "na.png")),
    }
    panel.log("mainMenuBuild: i=%s, x=%s, y=%s, w=%s, h=%s", id, self.x, self.y, self.w, self.h)

    function self.draw(focused)
        local x, y, w, h = self.x, self.y, self.w, self.h
        if focused then
            panel.drawFocus(x, y, w, h)
        end

        panel.drawFilledRectangle(x, y, w, h, self.bgColor)
        panel.drawFilledRectangle(x+5, y+85, w-5-5, 2, lcd.RGB(0x30,0x30,0x30))
        panel.drawBitmap(self.img, x+10, y+20, 100)

        if self.title_txt then
            panel.drawFilledRectangle(x, y, w, 20, lcd.RGB(0x39,0x95,0xBD))
            panel.drawText(x+ 5, y + 4, self.title_txt, WHITE + panel.FONT_SIZES.FONT_6)
        end

        local x1 = panel._.align_w(x, w, CENTER)
        -- panel.drawText(x+ 10, y + h -14, self.text, bit32.bor(WHITE, self.flags))
        panel.drawText(x1, y + h -14, self.text, bit32.bor(WHITE, self.flags))

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

return ctl_rf2_button_menu




