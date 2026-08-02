# Установка BAR Learning Coach

Инструкция устанавливает только production widget и его зависимости. Виджет предназначен для custom/user widgets и по умолчанию выключен.

## Поддерживаемый lesson

Первый lesson рассчитан на `Ravaged Remake v1.2` за Cortex с Cortex Bot Lab. Для воспроизводимой практики рекомендуется локальная 1v1. Runtime guard проверяет карту и Cortex commander, но не подтверждает режим матча или выбранную фабрику заранее.

## Требования

- Windows PowerShell 5.1 или PowerShell 7+ для install/uninstall scripts.
- Node.js с npm и Lua 5.1, доступный как команда `lua`, для локальной проверки репозитория.

Откройте BAR launcher и выберите **Open install directory**. Это BAR data directory, который нужно передать в `-BarDataDir`. Следующие команды выполняются из корня clone репозитория.

## Установка или обновление

Запустите:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File ".\scripts\install.ps1" `
  -BarDataDir "C:\path\to\Beyond-All-Reason"
```

Скрипт проверяет исходные production-файлы до изменения BAR data directory, создаёт необходимые каталоги, удаляет старый `bar_learning_coach_debug.lua` и копирует актуальный entrypoint с production helpers. Повторный запуск этой же команды обновляет установленную версию.

Build-power, replay/research modules и tests не устанавливаются. Единый список файлов, которыми управляют install/uninstall scripts, хранится в `scripts/production-files.psd1`.

## Проверка репозитория

Основная локальная команда:

```powershell
npm run check
```

Она запускает существующий standalone suite через `lua tests/run.lua`. На Windows, если политика выполнения блокирует `npm.ps1`, используйте эквивалентную команду `npm.cmd run check`.

## Включение и проверка в BAR

1. Запустите локальную practice с разрешёнными user widgets.
2. Откройте Widget Selector клавишей `F11`.
3. Найдите **BAR Learning Coach** и включите его.
4. Если установка выполнялась при запущенном BAR, перезагрузите LuaUI или матч.

В поддерживаемом контексте должна появиться одна milestone-card. При подтверждённом energy stall она временно сменяется recovery-card; после завершения lesson показывается итог. На другой карте или faction показывается нейтральный unsupported status. Проверяйте `infolog.txt` на первое сообщение `[BAR Learning Coach]` и ошибки `VFS.Include`.

Эта проверка подтверждает загрузку, но не пользовательскую полезность.

## Удаление

Отключите widget и запустите:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File ".\scripts\uninstall.ps1" `
  -BarDataDir "C:\path\to\Beyond-All-Reason"
```

Скрипт удаляет только управляемые файлы BAR Learning Coach и старый debug-entrypoint. Общий `LuaUI/Include`, другие custom widgets и неизвестные файлы в project helper directory остаются на месте. Повторное удаление безопасно и сообщает об уже отсутствующих файлах.

## Ручной fallback

Если запуск PowerShell-скрипта невозможен, повторите его минимальные действия вручную: скопируйте `LuaUI/Widgets/bar_learning_coach.lua` в BAR `LuaUI/Widgets`, затем скопируйте helpers из списка `scripts/production-files.psd1` в BAR `LuaUI/Include/bar_learning_coach`. Удалите старый `bar_learning_coach_debug.lua`, чтобы BAR не загрузил две копии.

## Troubleshooting

- Неверный `-BarDataDir`: передайте существующий каталог, открытый BAR launcher, а не каталог clone репозитория.
- Widget отсутствует: проверьте разрешение user widgets, прямое размещение entrypoint в `LuaUI/Widgets` и отсутствие лишней вложенности `LuaUI/LuaUI`.
- Missing include: повторно запустите install-скрипт и проверьте, что он завершился без ошибки.
- Загружаются две копии: повторно запустите install-скрипт; он удаляет старый `bar_learning_coach_debug.lua`.
- Подсказка временно недоступна: widget не смог подтвердить необходимые данные и намеренно не выдаёт gameplay-совет.
- Lesson неподдерживаемый: сверьте карту и Cortex faction; режим local 1v1 и Bot Lab — рекомендуемый сценарий, а не отдельный preflight check.
