-- Bootstrap function for initializing all required files
function Bastion.Bootstrap()
    local MODULES = {}

    -- ===================== 核心类实例化 =====================
    -- 类定义已通过 .toc 加载并注册到 Bastion 表，此处仅创建实例
    ---@type UnitManager
    Bastion.UnitManager = Bastion.UnitManager:New()
    ---@type ObjectManager
    Bastion.ObjectManager = Bastion.ObjectManager:New()
    Bastion.Globals.EventManager = Bastion.EventManager:New()
    Bastion.Globals.SpellBook = Bastion.SpellBook:New()
    Bastion.Globals.ItemBook = Bastion.ItemBook:New()
    ---@type Timer
    Bastion.CombatTimer = Bastion.Timer:New('combat')
    ---@type NotificationsList
    Bastion.Notifications = Bastion.NotificationsList:New()

    -- ===================== UI 系统初始化 =====================
    -- 创建 UI 容器
    Bastion.UI = {}

    -- 初始化状态框架
    Bastion.UI.StatusFrame = Bastion.StatusFrame:New({
        size = 48,
        position = { point = "CENTER", x = -500, y = 300 },
        icon = "Interface\\Icons\\Ability_Hunter_RunningShot"
    })

    -- ===================== 状态显示更新函数 =====================
    function Bastion:UpdateStatusDisplay()
        Bastion.UI.StatusFrame:SetModulesRef(MODULES)
        Bastion.UI.StatusFrame:Update()
    end

    -- ===================== 核心系统初始化完成 =====================

    -- 状态显示初始化
    Bastion:UpdateStatusDisplay()

    -- ===================== 事件注册 =====================
    -- 注册单位光环更新事件
    Bastion.Globals.EventManager:RegisterWoWEvent('UNIT_AURA', function(unit, auras)
        local u = Bastion.UnitManager[unit]
        if u then
            u:GetAuras():OnUpdate(auras)
        end
    end)

    -- 注册法术施放成功事件
    Bastion.Globals.EventManager:RegisterWoWEvent("UNIT_SPELLCAST_SUCCEEDED", function(...)
        local unit, _, spellID = ...
        local spell = Bastion.Globals.SpellBook:GetIfRegistered(spellID)

        if unit == "player" and spell then
            spell.lastCastAt = GetTime()
            if spell:GetPostCastFunction() then
                spell:GetPostCastFunction()(spell)
            end
        end
    end)

    -- ===================== 主循环定时器 =====================
    Bastion.Ticker = C_Timer.NewTicker(0.1, function()
        -- 战斗计时器管理
        if not Bastion.CombatTimer:IsRunning() and UnitAffectingCombat("player") then
            Bastion.CombatTimer:Start()
        elseif Bastion.CombatTimer:IsRunning() and not UnitAffectingCombat("player") then
            Bastion.CombatTimer:Reset()
        end

        -- 对象管理器刷新
        Bastion.ObjectManager:Refresh()

        -- 执行所有已注册的模块
        for i = 1, #MODULES do
            MODULES[i]:Tick()
        end
    end)

    -- ===================== 模块管理函数 =====================
    function Bastion:Register(module)
        table.insert(MODULES, module)
        Bastion:Print("Registered", module)
    end

    function Bastion:FindModule(name)
        for i = 1, #MODULES do
            if MODULES[i].name == name then
                return MODULES[i]
            end
        end
        return nil
    end

    -- ===================== 日志输出函数 =====================
    function Bastion:Print(...)
        local args = {...}
        local str = "|cFFDF362D[Bastion]|r |cFFFFFFFF"
        for i = 1, #args do
            str = str .. tostring(args[i]) .. " "
        end
        print(str)
    end

    function Bastion:Debug(...)
        if not Bastion.DebugMode then
            return
        end
        local args = {...}
        local str = "|cFFDF6520[Bastion]|r |cFFFFFFFF"
        for i = 1, #args do
            str = str .. tostring(args[i]) .. " "
        end
        print(str)
    end

    -- ===================== 命令注册 =====================
    local Command = Bastion.Command:New('bastion')

    Command:Register('debug', 'Toggle debug mode on/off', function()
        Bastion.DebugMode = not Bastion.DebugMode
        if Bastion.DebugMode then
            Bastion:Print("Debug mode enabled")
        else
            Bastion:Print("Debug mode disabled")
        end
    end)

    Command:Register('module', 'Toggle a module on/off', function(args)
        local module = Bastion:FindModule(args[2])
        if module then
            module:Toggle()
            if module.enabled then
                Bastion:Print("Enabled", module.name)
            else
                Bastion:Print("Disabled", module.name)
            end
            Bastion:UpdateStatusDisplay()
        else
            Bastion:Print("Module not found")
        end
    end)

end

-- ===================== 启动 Bastion 系统 =====================
Bastion.Bootstrap()
