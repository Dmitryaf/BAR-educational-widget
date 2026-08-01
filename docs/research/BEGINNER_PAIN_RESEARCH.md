# Исследование боли новичков

Обновлено: 2026-08-01.

## Вопрос исследования

Нужен ли новичку набор реактивных экономических подсказок или более практический scaffold первых минут?

## Ограничения метода

Использованы официальные BAR guides, актуальная страница карты, публичные Reddit-обсуждения 2025–2026 годов, локальный `mapinfo.lua` установленной карты и официальный BAR source. Отдельный Discord-опрос не проводился по решению пользователя.

Это качественные сигналы. Они подтверждают существование боли, но не её частоту среди всех игроков.

## Подтверждённая боль

Новички описывают не только отдельный дефицит ресурса. Главный практический разрыв — как одновременно получить рабочую экономику, factory, units и expansion и не отстать уже в первые минуты.

Официальный starter guide задаёт четыре первых результата: metal, energy, production и intel. Он также пишет, что обычно сначала строят два mex. Публичные вопросы прямо просят opening/build order и объяснение масштабирования, потому что игра не связывает отдельные механики в выполняемую последовательность.

Свежие community-советы повторяют практический способ обучения: пройти scenarios, скопировать первые минуты сильного игрока на конкретной карте, затем повторять и понимать, где не хватает energy, expansion или production. Это поддерживает scaffold, но не доказывает один универсальный build.

## Почему не универсальный build

Официальная страница openings разделяет как минимум:

- solar opening для большой карты со слабым wind и низким ранним давлением;
- general bot opening для небольших карт и 1v1;
- air opening, привязанный к конкретной карте.

Community-обсуждения также спорят о factory и составе в зависимости от карты, faction и matchup. Поэтому продукт начинает с одного context, а не с обещания «правильного старта BAR».

## Рабочий первый context

`cortex_bot_ravaged_1v1_practice`:

- Ravaged Remake — официальная 10×10 duel 1v1/2v2 карта;
- официальный openings guide считает bot opening подходящим для небольших карт и 1v1;
- локальный `Ravaged Remake v1.2/mapinfo.lua` подтверждает `minWind = 5`, `maxWind = 15`;
- официальная web-страница карты указывает average wind 11.5;
- актуальный Cortex Bot Lab строит constructor `corck` и ранние combat bots;
- публичные обсуждения 1v1 подтверждают практичность Cortex bots, но одновременно показывают зависимость matchup и баланса, поэтому lesson не диктует единственный армейский состав.

Режим — локальная 1v1 skirmish/practice. Сила AI и исход боя не входят в критерии lesson; наблюдается только собственный opening.

Эти сигналы обосновали context-specific исследование, но не доказали, что `corlab` — лучшая основа первого beginner lesson. До фиксации provisional lesson требовалась непредвзятая выборка сопоставимых replay сильных duel-игроков с решением `keep`, `revise` или `replace`.

Первый восьмиминутный Phase 6F replay усилил это ограничение: factual Cortex player открылся через `corvp`, а не `corlab`. Это прямой replay-сигнал против универсализации Bot Lab, но один матч ещё не определяет новый baseline и не доказывает, что vehicle opening лучше для новичка.

После трёх replay первая factory во всех случаях была vehicle plant. Четвёртый сопоставимый replay на другой карте дал Bot Lab и тем самым опроверг factory family как cross-map invariant. Во всех 4/4 повторились три pre-factory mex, собственная энергия, одна T1 factory, ранний constructor и combat production. [Decision checkpoint](../decisions/PROVISIONAL_OPENING_CONTEXT.md) завершился `revise`: Bot Lab сохранён только как контролируемая ветка Ravaged practice lesson, а не replay-derived универсальный baseline. Beginner margin и педагогическая полезность остаются неподтверждёнными до usefulness validation.

## Почему guide/replay недостаточно

Guide объясняет общую структуру, но не сообщает во время собственного матча, какой результат уже достигнут. Replay показывает конкретный пример, но требует переключения внимания и не объясняет остановку текущей экономики. Live scaffold полезен только если он остаётся коротким, показывает один ближайший результат и умеет честно молчать при `unknown`.

## Альтернативы и риск лишнего продукта

Официальные guides, короткие видео, scenarios, AI practice и replay уже обучают opening. Поэтому существование боли само по себе не доказывает необходимость отдельного виджета.

Ключевая проверка — сравнение с короткой статической шпаргалкой с теми же milestones. Если live-card не улучшает выполнение или последующее повторение без помощи, программная часть не оправдана, даже если opening-content полезен.

Отдельный риск — ручная установка custom widget. Она может отсечь именно начинающих игроков. До community-ready нужно проверить установку на целевом пользователе; до этого аудитория ограничена мотивированными новичками, согласными настроить LuaUI.

## Что сохраняем из прежней разработки

`ENERGY_STALL` подтверждён runtime и остаётся recovery: он объясняет, почему factory и строительство замедлились. Build-power observability остаётся debug evidence. Эти механизмы не являются отдельной учебной программой и не оправдывают новые карточки сами по себе.

## Риски первого lesson

1. Порог combat group может оказаться слишком маленьким или слишком большим.
2. Expansion нельзя определять только общим числом mex; нужна подтверждённая стартовая зона.
3. Текущий wind колеблется, поэтому solar должен оставаться допустимой альтернативой.
4. Уничтожение unit может откатить фактическую готовность, но не обязательно отменяет усвоенный milestone.
5. Реальный бой может сделать рекомендуемый следующий шаг неуместным; при неподдерживаемом контексте виджет должен молчать.

## Источники

Официальные:

- [To get started](https://www.beyondallreason.info/guide/how-to-start-manage-your-economy)
- [Possible Game openings](https://www.beyondallreason.info/guide/possible-game-openings)
- [In Depth Look at Economy](https://www.beyondallreason.info/guide/in-depth-look-at-economy)
- [Ravaged map](https://www.beyondallreason.info/map/ravaged)
- [BAR source](https://github.com/beyond-all-reason/Beyond-All-Reason)

Публичные community-сигналы:

- [Need New Player Advice: opening builds and scaling](https://www.reddit.com/r/beyondallreason/comments/1ng7my3/need_new_player_advice_give_us_your_best_opening/)
- [Best way to quickly learn the game?](https://www.reddit.com/r/beyondallreason/comments/1uh1133/best_way_to_quickly_learn_the_game/)
- [How much of a disadvantage is Core Bot Factory not having dedicated scouts?](https://www.reddit.com/r/beyondallreason/comments/1tug0cm/how_much_of_a_disadvantage_is_core_bot_factory/)
- [What do you open with?](https://www.reddit.com/r/beyondallreason/comments/1suwzar/what_do_you_open_with/)
- [How We Can Make Our Game Better for Newbies?](https://www.reddit.com/r/beyondallreason/comments/1bkudj5/how_we_can_make_our_game_better_for_newbies/)
- [A basic guide to modding Beyond All Reason](https://www.reddit.com/r/beyondallreason/comments/1m0je6x/a_basic_guide_to_modding_beyond_all_reason/)
