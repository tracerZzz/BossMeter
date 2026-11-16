# Tracer 模组架构与实施规划

## Goal Description

基于前期构想备忘录与已确认的需求，本项目将为《饥荒联机版》（DST）构建名为 **`Tracer`** 的 Boss 战数据统计与可视化模组（单仓库 Monorepo）。

### 已确认核心需求
1. **MVP 统计维度全覆盖（4 大类）**：
   * **伤害输出类**：总伤害、DPS、伤害占比、伤害来源归属（武器/技能/随从等）。
   * **生存承伤类**：受到 Boss 的总伤害、死亡/濒死次数。
   * **辅助治疗类**：治疗量/回血贡献、控制或减伤辅助。
   * **资源消耗类**：护甲耐久损耗、食物/药品消耗统计。
2. **UI 与交互形态**：
   * **战斗中**：隐藏复杂面板，仅保留极简状态提示（如正在追踪 Boss 的微弱角标/提示，不遮挡战斗视野）。
   * **战后**：弹出/可呼出的**完整数据回顾面板**，包含柱状图（玩家对比/来源占比）与折线图（时间轴 DPS/承伤趋势等）。

---

## Technical Evaluation & Architecture Decisions

### 1. 网络同步机制选型（战后 ModRPC 批量下发 + 战斗中极简心跳）

| 方案 | 优点 | 缺点 | 与当前需求匹配度 |
| :--- | :--- | :--- | :--- |
| **A. 战后 ModRPC 结算包（已采用）** | 战斗中几乎零网络开销；无 `net_string` 长度限制，可完整传输 4 大类指标、来源明细与折线采样序列；天然适配 Master/Caves 双分片（Boss 所在分片直接下发给该分片玩家） | 战斗中不展示实时详细图表（恰好符合 UI 选择） | **极高** |
| **B. 纯 NetVar 网络变量** | 引擎自动同步给附近客户端 | 仅适合简单标量；复杂嵌套表与时间序列数组难以用 NetVar 表达，且高频更新占用带宽 | **低** |
| **C. 战斗中高频 RPC 推送** | 支持战斗中实时折线图 | 战斗中无实时面板展示需求，高频序列化属于无效开销 | **低** |

> **设计原则**：战斗期间所有采集与时间桶采样（每秒 1 个采样点）**仅在服务端内存**中完成；战斗中仅通过轻量 `BossState` 同步状态。Boss 战结束时，服务端一次性将完整结算数据序列化并通过 `SendModRPCToClient`（支持大数据分片传输）推送给客户端缓存与渲染。

### 2. 扩展注册 API 规范（统一 `RegisterMetric` + `Record` 混合模式）

为了避免内置 4 大类指标与外部模组指标走两套逻辑，采用**「声明式注册 + 统一上报接口」**：
* **声明式定义 (`Tracer.RegisterMetric(id, def)`)**：注册指标 ID、显示名称、所属分类（`damage`/`survival`/`support`/`resource` 或自定义）、聚合方式（累加 `sum`、峰值 `max`、时间序列 `timeseries`）、图表渲染类型（`bar`/`line`/`breakdown`）。
* **统一数据上报 (`Tracer.Record(metric_id, boss_id, player_id, player_name, value, source_name, timestamp, player_prefab)`)**：外部模组可在自己的事件钩子中直接上报；同时 Tracer 内置的 4 大类采集器也通过完全相同的 `RegisterMetric` + `Record` 管线运行。

---

## 工程目录结构（Monorepo）

```text
dst-tracer/
├── modinfo.lua                     # 模组元信息与配置项
├── modmain.lua                     # 双端入口：注册 RPC、加载模块与钩子
├── docs/
│   ├── implementation_plan.md      # 架构设计与分阶段规划
│   └── walkthrough.md              # 实施总结与验证进度
├── scripts/
│   └── tracer/
│       ├── core/
│       │   ├── registry.lua        # 指标注册表 (RegisterMetric) 与分类管理
│       │   ├── session.lua         # Boss 战生命周期状态机 (进战/脱战/击杀/时间桶)
│       │   ├── collector.lua       # 统一数据采集与归因 (Record)
│       │   └── serializer.lua      # 结算数据序列化/反序列化与分片校验
│       ├── metrics/
│       │   ├── init.lua            # 内置指标注册与服务端钩子总入口
│       │   ├── attribution.lua     # 玩家/随从/武器归属解析
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
│           └── review_panel.lua    # 战后完整数据回顾弹窗 (Tab 切换 4+1 类 + 图表)
└── tests/
    ├── run_tests.lua               # 纯 Lua 单元测试入口
    ├── test_session.lua            # Boss 战状态机与时间桶测试
    ├── test_registry_metrics.lua   # 4 类指标聚合与外部注册 API 测试
    └── test_serializer.lua         # 序列化与边界条件测试
```

---

## 分阶段实施与演进路线

* **Phase 1: 仓库骨架与纯 Lua 测试基建**（已完成）
* **Phase 2: 4 大类内置指标采集器 (`metrics/`)**（已完成 MVP）
* **Phase 3: 网络同步层 (`net/sync.lua`)**（已完成 MVP）
* **Phase 4: 内置图表库与战后回顾面板 (`ui/`)**（已完成 MVP，本地实机已跑通）
* **Phase 5: 持续优化与深度验证**（进行中）
  * 多人洞穴（Master + Caves 双分片）实机稳定性与跨分片边界测试
  * 特定 Boss 多阶段/特殊伤害机制与道具归因细化
  * 战后回顾面板 UI 交互、视觉细节与图表可读性优化
  * 外部模组 `GLOBAL.Tracer` 扩展注册联调示例与文档
