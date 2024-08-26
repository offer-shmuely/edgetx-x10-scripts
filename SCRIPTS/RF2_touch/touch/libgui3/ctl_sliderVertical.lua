
function verticalSlider(panel, id, args)
    local self = {
        disabled = false,
        hidden= false,
        editable = true,

        -- args
        x=args.x,
        y=args.y,
        h=args.h,
        value=args.value,
        min = args.min,
        max = args.max,
        delta = args.delta,
        callback=args.callback or panel.doNothing,

        SLIDER_DOT_RADIUS=10,
    }

    function self.draw(focused)
        local x,y,h = self.x, self.y, self.h

        local ydot = y + h * (1 - (self.value - self.min) / (self.max - self.min))

        local colorBar = panel.colors.primary3
        local colorDot = panel.colors.primary2
        local colorDotBorder = panel.colors.primary3

        if focused then
            colorDotBorder = panel.colors.active
            if panel.editing or panel._.scrolling then
                colorBar = panel.colors.primary1
                colorDot = panel.colors.edit
            end
        end

        panel.drawFilledRectangle(x - 2, y, 5, h, colorBar)
        panel.drawFilledCircle(x, ydot, self.SLIDER_DOT_RADIUS, colorDot)
        for i = -1, 1 do
            panel.drawCircle(x, ydot, self.SLIDER_DOT_RADIUS + i, colorDotBorder)
        end
    end

    function self.onEvent(event, touchState)
        local x,y,h = self.x, self.y, self.h
        local v0 = self.value

        if panel.editing then
            if panel.match(event, EVT_VIRTUAL_ENTER, EVT_VIRTUAL_EXIT) then
                panel.editing = false
            elseif event == EVT_VIRTUAL_INC then
                self.value = math.min(self.max, self.value + self.delta)
            elseif event == EVT_VIRTUAL_DEC then
                self.value = math.max(self.min, self.value - self.delta)
            end
        elseif event == EVT_VIRTUAL_ENTER then
            panel.editing = true
        end

        if event == EVT_TOUCH_SLIDE then
            local value = self.max - (self.max - self.min) * (touchState.y - y) / h
            value = math.min(self.max, value)
            value = math.max(self.min, value)
            self.value = self.min + self.delta * math.floor((value - self.min) / self.delta + 0.5)
        end

        if v0 ~= self.value then
            self.callback(self)
        end
    end

    function self.covers(p, q)
        local ydot = self.y + self.h * (1 - (self.value - self.min) / (self.max - self.min))
        return ((p - self.x) ^ 2 + (q - ydot) ^ 2 <= 2 * self.SLIDER_DOT_RADIUS ^ 2)
    end

    if panel~=nil then
        panel.addCustomElement(self)
    end
    return self
end


return verticalSlider
