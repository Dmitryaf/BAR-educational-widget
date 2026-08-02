# BAR Learning Coach

BAR Learning Coach — экспериментальный LuaUI-виджет для практики первых минут Beyond All Reason. В поддерживаемом учебном сценарии он показывает один ближайший результат opening, а при подтверждённой нехватке энергии временно заменяет его recovery-подсказкой.

Сейчас реализован минимальный live-flow для `Ravaged Remake v1.2` за Cortex. Это проверяемая продуктовая гипотеза, а не универсальный build order и не доказанная помощь новичкам. Виджет не отдаёт команды юнитам и не использует скрытую информацию.

## Установка

Запустите PowerShell-скрипт по [инструкции установки](docs/INSTALLATION.md), затем включите **BAR Learning Coach** через Widget Selector (`F11`). Тот же скрипт повторно запускается для обновления; виджет по умолчанию выключен.

## Документация

- [Продуктовая модель](docs/PRODUCT.md)
- [Архитектура](docs/ARCHITECTURE.md)
- [Установка и удаление](docs/INSTALLATION.md)
- [Статическая opening-шпаргалка](docs/OPENING_GUIDE.md)

Участие в проекте описано в [CONTRIBUTING.md](CONTRIBUTING.md), сообщения об уязвимостях — в [security policy](.github/SECURITY.md).

## Лицензия и принадлежность

Код и документация распространяются по [GNU General Public License v2.0 or later](LICENSE). Beyond All Reason и Recoil Engine принадлежат соответствующим правообладателям; проект не является официальным компонентом Beyond All Reason.
