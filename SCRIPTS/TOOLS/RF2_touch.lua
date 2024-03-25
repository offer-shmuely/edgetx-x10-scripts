local toolName = "TNS|_Rotorflight 2 touch v0.1|TNE"
chdir("/SCRIPTS/RF2_touch")

--local app_ver = "0.1.0"

-- local function isHighResolutionColor_on_EdgeTx_2_9_x()
--     local ver, radio, maj, minor, rev, osname = getVersion()
--     if osname ~= "EdgeTX"   then return false end
--     if LCD_W ~= 480         then return false end
--     if maj ~= 2             then return false end
--     if minor < 9            then return false end
--     return true
-- end

local function select_ui()
    local ver, radio, maj, minor, rev, osname = getVersion()

    local isTouch = (osname=="EdgeTX") and (LCD_W==480) and (maj==2) and (minor>=9)
    if isTouch then
        return "ui_touch.lua"
    end

     --local isHighresColor = (LCD_W == 480)
     --if isHighresColor then
     --    return "ui_color.lua"
     --end

    assert(false, "RF2 need EdgeTx with color screen")
    --return "ui.lua"
end

apiVersion = 0
mcuId = nil
runningInSimulator = string.sub(select(2,getVersion()), -4) == "simu"

local run = nil
local scriptsCompiled = assert(loadScript("COMPILE/scripts_compiled.lua"))()

if scriptsCompiled then
    protocol = assert(loadScript("protocols.lua"))()
    radio = assert(loadScript("radios.lua"))().msp
    assert(loadScript(protocol.mspTransport))()
    assert(loadScript("MSP/common.lua"))()
    local ui_file = select_ui()
    run = assert(loadScript(ui_file))()
    -- run = assert(loadScript("ui.lua"))()

else
    run = assert(loadScript("COMPILE/compile.lua"))()
end

return { run=run }
