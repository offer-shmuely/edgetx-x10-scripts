-- Create a image area

-- args: x,y,w,h,text
function button(panel, id, args, flags)
    local self = {
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
        img = bitmap.open(args.img)
    }
    self.img = bitmap.resize(self.img, self.w, self.h)


    function self.draw(focused)
        local x, y, w, h = self.x, self.y, self.w, self.h
        if focused then
        --     panel.drawFocus(x, y, w, h)
        end

        -- rf2.log("drawBitmap: %s", args.img)
        -- panel.drawRectangle(x, y, w, h, panel.colors.btn.border)
        -- panel.drawBitmap(self.img, x+w-h+8, y+8, 50)
        panel.drawBitmap(self.img, x, y)

        -- if self.disabled then
        --     panel.drawFilledRectangle(x, y, w, h, GREY, 7)
        -- end
    end

    if panel~=nil then
        panel.addCustomElement(self)
    end
    return self
end

return button




