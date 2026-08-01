# MVP

Обновлено: 2026-07-31.

## Гипотеза

Один context-bound opening с ближайшим milestone может помочь мотивированному новичку связать economy, production, army и expansion. Runtime-формат оправдан только если он полезнее короткой статической шпаргалки с тем же content.

## Поддерживаемый context

MVP поддерживает только `cortex_bot_ravaged_1v1_practice`:

- `Ravaged Remake v1.2`;
- Cortex commander `corcom`;
- Bot Lab `corlab`;
- локальная 1v1 skirmish/practice;
- только доступные данные собственной команды;
- завершение на устойчивом T1 без обязательного T2.

Bot Lab — выбранная ветка одного контролируемого lesson, а не универсальный top-player baseline. При несовпадении context виджет молчит и не подбирает альтернативный build.

## Observation contract

Infrastructure формирует нормализованное observation:

```lua
{
  contextId = "cortex_bot_ravaged_1v1_practice",
  contextStatus = "supported" | "unsupported" | "unknown",
  gameTime = number | nil,
  finishedCounts = {
    cormex = number | nil,
    corwin = number | nil,
    corsolar = number | nil,
    corlab = number | nil,
    corck = number | nil,
    combatBots = number | nil,
    expansionMex = number | nil,
  },
  factory = {
    active = boolean | nil,
    idleDuration = number | nil,
  },
  recovery = {
    energyState = string | nil,
  },
}
```

Counts относятся только к законченным собственным units. `expansionMex` использует valid own-team start position и exact-context radius `900`; равенство radius остаётся внутри стартовой зоны. Потеря API, definition, build state, position или context evidence сохраняется как `nil`/`unknown`.

## Milestones

| Milestone | Наблюдаемый результат | Текущий provisional threshold |
| --- | --- | --- |
| `base_income` | Закончены стартовые mex и доступная генерация | 3 `cormex` и 1 `corwin` или `corsolar` |
| `bot_lab` | Запущено первое производство | 1 законченный `corlab` |
| `production_cycle` | Есть constructor и первые combat bots | 1 `corck` и 3 combat bots из build options `corlab` |
| `first_expansion` | Законченный mex вне стартовой зоны | 1 `cormex` строго дальше radius `900` |
| `t1_loop` | Предыдущие результаты достигнуты, производство продолжается | 5 combat bots, factory idle не дольше 15 секунд, нет active/resolving energy recovery |

Thresholds подтверждены технически только для exact context и остаются гипотезами до Phase 8.

## Presentation decision

1. Active/resolving `ENERGY_STALL` выбирает recovery.
2. Иначе выбирается первый незавершённый milestone.
3. `unknown` и unsupported context дают `presentation = "none"`.
4. После завершения lesson карточка скрывается.
5. Достигнутый milestone запоминается в текущей team/context/game timeline и сбрасывается при explicit reset, context/team change или replay rewind.

## Текущее состояние реализации

Реализованы и покрыты specs:

- context configuration и validation;
- stateless scan собственных units;
- stateful factory idle/recovery tracking;
- milestone evaluation, out-of-order completion и completion memory;
- expansion classification для exact context;
- recovery recommendation;
- replay collector для research.

`bar_learning_coach_debug.lua` показывает debug/telemetry state. Отдельная пользовательская opening-card и статическая шпаргалка ещё не реализованы; это граница Phase 7.

Последнее сохранённое runtime evidence Phase 6I находится в [`runtime/opening/phase6i_completion_memory_2026-07-25.md`](runtime/opening/phase6i_completion_memory_2026-07-25.md). Оно подтверждает технический flow, но не usefulness.

## Не входит

Актуальный список замороженных направлений находится в [`NOT_NOW.md`](NOT_NOW.md). В MVP нет второго context, T2 lesson, opponent-dependent composition, новых самостоятельных diagnosis cards, post-match scoring, automation и distribution infrastructure.

## Готовность к usefulness validation

До Phase 8 необходимо:

1. реализовать минимальную opening-card и эквивалентную статическую шпаргалку;
2. подтвердить supported, unsupported, unknown, recovery и lesson-complete runtime paths после последнего изменения;
3. подготовить одинаковый сценарий наблюдения и installation-friction notes;
4. не менять content между comparator и live-widget, кроме самого способа показа.
