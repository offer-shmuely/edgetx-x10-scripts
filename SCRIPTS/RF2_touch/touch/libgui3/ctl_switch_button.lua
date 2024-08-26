-- args: x,y,value, callback
function switch_button(panel, id, args, flags)
    local space1 = 2
    local space2 = 5
    local r1 = 17
    local r2 = 13

    local self = {
        flags = bit32.bor(flags or panel.flags, CENTER, VCENTER),
        disabled = false,
        editable = true,
        hidden= false,

        panel = panel,
        id = id,
        x = args.x,
        y = args.y,
        h = 36,
        w= r1*4,
        value = args.value,
        callback = args.callback or panel.doNothing,
    }

    function self.draw(focused)
        local x,y,w,h = self.x, self.y, self.w,self.h
        local fg = panel.colors.secondary1
        local bg = panel.colors.primary2
        local border = panel.colors.secondary2
        if self.value then
            bg = panel.colors.active
        end
        if focused then
            border = panel.colors.focus
        end

        -- border
        panel.drawFilledCircle(x + r1  , y + r1, r1, border)
        panel.drawFilledCircle(x + 3*r1, y + r1, r1, border)
        panel.drawFilledRectangle(x + r1, y, 2*r1, 2*r1+1, border)
        -- background
        panel.drawFilledCircle(x + r1  , y + r1, r1-space1, bg)
        panel.drawFilledCircle(x + 3*r1, y + r1, r1-space1, bg)
        panel.drawFilledRectangle(x + r1, y+space1, 2*r1, 2*r1-2*space1+1, bg)
        -- circle
        if self.value then
            panel.drawFilledCircle(x + 2*space2 + 3*r2, y + r1, r2, fg)
        else
            panel.drawFilledCircle(x + space2 + r2  , y + r1, r2, fg)
        end

        if self.disabled then
            panel.drawFilledRectangle(x, y, w, h, GREY, 7)
        end
    end

    function self.onEvent(event, touchState)
        if event == EVT_VIRTUAL_ENTER then
            self.value = not self.value
            return self.callback(self)
        end
    end

    if panel~=nil then
        panel.addCustomElement(self)
    end
    return self
end

return switch_button




