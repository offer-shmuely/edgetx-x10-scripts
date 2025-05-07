-- args:

function ctl_waiting_dialog(panel, id, args)
    panel.log("modalWating(%s) %s", id, args)
    local self = {
        -- flags = bit32.bor(flags or panel.flags, CENTER, VCENTER),
        flags = bit32.bor(panel.flags or panel.default_flags),
        disabled = false,
        editable = true,
        hidden = false,

        panel = panel,
        id = id,
        x=20, y=80, w=440, h=120,

        text = args.text,
        textOrg = args.text,
        timeout = args.timeout,
        retryCount = args.retryCount,
        retries = 1,
        onRetry = args.callbackRetry or panel.doNothing,
        onGaveup = args.callbackGaveup or panel.doNothing,

        h_header = 30,
        startTS = getTime()
    }
    --  print all args
    for k,v in pairs(args) do
        panel.log("modalWating args %s=%s", k, v)
    end

    function self.calc()
        -- panel.log("modalWating calc %s/%s retry:%s/%s", getTime() - self.startTS, self.timeout,  self.retries, self.retryCount)
        if getTime() - self.startTS > self.timeout then
            if self.retries < self.retryCount then
                self.onRetry()
                self.retries  = self.retries +1
                self.startTS = getTime()
            else
                self.onGaveup()
                return true
            end
        end
        return false
    end

    function self.draw(focused)
        local x,y,w,h,f = self.x, self.y, self.w,self.h,self.f

        panel.drawFilledRectangle(0, 30, LCD_W, LCD_H - self.h_header, LIGHTGREY, 6) -- obfuscate main page
        panel.drawFilledRectangle(x, y, w, h, GREY, 2) -- edit window bkg
        panel.drawFilledRectangle(x+8, y+8, w, h, GREY, 12) -- bkg shadow
        -- panel.drawFilledRectangle(x, y, w, self.h_header, panel.colors.topbar.bg , 2) -- header
        panel.drawRectangle(x + 5, y + 2, 10, 10, WHITE, 0) -- x
        -- panel.drawText(x + w - 20, y + 5, "x", panel.FONT_SIZES.FONT_8 + BOLD + WHITE)
        panel.drawRectangle(x, y, w, h, GREY, 0) -- border
        -- lcd.drawText(x1 + 5, y1 + h_header, field_name, FONT_SIZES.FONT_12 + BOLD + CUSTOM_COLOR)

        -- title
        panel.drawText((x + w) / 2, y + 5, "", panel.FONT_SIZES.FONT_8 + BOLD + panel.colors.topbar.txt + CENTER)

        -- wait message
        panel.drawText(x + 50, y + 20, self.text, panel.FONT_SIZES.FONT_12 + WHITE, VCENTER)
        if self.retries > 1 then
            panel.drawText(x + 50, y + 20 +40,
                string.format("Retry %s/%s", self.retries, self.retryCount),
                panel.FONT_SIZES.FONT_8 + WHITE)
        end

        -- progress
        local percent = (getTime() - self.startTS) / self.timeout

        -- local fg_col = lcd.RGB(0x00, 0xB0, 0xDC)
        local prg_w = w-30
        local px = (prg_w - 2) * percent

        panel.drawFilledRectangle(x+15, y +h-30 +2, prg_w, 10, LIGHTGREY)
        -- panel.drawFilledRectangle(x+15, y +h-30 +2, px, 10, lcd.RGB(0x00, 0xB0, 0xDC))
        panel.drawFilledRectangle(x+15, y +h-30 +2, px, 10, GREEN)

    end

    if panel~=nil then
        panel.addCustomElement(self)
    end

    return self
end

return ctl_waiting_dialog

