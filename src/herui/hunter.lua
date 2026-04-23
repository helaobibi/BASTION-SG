-- HunterUI Class
-- =============================================

local _, playerClass = UnitClass("player")
if playerClass ~= "HUNTER" then return end

-- =============================================
-- Constants
-- =============================================


-- 第一行按钮配置
local ROW1_BUTTONS = {
    { name = "ViperStingModeButton", state = "viperStingMode", icon = "Interface\\Icons\\ability_hunter_aimedshot",         label = "蝰蛇" },
    { name = "BlackArrowButton",     state = "blackArrow",     icon = "Interface\\Icons\\spell_shadow_painspike",           label = "黑箭",  exclusive = {"explosiveTrap"} },
    { name = "ExplosiveTrapButton",  state = "explosiveTrap",  icon = "Interface\\Icons\\Spell_Fire_SelfDestruct",          label = "爆炸",  exclusive = {"blackArrow"} },
    { name = "AimedShotButton",      state = "aimedShot",      icon = "Interface\\Icons\\inv_spear_07",                     label = "瞄准",  exclusive = {"multiShot"} },
    { name = "MultiShotButton",      state = "multiShot",      icon = "Interface\\Icons\\ability_upgrademoonglaive",        label = "多重",  exclusive = {"aimedShot"} },
    { name = "PetAttackButton",      state = "petAttack",      icon = "Interface\\Icons\\Ability_Physical_Taunt",           label = "攻击",  exclusive = {"petFollow"} },
    { name = "PetFollowButton",      state = "petFollow",      icon = "Interface\\Icons\\Spell_Nature_Spiritwolf",          label = "跟随",  exclusive = {"petAttack"} },
    { name = "ViperStingButton",     state = "viperSting",     icon = "Interface\\Icons\\ability_hunter_aspectoftheviper",  label = "蚰蛇" },
}

-- 第二行下拉框配置
local ROW2_DROPDOWNS = {
    { name = "HunterTrapDistanceDropdown",          state = "trapDistanceOffset",    label = "陷阱距离", options = {1, 2, 3, 4, 5, 6, 7, 8, 9}, ref = "trapDistanceDropdown",          width = 42 },
    { name = "HunterPorcupineBaitDistanceDropdown", state = "porcupineBaitDistance", label = "豪猪距离", options = {5, 10, 15, 20},               ref = "porcupineBaitDistanceDropdown", width = 42 },
    { name = "HunterPetFollowThresholdDropdown",    state = "petFollowThreshold",    label = "跟随血线", options = {50, 60, 70, 80, 90, 100},          ref = "petFollowThresholdDropdown",    width = 42, valueSuffix = "%" },
    { name = "HunterPetHealThresholdDropdown",      state = "petHealThreshold",      label = "治疗血线", options = {50, 60, 70, 80, 90, 100},     ref = "petHealThresholdDropdown",      width = 42, valueSuffix = "%" },
}

-- 第二行按钮配置
local ROW2_BUTTONS = {
    { name = "IgnoreLowHealthFollowButton", state = "ignoreLowHealthFollow", icon = "Interface\\Icons\\ability_hunter_pet_bear",     label = "忽略低血" },
    { name = "StealTargetButton",           state = "stealTarget",           icon = "Interface\\Icons\\ability_hunter_rapidkilling", label = "抢怪" },
    { name = "FrozenArrowButton",           state = "frozenArrow",           icon = "Interface\\Icons\\spell_frost_chillingbolt",    label = "冰箭" },
    { name = "AutoTargetButton",            state = "autoTarget",            icon = "Interface\\Icons\\ability_hunter_snipershot",   label = "切目标" },
    { name = "KillShotModeButton",          state = "killShotMode",          icon = "Interface\\Icons\\ability_hunter_assassinate2", label = "杀戮" },
}

-- 默认状态
local DEFAULT_STATES = {
    blackArrow = false,
    explosiveTrap = true,
    normal = true,
    aoe = false,
    simple = false,
    aimedShot = false,
    multiShot = true,
    petAttack = true,
    petFollow = false,
    viperSting = false,
    autoTarget = true,
    stealTarget = false,
    viperStingMode = false,
    killShotMode = true,
    frozenArrow = false,
    trapDistanceOffset = 1,
    porcupineBaitDistance = 10,
    petFollowThreshold = 50,
    petHealThreshold = 50,
    ignoreLowHealthFollow = false,
}

-- =============================================
-- Helpers
-- =============================================

local function trim(str)
    if not str then return str end
    return (str:gsub("^%s+", "")):gsub("%s+$", "")
end

local function deepCopy(t)
    if type(t) ~= "table" then return t end
    local copy = {}
    for k, v in pairs(t) do copy[k] = deepCopy(v) end
    return copy
end

-- 从 SavedVariables 恢复上次保存的位置
---@return table|nil
local function loadSavedPosition()
    local pos = BastionDB and BastionDB.HunterUIPosition
    if pos and type(pos) == "table" then
        return {
            point         = pos.point or "CENTER",
            relativePoint = pos.relativePoint or "CENTER",
            x             = pos.x or 0,
            y             = pos.y or 0,
        }
    end
    return nil
end

-- 保存位置到 SavedVariables
---@param pos table
---@return boolean
local function savePosition(pos)
    if not pos then return false end
    BastionDB = BastionDB or {}
    BastionDB.HunterUIPosition = {
        point = pos.point,
        relativePoint = pos.relativePoint,
        x = pos.x,
        y = pos.y,
    }
    Bastion:Debug("HERUI position saved:", pos.point, pos.relativePoint, pos.x, pos.y)
    return true
end

-- =============================================
-- Class Definition
-- =============================================

---@class HunterUI
---@field states table
---@field frame Frame
---@field buttonStateMap table<string, Button>
local HunterUI = {}
HunterUI.__index = HunterUI

-- tostring
---@return string
function HunterUI:__tostring()
    return "Bastion.__HunterUI"
end

-- =============================================
-- Constructor
-- =============================================

---@return HunterUI
function HunterUI:New()
    local self = setmetatable({}, HunterUI)

    self.states = deepCopy(DEFAULT_STATES)
    self.buttonStateMap = {}

    self:CreateMainFrame()
    self:CreateButtonRow(ROW1_BUTTONS, "TOPLEFT", 10, -5)
    self:CreateSecondRow()
    self:UpdateStates()
    self:RegisterSlashCommands()

    return self
end

-- =============================================
-- State Management
-- =============================================

-- 切换状态，支持互斥组
---@param stateName string
---@param exclusiveWith? table
function HunterUI:ToggleState(stateName, exclusiveWith)
    local oldState = self.states[stateName]
    self.states[stateName] = not oldState

    if self.states[stateName] and exclusiveWith then
        for _, state in ipairs(exclusiveWith) do
            self.states[state] = false
        end
    end

    self:UpdateStates(stateName, oldState)
end

-- 通过命令行切换状态（支持 on/off 参数）
---@param stateName string
---@param state? string
function HunterUI:OptimizedToggle(stateName, state)
    local oldState = self.states[stateName]

    if state then state = trim(state) end

    if state == "on" then
        self.states[stateName] = true
    elseif state == "off" then
        self.states[stateName] = false
    else
        self.states[stateName] = not oldState
    end

    self:UpdateStates(stateName, oldState)
end

-- 获取状态的闭包 getter
---@param stateName string
---@return fun(): any
function HunterUI:GetState(stateName)
    return function()
        return self.states[stateName]
    end
end

-- =============================================
-- Frame Creation
-- =============================================

-- 创建主框体（可拖动，自动保存/恢复位置）
function HunterUI:CreateMainFrame()
    local savedPos = loadSavedPosition() or {
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = 0,
    }

    self.frame = CreateFrame("Frame", "HunterUIMainFrame", UIParent)
    self.frame:SetSize(560, 132)
    self.frame:SetPoint(savedPos.point, UIParent, savedPos.relativePoint, savedPos.x, savedPos.y)

    -- 拖动支持
    self.frame:SetMovable(true)
    self.frame:EnableMouse(true)
    self.frame:RegisterForDrag("LeftButton")
    self.frame:SetScript("OnDragStart", self.frame.StartMoving)
    self.frame:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        local point, _, relativePoint, x, y = frame:GetPoint()
        savePosition({ point = point, relativePoint = relativePoint, x = x, y = y })
    end)
end

-- =============================================
-- Widget Factories
-- =============================================

-- 创建单个图标按钮
---@param name string
---@param parent Frame
---@param icon string
---@param label string
---@param onClick function
---@return Button
function HunterUI:CreateButton(name, parent, icon, label, onClick)
    local button = CreateFrame("Button", name, parent, "ActionButtonTemplate")
    button:SetSize(36, 36)
    button.icon = _G[button:GetName() .. "Icon"]
    button.icon:SetTexture(icon)
    button:SetScript("OnClick", onClick)

    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.text:SetPoint("BOTTOM", button, "BOTTOM", 0, -10)
    button.text:SetText(label)

    return button
end

-- 创建单个下拉框控件
---@param name string
---@param parent Frame
---@param state string
---@param label string
---@param options table
---@param width? number
---@param valueSuffix? string
---@return Frame
function HunterUI:CreateDropdownWidget(name, parent, state, label, options, width, valueSuffix)
    local ui = self
    local dropdown = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
    local suffix = valueSuffix or ""
    local dropdownWidth = width or 50
    local dropdownButton = _G[name .. "Button"]
    local dropdownText = _G[name .. "Text"]
    local valueText = dropdown:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")

    valueText:SetJustifyH("CENTER")
    valueText:SetJustifyV("MIDDLE")

    local function setFittedText(value)
        local text = tostring(value) .. suffix
        UIDropDownMenu_SetText(dropdown, text)

        if not valueText then
            return
        end

        local fontPath, _, fontFlags = valueText:GetFont()
        if not fontPath then
            return
        end

        valueText:SetText(text)

        local maxTextWidth = dropdownWidth + 14
        local fitted = false

        for fontSize = 12, 8, -1 do
            valueText:SetFont(fontPath, fontSize, fontFlags)
            if valueText:GetStringWidth() <= maxTextWidth then
                fitted = true
                break
            end
        end

        if not fitted then
            valueText:SetFont(fontPath, 8, fontFlags)
        end
    end
	
    -- 标签
    local dropdownLabel = dropdown:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dropdownLabel:SetPoint("BOTTOM", dropdown, "BOTTOM", 0, -10)
    dropdownLabel:SetText(label)
	
    UIDropDownMenu_SetWidth(dropdown, dropdownWidth)
    UIDropDownMenu_SetButtonWidth(dropdown, dropdownWidth + 24)
    UIDropDownMenu_JustifyText(dropdown, "CENTER")

    if dropdownButton and dropdownText then
        dropdownText:ClearAllPoints()
        dropdownText:SetPoint("LEFT", dropdownButton, "LEFT", 6, 2)
        dropdownText:SetPoint("RIGHT", dropdownButton, "RIGHT", -16, 2)
        dropdownText:Hide()
    end

    if dropdownButton then
        valueText:SetPoint("LEFT", dropdownButton, "LEFT", 8, 1)
        valueText:SetPoint("RIGHT", dropdownButton, "RIGHT", -20, 1)
    else
        valueText:SetPoint("CENTER", dropdown, "CENTER", 0, 1)
    end

    setFittedText(self.states[state])
	
    local function OnClick(btn)
        UIDropDownMenu_SetSelectedValue(dropdown, btn.value)
        setFittedText(btn.value)
        ui.states[state] = btn.value
        print("|cff00ff00[HERUI]|r " .. label .. "设置为: " .. btn.value .. suffix)
    end

    UIDropDownMenu_Initialize(dropdown, function()
        for _, value in ipairs(options) do
            local info = UIDropDownMenu_CreateInfo()
            info.text  = tostring(value)
            info.value = value
            info.func  = OnClick
            UIDropDownMenu_AddButton(info)
        end
    end)

    UIDropDownMenu_SetSelectedValue(dropdown, self.states[state])
    return dropdown
end

-- =============================================
-- Row Builders
-- =============================================

-- 根据配置表批量创建一行按钮
---@param configs table
---@param anchorPoint string
---@param offsetX number
---@param offsetY number
function HunterUI:CreateButtonRow(configs, anchorPoint, offsetX, offsetY)
    local lastButton = nil

    for _, cfg in ipairs(configs) do
        local button = self:CreateButton(
            cfg.name, self.frame, cfg.icon, cfg.label,
            function() self:ToggleState(cfg.state, cfg.exclusive) end
        )

        if lastButton then
            button:SetPoint("LEFT", lastButton, "RIGHT", 10, 0)
        else
            button:SetPoint(anchorPoint, self.frame, anchorPoint, offsetX, offsetY)
        end

        lastButton = button
        self[cfg.name] = button
        self.buttonStateMap[cfg.state] = button
    end
end

-- 创建第二行（下拉框 + 按钮混排）
function HunterUI:CreateSecondRow()
    local lastButton = nil

    -- 下拉框
    for index, cfg in ipairs(ROW2_DROPDOWNS) do
        local dropdown = self:CreateDropdownWidget(
            cfg.name, self.frame, cfg.state, cfg.label, cfg.options, cfg.width, cfg.valueSuffix
        )

        local row = math.floor((index - 1) / 2)
        local col = (index - 1) % 2
        local offsetX = col == 0 and -6 or 58
        local offsetY = -60 - (row * 38)

        dropdown:SetPoint("TOPLEFT", self.frame, "TOPLEFT", offsetX, offsetY)
        self[cfg.ref] = dropdown
    end

    -- 按钮
    for i, cfg in ipairs(ROW2_BUTTONS) do
        local button = self:CreateButton(
            cfg.name, self.frame, cfg.icon, cfg.label,
            function() self:ToggleState(cfg.state, cfg.exclusive) end
        )

        if lastButton then
            button:SetPoint("LEFT", lastButton, "RIGHT", 10, 0)
        else
            button:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 146, -78)
        end
        lastButton = button

        self[cfg.name] = button
        self.buttonStateMap[cfg.state] = button
    end
end

-- =============================================
-- UI State Update
-- =============================================

-- 更新单个按钮的视觉状态
---@param button Button
---@param isActive boolean
function HunterUI:UpdateButtonState(button, isActive)
    local brightness = isActive and 1 or 0.4
    button.icon:SetVertexColor(brightness, brightness, brightness)
end

-- 刷新所有按钮状态，可选打印变化信息
---@param changedState? string
---@param oldState? boolean
function HunterUI:UpdateStates(changedState, oldState)
    if changedState then
        local newState = self.states[changedState]
        if newState ~= oldState then
            local stateText = newState and "启用" or "禁用"
            local color = newState and "|cff00ff00" or "|cffff0000"
            print(changedState .. " 现在是 " .. color .. stateText .. "|r")
        end
    end

    for stateName, button in pairs(self.buttonStateMap) do
        self:UpdateButtonState(button, self.states[stateName])
    end
end

-- =============================================
-- Slash Commands
-- =============================================

function HunterUI:RegisterSlashCommands()
    local cmd = Bastion.Command:New('hunter')

    cmd:Register('normal', '切换默认模式 (on/off)', function(args)
        self:OptimizedToggle("normal", args[2] and string.lower(args[2]) or "")
    end)

    cmd:Register('aoe', '切换AOE模式 (on/off)', function(args)
        self:OptimizedToggle("aoe", args[2] and string.lower(args[2]) or "")
    end)

    cmd:Register('simple', '切换简单模式 (on/off)', function(args)
        self:OptimizedToggle("simple", args[2] and string.lower(args[2]) or "")
    end)

    cmd:Register('ui', '显示UI界面', function()
        self.frame:Show()
    end)

    print("|cff00ff00[HERUI]|r 注册命令: /hunter normal, /hunter aoe, /hunter simple, /hunter ui")
end

-- =============================================
-- Export API
-- =============================================

---@return table
function HunterUI:BuildExports()
    local exports = {
        BlackArrow            = self:GetState("blackArrow"),
        ExplosiveTrap         = self:GetState("explosiveTrap"),
        Normal                = self:GetState("normal"),
        Simple                = self:GetState("simple"),
        AimedShot             = self:GetState("aimedShot"),
        MultiShot             = self:GetState("multiShot"),
        PetAttack             = self:GetState("petAttack"),
        PetFollow             = self:GetState("petFollow"),
        ViperSting            = self:GetState("viperSting"),
        ViperStingMode        = self:GetState("viperStingMode"),
        KillShotMode          = self:GetState("killShotMode"),
        FrozenArrow           = self:GetState("frozenArrow"),
        AutoTarget            = self:GetState("autoTarget"),
        StealTarget           = self:GetState("stealTarget"),
        AOE                   = self:GetState("aoe"),
        TrapDistanceOffset    = self:GetState("trapDistanceOffset"),
        PorcupineBaitDistance = self:GetState("porcupineBaitDistance"),
        PetFollowThreshold    = self:GetState("petFollowThreshold"),
        PetHealThreshold      = self:GetState("petHealThreshold"),
        IgnoreLowHealthFollow = self:GetState("ignoreLowHealthFollow"),
    }

    -- 统一入口，按名字取状态
    function exports:State(name)
        local getter = self[name]
        return getter and getter() or nil
    end

    return exports
end

-- =============================================
-- Initialize & API Registration
-- =============================================

local hunterUI = HunterUI:New()
Bastion.Globals.HERUI = hunterUI:BuildExports()
Bastion:Debug("HERUI exports registered to Bastion.Globals")
print("|cff00ff00[HERUI]|r Hunter 模块已加载")

Bastion.HunterUI = HunterUI
