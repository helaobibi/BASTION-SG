---@class Bastion
Bastion = { DebugMode = false }
Bastion.__index = Bastion
Bastion._Tinkr = Tinkr  -- 保留 Tinkr 运行时引用
Bastion.Globals = {}    -- 预初始化，避免 Bootstrap 前被引用时 nil

-- SavedVariables（WoW 在登出时自动持久化）
BastionDB = BastionDB or {}
