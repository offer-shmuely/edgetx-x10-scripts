local app_name, script_dir = ...

local M = {}

function M.buildSpecialFields(libGUI, panel, Page, y, updateValueChange)
    local row_x = 10
    local row_h = 35
    local row_w = 260
    local title_w = LCD_W - 10

    local txt

    -- libGUI.newControl.ctl_title(panel, nil, {x=0, y=y, w=LCD_W, h=25, text1="Status", bg_color=panel.colors.topbar.bg, txt_color=panel.colors.topbar.txt})
    -- y = y + 40


    local f4 = Page.fields[4]
    local f4_value = f4.data.value /10
    local f5 = Page.fields[5]
    local f5_value = f5.data.value / 10



    -- real-time load
    libGUI.newControl.ctl_label(panel, nil,              {x=300, y=y, text="Realtime Load"}, 0)
    libGUI.newControl.ctl_sliderHorizontal(panel, "cpu", {x=300, y=y+30, w=160, value=f4_value, min=0, max=100, delta=1})
    y = y + 50

    -- cpu load
    libGUI.newControl.ctl_label(panel, nil,              {x=300, y=y, text="CPU Load"}, 0)
    libGUI.newControl.ctl_sliderHorizontal(panel, "cpu", {x=300, y=y+30, w=160, value=f5_value, min=0, max=100, delta=1})
    y = y + 60

    -- Dataflash Free Space
    libGUI.newControl.ctl_label(panel, nil,              {x=300, y=y, text="Blackbox Storage"}, 0)
    libGUI.newControl.ctl_sliderHorizontal(panel, "cpu", {x=300, y=y+30, w=160, value=f5_value, min=0, max=100, delta=1})
    y = y + 50

    libGUI.newControl.ctl_button(panel, "Erase", {x=300, y=y, w=130, h=30, text="Erase Blackbox", onPress=function()
            -- panel.showPrompt(aboutPanel)
        end
    })


    libGUI.newControl.ctl_label(panel, nil, {x=30, y=80, text=string.format("PID profile (bank): %s", Page.fields[1].data.value) }, 0)
    libGUI.newControl.ctl_label(panel, nil, {x=30, y=120, text=string.format("Rate profile: %s", Page.fields[2].data.value) }, 0)


    y = 170

    for i=1, 10 do

        local f = Page.fields[i]
        if f == nil then break end

        local f_min = f.min or (f.data and f.data.min) or 0
        local f_max = f.min or (f.data and f.data.max) or 0
        local f_value = f.value or (f.data and f.data.value)
        if (f_value) then
            f_value = f_value/(f.data.scale or 1)
        end
        -- local f_name = string.format("%d. %s (%s)", i, f.t2 or f.t, f_value)
        local f_name = string.format("%d. %s", i, f.t2 or f.t, f_value)

        libGUI.newControl.ctl_rf2_button_number(panel, txt, {
            x=row_x, y=y, w=row_w, h=row_h,
            min = f_min,
            max = f_max,
            steps=(1/(f.scale or 1))*(f.mult or 1),
            value=f_value,
            units="",
            text=f_name,
            -- help=help,
            -- callbackOnModalActive=function(ctl)    end,
            -- callbackOnModalInactive=function(ctl)  end
            -- onValueUpdated=function(ctl, newVal)
            --     updateValueChange(i, newVal)
            -- end
        })

        y = y + 50
    end



    return 999,200 -- firstRegularField, last_y
end

return M
