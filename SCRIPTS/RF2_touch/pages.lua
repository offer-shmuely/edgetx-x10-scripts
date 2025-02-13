local PageFiles = {}
local settings = assert(rf2.loadScript("PAGES/helpers/settingsHelper.lua"))().loadSettings()

-- Rotorflight pages.
PageFiles[#PageFiles + 1] = { title = "Status",             t2 = "Status",              type="",            script = "status.lua",            img="about.png" }
PageFiles[#PageFiles + 1] = { title = "Rates",              t2 = "Rates",               type="per_rate",    script = "rates.lua",             img="rates.png" }
PageFiles[#PageFiles + 1] = { title = "Profile - PIDs",     t2 = "PIDs",                type="per_profile", script = "pids.lua",              img="pids.png" }
PageFiles[#PageFiles + 1] = { title = "Profile - Various",  t2 = "Various",             type="per_profile", script = "profile.lua",           img="Various.png" }
PageFiles[#PageFiles + 1] = { title = "Profile - Rescue",   t2 = "Rescue",              type="per_profile", script = "profile_rescue.lua",    img="rescue.png" }
PageFiles[#PageFiles + 1] = { title = "Profile - Governor", t2 = "Governor",            type="per_profile", script = "profile_governor.lua",  img="governor.png" }
PageFiles[#PageFiles + 1] = { title = "Servos",             t2 = "Servos",              type="",            script = "servos.lua",            img="servo.png" }
PageFiles[#PageFiles + 1] = { title = "Mixer",              t2 = "Mixer",               type="",            script = "mixer.lua",             img="mixer.png" }
PageFiles[#PageFiles + 1] = { title = "Gyro Filters",       t2 = "Filters",             type="",            script = "filters.lua",           img="filters.png" }
PageFiles[#PageFiles + 1] = { title = "Governor",           t2 = "Governor2",           type="",            script = "governor.lua",          img="governor.png" }
-- PageFiles[#PageFiles + 1] = { title = "Accelerometer Trim", t2 = "Trim Acc",            type="",            script = "accelerometer.lua",     img="acc.png" }
--PageFiles[#PageFiles + 1] = { title = "Copy profiles",      t2 = "Copy Prof",           per_profile=false, script = "copy_profiles.lua",     img="copy.png" }

if rf2.apiVersion >= 12.07 then
    -- if settings.showModelOnTx == 1 then
        -- PageFiles[#PageFiles + 1] = { title = "Model on TX", script = "model.lua" }
    -- end
    -- if settings.showExperimental == 1 then
        -- PageFiles[#PageFiles + 1] = { title = "Experimental (danger!)", t2 = "Experimental (danger!)", type="", script = "experimental.lua" }
    -- end
    -- if settings.showFlyRotor == 1 then
        -- PageFiles[#PageFiles + 1] = { title = "ESC - FlyRotor",             t2="FlyRotor", type="esc", script = "esc_flyrotor.lua", img="esc_xdfly.png" }
    -- end
    -- if settings.showPlatinumV5 == 1 then
        -- PageFiles[#PageFiles + 1] = { title = "ESC - HW Platinum V5",       t2 = "HW V5",    type="esc", script = "esc_hwpl5.lua", img="esc_hobbywing.png" }
    -- end
    -- if settings.showTribunus == 1 then
        -- PageFiles[#PageFiles + 1] = { title = "ESC - Scorpion Tribunus",    t2 = "Scorpion", type="esc", script = "esc_scorp.lua", img="esc_scorpion.png"}
    -- end
    -- if settings.showYge == 1 then
        -- PageFiles[#PageFiles + 1] = { title = "ESC - YGE",                  t2 = "YGE",      type="esc", script = "esc_yge.lua", img="esc_yge.png" }
    -- end

    -- PageFiles[#PageFiles + 1] = { title = "Settings", t2 = "Settings", script = "settings.lua", img="settings.png"  }
end

return PageFiles
