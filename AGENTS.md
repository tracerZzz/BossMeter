# AGENTS.md

本文件用于约束本仓库（`BossMeter`）的 AI 辅助开发规范与工程约定。

## 1. 文档维护约定 (`docs/`)

- `docs/` 目录仅用于沉淀**面向项目本身的持久设计、规范与当前生效状态**，不按 AI 会话堆砌一次性的 `plan` 或 `walkthrough` 文件。
- `docs/` 当前维护 4 份核心文档：`docs/architecture.md`（总体架构）、`docs/session_boundaries.md`（统计边界规范）、`docs/api.md`（外部扩展 API）、`docs/CHANGELOG.md`（变更与验证记录）。
- 每次代码变更若涉及架构、公共 API、配置项或统计边界的调整，应同步更新 `docs/` 下对应的现有文档，保持文档与代码现状一致。

## 2. 核心统计边界约束

改动采集器（`scripts/bossmeter/metrics/`）、会话管理（`scripts/bossmeter/core/session.lua`）或网络同步（`scripts/bossmeter/net/sync.lua`）时，需遵守以下边界：

- **参战隔离**：玩家侧指标（承伤、治疗、护甲、消耗品）必须通过 `Attribution.ResolveRelevantBoss` 判定归属（40 码内或存在直接战斗交互），禁止无条件归入全服最近活跃 Boss。
- **脱战续期**：仅对 Boss 造成伤害、Boss 直接攻击玩家、以及 Boss `combat.target` 仍为玩家时续期 `last_activity_time`；纯玩家侧回血、吃东西、护甲损耗等传入 `{ touch_activity = false }`。
- **超时时长**：`timeout` 结束时的 `end_time` 必须取 `session.last_activity_time`，不得把脱战等待时间计入战斗时长。
- **多 Boss 与微战报**：`BossState` 须携带 `boss_id`；`timeout` / `despawn` 战报需经过 `Sync.ShouldBroadcastReport` 过滤。

## 3. 验证要求

- 任何核心逻辑或采集/同步逻辑改动后，必须运行纯 Lua 单元测试并确保全部通过：
  ```bash
  /usr/local/bin/luajit tests/run_tests.lua
  ```
- 若新增/修改了边界规则或核心流程，需在 `tests/` 中补充对应单元测试。
