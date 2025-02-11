local app_name, script_dir = ...

local M = {}

function M.buildSpecialFields(libGUI, panel, Page, y, updateValueChange)
    local num_col = 4
    local row_h = 35
    local col1_w = 120
    local col_w = (LCD_W-col1_w)/num_col-1
    local col_w2 = (LCD_W-col1_w)/num_col
    local hdr_h = 20

    -- col headers
    local txt
    libGUI.newControl.ctl_title(panel, nil, {x=0,y=y, w=col1_w, h=hdr_h, text1_x=10, bg_color=GREY, text1=" "})
    libGUI.newControl.ctl_title(panel, nil, {x=col1_w+1+0*(col_w2), y=y, w=col_w, h=hdr_h, text1_x="CENTER", bg_color=GREY, text1="P"})
    libGUI.newControl.ctl_title(panel, nil, {x=col1_w+1+1*(col_w2), y=y, w=col_w, h=hdr_h, text1_x="CENTER", bg_color=GREY, text1="I"})
    libGUI.newControl.ctl_title(panel, nil, {x=col1_w+1+2*(col_w2), y=y, w=col_w, h=hdr_h, text1_x="CENTER", bg_color=GREY, text1="D"})
    libGUI.newControl.ctl_title(panel, nil, {x=col1_w+1+3*(col_w2), y=y, w=col_w, h=hdr_h, text1_x="CENTER", bg_color=GREY, text1="Feed Fwd"})

    y = y + hdr_h
    -- line names
    libGUI.newControl.ctl_title(panel, nil, {x=0, y=y+0*row_h, w=col1_w, h=row_h, bg_color=RED,    text1_x=10, text1="ROLL"})
    libGUI.newControl.ctl_title(panel, nil, {x=0, y=y+1*row_h, w=col1_w, h=row_h, bg_color=GREEN,  text1_x=10, text1="PITCH"})
    libGUI.newControl.ctl_title(panel, nil, {x=0, y=y+2*row_h, w=col1_w, h=row_h, bg_color=BLUE,   text1_x=10, text1="YAW"})
    local last_y = y

    -- values
    -- local defaults = { 120,100,90, 150,150,150, 80,120,10, 60,70,0,     1,2,3,   4, 5, 6}
    for col=1, 4 do
        for row=1, 3 do
            local x1 = col1_w+1+(col-1)*(col_w2)
            local y1 = y + (row-1)*row_h
            local i = (col-1)*3 + row
            local f = Page.fields[i]

            libGUI.newControl.ctl_rf2_button_number(panel, "butnum-pid"..col.."-"..row, {
                x=x1+1, y=y1+1, w=col_w-2, h=row_h-2,
                min=f.min /  (f.scale or 1),
                max=f.max /  (f.scale or 1),
                steps=(1/(f.scale or 1))*(f.mult or 1),
                value=f.value,
                units="",
                text=nil,
                help=nil,
                onValueUpdated=function(ctl, newVal)
                    updateValueChange(i, newVal)
                end
            })

            last_y = y1
        end
    end

    y = last_y + 60

    -- advance
    num_col = 2
    col_w = (LCD_W-col1_w)/num_col-1
    col_w2 = (LCD_W-col1_w)/num_col

    libGUI.newControl.ctl_title(panel, nil,{x=0, y=y, w=LCD_W, h=25, text1="Advance", bg_color=panel.colors.topbar.bg, txt_color=panel.colors.topbar.txt})

    y = y + 25 + 4

    -- -- col headers
    -- local txt
    -- libGUI.newControl.ctl_title(panel, nil, {x=0, y=y, w=col1_w, h=hdr_h, text1_x=10, bg_color=GREY, text1=" "})
    -- libGUI.newControl.ctl_title(panel, nil, {x=col1_w+1+0*(col_w2), y=y, w=col_w, h=hdr_h, text1_x=="CENTER", bg_color=GREY, text1="Boost"}) -- boost
    -- libGUI.newControl.ctl_title(panel, nil, {x=col1_w+1+1*(col_w2), y=y, w=col_w, h=hdr_h, text1_x=="CENTER", bg_color=GREY, text1="HSI Offset Gain"}) -- offset

    -- y = y + hdr_h
    -- -- line names
    -- libGUI.newControl.ctl_title(panel, nil, {x=0, y=y+0*row_h, w=col1_w, h=row_h, bg_color=RED,    text1_x=10, text1="ROLL"})
    -- libGUI.newControl.ctl_title(panel, nil, {x=0, y=y+1*row_h, w=col1_w, h=row_h, bg_color=GREEN,  text1_x=10, text1="PITCH"})
    -- libGUI.newControl.ctl_title(panel, nil, {x=0, y=y+2*row_h, w=col1_w, h=row_h, bg_color=BLUE,   text1_x=10, text1="YAW"})

    -- -- values
    -- for col=1, 2 do
    --     for row=1, 3 do
    --         local x1 = col1_w+1+(col-1)*(col_w2)
    --         local y1 = y + (row-1)*row_h
    --         local i = 16 +(col-1)*3 + row
    --         local f = Page.fields[i]
    --         if f then
    --             rf2.log("111* %d.  f.value=%s, f.min=%s, f.max=%s, f.scale=%s", i, f.value, f.min, f.max, f.scale)

    --             local min = f.min or (f.data and f.data.min) or 0
    --             local max = f.min or (f.data and f.data.max) or 0
    --             local val = f.value or (f.data and f.data.value)
    --             -- rf2.log("111 min=%s", min)
    --             libGUI.newControl.ctl_rf2_button_number(panel, "butnum-adv"..col.."-"..row, {
    --                 x=x1+1, y=y1+1, w=col_w-2, h=row_h-2,
    --                 steps=f.mult,
    --                 value=val,
    --                 min=min / (f.scale or 1),
    --                 max=max / (f.scale or 1),
    --                 scale=(f.scale or 1),
    --                 units="",
    --                 text=nil,
    --                 help=nil,
    --                     onValueUpdated=function(ctl, newVal)
    --                     updateValueChange(i, newVal)
    --                 end
    --             })
    --         end
    --     end
    -- end

    return 18,200 -- firstRegularField, last_y
end

return M
