# Phase 6D opening replay analysis

Дата: 2026-07-22.

## Source

Повторно воспроизведён существующий ненулевой replay на `Ravaged Remake v1.2` и game version `2026.06.12`.

Два других ненулевых replay на Ravaged от 2026-07-18 были кратко проверены на faction. Оба также содержали `armcom`; долгие дублирующие прогоны не выполнялись.

## Tests

- первый запуск: 80 success / 1 failure из-за повторного использования mutable fake observation в новом tracker spec;
- fixture исправлена;
- обязательный полный повтор: 81 success / 0 failures.

## Complete opening series

- 46 полных samples;
- максимальный `gameTime=750.3`;
- 4 pregame samples: `contextStatus=unknown`, commander отсутствует;
- 42 game samples: `contextStatus=unsupported`, commander=`armcom`;
- teamID 0: 42 samples, teamID 1: 4 samples;
- все `GetTeamUnits`, `GetUnitDefID`, `GetUnitIsBeingBuilt`, `GetUnitWorkerTask`, `GetUnitPosition` и `UnitDefs` доступны во всех samples;
- `unknownUnitCount=0` во всех samples;
- milestone presentation отсутствует во всех unsupported samples;
- собственных test/telemetry/production widget errors нет.

Последняя строка raw log оборвана принудительным завершением процесса, но это detail-строка build-power unit после полностью записанного opening sample 46. Она не попала в opening CSV.

## Decision

`keep` для tracker/runtime integration и context guard. Нельзя принять `keep` для supported opening milestones по этому replay: Cortex context отсутствует. Следующая runtime-проверка должна использовать `corcom`, но не требуется повторять Armada replay или создавать новую партию только ради длительности.
