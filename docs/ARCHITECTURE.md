# Архитектура

## Основной replay-поток

```text
BAR/Recoil replay observations
→ normalized telemetry выбранного team
→ подтверждённые episodes
→ детерминированный ranking
→ coaching report с одной training task
```

`bar_replay_coach.lua` является единственной BAR/UI-границей нового режима. Он проверяет `Spring.IsReplay()`, загружает явный `targetTeamID`, безопасно читает API и рисует готовую presentation-модель. Domain-модули не обращаются к `Spring`, `VFS`, `gl` или widget call-ins.

## Replay production-модули

| Модуль | Ответственность |
| --- | --- |
| `replay_opening_collector.lua` | Защищённо читает resources, units, factory task и start position только выбранного team |
| `replay_context.lua` | Хранит exact context и provisional thresholds |
| `replay_observation.lua` | Преобразует raw API evidence в normalized replay observation, сохраняя unknown |
| `history_buffer.lua`, `energy_stall.lua` | Переиспользуемая временная история и подтверждённый energy-stall lifecycle |
| `episode_aggregator.lua` | Объединяет соседние подтверждённые состояния, закрывает episodes и отбрасывает короткие кандидаты |
| `replay_session.lua` | Владеет одним team/timeline, first factory/expansion memory, reset и завершением анализа |
| `issue_ranker.lua` | Детерминированно выбирает ровно одну главную проблему |
| `training_task_selector.lua` | Сопоставляет проблеме одну ограниченную тренировочную задачу |
| `replay_report.lua` | Строит чистую report-модель и ограничения причинности |
| `replay_report_presentation.lua` | Формирует строки для панели и локального лога |
| `bar_replay_coach.lua` | Replay guard, target-team metadata, polling, команды report/hide/show и rendering |

## Team и replay boundary

`Spring.GetMyTeamID()` не используется для выбора анализируемого игрока. Team задаётся в локальном `LuaUI/Config/bar_replay_coach.lua`, проверяется по `Spring.GetTeamList()` и отклоняется, если это Gaia или отсутствующий team. Имя берётся через защищённые `GetPlayerList`/`GetPlayerInfo`, с нейтральным fallback для AI или неизвестного имени.

Анализ запускается только когда `Spring.IsReplay()` явно возвращает `true`. Виджет не отдаёт игровые команды, не вызывает `Spring.GiveOrder*`, не меняет playback и не показывает live gameplay recommendation. Raw replay-файл не читается: источником является воспроизведение внутри BAR.

## Episodes и timeline

- `energy_stall` переиспользует hysteresis и candidate/recovery lifecycle существующего detector; в report попадает только подтверждённая достаточная длительность.
- `factory_idle` относится только к первой наблюдённой завершённой Bot Lab; unknown task state и уничтожение фабрики не продолжают idle episode.
- `late_expansion` использует существующее определение законченного mex за радиусом `900` и отдельное context control window.

Aggregator хранит только подтверждённые интервалы. Смена team или rewind очищает всю текущую analysis session, поэтому две временные линии не смешиваются. `GameOver` или явная команда завершает активные episodes и делает report неизменяемым для этой session.

Ranking сначала учитывает подтверждённую последовательность energy stall → factory idle в ограниченном окне, затем общую длительность, повторяемость, положение по времени и стабильный type tie-break. Это узкое детерминированное правило, а не универсальная оценка качества игры.

## Вторичная opening-ветка

Существующий `bar_learning_coach.lua` и его opening/recovery domain остаются отдельной production-веткой:

```text
own-team live observations
→ opening/recovery decision
→ одна practice-card
```

Replay Coach не импортирует opening progress/presentation и не расширяет live-рекомендации. Общими остаются только проверенные низкоуровневые временные и API-подходы.

## Проверка

Standalone Lua specs проверяют normalized evidence, три episode type, короткие колебания, neutral/unsupported results, team change, rewind, active-episode close, ranking, training task и report presentation. Recoil runtime всё равно нужен отдельно: unit tests не подтверждают фактическую видимость выбранного team, factory task semantics, widget call-ins или layout в конкретной версии BAR.
