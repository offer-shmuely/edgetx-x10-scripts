-- TNS|Flights History|TNE

local function run()
    local ver, radio, maj, minor, rev, osname = getVersion()
    local nVer = maj*1000000 + minor*1000 + rev
    --wgt.log("version: %s, %s %s %s %s", string.format("%d.%03d.%03d", maj, minor, rev), nVer<2011000, nVer>2011000, nVer>=2011000, nVer>=2011000)
    local is_valid_ver = (nVer>=2011003)
    print(string.format("Version: %s, nVer: %d, is_valid_ver: %s", string.format("%d.%03d.%03d", maj, minor, rev), nVer, tostring(is_valid_ver)))

    if is_valid_ver==false then
        -- lcd.clear()
        lcd.drawText(10, 10, "Flights History\nRequires EdgeTX 2.11.3 or higher\nPlease upgrade your Radio\n\nPress <RTN> to exit", RED)
        return 0
    end

    return "/SCRIPTS/TOOLS/FlightsHistory/main.lua"
end

return { run = run }
