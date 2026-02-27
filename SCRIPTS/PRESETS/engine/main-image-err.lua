local app_name = "PresetsLoader"

local app_folder    = "/SCRIPTS/PRESETS"

-- better font names
local FS={FONT_38=XXLSIZE,FONT_16=DBLSIZE,FONT_12=MIDSIZE,FONT_8=0,FONT_6=SMLSIZE}

local function init()
    lvgl.clear()
    lvgl.build({
        -- {type="image", x=0, y=0, w=LCD_W, h=LCD_H, file=ImgBackground},
        {type="image", x=20, y=20, w=300, h=200, file="/SCRIPTS/PRESETS/engine/img/background.png", fill=true},
        {type="label", text="Preset:", x=75, y=65, color=BLACK},

    })
end

local function run(event, touchState)
    return 0
end


return { init=init, run=run, useLvgl=true }
