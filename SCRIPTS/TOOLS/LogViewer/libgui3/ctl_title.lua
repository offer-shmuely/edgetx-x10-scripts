-- Create a text label
-- args: x, y, w, h, txt_color, bg_color, [text1_x, text1, text2_x,text2]
function title(panel, id, args, flags)
    assert(args)
        local self = {
        flags = flags or 0,
        disabled = false,
        editable = false,
        hidden= false,

        panel = panel,
        id = id,
        -- args
        x = args.x,
        y = args.y,
        w = args.w or 0,
        h = args.h or 0,
        text1 = args.text1 or "",
        text1_x = args.text1_x or 30,
        txt_color = args.txt_color or WHITE,
        bg_color = args.bg_color or GREY,

    }
    if self.text1_x == "CENTER" then
        self.text1_x = self.w/ 2
        self.flags = bit32.bor(self.flags, CENTER)
        self.flags = CENTER
    end

    function self.draw(focused)
        local x,y,w,h = self.x, self.y, self.w, self.h
        local flags = panel.getFlags(self)

        panel.drawFilledRectangle(x, y, w, h, self.bg_color, 2) -- header
        panel.drawRectangle(x + 5, y + 2, 10, 10, WHITE, 0) -- x
        panel.drawRectangle(x, y, w, h, GREY, 0) -- border

        panel.drawText(
            self.x + self.text1_x,
            self.y + self.h/2,
            self.text1,
            self.txt_color + VCENTER + self.flags
            -- bit32.bor(self.txt_color, VCENTER, self.flags)
        )

    end

    -- We should not ever onEvent, but just in case...
    function self.onEvent(event, touchState)
        -- self.disabled = true
        moveFocus(1)
    end

    function self.covers(p, q)
        return false
    end

    if panel~=nil then
        panel.addCustomElement(self)
    end

    return self
end

return title
