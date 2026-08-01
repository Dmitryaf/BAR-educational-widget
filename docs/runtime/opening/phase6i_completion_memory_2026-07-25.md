# Phase 6I completion memory runtime — 2026-07-25

## Scope

Проверена только память завершённых opening milestones в уже сохранённом exact-context replay. Это technical validation, а не usefulness test и не evidence оптимальности opening.

## Inputs

- saved replay: `Ravaged Remake v1.2`, записан 2026-07-23;
- engine: `recoil_2026.06.12`;
- target team: 0, factual commander `corcom`;
- collector interval: approximately 5 game seconds;
- full runtime log: `phase6i_completion_memory_2026-07-25_infolog.txt`;
- full runtime log SHA-256: `F747A223697256F269B7B08AE500FFDAAA636854468990805E526570D92D3A9A`;
- final spec log: `phase6i_completion_memory_specs_2026-07-25_infolog.txt`;
- final spec log SHA-256: `74FCB121EF69D4CB6AB13FF62E881A20545B063AB04CD5F3BA9D207FB8DE3026`.

## Results

- final Recoil suite: `104 successes / 0 failures`;
- full replay: 101 opening rows, 97 supported rows, last `gameTime=485.900`;
- lesson first reached `complete` around `gameTime=214.633`;
- later current state regressed to `corck=0`, then `expansionMex=0` and `combatBots=1`;
- all remembered milestones remained `complete`, `lesson=complete`, `next=unknown`, `presentation=none`;
- no own runtime error, failed spec or missing helper was found in the trusted full run;
- temporary test/telemetry widgets and installed specs were removed after verification;
- installed production modules were checked against project source hashes.

Предварительные setup attempts и несовместимый test helper были исключены из evidence. После исправления полный runtime повторён, а финальный расширенный suite прошёл отдельно.

## Remaining unknowns

- whether a beginner understands and benefits from the future opening-card;
- whether live guidance is more useful than the same milestones in a static cheat sheet;
- whether destruction after lesson completion needs a separate post-opening recovery product later.
