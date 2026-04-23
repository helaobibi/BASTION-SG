-- 创建模块
local SurvivalModule = Bastion.Module:New('SurvivalModule')

-- 获取玩家和目标单位
local Player = Bastion.UnitManager:Get('player')
local Target = Bastion.UnitManager:Get('target')
local Pet = Bastion.UnitManager:Get('pet')
local PetTarget = Bastion.UnitManager:Get('pettarget')
local TargetTarget = Bastion.UnitManager:Get('targettarget')
local Focus = Bastion.UnitManager:Get('focus')

-- 创建法术书
local SpellBook = Bastion.Globals.SpellBook
-- 创建物品书
local ItemBook = Bastion.Globals.ItemBook
-- 添加新变量来跟踪T键触发的威慑
local isTKeyIntimidationActive = false
-- 定义技能
-- 基础技能
local LeechingSwarm = SpellBook:GetSpell(66118)           -- 吸血虫群
local shalumingling = SpellBook:GetSpell(34026)           -- 杀戮命令
local MendPet = SpellBook:GetSpell(48990)                 -- 治疗宠物
local Intimidation = SpellBook:GetSpell(19263)            -- 威慑
local ConcussiveShot = SpellBook:GetSpell(5116)           -- 震荡射击
local FrostTrap = SpellBook:GetSpell(13810)               -- 冰霜陷阱
local HolyWrath = SpellBook:GetSpell(48817)               -- 神圣愤怒
local HammerOfJustice = SpellBook:GetSpell(10308)         -- 制裁之锤
local kuishe = SpellBook:GetSpell(34074)                  -- 蝰蛇守护
local longying = SpellBook:GetSpell(61847)                -- 龙鹰守护
local TrapSpell = SpellBook:GetSpell(425777)              -- 爆炸陷阱
local MultiShotSpell = SpellBook:GetSpell(58434)          -- 乱射范围技能
local KillShot = SpellBook:GetSpell(61006)                -- 杀戮射击
local SteadyShot = SpellBook:GetSpell(49052)              -- 稳固射击
local ExplosiveShot = SpellBook:GetSpell(60053)           -- 爆炸射击（4级）
local ExplosiveShott = SpellBook:GetSpell(60052)          -- 爆炸射击（3级）
local BlackArrow = SpellBook:GetSpell(63672)              -- 黑箭
local AimedShot = SpellBook:GetSpell(49050)               -- 瞄准射击
local MultiShot = SpellBook:GetSpell(49048)               -- 多重射击
local Serpent = SpellBook:GetSpell(49001)                 -- 毒蛇钉刺
local HuntersMark = SpellBook:GetSpell(53338)             -- 猎人印记
local heqiang = SpellBook:GetSpell(56453)                 -- 荷枪实弹
local Cower = SpellBook:GetSpell(1742)                    -- 畏缩
local FeignDeath = SpellBook:GetSpell(5384)               -- 假死
local ViperSting = SpellBook:GetSpell(3034)               -- 蝰蛇钉刺
local MindControl = SpellBook:GetSpell(36797)             -- 精神控制
local WingClip = SpellBook:GetSpell(2974)                 -- 摔绊
local FrozenArrow = SpellBook:GetSpell(60192)             -- 冰冻之箭

-- 寻找最佳目标
local BestTarget = Bastion.UnitManager:CreateCustomUnit('besttarget', function()
    local bestTarget = nil
    local highestHealth = 0

    -- 遍历所有敌人，寻找最适合的目标
    Bastion.ObjectManager.enemies:each(function(unit)
        -- 检查目标是否符合条件：
        -- 1. 正在战斗中
        -- 2. 在35码范围内
        -- 3. 玩家可以看见该目标
        -- 4. 目标距离玩家至少5码
        -- 5. 玩家面向该目标
        if unit:IsAffectingCombat() and ExplosiveShot:IsInRange(unit)
        and Player:CanSee(unit) and unit:IsAlive() and unit:Exists() and Player:IsFacing(unit) then
            -- 如果没有最佳目标或当前单位血量更高
            if unit:GetHealth() > highestHealth then
                highestHealth = unit:GetHealth()
                bestTarget = unit
            end
        end
    end)

    -- 如果没找到合适目标，返回空目标
    return bestTarget or Bastion.UnitManager:Get('none')
end)

-- 选择目标
local function CheckAndSetTarget()
    if (not Target:Exists() or Target:IsFriendly() or not Target:IsAlive())
        and not Target:GetAuras():FindAny(MindControl):IsUp() then
        if BestTarget:Exists() then -- 检查返回值有效
            -- 设置最佳目标为当前目标
            SetTargetObject(BestTarget.unit)
            return true
        end
    end
    return false
end

-- 检查目标是否为艾蒂丝、菲奥拉、小宝或大臭
local function IsTargetBoss()
    return Bastion.ObjectManager.enemies:find(function(unit)
        local name = unit:GetName()
        return name
            and (
                string.find(name, "艾蒂丝")
                or string.find(name, "菲奥拉")
                or string.find(name, "小宝")
                or string.find(name, "大臭")
            )
    end) ~= nil
end

-- 寻找可斩杀目标（生命值低于20%）
local ExecuteTarget = Bastion.UnitManager:CreateCustomUnit('executetarget', function()
    -- 先检查当前目标是否满足条件
    if Target:IsAlive()
        and Target:GetHP() < 20
        and KillShot:IsInRange(Target) then
        return Target
    end

    -- 如果当前目标不满足条件,再查找其他目标
    local executeTarget = Bastion.ObjectManager.enemies:find(function(unit)
        local unitName = unit:GetName()
        return unit:IsAlive()
            and unit:GetHP() < 20
            and unit:IsAffectingCombat()
            and KillShot:IsInRange(unit)
            and Player:CanSee(unit)
            and Player:IsFacing(unit)
            and unitName
            and not (
                string.find(unitName, "黑暗之核") or
                string.find(unitName, "动力炸弹") or
                string.find(unitName, "瓦拉纳王子") or
                string.find(unitName, "塔达拉姆王子") or
                string.find(unitName, "凯雷塞斯王子")
            )
    end)

    return executeTarget or Bastion.UnitManager:Get('none')
end)

-- 寻找蝰蛇钉刺目标（能量类型为0且血量最高的敌人）
local ViperStingTarget = Bastion.UnitManager:CreateCustomUnit('viperstingtarget', function()
    local bestTarget = nil
    local highestHealth = 0

    -- 遍历所有敌人，寻找能量类型为0且血量最高的目标
    Bastion.ObjectManager.enemies:each(function(unit)
        -- 检查目标是否符合条件：
        -- 1. 单位存活
        -- 2. 在范围内
        -- 3. 玩家可以看见该目标
        -- 4. 玩家面向该目标
        -- 5. 能量类型为0（法力值）
        if unit:IsAlive()
            and unit:Exists()
            and ViperSting:IsInRange(unit)
            and Player:CanSee(unit)
            and Player:IsFacing(unit)
            and unit:IsAffectingCombat() then

            -- 获取单位的能量类型
            local powerType = UnitPowerType(unit:GetOMToken())

            -- 只选择能量类型为0（法力值）的目标
            if powerType == 0 then
                local currentHealth = unit:GetHealth()
                -- 如果没有最佳目标或当前单位血量更高
                if currentHealth > highestHealth then
                    highestHealth = currentHealth
                    bestTarget = unit
                end
            end
        end
    end)

    -- 如果没找到合适目标，返回空目标
    return bestTarget or Bastion.UnitManager:Get('none')
end)

-- 通过 Bastion.Globals.HERUI 读取 UI 状态，兼容非全局导出
local function createUIAccessor(name, default)
    return function()
        local api = Bastion.Globals and Bastion.Globals.HERUI
        if api then
            local getter = api[name]
            if type(getter) == "function" then
                return getter()
            end
            if api.State then
                local state = api:State(name)
                if state ~= nil then
                    return state
                end
            end
        end
        return default
    end
end

local HERUI = {
    ExplosiveTrap = createUIAccessor("ExplosiveTrap", true),
    BlackArrow = createUIAccessor("BlackArrow", false),
    Normal = createUIAccessor("Normal", true),
    Simple = createUIAccessor("Simple", false),
    AimedShot = createUIAccessor("AimedShot", false),
    MultiShot = createUIAccessor("MultiShot", true),
    PetAttack = createUIAccessor("PetAttack", true),
    PetFollow = createUIAccessor("PetFollow", false),
    ViperSting = createUIAccessor("ViperSting", false),
    ViperStingMode = createUIAccessor("ViperStingMode", false),  -- 新增：蝰蛇钉刺模式
    KillShotMode = createUIAccessor("KillShotMode", true),
    AOE = createUIAccessor("AOE", false),
    AOEAuto = createUIAccessor("AOEAuto", false),
    AutoTarget = createUIAccessor("AutoTarget", true),
    StealTarget = createUIAccessor("StealTarget", false),
    Growl = createUIAccessor("Growl", true),
    TrapDistanceOffset = createUIAccessor("TrapDistanceOffset", 1),  -- 新增：陷阱距离修正值，默认1码
    FrozenArrow = createUIAccessor("FrozenArrow", false),            -- 冰冻之箭开关
    PetFollowThreshold = createUIAccessor("PetFollowThreshold", 50), -- 宠物低血跟随阈值
    PetHealThreshold = createUIAccessor("PetHealThreshold", 50),     -- 治疗宠物阈值
    IgnoreLowHealthFollow = createUIAccessor("IgnoreLowHealthFollow", false)  -- 忽略低血量跟随/攻击限制
}

-- ===================== APL定义 =====================
local DefaultAPL = Bastion.APL:New('default')         -- 默认输出循环
local DefensiveAPL = Bastion.APL:New('defensive')     -- 防御循环
local AoEAPL = Bastion.APL:New('aoe')                 -- AOE循环
local ResourceAPL = Bastion.APL:New('resource')       -- 资源管理循环
local ResourceAPL2 = Bastion.APL:New('resource2')     -- 资源管理循环2
local PetControlAPL = Bastion.APL:New('petcontrol')   -- 宠物控制
local DefaultSPAPL = Bastion.APL:New('DefaultSP')     -- 简单模式
local EsoAPL = Bastion.APL:New('eso')                       -- 抢怪爆炸射击

-- 乱射（直接打当前目标，不判断目标类型）
EsoAPL:AddSpell(
    MultiShotSpell:CastableIf(function(self)
        return not Player:IsChanneling()
    end):SetTarget(Target):OnCast(function(self)
        self:Click(Target:GetPosition())
    end)
)

-- ===================== 防御循环 =====================
-- 摔绊（目标有精神控制时使用）
DefensiveAPL:AddSpell(
    WingClip:CastableIf(function(self)
        return Target:Exists()
            and Target:GetAuras():FindAny(MindControl):IsUp()
    end):SetTarget(Target)
)

-- 治疗石
DefensiveAPL:AddAction("UseHealingStone", function()
    -- 先检查血量，避免不必要的背包搜索
    if Player:GetHP() <= 50 and Player:IsAffectingCombat() then
        local healingStone = ItemBook:GetItemByName("治疗石")
        if healingStone and not healingStone:IsOnCooldown() then
            healingStone:Use(Player)
            return true
        end
    end
    return false
end)

-- 冰冻之箭（对焦点目标脚底释放）
DefensiveAPL:AddSpell(
    FrozenArrow:CastableIf(function(self)
        return Focus:Exists()
            and Focus:IsAlive()
            and not self:IsOnCooldown()
            and Focus:GetDistance(Player) <= 40
            and HERUI.FrozenArrow()
    end):SetTarget(Focus):OnCast(function(self)
        self:Click(Focus:GetPosition())
    end)
)

-- 假死
DefensiveAPL:AddSpell(
    FeignDeath:CastableIf(function(self)
        return GetKeyState(3)  -- 按下F键时释放
            and not Player:GetAuras():FindMy(FeignDeath):IsUp()  -- 没有假死buff
    end):SetTarget(Player):PreCast(function(self)
        if Player:IsCastingOrChanneling() then
            SpellStopCasting()  -- 打断当前施法
        end
    end)
)

-- 威慑（原有逻辑）
DefensiveAPL:AddSpell(
    Intimidation:CastableIf(function(self)
        return Player:GetHP() <= 30 and
               not self:IsOnCooldown() and
               Player:IsAffectingCombat() and
               not Player:GetAuras():FindAny(LeechingSwarm):IsUp() and
               not IsTargetBoss() and
               not GetKeyState(17) -- 不在按T键时才使用原有逻辑
    end):SetTarget(Player):PreCast(function(self)
        if Player:IsCastingOrChanneling() then
            SpellStopCasting()
        end
    end)
)

-- 威慑（按T键触发）
DefensiveAPL:AddSpell(
    Intimidation:CastableIf(function(self)
        return GetKeyState(17) and -- 按下T键时释放
               not Player:GetAuras():FindMy(Intimidation):IsUp() -- 没有威慑buff
    end):SetTarget(Player):PreCast(function(self)
        if Player:IsCastingOrChanneling() then
            SpellStopCasting() -- 打断当前施法
        end
    end):OnCast(function(self)
        -- 标记这是T键触发的威慑
        isTKeyIntimidationActive = true
    end)
)

-- 取消威慑（松开T键时）
DefensiveAPL:AddAction("CancelTKeyIntimidation", function()
    if isTKeyIntimidationActive then
        -- T键触发的威慑，按原有逻辑处理
        if not GetKeyState(17) and Player:GetAuras():FindMy(Intimidation):IsUp() then
            CancelSpellByName("威慑")
            isTKeyIntimidationActive = false
            return true
        end
    else
        -- 非T键触发的威慑，血量大于等于80%时取消
        if not GetKeyState(17) and Player:GetHP() >= 80 and Player:GetAuras():FindMy(Intimidation):IsUp() then
            CancelSpellByName("威慑")
            return true
        end
    end
    return false
end)

-- 杀戮命令
DefensiveAPL:AddSpell(
    shalumingling:CastableIf(function(self)
        return Pet:IsAlive()
            and Pet:Exists()
            and Target:Exists()
		    and Target:IsAlive()
            and Target:IsEnemy()
            and self:GetCooldownRemaining() < 1.5
            and Player:IsAffectingCombat()
            and not Player:IsChanneling()
    end):SetTarget(Target)
)

-- 震荡射击
DefensiveAPL:AddSpell(
    ConcussiveShot:CastableIf(function(self)
        return Target:Exists()
            and Target:IsAlive()
            and Target:IsEnemy()
            and self:GetCooldownRemaining() < 1.5
            and self:IsInRange(Target)
            and not Target:GetAuras():FindAny(ConcussiveShot):IsUp()
            and not Target:GetAuras():FindAny(FrostTrap):IsUp()
            and not Target:GetAuras():FindAny(HolyWrath):IsUp()
            and not Target:GetAuras():FindAny(HammerOfJustice):IsUp()
            and not Player:IsChanneling()
            and ((string.find(Target:GetName(), "瓦格里暗影戒卫者") or string.find(Target:GetName(), "脓疮僵尸") or string.find(Target:GetName(), "内心之魔"))
                or (TargetTarget:Exists() and Player:IsUnit(TargetTarget) and string.find(Target:GetName(), "灵魂戒卫")))
    end):SetTarget(Target)
)

-- 蝰蛇钉刺
DefensiveAPL:AddSpell(
    ViperSting:CastableIf(function(self)
        return ViperStingTarget:Exists()
            and self:IsKnownAndUsable()
            and not Player:IsChanneling()
            and Player:IsAffectingCombat()
            and HERUI.ViperStingMode()  -- 只在蝰蛇钉刺模式启用时释放
    end):SetTarget(ViperStingTarget)
)

-- 畏缩
PetControlAPL:AddSpell(
    Cower:CastableIf(function(self)
        return Pet:Exists()
            and Pet:IsAlive()
            and Player:IsAffectingCombat()
            and not self:IsOnCooldown()
            and Pet:GetHP() <= 85
    end):SetTarget(Pet)
)

-- 宠物攻击
PetControlAPL:AddAction("PetAttack", function()
    if Pet:Exists() and Pet:IsAlive()
        and (Pet:GetHP() > HERUI.PetFollowThreshold() or HERUI.IgnoreLowHealthFollow())
        and HERUI.PetAttack()
        and Target:IsAlive()
        and Target:Exists()
        and not string.find(Target:GetName(), "卡波妮娅") then
        -- 检测宠物目标和玩家目标是否一致，不一致则攻击玩家目标
        if not PetTarget:Exists() or not PetTarget:IsUnit(Target) then
            PetAttack()
            return true
        end
    end
    return false
end)

-- 宠物跟随
PetControlAPL:AddAction("PetFollow", function()
    local petTargetName = PetTarget:Exists() and PetTarget:GetName()
    if Pet:Exists() and Pet:IsAlive()
        and PetTarget:Exists()
        and (HERUI.PetFollow() or (Pet:GetHP() < HERUI.PetFollowThreshold() and not HERUI.IgnoreLowHealthFollow()) or string.find(petTargetName, "卡波妮娅")) then
        PetFollow()
        return true
    end
    return false
end)

-- 治疗宠物
PetControlAPL:AddSpell(
    MendPet:CastableIf(function(self)
        return Pet:Exists()
            and Pet:IsAlive()
            and Pet:GetHP() <= HERUI.PetHealThreshold()
            and Player:IsAffectingCombat()
            and not Pet:GetAuras():FindAny(MendPet):IsUp()
            and not Player:IsChanneling()
    end):SetTarget(Pet)
)

-- ===================== 资源管理循环 =====================
-- 守护切换
-- 蝰蛇
ResourceAPL:AddSpell(
    kuishe:CastableIf(function(self)
        return Player:GetPP() <= 7 and
               not Player:GetAuras():FindMy(kuishe):IsUp() and
               Player:IsAffectingCombat()
    end):SetTarget(Player)
)

-- 龙鹰
ResourceAPL:AddSpell(
    longying:CastableIf(function(self)
        return Player:GetPP() >= 30 and
               not Player:GetAuras():FindMy(longying):IsUp() and
               Player:IsAffectingCombat()
    end):SetTarget(Player)
)

-- 资源管理循环2
-- 蝰蛇
ResourceAPL2:AddSpell(
    kuishe:CastableIf(function(self)
        return not Player:GetAuras():FindMy(kuishe):IsUp()
               and Player:IsAffectingCombat()
    end):SetTarget(Player)
)

-- ===================== AOE循环 =====================
-- AOE循环技能序列
-- 斩杀射击（斩杀阶段使用）
AoEAPL:AddSpell(
    KillShot:CastableIf(function(self)
        return self:GetCooldownRemaining() < 1.5 and
               ExecuteTarget:Exists() and
               not Player:IsChanneling() and
               HERUI.KillShotMode() and
               Player:IsAffectingCombat()
    end):SetTarget(ExecuteTarget)
)

-- -- 爆炸陷阱
-- AoEAPL:AddSpell(
--     TrapSpell:CastableIf(function(self)
--         return Target:Exists()
--             and self:IsKnownAndUsable()
--             and not Player:IsChanneling()
--             and Target:IsAlive()
--             and Target:IsEnemy()
--             and HERUI.ExplosiveTrap()
--     end):SetTarget(Target):PreCast(function(self)
--         -- 检查是否正在读条稳固射击，如果是则停止施法
--         if Player:IsCastingOrChanneling() and Player:GetCastingOrChannelingSpell():GetID() == 49052 then
--             SpellStopCasting()
--         end
--     end):OnCast(function(self)
--         local distance = Target:GetDistance(Player)
--         local position
        
--         if distance < 40 then
--             -- 距离40码内，直接使用目标位置
--             position = Target:GetPosition()
--         else
--             -- 距离40码外，计算向玩家方向退的位置
--             local playerPos = Player:GetPosition()
--             local targetPos = Target:GetPosition()
--             local direction = (targetPos - playerPos):Normalize()
--             position = targetPos - direction * math.floor(Target:GetCombatReach() / 3)
--         end
        
--         self:Click(position)
--     end)
-- )

-- -- 乱射(直接使用目标坐标)
-- AoEAPL:AddSpell(
--     MultiShotSpell:CastableIf(function(self)
--         return Target:Exists()
--             and not Player:IsChanneling()
--             and Target:IsAlive()
--             and Target:IsEnemy()
--             and Target:GetDistance(Player) <= 35
--             and TrapSpell:GetCooldownRemaining() > 1.1
--     end):SetTarget(Target):PreCast(function(self)
--         -- 检查是否正在读条稳固射击，如果是则停止施法
--         if Player:IsCastingOrChanneling() and Player:GetCastingOrChannelingSpell():GetID() == 49052 then
--             SpellStopCasting()
--         end
--     end):OnCast(function(self)
--         local position = Target:GetPosition()
--         self:Click(position)
--     end)
-- )

-- 爆炸陷阱
AoEAPL:AddSpell(
    TrapSpell:CastableIf(function(self)
        return Target:Exists()
            and self:IsKnownAndUsable()
            and not Player:IsChanneling()
            and Target:IsAlive()
            and Target:IsEnemy()
            and HERUI.ExplosiveTrap()
    end):SetTarget(Target):PreCast(function(self)
        -- 检查是否正在读条稳固射击，如果是则停止施法
        if Player:IsCastingOrChanneling() and Player:GetCastingOrChannelingSpell():GetID() == 49052 then
            SpellStopCasting()
        end
    end):OnCast(function(self)
        -- 使用GetEnemyClosestToCentroid函数找到最密集敌人群中最接近质心的敌人
        -- 参数：半径10码，范围40码，最少需要3个敌人才使用质心定位
        local centralEnemy = Bastion.UnitManager:GetEnemyClosestToCentroid(10, 40, 3)
        local position

        if centralEnemy then
            position = centralEnemy:GetPosition()
        else
            -- 如果没有找到足够密集的敌人群（少于3个敌人），退回到目标位置
            position = Target:GetPosition()
        end

        self:Click(position)
    end)
)

-- 乱射(使用敌人群质心坐标)
AoEAPL:AddSpell(
    MultiShotSpell:CastableIf(function(self)
        return Target:Exists()
            and not Player:IsChanneling()
            and Target:IsAlive()
            and Target:IsEnemy()
            and Target:GetDistance(Player) <= 35
            and TrapSpell:GetCooldownRemaining() > 1.1
    end):SetTarget(Target):PreCast(function(self)
        -- 检查是否正在读条稳固射击，如果是则停止施法
        if Player:IsCastingOrChanneling() and Player:GetCastingOrChannelingSpell():GetID() == 49052 then
            SpellStopCasting()
        end
    end):OnCast(function(self)
        -- 使用FindEnemiesCentroid函数找到敌人群的质心位置
        -- 参数：半径8码，范围35码，最少需要2个敌人才使用乱射
        local centroid = Bastion.UnitManager:FindEnemiesCentroid(8, 35, 2)
        local position

        if centroid then
            position = centroid
        else
            -- 如果没有找到足够密集的敌人群（少于2个敌人），退回到目标位置
            position = Target:GetPosition()
        end

        self:Click(position)
    end)
)

-- ===================== 默认循环 =====================
-- 斩杀射击（斩杀阶段使用）
DefaultAPL:AddSpell(
    KillShot:CastableIf(function(self)
        return HERUI.KillShotMode()
            and self:GetCooldownRemaining() < 1.5
            and ExecuteTarget:Exists()
            and Player:IsAffectingCombat()
    end):SetTarget(ExecuteTarget)
)

DefaultAPL:AddSpell(
    KillShot:CastableIf(function(self)
        return not HERUI.KillShotMode()
            and self:GetCooldownRemaining() < 1.5
            and Target:Exists()
            and Target:IsAlive()
            and Target:IsEnemy()
            and Target:GetHP() < 20
            and KillShot:IsInRange(Target)
            and Player:IsAffectingCombat()
    end):SetTarget(Target)
)

-- 爆炸陷阱
DefaultAPL:AddSpell(
    TrapSpell:CastableIf(function(self)
        return Target:Exists()
            and self:IsKnownAndUsable()
            and not Player:IsCastingOrChanneling()
            and Target:IsAlive()
            and Target:IsEnemy()
            and HERUI.ExplosiveTrap()
    end):SetTarget(Target):OnCast(function(self)
        local distance = Target:GetDistance(Player)
        local position

        if distance <= 40 then
            -- 距离40码内，直接使用目标位置
            position = Target:GetPosition()
        else
            -- 距离40码外，计算向玩家方向退的位置
            -- 后退距离 = UI下拉框设置的数值
            local playerPos = Player:GetPosition()
            local targetPos = Target:GetPosition()
            local direction = (targetPos - playerPos):Normalize()
            local retreatDistance = HERUI.TrapDistanceOffset()  -- 使用UI设置值
            position = targetPos - direction * retreatDistance
        end

        self:Click(position)
    end)
)

-- 毒蛇钉刺（开战前10秒优先于爆炸射击）
DefaultAPL:AddSpell(
    Serpent:CastableIf(function(self)
        return Target:Exists()
            and Target:IsAlive()
            and self:IsKnownAndUsable()
            and Bastion.CombatTimer:GetTime() < 10
            and Target:GetAuras():FindMy(Serpent):GetRemainingTime() < 3
            and (TrapSpell:GetCooldownRemaining() > 0.5 or HERUI.ExplosiveTrap() == false)
            and not HERUI.ViperStingMode()
    end):SetTarget(Target)
)

-- 爆炸射击4
DefaultAPL:AddSpell(
    ExplosiveShot:CastableIf(function(self)
        return Target:Exists()
		    and Target:IsAlive()
            and self:IsKnownAndUsable()
			and (Player:GetAuras():FindMy(heqiang):GetCount() == 2 or Player:GetAuras():FindMy(heqiang):GetCount() == 0)
    end):SetTarget(Target)
)

-- 爆炸射击3
DefaultAPL:AddSpell(
    ExplosiveShott:CastableIf(function(self)
        return Target:Exists()
		    and Target:IsAlive()
            and self:IsKnownAndUsable()
			and Player:GetAuras():FindMy(heqiang):GetCount() == 1
    end):SetTarget(Target)
)

-- 黑箭
DefaultAPL:AddSpell(
    BlackArrow:CastableIf(function(self)
        return Target:Exists()
		    and Target:IsAlive()
            and self:IsKnownAndUsable()
			and HERUI.BlackArrow()
    end):SetTarget(Target)
)

-- 多重射击
DefaultAPL:AddSpell(
    MultiShot:CastableIf(function(self)
        return Target:Exists()
		    and Target:IsAlive()
            and self:IsKnownAndUsable()
			and HERUI.MultiShot()
			and ExplosiveShot:GetCooldownRemaining() > 0.5
			and (TrapSpell:GetCooldownRemaining() > 0.5 or HERUI.ExplosiveTrap() == false)
    end):SetTarget(Target)
)

-- 毒蛇钉刺
DefaultAPL:AddSpell(
    Serpent:CastableIf(function(self)
        return Target:Exists()
            and Target:IsAlive()
            and self:IsKnownAndUsable()
            and (Target:GetAuras():FindMy(Serpent):GetRemainingTime() < ExplosiveShot:GetCooldownRemaining()
                or Target:GetAuras():FindMy(Serpent):GetRemainingTime() < 3)
            and ExplosiveShot:GetCooldownRemaining() > 0.5
            and (TrapSpell:GetCooldownRemaining() > 0.5 or HERUI.ExplosiveTrap() == false)
            and not HERUI.ViperStingMode()  -- 蝰蛇钉刺模式启用时禁用毒蛇钉刺
    end):SetTarget(Target)
)

-- 瞄准射击
DefaultAPL:AddSpell(
    AimedShot:CastableIf(function(self)
        return Target:Exists()
		    and Target:IsAlive()
            and self:IsKnownAndUsable()
			and HERUI.AimedShot()
			and ExplosiveShot:GetCooldownRemaining() > 0.5
			and (TrapSpell:GetCooldownRemaining() > 0.5 or HERUI.ExplosiveTrap() == false)
    end):SetTarget(Target)
)

-- 猎人印记
DefaultAPL:AddSpell(
    HuntersMark:CastableIf(function(self)
        return Target:Exists()
		    and Target:IsAlive()
            and self:IsKnownAndUsable()
            and not Target:GetAuras():FindAny(HuntersMark):IsUp()
			and ExplosiveShot:GetCooldownRemaining() > 0.5
			and (TrapSpell:GetCooldownRemaining() > 0.5 or HERUI.ExplosiveTrap() == false)
			and (not HERUI.MultiShot() or MultiShot:GetCooldownRemaining() > 0.5)
    end):SetTarget(Target)
)

-- 稳固射击（基础填充技能）
DefaultAPL:AddSpell(
    SteadyShot:CastableIf(function(self)
        return ExplosiveShot:GetCooldownRemaining() > 0.5
            and (TrapSpell:GetCooldownRemaining() > 0.5 or HERUI.ExplosiveTrap() == false)
            and (not HERUI.AimedShot() or AimedShot:GetCooldownRemaining() > 0.5)
            and Target:Exists()
            and Target:IsAlive()
            and self:IsKnownAndUsable()
    end):SetTarget(Target)
)

-- ===================== 简单循环 =====================
-- 斩杀射击（斩杀阶段使用）
DefaultSPAPL:AddSpell(
    KillShot:CastableIf(function(self)
        return HERUI.KillShotMode()
            and self:GetCooldownRemaining() < 1.5
            and ExecuteTarget:Exists()
            and Player:IsAffectingCombat()
    end):SetTarget(ExecuteTarget)
)

DefaultSPAPL:AddSpell(
    KillShot:CastableIf(function(self)
        return not HERUI.KillShotMode()
            and self:GetCooldownRemaining() < 1.5
            and Target:Exists()
            and Target:IsAlive()
            and Target:IsEnemy()
            and Target:GetHP() < 20
            and KillShot:IsInRange(Target)
            and Player:IsAffectingCombat()
    end):SetTarget(Target)
)

-- 爆炸射击4
DefaultSPAPL:AddSpell(
    ExplosiveShot:CastableIf(function(self)
        return Target:Exists()
		    and Target:IsAlive()
            and self:IsKnownAndUsable()
			and (Player:GetAuras():FindMy(heqiang):GetCount() == 2 or Player:GetAuras():FindMy(heqiang):GetCount() == 0)
    end):SetTarget(Target)
)

-- 爆炸射击3
DefaultSPAPL:AddSpell(
    ExplosiveShott:CastableIf(function(self)
        return Target:Exists()
		    and Target:IsAlive()
            and self:IsKnownAndUsable()
			and Player:GetAuras():FindMy(heqiang):GetCount() == 1
    end):SetTarget(Target)
)

-- 多重射击
DefaultSPAPL:AddSpell(
    MultiShot:CastableIf(function(self)
        return ExplosiveShot:GetCooldownRemaining() > 0.5
            and Target:Exists()
		    and Target:IsAlive()
            and self:IsKnownAndUsable()
			and HERUI.MultiShot()
    end):SetTarget(Target)
)

-- 瞄准射击
DefaultSPAPL:AddSpell(
    AimedShot:CastableIf(function(self)
        return ExplosiveShot:GetCooldownRemaining() > 0.5
            and Target:Exists()
		    and Target:IsAlive()
            and self:IsKnownAndUsable()
			and HERUI.AimedShot()
    end):SetTarget(Target)
)

-- 稳固射击（基础填充技能）
DefaultSPAPL:AddSpell(
    SteadyShot:CastableIf(function(self)
        return Target:Exists()
            and Target:IsAlive()
            and self:IsKnownAndUsable()
            and (not HERUI.MultiShot() or MultiShot:GetCooldownRemaining() > 0.5)
            and ExplosiveShot:GetCooldownRemaining() > 0.5
    end):SetTarget(Target)
)

-- ===================== 模块同步 =====================
SurvivalModule:Sync(function()
    -- 检查威慑状态，如果没有威慑buff则重置T键状态
    if isTKeyIntimidationActive and not Player:GetAuras():FindMy(Intimidation):IsUp() then
        isTKeyIntimidationActive = false
    end

    -- 最高优先级：防御逻辑
    DefensiveAPL:Execute()

    -- 当前目标被精神控制时，除防御循环外完全停止输出
    if Target:Exists() and Target:GetAuras():FindAny(MindControl):IsUp() then
        return
    end

    -- 抢怪目标（不要求战斗状态）
    if HERUI.StealTarget() then
        EsoAPL:Execute()
        return
    end

    PetControlAPL:Execute()

    -- 如果按住F键（假死状态）或T键（威慑状态），则不执行其他循环
    if GetKeyState(3) or GetKeyState(17) then
        return
    end

    -- 强制蝰蛇模式（保持原有ViperSting逻辑不变）
    if HERUI.ViperSting() then
        ResourceAPL2:Execute()
    end
    if not HERUI.ViperSting() then
        ResourceAPL:Execute()
    end

    -- 战斗中切目标（绑定UI状态）
    if Player:IsAffectingCombat() and HERUI.AutoTarget() then
        CheckAndSetTarget()
    end
    if HERUI.AOE() then
        AoEAPL:Execute()
    end
    if HERUI.Normal() then
        DefaultAPL:Execute()
    end
    if HERUI.Simple() then
        DefaultSPAPL:Execute()
    end
    -- local pending = IsSpellPending()
    -- print(pending)
    -- if not Player:InMelee(Target) or not Player:IsBehind(Target) then
    --     Target:MoveToTargetBehind()
    -- end
    -- if not Player:IsFacing(Target) and not Player:IsMoving() then  -- 只在不移动时调整朝向
    --     FaceObject('target')
    -- end
end)
-- ===================== 注册模块 =====================
Bastion:Register(SurvivalModule)
