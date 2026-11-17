# BossMeter 变更与验证记录 (CHANGELOG)

本文档记录 `BossMeter` 模组的功能里程碑、主要变更与测试验证状态。

---

## [0.1.1] - 统一品牌与项目更名为 BossMeter

- **模组与仓库更名**：模组名称、GitHub 仓库（`tracerZzz/BossMeter`）、公共全局接口（`GLOBAL.BossMeter`）、RPC 命名空间（`BossMeter`）、模块目录（`scripts/bossmeter/`）及 UI 文案统一更名为 `BossMeter`。

---

## [0.1.0] - 统计边界定型与核心 MVP

### 统计边界定型与修复
- **超时与续期边界**：`PruneTimeouts` 改用 `session.last_activity_time` 作为 `timeout` 结束时间；新增 `touch_activity` 与 `combat_interaction` 控制，确保吃食物、回血、护甲消耗等非战斗行为不无限续期脱战计时，并在 5 秒轮询中对仍有玩家仇恨目标的 Boss 调用 `TouchSession`。
- **参战范围与多 Boss 隔离**：在 `attribution.lua` 新增 `ResolveRelevantBoss`（40 码距离 + 直接战斗交互判定），隔离未参战的基地/远距离玩家并防止多 Boss 归因串台。
- **多 Boss HUD 与微战报过滤**：`BossState` RPC 携带 `boss_id`，客户端通过 `active_bosses` 集合维护 HUD 状态；新增 `Sync.ShouldBroadcastReport` 过滤路过擦边产生的无效 `timeout` / `despawn` 微战报。

### 核心 MVP 模块
- **配置与入口**：`modinfo.lua`（5 项联机配置）、`modmain.lua`（双端初始化与 `GLOBAL.BossMeter` 暴露）。
- **核心引擎**：`registry.lua`、`session.lua`、`collector.lua`、`serializer.lua`。
- **4 大类采集器**：`damage.lua`、`survival.lua`、`support.lua`、`resource.lua` 及 `attribution.lua`。
- **网络与 UI**：`sync.lua`（`BossState` + `SyncChunk` 分片推送）、`hud_indicator.lua`、`review_panel.lua`、`bar_chart.lua`、`line_chart.lua`。

---

## 验证状态

- **纯 Lua 单元测试**：`/usr/local/bin/luajit tests/run_tests.lua` — **57 passed, 0 failed**（覆盖 `test_registry_metrics`、`test_session`、`test_serializer`）。
- **本地联机 MVP**：已通过 `mods/BossMeter` 在《饥荒联机版》本地环境中成功加载并跑通。
- **待验证项**：多人洞穴（Master + Caves 双分片）跨世界联机稳定性。
