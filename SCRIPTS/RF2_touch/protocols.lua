local supportedProtocols =
{
    smartPort =
    {
        mspTransport    = "MSP/sp.lua",
        push            = sportTelemetryPush,
        maxTxBufferSize = 6,
        maxRxBufferSize = 6,
        maxRetries      = 3,
        saveTimeout     = 5.0,
        cms             = {},
    },
    crsf =
    {
        mspTransport    = "MSP/crsf.lua",
        cmsTransport    = "CMS/crsf.lua",
        push            = crossfireTelemetryPush,
        maxTxBufferSize = 8,
        maxRxBufferSize = 58,
        maxRetries      = 3,
        saveTimeout     = 3.0,
        cms             = {},
    },
    ghst =
    {
        mspTransport    = "MSP/ghst.lua",
        push            = ghostTelemetryPush,
        maxTxBufferSize = 10, -- Tx -> Rx (Push)
        maxRxBufferSize = 6,  -- Rx -> Tx (Pop)
        maxRetries      = 3,
        saveTimeout     = 3.0,
        cms             = {},
    },
    simu =
    {
        mspTransport    = "MSP/simu.lua",
        push            = ghostTelemetryPush,
        maxTxBufferSize = 10, -- Tx -> Rx (Push)
        maxRxBufferSize = 6,  -- Rx -> Tx (Pop)
        maxRetries      = 3,
        saveTimeout     = 3.0,
        cms             = {},
    }
}

local function getProtocol()
    if supportedProtocols.smartPort.push() ~= nil then
        return supportedProtocols.smartPort
    elseif supportedProtocols.crsf.push() ~= nil then
        return supportedProtocols.crsf
    elseif supportedProtocols.ghst.push() ~= nil then
        return supportedProtocols.ghst
    elseif rf2.runningInSimulator ~= nil then
        return supportedProtocols.simu
    end
end

local protocol = assert(getProtocol(), "Telemetry protocol not supported!")

return protocol
