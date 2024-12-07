local allow_touch_app = ...
-- to disable touch app, and use the command line version. set to false
-- allow_touch_app = false

local LUA_VERSION = "2.1.14"

chdir("/SCRIPTS/RF2_touch")

local function select_ui()
    if allow_touch_app == false then
        return "ui.lua"
    end

    local ver, radio, maj, minor, rev, osname = getVersion()

    local isTouch = (osname=="EdgeTX") and (LCD_W==480) and (LCD_H==272 or LCD_H==320) and (maj==2) and (minor>=9)
    if isTouch then
        return "touch/ui_touch.lua"
    end

    return "ui.lua"
end

local run = nil
local scriptsCompiled = assert(loadScript("COMPILE/scripts_compiled.lua"))()

local stick_ail_val = getValue('ail')
local stick_ail_ele = getValue('ele')
local force_recompile = (math.abs(stick_ail_val) > 1000) and (math.abs(stick_ail_ele) > 1000)

if scriptsCompiled and force_recompile==false then
    assert(loadScript("rf2.lua"))()
    rf2.protocol = assert(rf2.loadScript("protocols.lua"))()
    rf2.radio = assert(rf2.loadScript("radios.lua"))().msp
    rf2.mspQueue = assert(rf2.loadScript("MSP/mspQueue.lua"))()
    rf2.mspQueue.maxRetries = rf2.protocol.maxRetries
    rf2.mspHelper = assert(rf2.loadScript("MSP/mspHelper.lua"))()
    assert(rf2.loadScript(rf2.protocol.mspTransport))()
    assert(rf2.loadScript("MSP/common.lua"))()
    local ui_file = select_ui()
    run = assert(rf2.loadScript(ui_file))(LUA_VERSION)
else
    run = assert(loadScript("COMPILE/compile.lua"))()
    collectgarbage()
end

return { run = run }
