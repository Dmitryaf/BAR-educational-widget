# Phase 6E supported Cortex runtime analysis

Дата: 2026-07-22.

## Граница вывода

Это техническая runtime-проверка. AI использовался только как источник наблюдаемых transitions. Его build не подтверждает полезность lesson, правильность opening или thresholds.

## SimpleAI

- 69 полных samples, `gameTime=0..335.267`;
- context status: `unknown=2`, `supported=62`, `unsupported=5`;
- next milestone: `unknown=7`, `base_income=12`, `bot_lab=50`;
- API false rows: 0;
- unknown unit rows: 0;
- first complete `base_income`: sample 15, `gameTime=64.167`;
- `corlab=0`, `corck=0`, combat bots = 0 во всех samples.

## BARb stable

- 65 полных samples, `gameTime=0..315.100`;
- context status: `unknown=2`, `supported=58`, `unsupported=5`;
- team: `0=60`, `1=5`;
- next milestone: `unknown=7`, `base_income=13`, `bot_lab=45`;
- recovery: `inactive=63`, `candidate=2`;
- API false rows: 0;
- unknown unit rows: 0;
- first complete `base_income`: sample 16, `gameTime=69.400`;
- `factoryActive=false` и `factoryIdle=unknown` во всех 65 samples;
- `corlab=0`, `corck=0`, combat bots = 0 во всех samples.

Сообщения BARb об unknown UnitDef и missing script callbacks появились при инициализации самого AI. BARb затем сообщил об успешной инициализации, матч продолжился. Собственных errors BAR Learning Coach не найдено.

## Подтверждено

- `unknown -> supported` для exact `corcom` context;
- finished counts читаются из собственных units без потери API-уверенности;
- чужая Armada team не интерпретируется как Cortex;
- tracker восстанавливает supported context после spectator-переключения;
- `base_income` переходит в `complete`, а next milestone — в `bot_lab`;
- Recoil tests: `81 successes / 0 failures`.

## Не подтверждено

- factory active/idle lifecycle для `corlab`;
- counts `corck` и combat bots в supported runtime;
- `bot_lab -> production_cycle` transition;
- expansion zone и `first_expansion`;
- usefulness будущей opening-card.

Повторять AI-сценарий только ради количества не нужно. Следующий runtime-шаг должен целенаправленно дать `corlab` и production transitions через ручной opening или подходящий replay.

## Артефакты

- `phase6e_supported_cortex_2026-07-22_infolog.txt`;
- `phase6e_supported_cortex_2026-07-22.csv`;
- `phase6e_supported_cortex_barb_2026-07-22_infolog.txt`;
- `phase6e_supported_cortex_barb_2026-07-22.csv`.

Неполные хвостовые detail-строки не включались в анализ; источником для counts были только полные `[BAR Learning Coach Opening]` строки.
