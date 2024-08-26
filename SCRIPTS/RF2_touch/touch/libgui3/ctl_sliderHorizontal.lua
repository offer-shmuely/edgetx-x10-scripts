
function horizontalSlider(panel, id, args)
    local self = {
        -- args
        x=args.x,
        y=args.y,
        w=args.w,
        value=args.value,
        min = args.min,
        max = args.max,
        delta = args.delta,
        callback=args.callback or panel.doNothing,

        disabled = false,
        hidden= false,
        editable = true,

        SLIDER_DOT_RADIUS = 10,
    }

    function self.draw(focused)
        local x,y,w = self.x, self.y, self.w
        local xdot = x + w * (self.value - self.min) / (self.max - self.min)

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

        panel.drawFilledRectangle(x, y - 2, w, 5, colorBar)
        panel.drawFilledCircle(xdot, y, self.SLIDER_DOT_RADIUS, colorDot)
        panel.drawCircle(xdot, y, self.SLIDER_DOT_RADIUS, colorDotBorder, 2)
    end

    function self.onEvent(event, touchState)
        local x,y,w = self.x, self.y, self.w
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
            local value = self.min + (self.max - self.min) * (touchState.x - x) / w
            value = math.min(self.max, value)
            value = math.max(self.min, value)
            self.value = self.min + self.delta * math.floor((value - self.min) / self.delta + 0.5)
        end

        if v0 ~= self.value then
            self.callback(self)
        end
    end

    function self.covers(p, q)
        local xdot = self.x + self.w * (self.value - self.min) / (self.max - self.min)
        return ((p - xdot) ^ 2 + (q - self.y) ^ 2 <= 2 * self.SLIDER_DOT_RADIUS ^ 2)
    end

    if panel~=nil then
        panel.addCustomElement(self)
    end
    return self
end

return horizontalSlider
