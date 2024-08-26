-- Create a text label
-- args: x, y, w, h, text

-- not yet: align_w=LEFT/CENTER/RIGHT, align_vert=TOP|CENTER|BUTTOM, text

function label(panel, id, args, flags)
    assert(args)
    assert(args.text)
        local self = {
        -- flags = bit32.bor(flags or panel.flags, VCENTER, panel.colors.primary1),
        flags = bit32.bor(flags or panel.flags, panel.colors.primary1),
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
        text = args.text,
    }

    function self.draw(focused)
        local flags = panel.getFlags(self)

        -- if focused then
        --     panel.drawFocus(x, y, w, h)
        -- end
        -- panel.drawText(panel._.align_w(self.x, self.w, flags), self.y + self.h / 2, self.text, self.flags)

        if self.w > 0 then
            self.flags = bit32.bor(self.flags, CENTER)
        else
            self.flags = bit32.band(self.flags, bit32.bnot(CENTER))
        end
        if self.h > 0 then
            self.flags = bit32.bor(self.flags, VCENTER)
        else
            self.flags = bit32.band(self.flags, bit32.bnot(VCENTER))
        end

        panel.drawText(
            panel._.align_w(self.x, self.w, self.flags),
            panel._.align_h(self.y, self.h, self.flags),
            self.text,
            self.flags)
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

return label
