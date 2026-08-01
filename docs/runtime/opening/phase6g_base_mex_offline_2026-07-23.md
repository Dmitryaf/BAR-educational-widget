# Phase 6G — base-income offline revision

Дата: 2026-07-23.

## Изменение

Phase 6F decision `revise` применено к offline lesson contract:

- `baseMex`: `2 -> 3`;
- action: закончить три mex и добавить раннюю генерацию;
- wind и solar остаются равноправными способами выполнить energy часть milestone;
- factory, combat thresholds и остальные milestones не менялись.

Это threshold одного Ravaged practice lesson, а не универсальное правило BAR. Основание — три pre-factory mex в 4/4 проанализированных top-player replay; usefulness для новичка остаётся неизвестной.

## Specs

Обновлены:

- default context и copy isolation;
- solar alternative;
- production-cycle fixture;
- adapter-to-progress integration fixture.

Добавлена отдельная граница: два finished mex при подтверждённой energy дают `base_income=in_progress`, а не `complete`.

## Recoil verification

- exact engine: `recoil_2025.06.24`;
- test harness: `87 successes / 0 failures`;
- raw: `phase6g_base_mex_specs_2026-07-23_infolog.txt`;
- test log SHA-256: `87ba42ce0a46c8c5c318c01d63b638201d5da30983cbe410b717960655e825eb`;
- production `opening_context.lua` и repository source совпали по SHA-256 после установки.

Test harness был запущен в Tundra replay только как Lua 5.1 host. Gameplay этого запуска не анализировался и не является дополнительным replay evidence.

## Не проверено

- полный `base_income -> bot_lab -> production_cycle` на exact Ravaged context;
- factory active/idle для `corlab` на Ravaged;
- понятность и usefulness рекомендации про три mex.

Следующий отдельный concern — ручной Ravaged runtime не менее пяти игровых минут.
