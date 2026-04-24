# 缓存表结构详解

### 1. Cache（核心缓存引擎）
**文件**: `src/Cache/Cache.lua`
**说明**: 基于时间的 KV 缓存，所有带过期时间的缓存都基于此类。

| 字段 | 类型 | 说明 |
|------|------|------|
| `self.cache` | `table` | 缓存存储主表 |
| `self.cache[key]` | `table` | 单条缓存条目 |
| `self.cache[key].value` | `any` | 缓存的值 |
| `self.cache[key].duration` | `number` | 有效时长（秒） |
| `self.cache[key].time` | `number` | 写入时的 `GetTime()` 时间戳 |

```lua
-- 示例：Cache 内部 self.cache 表的完整结构
self.cache = {
    ["enemies_8"] = {
        value    = 3,            -- 8码内有3个敌人
        duration = 0.5,          -- 缓存有效 0.5 秒
        time     = 12345.678     -- 写入时的 GetTime()
    },
    ["melee_attackers"] = {
        value    = 2,            -- 2个近战攻击者
        duration = 0.5,
        time     = 12345.702
    },
    ["besttarget"] = {
        value    = Cacheable,    -- 自定义单位的 Cacheable 对象
        duration = 0.1,          -- 0.1秒过期
        time     = 12345.710
    }
}
```

---

### 2. Cacheable（自动刷新缓存包装器）
**文件**: `src/Cacheable/Cacheable.lua`
**说明**: 包装一个值 + 回调函数，访问时如果缓存过期（0.1s）则自动调用回调重新计算。用于 `UnitManager:CreateCustomUnit`。

| 字段 | 类型 | 说明 |
|------|------|------|
| `self.cache` | `Cache` | 内部 Cache 实例（key 固定为 `'self'`，duration=0.1s） |
| `self.value` | `any` | 当前缓存的值（通常是 Unit） |
| `self.callback` | `function` | 值过期时调用的刷新回调 |

```lua
-- 示例：Cacheable 实例的完整内部结构
self = {
    cache = Cache {                     -- 内部 Cache 实例
        cache = {
            ["self"] = {
                value    = Unit,        -- 当前缓存的 Unit 对象
                duration = 0.1,         -- 固定 0.1 秒过期
                time     = 12345.678    -- 上次写入时间
            }
        }
    },
    value    = Unit,                    -- 当前值：Unit("Creature-0-3151-2549-31-212793-0001")
    callback = function() ... end       -- 过期时调用：return findBestTarget()
}
-- 当外部访问 bestTarget:GetHP() 时：
--   1. __index 触发 → 检查 cache:IsCached('self')
--   2. 如果过期 → 调用 callback() 获取新 Unit → cache:Set('self', newUnit, 0.1)
--   3. 返回 self.value.GetHP
```

---

### 3. Refreshable（每次访问都刷新的包装器）
**文件**: `src/Refreshable/Refreshable.lua`
**说明**: 类似 Cacheable，但每次通过 `__index` 访问属性时都会调用回调刷新值。用于 `UnitManager:Get()` 返回的 token 单位。

| 字段 | 类型 | 说明 |
|------|------|------|
| `self.cache` | `Cache` | 内部 Cache 实例 |
| `self.value` | `any` | 当前值（通常是 Unit） |
| `self.callback` | `function` | 每次 `__index` 时调用的刷新回调 |

```lua
-- 示例：Refreshable 实例的完整内部结构
self = {
    cache = Cache {                     -- 内部 Cache 实例
        cache = {
            ["self"] = {
                value    = Unit,        -- 初始 Unit 对象
                duration = 0.1,
                time     = 12345.678
            }
        }
    },
    value    = Unit,                    -- 当前值：Unit("Player-3151-0A1B2C3D")
    callback = function() ... end       -- 每次 __index 都调用：return objects[ObjectGUID('target')]
}
-- 与 Cacheable 的区别：Refreshable 的 __index 每次都调用 callback() 刷新
-- 适合 token 单位（target/focus），因为底层 GUID 可能随时变化
```

---

### 4. AuraTable（光环/Buff/Debuff 缓存表）
**文件**: `src/AuraTable/AuraTable.lua`
**说明**: 每个 Unit 持有一个 AuraTable，缓存该单位的所有 Buff/Debuff，0.5s 内不重复查询 API。

| 字段 | 类型 | 说明 |
|------|------|------|
| `self.unit` | `Unit` | 所属单位 |
| `self.guid` | `string` | 单位 GUID（用于检测 token 指向变化） |
| `self.auras` | `table` | **非玩家释放**的光环：`{ [spellId] = { [instanceID] = Aura } }` |
| `self.playerAuras` | `table` | **玩家释放**的光环：`{ [spellId] = { [instanceID] = Aura } }` |
| `self.instanceIDLookup` | `table` | 实例ID反查：`{ [instanceID] = spellId }` |
| `self.lastUpdate` | `number` | 上次全量刷新的 `GetTime()` 时间戳 |

```lua
-- 示例：AuraTable 完整内部结构（一个目标身上有多个光环）
self = {
    unit = Unit,                                -- 所属单位
    guid = "Creature-0-3151-2549-31-212793-0001",
    lastUpdate = 12345.678,

    -- 玩家释放的光环（按 spellId 分组，每个 spellId 下按 instanceID 索引）
    playerAuras = {
        [172] = {                               -- 腐蚀术
            [1001] = Aura {
                aura = { name = "腐蚀术", icon = 136118, count = 0, dispelType = "Magic",
                         duration = 14, expirationTime = 12359.678, source = "player",
                         isStealable = false, spellId = 172, canApplyAura = true,
                         isBossDebuff = false, castByPlayer = true, auraInstanceID = 1001,
                         type = "HARMFUL", timeMod = 1, index = nil }
            },
        },
        [980] = {                               -- 痛苦灾祸
            [1003] = Aura {
                aura = { name = "痛苦灾祸", icon = 136139, count = 0, dispelType = nil,
                         duration = 18, expirationTime = 12363.678, source = "player",
                         isStealable = false, spellId = 980, canApplyAura = true,
                         isBossDebuff = false, castByPlayer = true, auraInstanceID = 1003,
                         type = "HARMFUL", timeMod = 1, index = nil }
            },
        },
    },

    -- 非玩家释放的光环
    auras = {
        [1459] = {                              -- 奥术智慧（法师给的 buff）
            [2001] = Aura {
                aura = { name = "奥术智慧", icon = 135932, count = 0, dispelType = "Magic",
                         duration = 3600, expirationTime = 15945.678, source = "Player-3151-0B2C3D4E",
                         isStealable = true, spellId = 1459, canApplyAura = true,
                         isBossDebuff = false, castByPlayer = false, auraInstanceID = 2001,
                         type = "HELPFUL", timeMod = 1, index = nil }
            },
        },
    },

    -- 实例ID反查表：快速定位 instanceID 属于哪个 spellId
    instanceIDLookup = {
        [1001] = 172,   -- instanceID 1001 → 腐蚀术
        [1003] = 980,   -- instanceID 1003 → 痛苦灾祸
        [2001] = 1459,  -- instanceID 2001 → 奥术智慧
    },
}
```

---

### 5. UnitManager（单位管理器）
**文件**: `src/UnitManager/UnitManager.lua`
**说明**: 全局单位管理器，管理所有已知单位对象和自定义单位选择器。

| 字段 | 类型 | 说明 |
|------|------|------|
| `self.objects` | `table` | 单位对象池：`{ [guid] = Unit }` |
| `self.customUnits` | `table` | 自定义单位：`{ [token] = { unit = Cacheable, cb = function } }` |
| `self.cache` | `Cache` | 自定义单位过期缓存（key=token, duration=0.1s） |

```lua
-- 示例：UnitManager 完整内部结构
self = {
    -- 单位对象池（key=GUID, value=Unit实例）
    objects = {
        ["Player-3151-0A1B2C3D"] = Unit {
            unit = <WoW Object>,  cache = Cache{...},  aura_table = AuraTable{...},
            regression_history = {},  id = false,  ttd = 0
        },
        ["Creature-0-3151-2549-31-212793-0001"] = Unit {
            unit = <WoW Object>,  cache = Cache{...},  aura_table = AuraTable{...},
            regression_history = { {time=100.0, percent=85.2}, {time=100.5, percent=82.1} },
            id = 212793,  ttd = 28.5
        },
        ["none"] = Unit {
            unit = nil,  cache = Cache{...},  aura_table = AuraTable{...},
            regression_history = {},  id = false,  ttd = 0
        },
    },

    -- 自定义单位（key=自定义token名, value={unit=Cacheable, cb=回调}）
    customUnits = {
        ["besttarget"] = {
            unit = Cacheable {
                cache = Cache{...},
                value = Unit("Creature-0-3151-2549-31-212793-0001"),
                callback = function() return findBestTarget() end
            },
            cb = function() return findBestTarget() end
        },
        ["lowhpfriend"] = {
            unit = Cacheable {
                cache = Cache{...},
                value = Unit("Player-3151-0B2C3D4E"),
                callback = function() return findLowestHPFriend() end
            },
            cb = function() return findLowestHPFriend() end
        },
    },

    -- 自定义单位过期控制缓存
    cache = Cache {
        cache = {
            ["besttarget"]  = { value = Cacheable, duration = 0.1, time = 12345.710 },
            ["lowhpfriend"] = { value = Cacheable, duration = 0.1, time = 12345.715 },
        }
    },
}
```

---

### 6. ObjectManager（对象管理器）
**文件**: `src/ObjectManager/ObjectManager.lua`
**说明**: 每帧遍历游戏内所有对象，分类到敌人/友方/爆炸物列表，支持自定义列表。

| 字段 | 类型 | 说明 |
|------|------|------|
| `self.enemies` | `List` | 敌方单位列表（每帧清空重建） |
| `self.friends` | `List` | 友方单位列表（每帧清空重建） |
| `self.explosives` | `List` | 爆炸物列表（M+ 大秘境，ID=120651） |
| `self._lists` | `table` | 自定义列表：`{ [name] = { list = List, cb = function } }` |

```lua
-- 示例：ObjectManager 完整内部结构
self = {
    -- 敌方单位列表（每帧 Refresh() 清空重建）
    enemies = List {
        _list = {
            [1] = Unit { unit = <WoW Object>, id = 212793 },  -- 怪物A "凶残的巨魔"
            [2] = Unit { unit = <WoW Object>, id = 212794 },  -- 怪物B "暗影萨满"
            [3] = Unit { unit = <WoW Object>, id = 212795 },  -- 怪物C "食腐秃鹫"
        }
    },

    -- 友方单位列表
    friends = List {
        _list = {
            [1] = Unit { unit = <WoW Object>, id = false },   -- 玩家自己
            [2] = Unit { unit = <WoW Object>, id = false },   -- 队友: 战士坦克
            [3] = Unit { unit = <WoW Object>, id = false },   -- 队友: 牧师治疗
        }
    },

    -- 爆炸物列表（M+ 大秘境词缀）
    explosives = List {
        _list = {
            [1] = Unit { unit = <WoW Object>, id = 120651 },  -- 爆炸物
        }
    },

    -- 自定义注册列表
    _lists = {
        ["dummies"] = {
            list = List {
                _list = {
                    [1] = Unit { unit = <WoW Object>, id = 198594 },  -- 训练假人A
                    [2] = Unit { unit = <WoW Object>, id = 198594 },  -- 训练假人B
                }
            },
            cb = function(object)  -- 每个对象都过一遍此回调，返回值非nil则加入list
                if ObjectType(object) == 5 then
                    local unit = Unit:New(object)
                    if unit:GetID() == 198594 then return unit end
                end
            end
        },
    },
}
```

---

### 7. SpellBook（法术注册表）
**文件**: `src/SpellBook/SpellBook.lua`
**说明**: 全局法术缓存，按 spellID 懒加载并复用 Spell 对象，避免重复创建。

| 字段 | 类型 | 说明 |
|------|------|------|
| `self.spells` | `table` | 法术缓存池：`{ [spellID] = Spell }` |

```lua
-- 示例：SpellBook 完整内部结构
self = {
    spells = {
        [61006] = Spell {
            spellID        = 61006,          -- 杀戮射击
            CastableIfFunc = function(self) return self:IsKnownAndUsable() end,
            PreCastFunc    = false,
            OnCastFunc     = false,
            PostCastFunc   = false,
            lastCastAttempt = 12340.123,
            lastCastAt     = 12340.130,
            wasLooking     = false,
            conditions     = {},
            target         = Unit("Creature-0-3151-..."),
            release_at     = false
        },
        [56641] = Spell {
            spellID        = 56641,          -- 稳固射击
            CastableIfFunc = false,
            PreCastFunc    = false,
            OnCastFunc     = false,
            PostCastFunc   = false,
            lastCastAttempt = 12344.567,
            lastCastAt     = 12344.580,
            wasLooking     = true,
            conditions     = { ["moving"] = { func = function(self) ... end } },
            target         = Unit("Creature-0-3151-..."),
            release_at     = false
        },
        [172] = Spell {
            spellID = 172,                   -- 腐蚀术（由 Aura 自动注册）
            CastableIfFunc = false, PreCastFunc = false, OnCastFunc = false,
            PostCastFunc = false, lastCastAttempt = false, lastCastAt = false,
            wasLooking = false, conditions = {}, target = false, release_at = false
        },
    }
}
```

---

### 8. ItemBook（物品注册表）
**文件**: `src/ItemBook/ItemBook.lua`
**说明**: 全局物品缓存，按 itemID 懒加载，并支持按名称搜索背包物品。

| 字段 | 类型 | 说明 |
|------|------|------|
| `self.items` | `table` | 物品缓存池：`{ [itemID] = Item }` |
| `self.nameCache` | `table` | 名称→ID 缓存：`{ [name] = itemID }` |

```lua
-- 示例：ItemBook 完整内部结构
self = {
    items = {
        [191384] = Item {
            ItemID         = 191384,         -- 治疗药水
            spellID        = 370511,         -- 物品对应的法术ID
            UsableIfFunc   = false,
            PreUseFunc     = false,
            OnUseFunc      = false,
            wasLooking     = false,
            lastUseAttempt = 12300.456,
            conditions     = {},
            target         = Unit("Player-3151-0A1B2C3D")
        },
        [194823] = Item {
            ItemID         = 194823,         -- 法力药水
            spellID        = 371024,
            UsableIfFunc   = function(self) return self:IsEquippedAndUsable() end,
            PreUseFunc     = false,
            OnUseFunc      = false,
            wasLooking     = false,
            lastUseAttempt = 0,
            conditions     = {},
            target         = false
        },
    },

    -- 名称→ID 缓存（按名称搜索背包时自动填充）
    nameCache = {
        ["治疗药水"] = 191384,
        ["法力药水"] = 194823,
    },
}
```

---

### 9. Unit（单位实例缓存）
**文件**: `src/Unit/Unit.lua`
**说明**: 每个单位对象内部持有独立缓存，用于存储需要频繁查询但短期不变的数据。

| 字段 | 类型 | 说明 |
|------|------|------|
| `self.cache` | `Cache` | 单位级缓存实例 |
| `self.aura_table` | `AuraTable` | 单位的光环表 |
| `self.regression_history` | `table` | TTD 回归数据：`{ { time = number, percent = number }, ... }` |

**Unit.cache 中常见的缓存 key：**

| 缓存 Key | Duration | 说明 |
|-----------|----------|------|
| `"enemies_" .. range` | 0.5s | 指定距离内的敌人数量 |
| `"melee_attackers"` | 0.5s | 近战攻击者数量 |

```lua
-- 示例：Unit 实例的完整内部结构
self = {
    unit = <WoW Object>,                      -- Tinkr 封装的游戏对象引用
    id   = 212793,                             -- ObjectID（怪物/NPC专有，玩家为 false）
    ttd  = 28.5,                               -- 预测死亡时间（秒）
    ttd_ticker = C_Timer.Ticker,               -- TTD 计算定时器
    last_shadow_techniques = 12340.0,          -- 上次暗影技巧触发时间
    swings_since_sht = 2,                      -- 自上次暗影技巧以来的挥砍次数
    last_main_attack = 12344.5,                -- 上次主手攻击时间
    last_off_attack  = 12344.3,                -- 上次副手攻击时间

    -- 单位级 Cache 实例
    cache = Cache {
        cache = {
            ["enemies_8"]      = { value = 3, duration = 0.5, time = 12345.678 },
            ["enemies_40"]     = { value = 7, duration = 0.5, time = 12345.680 },
            ["melee_attackers"] = { value = 2, duration = 0.5, time = 12345.690 },
        }
    },

    -- 光环表（见 AuraTable 详解）
    aura_table = AuraTable { ... },

    -- TTD 线性回归历史数据（最多60条，每0.5s采样一次）
    regression_history = {
        [1] = { time = 12340.0, percent = 100.0 },
        [2] = { time = 12340.5, percent = 97.3 },
        [3] = { time = 12341.0, percent = 94.1 },
        -- ... 最多60条，旧的从头部移除
    },
}
```

---

### 10. Spell（法术条件表）
**文件**: `src/Spell/Spell.lua`
**说明**: 法术对象可注册命名条件，在 APL 中按名称引用触发。

| 字段 | 类型 | 说明 |
|------|------|------|
| `self.conditions` | `table` | 命名条件：`{ [name] = { func = function } }` |

```lua
-- 示例：Spell.conditions 完整结构（杀戮射击的条件表）
-- spell = SpellBook:GetSpell(61006)  -- 杀戮射击
self.conditions = {
    ["execute_phase"] = {
        func = function(self)
            return Target:GetHP() < 20  -- 目标血量低于20%
        end
    },
    ["has_precise_shots"] = {
        func = function(self)
            return Player:GetAuras():FindMy(PreciseShots):IsUp()
        end
    },
}
-- 使用：spell:Cast(target, "execute_phase")  → 内部调用 EvaluateCondition("execute_phase")
```

---

### 11. EventManager（事件处理表）
**文件**: `src/EventManager/EventManager.lua`
**说明**: 管理自定义事件和 WoW 原生事件的处理器注册。

| 字段 | 类型 | 说明 |
|------|------|------|
| `self.events` | `table` | 自定义事件：`{ [eventName] = { handler1, handler2, ... } }` |
| `self.wowEventHandlers` | `table` | WoW 事件：`{ [eventName] = { handler1, handler2, ... } }` |

```lua
-- 示例：EventManager 完整内部结构
self = {
    -- 自定义事件（Bastion 内部事件）
    events = {
        ["UNIT_COMBAT_ENTER"] = {
            [1] = function(...) print("进入战斗") end,
        },
    },

    -- WoW 原生事件处理器（key=事件名, value=回调数组）
    wowEventHandlers = {
        ["UNIT_AURA"] = {
            [1] = function(unitTarget, updateInfo)  -- AuraTable:OnUpdate 处理
                local unit = UnitManager:GetObject(ObjectGUID(unitTarget))
                if unit then unit:GetAuras():OnUpdate(updateInfo) end
            end,
        },
        ["COMBAT_LOG_EVENT_UNFILTERED"] = {
            [1] = function()  -- 战斗日志：追踪挥砍/法术施放
                local _, subtype, _, sourceGUID = CombatLogGetCurrentEventInfo()
                -- ... 处理逻辑
            end,
        },
        ["UNIT_SPELLCAST_SUCCEEDED"] = {
            [1] = function(unit, castGUID, spellID)  -- 记录法术施放成功时间
                local spell = SpellBook:GetIfRegistered(spellID)
                if spell then spell.lastCastAt = GetTime() end
            end,
        },
    },

    frame = CreateFrame("Frame"),  -- 用于注册 WoW 事件的隐形 Frame
}
```

---

### 12. APL（攻击优先级列表）
**文件**: `src/APL/APL.lua`
**说明**: 攻击优先级列表，按顺序评估和执行法术/物品/动作。

| 字段 | 类型 | 说明 |
|------|------|------|
| `self.apl` | `table` | 动作列表：`{ APLActor1, APLActor2, ... }` |
| `self.variables` | `table` | APL 变量：`{ [name] = value }` |

```lua
-- 示例：APL 完整内部结构（一个猎人的攻击优先级列表）
self = {
    name = "default",

    -- 变量表（APL:AddVariable 注册，APL:GetVariable 读取）
    variables = {
        ["poolFocus"]  = true,    -- 是否蓄集中值
        ["burstPhase"] = false,   -- 是否爆发阶段
        ["aoeMode"]    = true,    -- 是否 AOE 模式
    },

    -- 动作列表（按顺序评估，第一个 Execute 返回 true 的就中断）
    apl = {
        [1] = APLActor {                       -- 变量计算
            actor = {
                variable = "burstPhase",
                cb = function(apl) return Player:GetAuras():FindMy(BestialWrath):IsUp() end,
                _apl = self
            },
            traits = {}
        },
        [2] = APLActor {                       -- 法术：杀戮射击
            actor = {
                spell        = Spell { spellID = 61006 },
                condition    = "execute_phase",
                castableFunc = function(self) return self:IsKnownAndUsable() end,
                onCastFunc   = false,
                target       = Unit("Creature-0-3151-...")
            },
            traits = {}
        },
        [3] = APLActor {                       -- 动作：手动逻辑
            actor = {
                action = "usePotion",
                cb = function(actor)
                    if Player:GetHP() < 35 then HealingPotion:Use(Player) end
                end
            },
            traits = { APLTrait { cb = function() return Player:IsAffectingCombat() end } }
        },
    },
}
```

---

### 13. List（通用列表）
**文件**: `src/List/List.lua`
**说明**: 通用有序列表，支持 push/pop/filter/map/reduce 等函数式操作。

| 字段 | 类型 | 说明 |
|------|------|------|
| `self._list` | `table` | 内部数组：`{ value1, value2, ... }` |

```lua
-- 示例：List 完整内部结构（以 ObjectManager.enemies 为例）
self = {
    _list = {
        [1] = Unit { unit = <WoW Object>, id = 212793, ttd = 28.5, cache = Cache{...} },
        [2] = Unit { unit = <WoW Object>, id = 212794, ttd = 15.2, cache = Cache{...} },
        [3] = Unit { unit = <WoW Object>, id = 212795, ttd = 42.0, cache = Cache{...} },
    }
}
-- 操作示例：
-- enemies:count()  → 3
-- enemies:filter(function(u) return u:GetHP() < 30 end)  → 新 List
-- enemies:each(function(u) if u:IsBoss() then return true end end)  → 遇到 Boss 中断
```

---

### 14. NotificationsList（通知系统）
**文件**: `src/NotificationsList/NotificationsList.lua`
**说明**: 游戏内弹出通知队列，0.1s Ticker 自动清理过期通知。

| 字段 | 类型 | 说明 |
|------|------|------|
| `self.notifications` | `table` | 通知数组：`{ Notification1, Notification2, ... }` |

**Notification 结构：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `self.addedAt` | `number` | 添加时的 `GetTime()` |
| `self.duration` | `number` | 显示时长（默认 2s） |
| `self.frame` | `Frame` | UI 帧 |
| `self.icon` | `Texture` | 图标纹理 |
| `self.text` | `FontString` | 文字内容 |

```lua
-- 示例：NotificationsList + Notification 完整内部结构
self = {
    frame = Frame("BastionNotificationsList"),  -- 600x60, 屏幕顶部 TOP,0,-100

    notifications = {
        [1] = Notification {
            addedAt  = 12345.678,                           -- 添加时间
            duration = 2,                                    -- 显示 2 秒后淡出
            frame    = Frame { width = 180, height = 32 },   -- 通知 UI 帧
            icon     = Texture { texture = 136118 },         -- 法术图标(腐蚀术)
            text     = FontString { text = "腐蚀术 已施放" }, -- 通知文字
            list     = self,                                 -- 父列表引用
        },
        [2] = Notification {
            addedAt  = 12346.100,
            duration = 5,
            frame    = Frame { width = 200, height = 32 },
            icon     = Texture { texture = 135130 },         -- 急速药水图标
            text     = FontString { text = "急速药水 冷却完毕" },
            list     = self,
        },
    },
}
```

---

### 15. BastionDB（持久化存储 - SavedVariables）
**说明**: WoW SavedVariables 持久化表，登出时自动保存到磁盘。

| 字段 | 类型 | 说明 |
|------|------|------|
| `BastionDB.StatusFramePosition` | `table` | UI 框体位置 |
| `BastionDB.StatusFramePosition.point` | `string` | 锚点（如 `"CENTER"`） |
| `BastionDB.StatusFramePosition.relative` | `string` | 相对框体（`"UIParent"`） |
| `BastionDB.StatusFramePosition.relativePoint` | `string` | 相对锚点 |
| `BastionDB.StatusFramePosition.x` | `number` | X 偏移 |
| `BastionDB.StatusFramePosition.y` | `number` | Y 偏移 |
| `BastionDB.StatusFrameIcon` | `table` | 状态图标 |
| `BastionDB.StatusFrameIcon.icon` | `string` | 图标路径 |

```lua
-- BastionDB 示例：
-- BastionDB = {
--     StatusFramePosition = { point = "CENTER", relative = "UIParent", relativePoint = "CENTER", x = -500, y = 300 },
--     StatusFrameIcon = { icon = "Interface\\Icons\\Ability_Hunter_RunningShot" }
-- }
```

---

### 16. Aura（光环数据结构）
**文件**: `src/Aura/Aura.lua`
**说明**: 单条 Buff/Debuff 的数据封装。

| 字段 | 类型 | 说明 |
|------|------|------|
| `self.aura.name` | `string` | 光环名称 |
| `self.aura.icon` | `string` | 图标 |
| `self.aura.count` | `number` | 层数 |
| `self.aura.dispelType` | `string` | 驱散类型（Magic/Curse/Poison/Disease） |
| `self.aura.duration` | `number` | 总时长（秒） |
| `self.aura.expirationTime` | `number` | 到期时间戳 |
| `self.aura.source` | `string` | 来源单位 token |
| `self.aura.isStealable` | `boolean` | 是否可偷取 |
| `self.aura.spellId` | `number` | 法术ID |
| `self.aura.canApplyAura` | `boolean` | 是否可施加 |
| `self.aura.isBossDebuff` | `boolean` | 是否 Boss Debuff |
| `self.aura.castByPlayer` | `boolean` | 是否玩家释放 |
| `self.aura.auraInstanceID` | `number` | 光环实例ID（唯一标识） |
| `self.aura.type` | `string` | `"HELPFUL"` 或 `"HARMFUL"` |
| `self.aura.timeMod` | `number` | 时间修正系数 |

```lua
-- 示例：3 个不同类型的 Aura 实例完整结构

-- 1) 玩家施放的 debuff（腐蚀术）
Aura {
    aura = {
        name             = "腐蚀术",
        icon             = 136118,
        count            = 0,           -- 无层数
        dispelType       = "Magic",     -- 可魔法驱散
        duration         = 14,          -- 持续14秒
        expirationTime   = 12359.678,   -- 到期时间戳
        source           = "player",    -- 玩家自己施放
        isStealable      = false,
        nameplateShowPersonal = false,
        spellId          = 172,
        canApplyAura     = true,
        isBossDebuff     = false,
        castByPlayer     = true,
        nameplateShowAll = false,
        timeMod          = 1,
        auraInstanceID   = 1001,        -- 唯一实例ID
        index            = nil,         -- 新版API不使用index
        type             = "HARMFUL"    -- debuff
    }
}

-- 2) 他人施放的 buff（奥术智慧，法师给的）
Aura {
    aura = {
        name             = "奥术智慧",
        icon             = 135932,
        count            = 0,
        dispelType       = "Magic",
        duration         = 3600,         -- 持续1小时
        expirationTime   = 15945.678,
        source           = "Player-3151-0B2C3D4E",  -- 法师队友
        isStealable      = true,         -- 可偷取
        nameplateShowPersonal = false,
        spellId          = 1459,
        canApplyAura     = true,
        isBossDebuff     = false,
        castByPlayer     = false,        -- 不是本玩家施放
        nameplateShowAll = false,
        timeMod          = 1,
        auraInstanceID   = 2001,
        index            = nil,
        type             = "HELPFUL"     -- buff
    }
}

-- 3) Boss debuff（带层数的 DOT）
Aura {
    aura = {
        name             = "灼烧创伤",
        icon             = 135818,
        count            = 3,            -- 3层
        dispelType       = nil,          -- 不可驱散
        duration         = 12,
        expirationTime   = 12357.000,
        source           = "Creature-0-3151-2549-31-999999-0001",  -- Boss
        isStealable      = false,
        nameplateShowPersonal = false,
        spellId          = 395893,
        canApplyAura     = true,
        isBossDebuff     = true,         -- Boss debuff
        castByPlayer     = false,
        nameplateShowAll = true,
        timeMod          = 1,
        auraInstanceID   = 3005,
        index            = nil,
        type             = "HARMFUL"
    }
}
```

---

### 17. HunterUI（猎人脚本 UI 状态表）
**文件**: `src/herui/hunter.lua`
**说明**: 猎人职业脚本的 UI 控制面板，管理技能开关和数值配置。

| 字段 | 类型 | 说明 |
|------|------|------|
| `self.states` | `table` | 所有 UI 开关/数值状态 |
| `self.buttonStateMap` | `table` | 按钮名→Button 控件映射 |
| `self.frame` | `Frame` | 主 UI 框体 |

```lua
-- 示例：HunterUI 完整内部结构
self = {
    -- 状态表（布尔开关 + 数值配置）
    states = {
        blackArrow           = false,    -- 黑箭模式
        explosiveTrap        = true,     -- 爆炸陷阱模式
        normal               = true,     -- 普通模式
        aoe                  = false,    -- AOE 模式
        simple               = false,    -- 简化模式
        aimedShot            = false,    -- 瞄准射击
        multiShot            = true,     -- 多重射击
        petAttack            = true,     -- 宠物攻击
        petFollow            = false,    -- 宠物跟随
        viperSting           = false,    -- 蚰蛇钉刺
        autoTarget           = true,     -- 自动切目标
        stealTarget          = false,    -- 抢怪模式
        viperStingMode       = false,    -- 蝰蛇钉刺模式
        killShotMode         = true,     -- 杀戮射击模式
        frozenArrow          = false,    -- 冰冻箭
        trapDistanceOffset   = 1,        -- 陷阱距离偏移（1-9）
        porcupineBaitDistance = 10,      -- 豪猪诱饵距离（5/10/15/20）
        petFollowThreshold   = 50,       -- 宠物跟随血线百分比
        petHealThreshold     = 50,       -- 宠物治疗血线百分比
        ignoreLowHealthFollow = false,   -- 忽略低血量跟随
    },

    -- 按钮状态映射（state名 → Button控件，用于更新UI图标颜色）
    buttonStateMap = {
        ["blackArrow"]    = Button { ... },   -- 黑箭按钮
        ["explosiveTrap"] = Button { ... },   -- 爆炸陷阱按钮
        ["petAttack"]     = Button { ... },   -- 宠物攻击按钮
        -- ... 其余按钮
    },

    frame = Frame("HunterUIFrame"),  -- 主框体，可拖拽
}
```

---

### 18. Bastion 全局表（bootstrap.lua）
**文件**: `init.lua` + `bootstrap.lua`
**说明**: 框架顶层全局表和 Bootstrap 阶段创建的共享对象。

```lua
-- 示例：Bastion 全局表完整结构
Bastion = {
    DebugMode = false,                        -- 调试模式开关
    _Tinkr    = Tinkr,                        -- Tinkr 运行时引用

    -- 全局共享对象容器
    Globals = {
        EventManager = EventManager { ... },  -- 事件管理器实例
        SpellBook    = SpellBook { ... },      -- 法术注册表实例
        ItemBook     = ItemBook { ... },       -- 物品注册表实例
    },

    -- UI 容器
    UI = {
        StatusFrame = StatusFrame { ... },    -- 状态图标框体
    },

    -- 核心管理器实例
    UnitManager   = UnitManager { ... },      -- 单位管理器
    ObjectManager = ObjectManager { ... },    -- 对象管理器
    CombatTimer   = Timer { startTime = 12300.0, type = "combat" },
    Notifications = NotificationsList { ... },
    Ticker        = C_Timer.Ticker,           -- 0.1s 主循环定时器
}

-- MODULES（bootstrap.lua 局部变量，非全局可见）
-- Bastion:Register(module) 时写入，Ticker 每帧遍历执行
MODULES = {
    [1] = Module { name = "HunterMarksmanship", enabled = true, synced = { function() ... end } },
    -- 可注册多个模块
}
```

---

### 19. BastionDB 补充字段（HunterUI 持久化）
**说明**: hunter.lua 也向 BastionDB 写入 UI 位置。

| 字段 | 类型 | 说明 |
|------|------|------|
| `BastionDB.HunterUIPosition` | `table` | 猎人 UI 框体位置 |
| `BastionDB.HunterUIPosition.point` | `string` | 锚点 |
| `BastionDB.HunterUIPosition.relativePoint` | `string` | 相对锚点 |
| `BastionDB.HunterUIPosition.x` | `number` | X 偏移 |
| `BastionDB.HunterUIPosition.y` | `number` | Y 偏移 |

```lua
-- BastionDB 完整结构（含所有持久化数据）
BastionDB = {
    StatusFramePosition = {
        point = "CENTER", relative = "UIParent",
        relativePoint = "CENTER", x = -500, y = 300
    },
    StatusFrameIcon = {
        icon = "Interface\\Icons\\Ability_Hunter_RunningShot"
    },
    HunterUIPosition = {
        point = "TOPLEFT", relativePoint = "TOPLEFT",
        x = 200, y = -150
    },
}
```

---

### 缓存层级总览

```
Bastion（全局）
├── UnitManager
│   ├── .objects { [guid] = Unit }                    -- 单位对象池
│   ├── .customUnits { [token] = { unit, cb } }       -- 自定义单位
│   └── .cache (Cache)                                 -- 自定义单位过期控制
│       └── [token] = { value, duration=0.1, time }
│
├── ObjectManager
│   ├── .enemies (List)                                -- 敌人列表（每帧重建）
│   ├── .friends (List)                                -- 友方列表（每帧重建）
│   ├── .explosives (List)                             -- 爆炸物列表
│   └── ._lists { [name] = { list, cb } }             -- 自定义列表
│
├── SpellBook
│   └── .spells { [spellID] = Spell }                  -- 法术缓存池
│
├── ItemBook
│   ├── .items { [itemID] = Item }                     -- 物品缓存池
│   └── .nameCache { [name] = itemID }                 -- 名称查找缓存
│
├── EventManager
│   ├── .events { [name] = { handlers } }              -- 自定义事件
│   └── .wowEventHandlers { [name] = { handlers } }   -- WoW事件
│
├── Globals
│   ├── .EventManager                                 -- 事件管理器
│   │   ├── .events { [name] = { handlers } }
│   │   └── .wowEventHandlers { [name] = { handlers } }
│   ├── .SpellBook
│   │   └── .spells { [spellID] = Spell }
│   └── .ItemBook
│       ├── .items { [itemID] = Item }
│       └── .nameCache { [name] = itemID }
│
├── UI
│   └── .StatusFrame                                   -- 状态图标
│
├── MODULES [ Module, Module, ... ]                    -- 已注册模块（局部变量）
│
├── BastionDB (SavedVariables)                         -- 持久化存储
│   ├── .StatusFramePosition { point, relativePoint, x, y }
│   ├── .StatusFrameIcon { icon }
│   └── .HunterUIPosition { point, relativePoint, x, y }
│
├── HunterUI (脚本级)                                   -- 猎人UI状态
│   ├── .states { blackArrow, multiShot, petAttack, ... }
│   └── .buttonStateMap { [stateName] = Button }
│
└── 每个 Unit 实例
    ├── .cache (Cache)                                 -- 单位级短期缓存
    │   ├── ["enemies_N"] → 敌人数量 (0.5s)
    │   └── ["melee_attackers"] → 近战数量 (0.5s)
    ├── .aura_table (AuraTable)                        -- 光环缓存
    │   ├── .auras { [spellId] = { [instID] = Aura } }
    │   ├── .playerAuras { [spellId] = { [instID] = Aura } }
    │   └── .instanceIDLookup { [instID] = spellId }
    └── .regression_history [ { time, percent } ]      -- TTD预测数据
```
