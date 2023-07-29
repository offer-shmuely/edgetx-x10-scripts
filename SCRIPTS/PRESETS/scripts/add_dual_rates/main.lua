local m_log,m_utils,m_libgui  = ...

-- Author: Offer Shmuely (2023)
local ver = "0.1"
local app_name = "add_dual_rate"

local M = {}

local ctx2
local input_idx_ail = -1
local input_idx_ele = -1

---------------------------------------------------------------------------------------------------
local Fields = {
    dual_rate_switch = { text = 'Dual Rate switch:', x = 200, y = 60 , w = 50, is_visible = 1, default_value = 3, avail_values = { "SA", "SB", "SC", "SD", "SE", "SF", "SG", "SH" } },
    rate_high        = { text = 'High Rate:'       , x = 200, y = 90 , w = 50, is_visible = 1, default_value = 100, min = 50, max = 100 },
    rate_med         = { text = 'Medium Rate:'     , x = 200, y = 120, w = 50, is_visible = 1, default_value = 75 , min = 40, max = 90  },
    rate_low         = { text = 'Low Rate:'        , x = 200, y = 150, w = 50, is_visible = 1, default_value = 50 , min = 30, max = 80  },
    expo             = { text = 'Expo:'            , x = 200, y = 180, w = 50, is_visible = 1, default_value = 30 , min = 0 , max = 100 }, -- expo
}
---------------------------------------------------------------------------------------------------

function M.getVer()
    return ver
end

local function log(fmt, ...)
    m_log.info(fmt, ...)
end

---------------------------------------------------------------------------------------------------
local function updateInputLine(inputIdx, lineNo, expoWeight, weight, switch_name_position)
    local inInfo = model.getInput(inputIdx, 0)

    -- expo
    inInfo.curveType = 1
    inInfo.curveValue = expoWeight
    inInfo.weight = weight
    if (switch_name_position ~= nil) then
        local switchIndex = getSwitchIndex(switch_name_position)
        inInfo.switch = switchIndex
    end

    -- delete the old line
    model.deleteInput(inputIdx, lineNo)
    model.insertInput(inputIdx, lineNo, inInfo)
end

------------------------------------------------------------------------------------------------------

function M.init()
    local menu_x = 50
    local menu_w = 60
    local menu_h = 26

    input_idx_ail = m_utils.input_search_by_name("Ail")
    input_idx_ele = m_utils.input_search_by_name("Ele")

    if input_idx_ail == -1 then
        return "can not find Aileron input, will not be able to add dual rates"
    end
    if input_idx_ele == -1 then
        return "can not find Elevator input, will not be able to add dual rates"
    end

    log("Aileron input=%d", input_idx_ail)
    log("Elevator input=%d", input_idx_ele)


    ctx2 = m_libgui.newGUI()

    local p = Fields.dual_rate_switch
    ctx2.label(menu_x, p.y, menu_w, menu_h, p.text)
    p.gui_obj = ctx2.dropDown(p.x, p.y, p.w, menu_h, p.avail_values, p.default_value)

    local p = Fields.rate_high
    ctx2.label(menu_x, p.y, menu_w, menu_h, p.text)
    p.gui_obj = ctx2.number(p.x, p.y, p.w, menu_h, p.default_value)

    local p = Fields.rate_med
    ctx2.label(menu_x, p.y, menu_w, menu_h, p.text)
    p.gui_obj = ctx2.number(p.x, p.y, p.w, menu_h, p.default_value)

    local p = Fields.rate_low
    ctx2.label(menu_x, p.y, menu_w, menu_h, p.text)
    p.gui_obj = ctx2.number(p.x, p.y, p.w, menu_h, p.default_value)

    local p = Fields.expo
    ctx2.label(menu_x, p.y, menu_w, menu_h, p.text)
    p.gui_obj = ctx2.number(p.x, p.y, p.w, menu_h, p.default_value)

    return nil
end

function M.draw_page(event, touchState)
    ctx2.run(event, touchState)

    return m_utils.PRESET_RC.OK_CONTINUE
end

function M.do_update_model()
    local rate_high = Fields.rate_high.gui_obj.value
    local rate_med = Fields.rate_med.gui_obj.value
    local rate_low = Fields.rate_low.gui_obj.value
    local expoVal = Fields.expo.gui_obj.value
    local dr_switch_idx = Fields.dual_rate_switch.gui_obj.selected
    local dr_switch = Fields.dual_rate_switch.avail_values[dr_switch_idx]

    -- input lines
    updateInputLine(input_idx_ail, 0, expoVal, rate_high, dr_switch .. CHAR_UP)
    updateInputLine(input_idx_ail, 1, expoVal, rate_med , dr_switch .. "-")
    updateInputLine(input_idx_ail, 2, expoVal, rate_low , dr_switch .. CHAR_DOWN)

    updateInputLine(input_idx_ele, 0, expoVal, rate_high, dr_switch .. CHAR_UP)
    updateInputLine(input_idx_ele, 1, expoVal, rate_med , dr_switch .. "-")
    updateInputLine(input_idx_ele, 2, expoVal, rate_low , dr_switch .. CHAR_DOWN)

    return m_utils.PRESET_RC.OK_CONTINUE
end

return M
