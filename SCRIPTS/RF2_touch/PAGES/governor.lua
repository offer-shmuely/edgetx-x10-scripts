local template = assert(rf2.loadScript(rf2.radio.template))()
local mspGovernorConfig = assert(rf2.loadScript("MSP/mspGovernorConfig.lua"))()
local margin = template.margin
local indent = template.indent
local lineSpacing = template.lineSpacing
local tableSpacing = template.tableSpacing
local sp = template.listSpacing.field
local yMinLim = rf2.radio.yMinLimit
local x = margin
local y = yMinLim - lineSpacing
local inc = { x = function(val) x = x + val return x end, y = function(val) y = y + val return y end }
local labels = {}
local fields = {}
local governorConfig = {}

x = margin
y = yMinLim - tableSpacing.header

fields[1] = { t = "Mode",                x = x, y = inc.y(lineSpacing), sp = x + sp, min = 0, max = 4,     vals = { 1 }, table = { [0]="OFF", "PASSTHROUGH", "STANDARD", "MODE1", "MODE2" }, id="govMode" }
fields[2] = { t = "Handover throttle%",  x = x, y = inc.y(lineSpacing), sp = x + sp, min = 10, max = 50,   vals = { 20 },                 id = "govHandoverThrottle" }
fields[3] = { t = "Startup time",        x = x, y = inc.y(lineSpacing), sp = x + sp, min = 0, max = 600,   vals = { 2,3 }, scale = 10,    id = "govStartupTime" }
fields[4] = { t = "Spoolup time",         x = x, y = inc.y(lineSpacing), sp = x + sp, id = "govSpoolupTime" }
fields[5] = { t = "Tracking time",       x = x, y = inc.y(lineSpacing), sp = x + sp, min = 0, max = 100,   vals = { 6,7 }, scale = 10,    id = "govTrackingTime" }
fields[6] = { t = "Recovery time",       x = x, y = inc.y(lineSpacing), sp = x + sp, min = 0, max = 100,   vals = { 8,9 }, scale = 10,    id ="govRecoveryTime" }
fields[7] = { t = "AR bailout time",     x = x, y = inc.y(lineSpacing), sp = x + sp, min = 0, max = 100,   vals = { 16,17 }, scale = 10,  id = "govAutoBailoutTime" }
fields[8] = { t = "AR timeout",          x = x, y = inc.y(lineSpacing), sp = x + sp, min = 0, max = 100,   vals = { 14,15 }, scale = 10,  id = "govAutoTimeout" }
fields[9] = { t = "AR min entry time",   x = x, y = inc.y(lineSpacing), sp = x + sp, min = 0, max = 100,   vals = { 18,19 }, scale = 10,  id = "govAutoMinEntryTime" }
fields[10] = { t = "Zero throttle TO",    x = x, y = inc.y(lineSpacing), sp = x + sp, min = 0, max = 100,   vals = { 10,11 }, scale = 10,  id = "govZeroThrottleTimeout" }
fields[11] = { t = "HS signal timeout",   x = x, y = inc.y(lineSpacing), sp = x + sp, min = 0, max = 100,   vals = { 12,13 }, scale = 10,  id = "govLostHeadspeedTimeout" }
fields[12] = { t = "HS filter cutoff",    x = x, y = inc.y(lineSpacing), sp = x + sp, min = 0, max = 250,   vals = { 22 },                 id = "govHeadspeedFilterHz" }
fields[13] = { t = "Volt. filter cutoff", x = x, y = inc.y(lineSpacing), sp = x + sp, min = 0, max = 250,   vals = { 21 },                 id = "govVoltageFilterHz" }
fields[14] = { t = "TTA bandwidth",       x = x, y = inc.y(lineSpacing), sp = x + sp, min = 0, max = 250,   vals = { 23 },                 id = "govTTAFilterHz" }
fields[15] = { t = "Precomp bandwidth",   x = x, y = inc.y(lineSpacing), sp = x + sp, min = 0, max = 250,   vals = { 24 },                 id = "govFFFilterHz" }

local function setValues()
    fields[1].data = governorConfig.gov_mode
    fields[2].data = governorConfig.gov_handover_throttle
    fields[3].data = governorConfig.gov_startup_time
    fields[4].data = governorConfig.gov_spoolup_time
    fields[5].data = governorConfig.gov_tracking_time
    fields[6].data = governorConfig.gov_recovery_time
    fields[7].data = governorConfig.gov_autorotation_bailout_time
    fields[8].data = governorConfig.gov_autorotation_timeout
    fields[9].data = governorConfig.gov_autorotation_min_entry_time
    fields[10].data = governorConfig.gov_zero_throttle_timeout
    fields[11].data = governorConfig.gov_lost_headspeed_timeout
    fields[12].data = governorConfig.gov_rpm_filter
    fields[13].data = governorConfig.gov_pwr_filter
    fields[14].data = governorConfig.gov_tta_filter
    fields[15].data = governorConfig.gov_ff_filter
end

local function receivedGovernorConfig(page, config)
    governorConfig = config
    setValues()
    rf2.lcdNeedsInvalidate = true
    page.isReady = true
end

return {
    read = function(self)
        mspGovernorConfig.getGovernorConfig(receivedGovernorConfig, self)
    end,
    write = function(self)
        mspGovernorConfig.setGovernorConfig(governorConfig)
        rf2.settingsSaved()
    end,
    title       = "Governor",
    reboot      = true,
    eepromWrite = true,
    labels      = labels,
    fields      = fields
}
