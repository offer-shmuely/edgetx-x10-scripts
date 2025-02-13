local app_name, script_dir = ...

local M = {}

function M.buildSpecialFields(libGUI, panel, Page, y, updateValueChange)
    local row_x = 10
    local row_h = 35
    local row_w = 260
    local title_w = LCD_W - 10


    local f4_value = Page.fields[4].data.value /10
    local f5_value = Page.fields[5].data.value / 10

    libGUI.newControl.ctl_title(panel, nil, {
        x = 0, y = LCD_H-20, w = LCD_W, h=20,
        text1 = "*",
        text1_x = 10,
        bg_color = lcd.RGB(0x00, 0x78, 0xD4)
    })

    -- prfile
    libGUI.newControl.ctl_label(panel, nil, {x=5, y=50 , text="Bank (profile)", text_size=panel.FONT_SIZES.FONT_8 })
    libGUI.newControl.ctl_image(panel, nil, {x=0, y=70, w=40,h=40, img="/SCRIPTS/RF2_touch/touch/images/pids.png"})
    libGUI.newControl.ctl_label(panel, nil, {x=50, y=60 , text=string.format("%s", Page.fields[1].data.value+1), text_size=panel.FONT_SIZES.FONT_38, text_color=BLUE })

    -- rate
    libGUI.newControl.ctl_label(panel, nil, {x=5, y=150, text="Rate profile", text_size=panel.FONT_SIZES.FONT_8 })
    libGUI.newControl.ctl_image(panel, nil, {x=0, y=170, w=40,h=40, img="/SCRIPTS/RF2_touch/touch/images/rates.png"})
    libGUI.newControl.ctl_label(panel, nil, {x=50, y=160, text=string.format("%s", Page.fields[2].data.value+1), text_size=panel.FONT_SIZES.FONT_38, text_color=ORANGE })





    -- Dataflash Free Space
    libGUI.newControl.ctl_label(panel, "bb",            {x=300, y=y, text="Blackbox Storage"}, 0)
    libGUI.newControl.ctl_sliderHorizontal(panel, "bb", {x=300, y=y+30, w=160, value=f5_value, min=0, max=100, delta=1})
    y = y + 50

    libGUI.newControl.ctl_button(panel, "Erase", {x=300, y=y, w=150, h=50, text="Erase Blackbox", onPress=function()
            -- panel.showPrompt(aboutPanel)
        end
    })


    -- status
    libGUI.newControl.ctl_label(panel, nil, {x=200, y=256, text=string.format("Realtime Load: %s%%", f4_value), text_color=WHITE, text_size=panel.FONT_SIZES.FONT_6}, 0)
    libGUI.newControl.ctl_label(panel, nil, {x=350, y=257, text=string.format("CPU Load: %s%%", f5_value)     , text_color=WHITE, text_size=panel.FONT_SIZES.FONT_6}, 0)

    y = 170

    -- for i=1, 10 do

    --     local f = Page.fields[i]
    --     if f == nil then break end

    --     local f_min = f.min or (f.data and f.data.min) or 0
    --     local f_max = f.min or (f.data and f.data.max) or 0
    --     local f_value = f.value or (f.data and f.data.value)
    --     if (f_value) then
    --         f_value = f_value/(f.data.scale or 1)
    --     end
    --     -- local f_name = string.format("%d. %s (%s)", i, f.t2 or f.t, f_value)
    --     local f_name = string.format("%d. %s", i, f.t2 or f.t, f_value)

    --     libGUI.newControl.ctl_rf2_button_number(panel, txt, {
    --         x=row_x, y=y, w=row_w, h=row_h,
    --         min = f_min,
    --         max = f_max,
    --         steps=(1/(f.scale or 1))*(f.mult or 1),
    --         value=f_value,
    --         units="",
    --         text=f_name,
    --         -- help=help,
    --         -- callbackOnModalActive=function(ctl)    end,
    --         -- callbackOnModalInactive=function(ctl)  end
    --         -- onValueUpdated=function(ctl, newVal)
    --         --     updateValueChange(i, newVal)
    --         -- end
    --     })

    --     y = y + 50
    -- end



    return 999,200 -- firstRegularField, last_y
end

return M
