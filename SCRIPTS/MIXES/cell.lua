-- battery cell voltage divider
-- offer shmuely 2023
--

local app_name = "batt-mix"
local app_ver= 0.1

-- up to 6 char
local _inputs = {
    { "BatSrc", SOURCE },          -- batt_total_voltage
    { "3s/6s" , VALUE, 0, 12, 0 }, -- cell_count
    { "li-ion", VALUE, 0 , 1, 0 }, -- lithium_ion, 0=LIPO battery, 1=LI-ION (18650/21500)
    { "idx"   , VALUE, 1 , 4, 0 }, -- idx, instance id, 0=no instance, this is the only one, 1=first instance, 2=second instance
  --{ "Lithium_HV" , BOOL  , 0  }, -- 0=LIPO battery, 1=LiHV 4.35V
}
--local _outputs = {"cell", "cell_count", "total"}

local voltageRanges_lipo = {4.3,8.6,12.9,17.2,21.5,25.8,30.1,34.4,38.7,43.0,47.3,51.6}
local voltageRanges_lion = {4.2,8.4,12.6,16.8,21,25.2,29.4,33.6,37.8,42,46.2,50.4,54.6}
local voltageRanges_hv   = {4.45,8.9,13.35,17.8,22.25,26.7,31.15,35.6,40.05,44.5,48.95,53.4,57.85}

local function log(fmt, ...)
    print("[" .. app_name .."] ".. string.format(fmt, ...))
end

-- Only invoke this function once.
local function calcCellCount(batt_total_voltage, Lithium_Ion, Lithium_HV)
    local voltageRanges = voltageRanges_lipo

    if Lithium_Ion == 1 and Lithium_HV == 0 then
        voltageRanges = voltageRanges_lion
    end
    if Lithium_Ion == 0 and Lithium_HV == 1 then
        voltageRanges = voltageRanges_hv
    end

    for i = 1, #voltageRanges do
        if batt_total_voltage < voltageRanges[i] then
            -- log("calcCellCount %s --> %s", batt_total_voltage, i)
            return i
        end
    end

    log("no match found" .. batt_total_voltage)
    return 1
end

local function run(batt_total_voltage, cell_count, lithium_ion, idx)
    if cell_count == 0 then
        cell_count = calcCellCount(batt_total_voltage, lithium_ion, 0)
    end
    local cell_v = batt_total_voltage/cell_count

    --log("------")
    --log("batt_total_voltage: " .. batt_total_voltage)
    --log("cellCount: " .. cell_count)
    --log("cell_v: " .. cell_v)

    local name_cell = "cell"
    local name_cell_count = "cel#"
    if idx > 0 then
        name_cell = idx .. "cel"
        name_cell_count = idx .. "c#"
    end
    --log("idx=%s, name=%s, name=%s", idx, name_cell, name_cell_count)

    local base_sens_id = idx *2
    setTelemetryValue(0x0310 + idx, 0, 1, cell_v * 100, 1, 2, name_cell)
    setTelemetryValue(0x0310+idx, 1, 1, cell_count, 0, 0, name_cell_count)

    -- return cell_v, math.ceil(cell_v * 1.024), cell_count, batt_total_voltage
    -- return cell_v, cell_count, batt_total_voltage
    return 0
end

return { input = _inputs, run = run }
