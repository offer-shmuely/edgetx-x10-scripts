local PageFiles = {}
local settings = assert(rf2.loadScript("PAGES/helpers/settingsHelper.lua"))().loadSettings()

-- Rotorflight pages.
PageFiles[#PageFiles + 1] = { title = "Status",             t2 = "Status",              per_profile=false, script = "status.lua",            img="about.png" }
PageFiles[#PageFiles + 1] = { title = "Rates",              t2 = "Rates",               per_profile=false, script = "rates.lua",             img="rates.png" }
PageFiles[#PageFiles + 1] = { title = "Profile - PIDs",     t2 = "PIDs",                per_profile=true,  script = "pids.lua",              img="pids.png" }
PageFiles[#PageFiles + 1] = { title = "Profile - Various",  t2 = "Various",             per_profile=true,  script = "profile.lua",           img="Various.png" }
PageFiles[#PageFiles + 1] = { title = "Profile - Rescue",   t2 = "Rescue",              per_profile=true,  script = "profile_rescue.lua",    img="rescue.png" }
PageFiles[#PageFiles + 1] = { title = "Profile - Governor", t2 = "Governor",            per_profile=true,  script = "profile_governor.lua",  img="governor.png" }
PageFiles[#PageFiles + 1] = { title = "Servos",             t2 = "Servos",              per_profile=false, script = "servos.lua",            img="servo.png" }
PageFiles[#PageFiles + 1] = { title = "Mixer",              t2 = "Mixer",               per_profile=false, script = "mixer.lua",             img="mixer.png" }
PageFiles[#PageFiles + 1] = { title = "Gyro Filters",       t2 = "Filters",             per_profile=false, script = "filters.lua",           img="filters.png" }
PageFiles[#PageFiles + 1] = { title = "Governor",           t2 = "Governor2",           per_profile=false, script = "governor.lua",          img="governor.png" }
PageFiles[#PageFiles + 1] = { title = "Accelerometer Trim", t2 = "Trim Acc",            per_profile=false, script = "accelerometer.lua",     img="acc.png" }
--PageFiles[#PageFiles + 1] = { title = "Copy profiles",      t2 = "Copy Prof",           per_profile=false, script = "copy_profiles.lua",     img="copy.png" }

if rf2.apiVersion >= 12.07 then
    PageFiles[#PageFiles + 1] = { title = "Model on TX",    t2 = "Model on TX",         per_profile=false, script = "model.lua" }
    -- PageFiles[#PageFiles + 1] = { title = "ESC - HW Platinum V5",       t2 = "ESC-HW P V5",    per_profile=false, script = "esc_hwpl5.lua" }
    -- PageFiles[#PageFiles + 1] = { title = "ESC - Scorpion Tribunus",    t2 = "ESC-Scorpion", per_profile=false, script = "esc_scorp.lua" }
    -- PageFiles[#PageFiles + 1] = { title = "ESC - YGE",                  t2 = "ESC-YGE",               per_profile=false, script = "esc_yge.lua" }
end

return PageFiles
