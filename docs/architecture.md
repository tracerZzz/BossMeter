# BossMeter 模组架构设计

本文档描述《饥荒联机版》（DST）Boss 战数据统计与可视化模组 **`BossMeter`** 的总体架构、核心技术选型与目录结构。

---

## 1. 核心能力与统计维度

1. **4 大内置统计维度 + 外部扩展**：
   - **伤害输出类（`damage`）**：`damage_total`（总伤害、DPS、占比、武器/技能/随从来源归属及每秒趋势）。
   - **生存承伤类（`survival`）**：`damage_taken`（承受伤害）、`deaths`（死亡/濒死次数）。
   - **辅助治疗类（`support`）**：`healing_done`（治疗/回血）、`mitigation`（护甲减伤吸收）。
   - **资源消耗类（`resource`）**：`armor_loss`（护甲耐久损耗）、`consumables_used`（食物/治疗道具消耗）。
   - **扩展指标**：通过 `GLOBAL.BossMeter` 公共接口注册任意自定义指标。
2. **双态 UI 交互**：
   - **战斗中**：仅在屏幕顶部显示极简状态角标（`hud_indicator.lua`），不遮挡视野。
   - **战后**：自动弹出或按快捷键（默认 `F8`）呼出完整数据回顾面板（`review_panel.lua`），支持横向柱状图与多序列时间轴折线图。

---

## 2. 技术选型与数据流

### 战后 ModRPC 批量下发 + 战斗中极简心跳

- **采集阶段（服务端内存）**：战斗期间所有事件采集与每秒时间桶采样（`buckets`）仅在服务端内存中完成，不进行高频网络同步。
- **状态心跳（`BossState` RPC）**：会话开始/结束时向客户端发送轻量状态通知，驱动 HUD 极简提示；携带 `boss_id` 以支持多 Boss 同场。
- **战后结算（`SyncChunk` RPC）**：Boss 战结束且通过 `Sync.ShouldBroadcastReport` 过滤后，服务端使用无 `loadstring` 依赖的 JSON 编解码器（`serializer.lua`）序列化 `SessionSummary` 并分片（4096 字节/片）推送给客户端缓存与渲染。
- **双分片天然适配**：Master 与 Caves 各自运行独立服务端实例，Boss 所在分片直接向该分片玩家下发战报。

---

## 3. 工程目录结构

```text
BossMeter/
├── AGENTS.md                       # AI 辅助开发规范与核心边界约束
├── modinfo.lua                     # 模组元信息与联机配置项
├── modmain.lua                     # 双端入口：注册 RPC、加载模块、暴露 GLOBAL.BossMeter
├── docs/
│   ├── architecture.md             # 总体架构与目录结构（本文档）
│   ├── session_boundaries.md       # 统计开始、续期、归因与结束边界规范
│   ├── api.md                      # GLOBAL.BossMeter 外部 Mod 扩展接口文档
│   └── CHANGELOG.md                # 模块进度、验证状态与变更记录
├── scripts/
│   └── bossmeter/
│       ├── core/
│       │   ├── registry.lua        # 指标注册表 (RegisterMetric) 与分类管理
│       │   ├── session.lua         # Boss 战生命周期状态机与每秒时间桶聚合
│       │   ├── collector.lua       # 对外核心门面 (Collector)
│       │   └── serializer.lua      # JSON 编解码器与 RPC 分片/重组器
│       ├── metrics/
│       │   ├── init.lua            # 内置指标注册与服务端钩子总入口
│       │   ├── attribution.lua     # 玩家/随从/武器归属与参战 Boss 判定
│       │   ├── damage.lua          # 伤害输出、DPS、来源归因采集器
│       │   ├── survival.lua        # 承伤、死亡/濒死采集器
│       │   ├── support.lua         # 治疗/减伤辅助采集器
│       │   └── resource.lua        # 护甲耐久损耗、食物/药品消耗采集器
│       ├── net/
│       │   └── sync.lua            # ModRPC 服务端推送与客户端接收缓存
│       └── ui/
│           ├── charts/
│           │   ├── bar_chart.lua   # 内置横向柱状图 Widget
│           │   └── line_chart.lua  # 内置折线趋势图 Widget
│           ├── hud_indicator.lua   # 战斗中极简提示角标
│           └── review_panel.lua    # 战后完整数据回顾弹窗
└── tests/
    ├── run_tests.lua               # 纯 Lua 单元测试入口
    ├── test_session.lua            # 会话状态机、边界与同步过滤测试
    ├── test_registry_metrics.lua   # 指标注册与聚合测试
    └── test_serializer.lua         # 序列化与分片重组测试
```

---

## 4. 待推进演进方向（TODO）

### 近期功能打磨
- **格挡与特殊机制采集**：核对 DST 女武神战斗盾牌等格挡机制，补齐格挡次数/抵消伤害统计。
- **特定多阶段 Boss 合并**：支持天体英雄等换实体转阶段 Boss 的会话衔接合并。
- **UI 交互与可读性优化**：打磨战后回顾面板（`review_panel.lua`）与图表展示细节。
- **双分片联机验证**：多人洞穴（Master + Caves）实机稳定性与跨分片边界测试。

### 长期架构抽象（Trace & Present）
- **通用追踪会话（Trace Scope）**：从单一 Boss 战扩展到袭击事件、远古探索、季节团队收支等通用场景追踪。
- **时间轴事件标记（Timeline Markers）**：在折线图上记录并标注关键离散事件（Boss 狂暴、玩家倒地、完美格挡等）以支持战后复盘。
- **开放基础设施 API**：在现有功能打磨成熟后，逐步抽象开放 `GetPlayerActiveBoss`、`OnSessionStart/End` 等通用追踪与呈现接口供第三方 Mod 调用，并补充联调示例。
