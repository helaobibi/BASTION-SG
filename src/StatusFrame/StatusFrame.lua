-- Create a new StatusFrame class
---@class StatusFrame
local StatusFrame = {}
StatusFrame.__index = StatusFrame

-- Default configuration
local DEFAULT_CONFIG = {
    size = 48,
    position = { point = "CENTER", x = -500, y = 300 },
    icon = "Interface\\Icons\\Ability_Hunter_RunningShot",
    enabledColor = { r = 1, g = 2, b = 1, a = 1 },
    disabledColor = { r = 0.4, g = 0.4, b = 0.4, a = 0.8 }
}


---Create a deep copy so shared defaults are never mutated
---@param value any
---@return any
local function deepCopy(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for k, v in pairs(value) do
        copy[k] = deepCopy(v)
    end
    return copy
end

---Merge defaults into a config table without overriding nested tables
---@param config table
---@param defaults table
---@return table
local function mergeDefaults(config, defaults)
    for k, v in pairs(defaults) do
        if config[k] == nil then
            config[k] = deepCopy(v)
        elseif type(v) == "table" and type(config[k]) == "table" then
            mergeDefaults(config[k], v)
        end
    end

    return config
end

local function loadSavedIcon()
    local data = BastionDB and BastionDB.StatusFrameIcon
    if data and type(data) == "table" then
        return data.icon
    end
    return nil
end

local function saveIcon(icon)
    if not icon then
        return false
    end
    BastionDB = BastionDB or {}
    BastionDB.StatusFrameIcon = { icon = icon }
    return true
end

local function loadSavedPosition()
    local pos = BastionDB and BastionDB.StatusFramePosition
    if pos and type(pos) == "table" then
        return {
            point = pos.point or "CENTER",
            relative = pos.relative or "UIParent",
            relativePoint = pos.relativePoint or "CENTER",
            x = pos.x or 0,
            y = pos.y or 0,
        }
    end
    return nil
end

local function savePosition(pos)
    if not pos then return false end
    BastionDB = BastionDB or {}
    BastionDB.StatusFramePosition = {
        point = pos.point,
        relative = "UIParent",
        relativePoint = pos.relativePoint,
        x = pos.x,
        y = pos.y,
    }
    return true
end

-- Constructor
---@param config? table
---@return StatusFrame
function StatusFrame:New(config)
    local self = setmetatable({}, StatusFrame)
    
    self.config = config and deepCopy(config) or {}
    self:MergeConfig(DEFAULT_CONFIG)

    local savedPos = loadSavedPosition()
    if savedPos then
        self.config.position = {
            point = savedPos.point,
            relativePoint = savedPos.relativePoint,
            x = savedPos.x,
            y = savedPos.y
        }
    end

    local savedIcon = loadSavedIcon()
    if savedIcon then
        self.config.icon = savedIcon
    end

    self.enabled = true
    self.modulesRef = {}
    
    self:CreateFrame()
    self:CreateTexture()
    self:SetupDragging()
    self:Update()
    
    return self
end

-- Merge default config with provided config
---@param defaults table
---@return nil
function StatusFrame:MergeConfig(defaults)
    self.config = mergeDefaults(self.config or {}, defaults)
end

-- Create the main frame
---@return nil
function StatusFrame:CreateFrame()
    self.frame = CreateFrame("Frame", "BastionStatusFrame", UIParent)
    self.frame:SetSize(self.config.size, self.config.size)
    self.frame:SetPoint(
        self.config.position.point,
        UIParent,
        self.config.position.relativePoint or self.config.position.point,
        self.config.position.x,
        self.config.position.y
    )

    -- 添加OnUpdate脚本，实时更新距离显示
    local updateTimer = 0
    self.frame:SetScript("OnUpdate", function(frame, elapsed)
        updateTimer = updateTimer + elapsed
        if updateTimer >= 0.5 then  -- 每0.5秒更新一次
            updateTimer = 0

            -- 快速检查是否有目标，没有目标则跳过计算
            if Bastion and Bastion.UnitManager then
                local Target = Bastion.UnitManager:Get('target')
                if Target and Target:Exists() and Target:IsAlive() then
                    -- 有目标时才执行完整更新
                    self:UpdateRangeDisplay()
                else
                    -- 无目标时直接显示"无目标"，不执行其他计算
                    if self.rangeText then
                        self.rangeText:SetText("无目标")
                        self.rangeText:SetTextColor(1, 0, 0, 1)
                    end
                end
            end
        end
    end)
end

-- Create the texture
---@return nil
function StatusFrame:CreateTexture()
    self.texture = self.frame:CreateTexture(nil, "ARTWORK")
    self.texture:SetAllPoints()
    self.texture:SetTexture(self.config.icon)

    -- 创建距离文字显示
    self.rangeText = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.rangeText:SetPoint("TOP", self.frame, "BOTTOM", 0, -5)
    self.rangeText:SetFont("Fonts\\ARKai_T.ttf", 14, "OUTLINE")
    self.rangeText:SetText("--")  -- 默认显示 "--"
    self.rangeText:SetTextColor(0.5, 0.5, 0.5, 1)
end

-- Setup dragging functionality
---@return nil
function StatusFrame:SetupDragging()
    self.frame:SetMovable(true)
    self.frame:EnableMouse(true)
    self.frame:RegisterForDrag("LeftButton")
    self.frame:SetScript("OnDragStart", self.frame.StartMoving)
    self.frame:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()

        local point, _, relativePoint, x, y = frame:GetPoint()
        self.config.position = {
            point = point,
            relativePoint = relativePoint,
            x = x,
            y = y
        }
        savePosition({
            point = point,
            relativePoint = relativePoint,
            x = x,
            y = y
        })
    end)
end

-- Enable the status frame logic and visuals
---@return nil
function StatusFrame:Enable()
    if self.enabled then
        return
    end
    self.enabled = true
    self:Update()
end

-- Disable the status frame logic and visuals
---@return nil
function StatusFrame:Disable()
    if not self.enabled then
        return
    end
    self.enabled = false
    self:Hide()
end

-- Check if the status frame is enabled
---@return boolean
function StatusFrame:IsEnabled()
    return self.enabled
end

-- Set modules reference for status checking
---@param modules? table
---@return nil
function StatusFrame:SetModulesRef(modules)
    self.modulesRef = modules or {}
    self:Update()
end

-- Check if any module is enabled
---@return boolean
function StatusFrame:IsAnyModuleEnabled()
    if not self.modulesRef or #self.modulesRef == 0 then
        return false
    end
    
    for i = 1, #self.modulesRef do
        local module = self.modulesRef[i]
        if module then
            if type(module.IsEnabled) == "function" then
                if module:IsEnabled() then
                    return true
                end
            elseif module.enabled then
                return true
            end
        end
    end
    
    return false
end

-- Apply the correct visual state
---@param anyEnabled boolean
---@return nil
function StatusFrame:ApplyState(anyEnabled)
    if not self.texture then
        return
    end
    
    local color = anyEnabled and self.config.enabledColor or self.config.disabledColor
    self.texture:SetDesaturated(not anyEnabled)
    self.texture:SetVertexColor(
        color.r,
        color.g,
        color.b,
        color.a
    )
end

-- Update the display based on module states
---@return nil
function StatusFrame:Update()
    if not self.enabled then
        self:Hide()
        return
    end
    
    self:Show()
    
    local anyEnabled = self:IsAnyModuleEnabled()
    self:ApplyState(anyEnabled)
end

-- Show the frame
---@return nil
function StatusFrame:Show()
    if self.frame then
        self.frame:Show()
    end
end

-- Hide the frame
---@return nil
function StatusFrame:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

-- Toggle visibility
---@return nil
function StatusFrame:Toggle()
    if self.enabled then
        self:Disable()
    else
        self:Enable()
    end
end

-- Set icon texture
---@param icon string
---@return nil
function StatusFrame:SetIcon(icon)
    self.config.icon = icon
    self.texture:SetTexture(icon)
    saveIcon(icon)
end

-- Set position
---@param point string
---@param x number
---@param y number
---@return nil
function StatusFrame:SetPosition(point, x, y)
    self.config.position = { point = point, relativePoint = point, x = x, y = y }
    self.frame:ClearAllPoints()
    self.frame:SetPoint(point, UIParent, point, x, y)
    savePosition({
        point = point,
        relativePoint = point,
        x = x,
        y = y
    })
end

-- Set size
---@param size number
---@return nil
function StatusFrame:SetSize(size)
    self.config.size = size
    self.frame:SetSize(size, size)
end

-- Update range display
---@param distance? number
---@return nil
function StatusFrame:UpdateRange(distance)
    if not self.rangeText then
        return
    end

    if distance and distance >= 0 then
        -- 有目标，显示距离
        local distText = string.format("%.0f码", distance)
        self.rangeText:SetText(distText)

        if distance <= 40 then
            -- 40码内，绿色
            self.rangeText:SetTextColor(0, 1, 0, 1)
        else
            -- 超过40码，红色
            self.rangeText:SetTextColor(1, 0, 0, 1)
        end
    else
        -- 无目标，显示红色"无目标"
        self.rangeText:SetText("无目标")
        self.rangeText:SetTextColor(1, 0, 0, 1)
    end
end

-- Internal method: Update range display automatically
---@return nil
function StatusFrame:UpdateRangeDisplay()
    if not self.rangeText then
        return
    end

    -- 直接使用文件顶部的 Bastion 变量（不是 _G.Bastion）
    if not Bastion or not Bastion.UnitManager then
        -- Bastion 未初始化，显示灰色 "--"
        self.rangeText:SetText("--")
        self.rangeText:SetTextColor(0.5, 0.5, 0.5, 1)
        return
    end

    local Player = Bastion.UnitManager:Get('player')
    local Target = Bastion.UnitManager:Get('target')

    if not Player or not Target then
        -- 无法获取 Player 或 Target
        self.rangeText:SetText("--")
        self.rangeText:SetTextColor(0.5, 0.5, 0.5, 1)
        return
    end

    -- 计算距离并更新显示
    if Target:Exists() and Target:IsAlive() then
        local playerPos = Player:GetPosition()
        local targetPos = Target:GetPosition()

        if not playerPos or not targetPos then
            self.rangeText:SetText("ERR")
            self.rangeText:SetTextColor(1, 0, 0, 1)
            return
        end

        -- 计算两个中心点之间的距离
        local dx = targetPos.x - playerPos.x
        local dy = targetPos.y - playerPos.y
        local dz = targetPos.z - playerPos.z
        local distance = math.sqrt(dx*dx + dy*dy + dz*dz)

        self:UpdateRange(distance)
    else
        self:UpdateRange(nil)  -- 无目标时显示"无目标"
    end
end

-- Get frame
---@return Frame
function StatusFrame:GetFrame()
    return self.frame
end

-- tostring
---@return string
function StatusFrame:__tostring()
    return "Bastion.__StatusFrame(" .. (self.enabled and "enabled" or "disabled") .. ")"
end

Bastion.StatusFrame = StatusFrame

