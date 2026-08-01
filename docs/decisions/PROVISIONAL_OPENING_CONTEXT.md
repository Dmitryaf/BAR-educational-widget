# Provisional opening context

Дата решения: 2026-07-23. Статус: принято как ограничение первого lesson; usefulness ещё не подтверждена.

## Вопрос

Можно ли считать Cortex Bot Lab универсальной основой beginner opening по replay сильных 1v1-игроков?

## Решение

Нет. Bot Lab сохраняется только как контролируемая ветка `cortex_bot_ravaged_1v1_practice`. Продукт не называет её универсальным или оптимальным opening для других карт, матчей и игроков.

Решение не обещает поддержку других карт, factions или openings.

## Evidence

В четырёх сопоставимых Cortex 1v1 replay повторились три pre-factory mex, собственная энергия, одна T1 factory, ранний constructor и combat production. При этом factory family менялась между картами: три replay использовали vehicle plant, один — Bot Lab. Поэтому устойчивой оказалась общая структура начала, но не конкретный тип factory.

## Последствия

- context guard должен проверять точные карту, faction и factory;
- replay evidence задаёт наблюдаемые ориентиры, а не обязательный build order;
- thresholds и beginner margin остаются гипотезами до Phase 8 usefulness validation;
- новый context или смена factory требуют отдельного evidence review.

## Условие пересмотра

Решение пересматривается, если Phase 8 опровергнет usefulness текущего lesson либо новое сопоставимое evidence потребует изменить карту, faction, factory или opening structure.

Подробный selection manifest, per-player analyses и raw logs сохранены локально как provenance и не являются публичным контрактом.
