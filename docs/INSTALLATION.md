# Установка BAR Learning Coach

Это руководство устанавливает только production widget и необходимые helper-модули. Оно не устанавливает BAR, не меняет игровые настройки автоматически и не подтверждает community-ready distribution.

## Требования и подтверждённая граница

- установленный Beyond All Reason с разрешёнными user/custom widgets для локальной practice;
- актуальная структура `LuaUI/Widgets` и `LuaUI/Include`, используемая BAR после переноса helper-файлов из старого `LuaUI/Widgets/Include`;
- последний доверенный opening runtime проекта: Recoil и game version `2026.06.12`;
- первый lesson ограничен `Ravaged Remake v1.2`, Cortex, Bot Lab и локальной 1v1 practice.

Подтверждённая версия — это версия последней технической проверки, а не заявленный минимальный системный requirement. Пользовательская opening-card ещё не реализована: текущий widget показывает recovery-рекомендацию при подтверждённом energy stall и содержит debug-интерфейс.

## Найти data directory

Открой BAR launcher и используй кнопку **Open install directory**. Используй открытый launcher каталог как фактический BAR data directory; не копируй пример пути другого пользователя и не считай конкретный Windows/macOS/Linux путь универсальным.

Дальше в примерах:

```powershell
$BarDataDir = 'PATH_OPENED_BY_BAR_LAUNCHER'
```

Перед копированием проверь, что переменная указывает именно на каталог данных BAR. Команды ниже выполняются из корня чистого clone этого репозитория.

## Установка

Создай целевые каталоги:

```powershell
New-Item -ItemType Directory -Force -Path (Join-Path $BarDataDir 'LuaUI/Widgets')
New-Item -ItemType Directory -Force -Path (Join-Path $BarDataDir 'LuaUI/Include/bar_learning_coach')
```

Скопируй production entrypoint:

```powershell
Copy-Item -LiteralPath 'LuaUI/Widgets/bar_learning_coach_debug.lua' -Destination (Join-Path $BarDataDir 'LuaUI/Widgets/bar_learning_coach_debug.lua') -Force
```

Скопируй только helper-модули, которые entrypoint загружает через `VFS.Include`:

```powershell
$HelperFiles = @(
  'build_power_adapter.lua',
  'build_power_snapshot.lua',
  'energy_stall.lua',
  'energy_stall_recommendation.lua',
  'history_buffer.lua',
  'opening_adapter.lua',
  'opening_context.lua',
  'opening_progress.lua',
  'opening_tracker.lua',
  'snapshot_collector.lua'
)

foreach ($FileName in $HelperFiles) {
  Copy-Item -LiteralPath (Join-Path 'LuaUI/Include/bar_learning_coach' $FileName) -Destination (Join-Path $BarDataDir 'LuaUI/Include/bar_learning_coach') -Force
}
```

Не копируй `tests/`, `tools/`, `docs/`, `tasks/`, runtime evidence или `replay_opening_collector.lua`. Для production widget они не нужны. Отдельный project-specific файл в `LuaUI/Config` также не требуется.

Итоговая структура:

```text
LuaUI/
├── Widgets/
│   └── bar_learning_coach_debug.lua
└── Include/
    └── bar_learning_coach/
        ├── build_power_adapter.lua
        ├── build_power_snapshot.lua
        ├── energy_stall.lua
        ├── energy_stall_recommendation.lua
        ├── history_buffer.lua
        ├── opening_adapter.lua
        ├── opening_context.lua
        ├── opening_progress.lua
        ├── opening_tracker.lua
        └── snapshot_collector.lua
```

## Включение

1. Запусти локальную practice, в которой user widgets разрешены.
2. Открой встроенный **Widget Selector** клавишей `F11` и при необходимости разреши user widgets его штатной кнопкой.
3. Найди **BAR Learning Coach** и включи его: в metadata проекта `enabled=false`, поэтому первая установка не включает widget автоматически.
4. Если BAR уже был запущен во время копирования, перезагрузи LuaUI штатной командой Widget Selector либо перезапусти матч.

## Проверка

- **BAR Learning Coach** присутствует и включён в Widget Selector;
- `infolog.txt` не содержит собственных ошибок `[BAR Learning Coach Debug]` или ошибок `VFS.Include` для `LuaUI/Include/bar_learning_coach/`;
- в подтверждённом supported context widget собирает собственное opening/economy state;
- при подтверждённом energy stall может появиться recovery-card;
- в здоровом или неподдерживаемом context постоянная карточка может отсутствовать: отдельная opening-card ещё не реализована, а неизвестные данные не должны давать уверенный совет;
- установка не использует ignored research, tasks, archive или runtime evidence.

Эта проверка подтверждает структуру и отсутствие видимых ошибок загрузки. Она не доказывает usefulness и не заменяет отдельный BAR runtime validation.

## Обновление

Повтори команды копирования для entrypoint и десяти helper-модулей, заменив старые версии. Предварительное удаление не требуется. После замены перезагрузи LuaUI или перезапусти матч.

У проекта нет обязательного собственного config-файла. BAR может хранить состояние включения и `GetConfigData` в общем widget config; обновление production-файлов не требует удалять этот общий файл.

## Удаление

Сначала отключи **BAR Learning Coach** в Widget Selector. Затем, только после повторной проверки `$BarDataDir`, удали проектные файлы:

```powershell
Remove-Item -LiteralPath (Join-Path $BarDataDir 'LuaUI/Widgets/bar_learning_coach_debug.lua')
Remove-Item -LiteralPath (Join-Path $BarDataDir 'LuaUI/Include/bar_learning_coach') -Recurse
```

Не удаляй общий каталог `LuaUI/Include`, общий BAR widget config или другие custom widgets. Отдельного project-specific config-файла нет; оставшаяся запись состояния в общем BAR config не загружает отсутствующий widget.

После удаления перезагрузи LuaUI или перезапусти матч и проверь, что **BAR Learning Coach** исчез из списка локальных widgets.

## Troubleshooting

- **Widget отсутствует в списке:** проверь, что файл лежит непосредственно в `LuaUI/Widgets`, user widgets разрешены и нет второй ошибочной вложенности `LuaUI/LuaUI`.
- **`VFS.Include` не находит модуль:** helper-файлы должны находиться в `LuaUI/Include/bar_learning_coach`, а не в устаревшем `LuaUI/Widgets/Include`.
- **Widget включён, но ничего не рисует:** постоянная opening-card ещё не реализована; проверь supported context и `infolog.txt`, а не считай отсутствие карточки успешным или ошибочным автоматически.
- **В `infolog.txt` есть ошибка:** ищи первое сообщение `[BAR Learning Coach Debug]` и точный missing include/API status; не копируй test widgets как исправление.
- **Opening неподдерживаемый:** текущий lesson намеренно ограничен одной картой, faction и factory; другой context должен безопасно молчать.
- **Загружаются две копии:** найди и удали только лишнюю копию `bar_learning_coach_debug.lua`, затем перезагрузи LuaUI.
