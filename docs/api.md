# BossMeter 外部扩展 API 文档

`BossMeter` 在 `modmain.lua` 中暴露了全局表 `GLOBAL.BossMeter`，供其他 DST 模组在战斗期间向 Boss 战报注册自定义指标并上报数据。

---

## 1. 注册自定义指标：`BossMeter.RegisterMetric(id, def)`

在任意模组初始化阶段注册指标。未显式设置 `def.is_custom` 时，外部调用会自动标记为 `is_custom = true`（在回顾面板的扩展分类中展示）。

- **参数**：
  - `id` (`string`, 必填)：全局唯一指标 ID（如 `"skill_shield_broken"`）。
  - `def` (`table`, 必填)：
    - `name` (`string`, 必填)：面板显示名称。
    - `category` (`string`, 必填)：分类（内置为 `"damage"` / `"survival"` / `"support"` / `"resource"`，也可填自定义分类）。
    - `unit` (`string`, 可选)：单位，如 `"HP"`、`"次"`。
    - `aggregation` (`string`, 可选)：`"sum"`（默认）| `"max"` | `"timeseries"`。
    - `chart_type` (`string`, 可选)：`"bar"`（默认）| `"line"` | `"breakdown"`。
    - `track_timeseries` (`boolean`, 可选)：是否按秒记录时间序列桶（用于折线图）。
    - `color` (`table`, 可选)：`{ r, g, b, a }`。
    - `order` (`number`, 可选)：排序权重，越小越靠前（默认 `100`）。
    - `description` (`string`, 可选)：指标说明。
- **返回值**：`boolean, string|nil`（成功返回 `true`，失败返回 `false, err`）。

```lua
if GLOBAL.BossMeter then
    GLOBAL.BossMeter.RegisterMetric("parry_count", {
        name = "完美格挡",
        category = "survival",
        unit = "次",
        aggregation = "sum",
        chart_type = "bar",
        track_timeseries = false,
        order = 50,
    })
end
```

---

## 2. 上报指标数据：`BossMeter.Record(...)`

向一个活跃中的 Boss 战会话写入一条玩家数据（仅在服务端调用）。

```lua
BossMeter.Record(metric_id, boss_id, player_id, player_name, value, source_name, timestamp, player_prefab)
```

- `metric_id` (`string`)：已注册的指标 ID。
- `boss_id` (`string|number`)：Boss 会话 ID（内置 Boss 为 `inst.GUID`）。
- `player_id` (`string`)：玩家唯一标识（推荐使用 `player.userid`）。
- `player_name` (`string`)：玩家显示名。
- `value` (`number`)：数值（不可为 `nil` 或 `NaN`）。
- `source_name` (`string|nil`)：可选来源明细（如武器、技能名）。
- `timestamp` (`number|nil`)：事件时间戳（`GetTime()`），默认使用会话最近活跃时间。
- `player_prefab` (`string|nil`)：可选玩家角色 prefab。
- **返回值**：`boolean, string|nil`。

---

## 3. 会话控制接口

适用于自定义 Boss 实体（非 `epic` 标签）手动开启或结束统计：

- `BossMeter.StartBossSession(boss_id, boss_prefab, boss_name, start_time, boss_max_hp)`
  - 幂等开启会话；返回 `session, err`。
- `BossMeter.EndBossSession(boss_id, end_time, outcome)`
  - 结束会话并生成 `SessionSummary`，触发结算广播；`outcome` 可选 `"victory"` | `"timeout"` | `"despawn"`。
- `BossMeter.GetActiveSessions()`
  - 返回当前所有活跃会话表 `[boss_id] = session`。
