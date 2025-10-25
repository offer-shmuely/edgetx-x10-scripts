-- args: x, y, w, h, items, selected, callback

function menu(panel, id, args, flags)
    assert(args)
    assert(args.items)
    assert(args.items[1])

    local self = {
        panel = panel,
        id = id,
        x = args.x,
        y = args.y,
        w = args.w,
        h = args.h,
        items0or1 = args.items or { "No items!" }, -- can be 0 based table, or 1 based table
        items1 = panel._.tableBasedX_convertTableTo1Based(args.items), -- 1 based table
        selected0or1 = args.selected or 1,
        initiatedselected0or1 = args.selected or 1,
        selected1 = panel._.tableBasedX_convertSelectedTo1Based(args.selected or 1, args.items),
        initiatedSelected1 = panel._.tableBasedX_convertSelectedTo1Based(args.selected or 1, args.items),
        callback = args.callback or panel.doNothing,
        flags = bit32.bor(flags or panel.flags),

        disabled = false,
        editable = true,
        hidden= false,
        dropdown_mode = false
    }

    local itemCount = panel._.tableBasedX_getLength(self.items0or1)
    local selected1 = panel._.tableBasedX_convertSelectedTo1Based(self.selected0or1, self.items0or1)
    local firstVisible = 1
    local firstVisibleScrolling
    local moving = 0
    local lh = 3 + select(2, lcd.sizeText("", self.flags)) -- space between lines (should be sync to dropdown)
    local visibleCount = math.floor(self.h / lh)
    local killEvt
    panel.log("111 self.selected1:%s self.selected0or1:%s", selected1, self.selected0or1)

    function self.isDirty()
        return selected1 ~= self.initiatedSelected1
    end

    local function setFirstVisible(v)
        firstVisible = v
        firstVisible = math.max(1, firstVisible)
        firstVisible = math.min(itemCount - visibleCount + 1, firstVisible)
    end

    local function adjustScroll()
        panel.log("111 %s %s %s", selected1, firstVisible, visibleCount)

        if selected1 >= firstVisible + visibleCount then
            firstVisible = selected1 - visibleCount + 1
        elseif selected1 < firstVisible then
            firstVisible = selected1
        end
    end

    function self.getSelected()
        return selected1
    end

    function self.getSelectedText()
        local txt = self.items1[selected1]
        return txt
    end

    function self.draw(focused)
        local flags = panel.getFlags(self)
        local visibleCount = math.min(visibleCount, itemCount)
        visibleCount = math.min(visibleCount, #self.items1)
        local sel
        local bgColor

        if focused and panel.editing then
            bgColor = panel.colors.edit
        else
            selected1 = self.selected1
            bgColor = panel.colors.list.selected.bg
        end
        if self.dropdown_mode then
            bgColor = panel.colors.list.selected.bg
        end


        for i = 0, visibleCount - 1 do
            local j = firstVisible + i
            local y = self.y + i * lh

            panel.log('self.items1:');
            for k, v in ipairs(self.items1) do
                panel.log("  %d: %s", k, v)
            end

            panel.log("111 j:%d visibleCount:%d itemCount:%d", j, visibleCount, itemCount)
            assert(self.items1)
            assert(self.items1[j])
            local x1 = panel._.align_w(self.x, self.w, flags)

            local txt_col = panel.colors.list.txt
            if j == selected1 then
                panel.drawFilledRectangle(self.x, y, self.w, lh, bgColor)
                txt_col = panel.colors.list.selected.txt
            end
            panel.drawText(x1+5, y + lh/2, self.items1[j], bit32.bor(txt_col, flags, VCENTER))
        end

        if focused then
            panel.drawFocus(self.x, self.y, self.w, self.h)
        end
    end

    function self.onEvent(event, touchState)
        panel.log("menu - onEvent")
        local visibleCount = math.min(visibleCount, itemCount)

        if moving ~= 0 then
            if panel.match(event, EVT_TOUCH_FIRST, EVT_VIRTUAL_ENTER, EVT_VIRTUAL_EXIT) then
                moving = 0
                event = 0
            else
                setFirstVisible(firstVisible + moving)
            end
        end

        if event ~= 0 then
            -- This hack is needed because killEvents does not seem to work
            if killEvt then
                killEvt = false
                if event == EVT_VIRTUAL_ENTER then
                    event = 0
                end
            end

            -- If we touch it, then start editing immediately
            if touchState then
                panel.editing = true
            end

            if event == EVT_TOUCH_SLIDE then
                if panel._.scrolling then
                    if touchState.swipeUp then
                        moving = 1
                    elseif touchState.swipeDown then
                        moving = -1
                    elseif touchState.startX then
                        setFirstVisible(firstVisibleScrolling + math.floor((touchState.startY - touchState.y) / lh + 0.5))
                    end
                end
            else
                panel._.scrolling = false

                if event == EVT_TOUCH_FIRST then
                    panel._.scrolling = true
                    firstVisibleScrolling = firstVisible
                elseif panel.match(event, EVT_VIRTUAL_NEXT, EVT_VIRTUAL_PREV) then
                    if event == EVT_VIRTUAL_NEXT then
                        selected1 = math.min(itemCount, selected1 + 1)
                        panel.log("EVT_VIRTUAL_NEXT --> selected: %d", selected1)
                    elseif event == EVT_VIRTUAL_PREV then
                        selected1 = math.max(1, selected1 - 1)
                        panel.log("EVT_VIRTUAL_PREV --> selected: %d", selected1)
                    end
                    adjustScroll()
                    --self.callback(self, "temp") --???
                elseif event == EVT_VIRTUAL_ENTER then
                    if panel.editing then
                        if touchState then
                            selected1 = firstVisible + math.floor((touchState.y - self.y) / lh)
                            panel.log("111 EVT_VIRTUAL_ENTER --> selected: %d", selected1)
                        end

                        panel.editing = false
                        self.selected1 = selected1
                        self.callback(self)
                        --self.callback(self, "final") --???
                    else
                        panel.editing = true
                        selected1 = self.selected1
                        --self.callback(self, "temp") --???
                        adjustScroll()
                    end
                elseif event == EVT_VIRTUAL_EXIT then
                    panel.editing = false
                end
            end
        end
    end

    if panel~=nil then
        panel.addCustomElement(self)
    end

    return self
end

return menu
