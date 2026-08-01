# Установка BAR Learning Coach

Инструкция устанавливает только production widget и его зависимости. Виджет предназначен для custom/user widgets и по умолчанию выключен.

## Поддерживаемый lesson

Первый lesson рассчитан на `Ravaged Remake v1.2` за Cortex с Cortex Bot Lab. Для воспроизводимой практики рекомендуется локальная 1v1. Runtime guard проверяет карту и Cortex commander, но не подтверждает режим матча или выбранную фабрику заранее.

## Найти data directory

Откройте BAR launcher и выберите **Open install directory**. В PowerShell задайте открытый каталог и убедитесь, что это именно BAR data directory:

```powershell
$BarDataDir = 'PATH_OPENED_BY_BAR_LAUNCHER'
```

Следующие команды выполняются из корня clone этого репозитория.

## Установка или обновление

Создайте каталоги:

```powershell
New-Item -ItemType Directory -Force -Path (Join-Path $BarDataDir 'LuaUI/Widgets')
New-Item -ItemType Directory -Force -Path (Join-Path $BarDataDir 'LuaUI/Include/bar_learning_coach')
```

Если раньше был установлен debug-entrypoint, сначала удалите только его, чтобы BAR не загрузил две копии:

```powershell
Remove-Item -LiteralPath (Join-Path $BarDataDir 'LuaUI/Widgets/bar_learning_coach_debug.lua') -ErrorAction SilentlyContinue
```

Скопируйте новый entrypoint:

```powershell
Copy-Item -LiteralPath 'LuaUI/Widgets/bar_learning_coach.lua' -Destination (Join-Path $BarDataDir 'LuaUI/Widgets/bar_learning_coach.lua') -Force
```

Скопируйте девять production helpers:

```powershell
$HelperFiles = @(
  'coach_presentation.lua',
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

Не копируйте `tests/`, research/runtime files, replay collector и build-power modules: production widget их не загружает.

## Включение и проверка

1. Запустите локальную practice с разрешёнными user widgets.
2. Откройте Widget Selector клавишей `F11`.
3. Найдите **BAR Learning Coach** и включите его.
4. Если файлы копировались при запущенном BAR, перезагрузите LuaUI или матч.

В поддерживаемом контексте должна появиться одна milestone-card. При подтверждённом energy stall она временно сменяется recovery-card; после завершения lesson показывается итог. На другой карте или faction показывается нейтральный unsupported status. Проверяйте `infolog.txt` на первое сообщение `[BAR Learning Coach]` и ошибки `VFS.Include`.

Эта проверка подтверждает загрузку, но не пользовательскую полезность.

## Удаление

Отключите widget, повторно проверьте `$BarDataDir`, затем удалите только проектные файлы:

```powershell
Remove-Item -LiteralPath (Join-Path $BarDataDir 'LuaUI/Widgets/bar_learning_coach.lua')
Remove-Item -LiteralPath (Join-Path $BarDataDir 'LuaUI/Include/bar_learning_coach') -Recurse
```

Не удаляйте общий `LuaUI/Include`, общий BAR widget config или другие custom widgets.

## Troubleshooting

- Widget отсутствует: проверьте разрешение user widgets, прямое размещение entrypoint в `LuaUI/Widgets` и отсутствие лишней вложенности `LuaUI/LuaUI`.
- Missing include: все девять helpers должны лежать в `LuaUI/Include/bar_learning_coach`.
- Загружаются две копии: удалите старый `bar_learning_coach_debug.lua`, оставив `bar_learning_coach.lua`.
- Подсказка временно недоступна: widget не смог подтвердить необходимые данные и намеренно не выдаёт gameplay-совет.
- Lesson неподдерживаемый: сверьте карту и Cortex faction; режим local 1v1 и Bot Lab — рекомендуемый сценарий, а не отдельный preflight check.
