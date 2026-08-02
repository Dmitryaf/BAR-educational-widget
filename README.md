# BAR Replay Coach

BAR Replay Coach — экспериментальный LuaUI-инструмент, который помогает разбирать собственные матчи Beyond All Reason, находить одну главную проблему и выбирать одну задачу для следующей тренировки.

Основной режим работает только при воспроизведении replay внутри BAR. Первый MVP ограничен `Ravaged Remake v1.2`, Cortex, Cortex Bot Lab и одним явно выбранным team. Он распознаёт только продолжительный energy stall, продолжительный простой первой Bot Lab и позднее первое расширение. Это не универсальный стратегический советчик, не оценка игрока и не доказанная замена стандартной replay-статистике.

## Установка и запуск

Запустите PowerShell-скрипт по [инструкции установки](docs/INSTALLATION.md), укажите `targetTeamID` в локальном replay-config и включите **BAR Replay Coach** через Widget Selector (`F11`). Виджет выключен по умолчанию и не запускает анализ вне replay.

## Opening practice

Существующий **BAR Learning Coach** сохранён как отдельный экспериментальный practice-режим для одного opening. Он по-прежнему выключен по умолчанию, не расширяется этой версией и не является основным направлением проекта. Короткий comparator находится в [opening-шпаргалке](docs/OPENING_GUIDE.md).

## Документация

- [Продуктовая модель](docs/PRODUCT.md)
- [Архитектура](docs/ARCHITECTURE.md)
- [Установка, настройка и удаление](docs/INSTALLATION.md)
- [Opening-шпаргалка](docs/OPENING_GUIDE.md)

Участие в проекте описано в [CONTRIBUTING.md](CONTRIBUTING.md), сообщения об уязвимостях — в [security policy](.github/SECURITY.md).

## Лицензия и принадлежность

Код и документация распространяются по [GNU General Public License v2.0 or later](LICENSE). Beyond All Reason и Recoil Engine принадлежат соответствующим правообладателям; проект не является официальным компонентом Beyond All Reason.
