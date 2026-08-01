# Phase 6H saved-replay runtime — 2026-07-23

## Scope

Проверена только техническая наблюдаемость `first_expansion` в `cortex_bot_ravaged_1v1_practice`. Это не usefulness test и не доказательство оптимальности radius.

## Inputs

- saved replay: `Ravaged Remake v1.2`, записан 2026-07-23;
- engine: `recoil_2026.06.12`;
- target team: 0, factual commander `corcom`;
- map: `Ravaged Remake v1.2`;
- collector interval: approximately 5 game seconds;
- raw log: `phase6h_expansion_replay_2026-07-23_infolog.txt`;
- raw log SHA-256: `02936815722A1729FE194E4ED57B35164B99D95AFD5D528EFC0A55914C60C1C5`.

## Results

- trusted Recoil harness: `93 successes / 0 failures`;
- 95 complete opening rows, sequential samples `1..95`;
- 96 resource telemetry rows;
- max opening `gameTime=457.267`, therefore the five-minute requirement is satisfied;
- 91 supported rows; every one has `apiStartPosition=true`, `startPositionKnown=true` and `unknownUnits=0`;
- factual start position stayed `(1152, 3840)`;
- first four finished mex remained inside radius `900`;
- fifth mex at `(1824, 4560)`, distance `984.878`, was classified outside;
- `expansionMex=1` first appeared at sample 41, `gameTime=184.867`; all five milestones were complete in that sample;
- recovery later passed `candidate -> active -> resolving -> resolved -> cooldown` and temporarily replaced milestone presentation;
- no own runtime error was found.

Предыдущий запуск с неполным test set и отдельная ускоренная попытка исключены из evidence. Перед доверенным прогоном helper был восстановлен hash-identically, а replay воспроизводился на скорости 1x.

## Additional observation

After units and mex were destroyed later in replay, `expansionMex` correctly followed current state back to `0`, while `first_expansion` and other milestones also regressed. This matches the present stateless/current-state contract, but runtime cannot decide whether a teaching milestone should remember a past achievement. Treat this as a separate product-semantics decision before the opening card, not as a hidden Phase 6H fix.

## Remaining unknowns

- whether radius `900` separates the intended cluster for the other Ravaged start position;
- whether a boundary this close to the fifth mex is robust to alternate placement;
- whether milestone rollback helps or distracts a beginner;
- whether the live card is more useful than the same opening as a static checklist.
