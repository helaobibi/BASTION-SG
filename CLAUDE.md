# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概览

Bastion 是基于 Tinkr 的 WoW 自动化框架，使用面向对象的 Lua 实现。通过 `.toc` 文件声明式加载，作为标准 WoW 插件运行。Tinkr 运行时 API（FaceObject、WriteFile、Tinkr.Util.* 等）保留不变。

## 构建/测试/运行

- **无本地构建**：不需要 `npm`/`make` 等工具
- **无自动化测试**：在游戏内手动验证
- **调试命令**：游戏内 `/bastion debug` 切换调试模式

## 架构

### 入口与初始化
- `.toc` 加载顺序：`init.lua`（创建全局 `Bastion` 表）→ `src/` 模块（注册类到 `Bastion.X`）→ `bootstrap.lua`（`Bastion.Bootstrap()` 创建实例、注册事件、启动 Ticker）
- 主循环：0.1 秒间隔的 Ticker，执行所有注册模块的 `Tick()`
- 位置数据通过 `SavedVariables`（`BastionDB`）持久化

### 模块加载约定
- 所有文件通过 `Bastion.toc` 声明式加载，按依赖顺序排列
- 模块文件末尾用 `Bastion.X = X` 注册到全局表（不再使用 `return`）
- 使用 Tinkr 的模块通过 `local Tinkr = Bastion._Tinkr` 获取引用

### 核心模块依赖
```
bootstrap.lua (引导启动)
├── ClassMagic (属性自动解析：unit.health → GetHealth())
├── Cache/Cacheable/Refreshable (三层缓存系统)
├── Unit → AuraTable, Cache
├── UnitManager (单位管理，支持自定义选择器)
├── ObjectManager (对象管理)
├── EventManager (WoW 事件处理)
├── SpellBook → Spell
├── ItemBook → Item
├── APL → APLActor, APLTrait, Sequencer (攻击优先级列表)
└── Module (脚本模块基类)
```

### 类定义模式
所有模块使用统一的 OOP 模式：
```lua
local Tinkr = Bastion._Tinkr  -- 仅在需要 Tinkr API 时
local MyClass = {}
MyClass.__index = MyClass

function MyClass:New(param)
    local self = setmetatable({}, MyClass)
    self.property = param
    return self
end

Bastion.MyClass = MyClass
```

## 目录结构

- `init.lua` - 初始化全局 Bastion 表和 SavedVariables
- `bootstrap.lua` - Bootstrap 启动（创建实例、注册事件、启动 Ticker）
- `Bastion.toc` - 插件声明文件
- `src/<Module>/<Module>.lua` - 核心模块（目录/文件名与类名一致）
- `scripts/*.lua` - 职业脚本模块
- UI 位置通过 `BastionDB` SavedVariables 持久化

## 脚本模块模板

```lua
local Tinkr = Bastion._Tinkr
local MyModule = Bastion.Module:New('MyModule')
local Player = Bastion.UnitManager:Get('player')
local SpellBook = Bastion.Globals.SpellBook
local MySpell = SpellBook:GetSpell(12345) -- 法术名

local DefaultAPL = Bastion.APL:New('default')
DefaultAPL:AddSpell(
    MySpell:CastableIf(function(self)
        return Player:Exists()
    end):SetTarget(Player)
)

MyModule:Sync(function()
    DefaultAPL:Execute()
end)

Bastion:Register(MyModule)
```

## 代码风格

- 缩进 4 空格，文件末尾 `Bastion.X = X` 注册到全局表
- 文件顶部：`local Tinkr = Bastion._Tinkr`（仅在需要 Tinkr API 时）
- 命名：PascalCase（类/模块），camelCase（局部变量）
- 方法前缀：`Get`（获取）、`Is`/`Has`（判断）
- 实例方法用冒号 `Class:Method()`，静态函数用点 `Class.Function()`
- 法术/物品变量附中文注释：`local KillShot = SpellBook:GetSpell(61006) -- 杀戮射击`
- 使用 EmmyLua 注解：`---@class`、`---@param`、`---@return`

## 常用 API

```lua
-- 单位
Bastion.UnitManager:Get('player')
Bastion.UnitManager:CreateCustomUnit('besttarget', callback)

-- 法术
Bastion.Globals.SpellBook:GetSpell(spellID)
Spell:CastableIf(func):SetTarget(unit)
Spell:PreCast(func) / Spell:OnCast(func)

-- 物品
Bastion.Globals.ItemBook:GetItem(itemID)
Item:UsableIf(func):Use(target)

-- APL
APL:AddSpell(spell) / APL:AddAction(func) / APL:AddVariable(name, func)
APL:Execute()
```

## 游戏内命令

- `/bastion debug` - 切换调试模式
- `/bastion module <name>` - 切换模块开关
- `/bastion dumpspells` - 导出法术列表
- `/bastion draw` - 切换绘制线条
- `/bastion follow` - 切换跟随目标

## 注意事项

- 全局共享对象挂载到 `Bastion.Globals`，避免新增全局变量
- 对可能失败的操作使用 `pcall`，失败时回退默认值
- 访问对象前检查 `Exists`/`IsAlive` 等条件
- 频繁计算的数据通过 `Cache`/`Cacheable`/`Refreshable` 复用
- UI 位置数据存储在 `BastionDB` SavedVariables 中，WoW 登出时自动保存
