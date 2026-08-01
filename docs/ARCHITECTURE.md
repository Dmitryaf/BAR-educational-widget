# Архитектура

Обновлено: 2026-08-01.

## Действующий data flow

```text
BAR/Recoil API and widget call-ins
→ infrastructure adapters
→ normalized snapshots/observations
→ stateful tracker and domain evaluation
→ presentation decision
→ debug UI или подтверждённая energy-recovery card
```

Domain-код тестируется без BAR и не обращается к `Spring`, `VFS` или `gl`. Текущий entrypoint объединяет скрытую по умолчанию debug-панель и существующую energy-recovery card; пользовательская opening milestone-card пока не реализована.

## Текущая структура

```text
LuaUI/Include/bar_learning_coach/
  history_buffer.lua
  snapshot_collector.lua
  energy_stall.lua
  energy_stall_recommendation.lua
  build_power_adapter.lua
  build_power_snapshot.lua
  opening_context.lua
  opening_adapter.lua
  opening_tracker.lua
  opening_progress.lua
  replay_opening_collector.lua

LuaUI/Widgets/
  bar_learning_coach_debug.lua

tests/
  *_spec.lua
  run.lua
  bar_*_widget.lua
```

## Ответственность модулей

| Модуль | Ответственность |
| --- | --- |
| `snapshot_collector.lua` | Нормализованный team-resource snapshot |
| `history_buffer.lua`, `energy_stall.lua` | Temporal history и lifecycle `ENERGY_STALL` |
| `energy_stall_recommendation.lua` | Presentation model подтверждённого recovery |
| `build_power_adapter.lua`, `build_power_snapshot.lua` | Debug/recovery observability build power без отдельной пользовательской карточки |
| `opening_context.lua` | Чистая конфигурация exact lesson и provisional thresholds |
| `opening_adapter.lua` | Stateless BAR scan → normalized opening observation |
| `opening_tracker.lua` | Factory idle history, reset и completion memory текущей timeline |
| `opening_progress.lua` | Чистая оценка milestones и выбор `milestone/recovery/none` |
| `replay_opening_collector.lua` | Target-only factual research evidence; не production recommendation logic |
| `bar_learning_coach_debug.lua` | Integration, invalidation/rescan и debug rendering |

## Context и observation

Канонический runtime-контракт и thresholds описаны в [`MVP.md`](MVP.md). Context не содержит runtime IDs, `Spring` или opponent data. Adapter сканирует только собственную team, считает законченные tracked units и сохраняет неполное evidence как `nil`.

Unknown definition делает зависимые exact counts неизвестными. Неизвестный build state влияет только на соответствующую count group. Expansion вычисляется stateless из current finished mex positions и current valid own-team start position.

## State и lifecycle

`opening_tracker.lua` располагается поверх полного stateless scan:

- измеряет idle duration только после подтверждённого idle sample;
- сбрасывает temporal confidence при team/context change, replay rewind, unknown factory activity и lifecycle invalidation;
- не хранит incremental unit counts и поэтому не маскирует пропущенный call-in;
- запоминает достигнутые milestones только в текущей timeline;
- сохраняет current regression как observed state, не возвращая игрока к уже завершённому шагу;
- очищает completion memory при explicit reset, team/context change и rewind.

Production widget call-ins инвалидируют state и запускают новый scan; они не являются самостоятельным источником counts.

## Границы слоёв

- Infrastructure владеет BAR/Recoil API, runtime IDs и валидацией внешних значений.
- Domain/application получает только normalized contracts и не рисует UI.
- Presentation decision выбирается до rendering.
- Debug UI не определяет milestone, expansion или recovery priority.
- Replay collector не используется как production adapter и не читает opponent team для recommendation logic.

## BAR/Recoil API

Текущий подтверждённый surface и версии источников находятся в [`research/BAR_API_RESEARCH.md`](research/BAR_API_RESEARCH.md). При новом или изменившемся вызове evidence обновляется до изменения domain contract.

## Установочная структура

Helper modules размещаются только в `LuaUI/Include/bar_learning_coach`. В `LuaUI/Widgets` остаются загружаемые widget entrypoints: handler может попытаться загрузить вложенный helper `.lua` как отдельный widget.

Test/telemetry widgets находятся в `tests/` и не должны оставаться активными после runtime-проверки.

## Следующая архитектурная граница

Phase 7 должен добавить минимальную пользовательскую presentation surface без переноса milestone/recovery logic в UI. Новый общий presenter module нужен только если реальный card path не может использовать существующий domain result без дублирования.
