# Replay research policy

Обновлено: 2026-07-23.

## Назначение

Replay используются для ответа на конкретный продуктовый вопрос, а не для накопления коллекции игр одного заранее выбранного игрока.

Два сильных duel-игрока были валидной выборкой Phase 6F: их setup skill около 64 зафиксирован рядом с датой replay, матчи относятся к июню–июлю 2026 года и позволили проверить cross-map factory hypothesis. Они не становятся постоянными эталонными игроками проекта.

## Новый поиск

Перед новой replay-задачей:

1. Сформулировать decision question и возможные решения `keep/revise/replace`.
2. Через public BAR replay API получить свежих кандидатов без обязательного фильтра по прежним игрокам.
3. Проверить detail каждого кандидата: normal end, no bots, mode, duration, date, game version, player и result.
4. Подтвердить уровень игрока duel skill рядом с датой replay, актуальным leaderboard/tournament result либо несколькими независимыми сигналами.
5. Выбрать минимальную сопоставимую группу, способную ответить на вопрос.
6. Зафиксировать manifest до просмотра build sequence.

При выборе важнее не имя игрока, а пригодность evidence:

```text
decision question
→ свежая и сопоставимая version/context group
→ подтверждённый уровень игрока
→ factual runtime sequence
→ ограниченное product decision
```

## Актуальность

Replay не считается актуальным только потому, что он недавно сыгран. Нужно учитывать:

- изменение engine/game/balance version;
- карту и её версию;
- faction и factory;
- duel/team mode и роль;
- доступность нескольких сопоставимых матчей;
- близость player evidence к дате replay.

Более старый replay допустим для механики, которая не менялась, либо для сравнения внутри exact version group. Он не смешивается с новой версией в один timing range.

## Stop rule

Исследование останавливается, когда минимальная выборка уже различает рассматриваемые решения. Оставшиеся replay не запускаются ради полноты.

Новый игрок или новая выборка нужны, если:

- изменился balance/game version, способный повлиять на вывод;
- прежняя выборка не содержит нужную faction/map/factory;
- результат держится на одном игроке и требуется cross-player check;
- manual/usefulness validation обнаружила конкретную content-проблему;
- прежний decision question изменился.

Новая выборка не нужна, если она только повторит уже принятое ограниченное решение и не изменит следующий этап.

## API boundary

`tools/query_bar_replays.ps1` используется только для read-only screening и detail. Search filters перепроверяются локально из-за server pagination и нестрогой совместной фильтрации.

API faction и setup side не заменяют factual runtime commander. Opponent hidden data не используется для recommendation logic.
