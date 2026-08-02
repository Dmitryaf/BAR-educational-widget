# Установка BAR Replay Coach

Install-скрипт устанавливает два выключенных по умолчанию production widgets:

- **BAR Replay Coach** — основной replay-analysis режим;
- **BAR Learning Coach** — отдельный экспериментальный opening practice.

## Требования

- Windows PowerShell 5.1 или PowerShell 7+ для install/uninstall scripts.
- Node.js с npm и Lua 5.1, доступный как команда `lua`, для локальной проверки репозитория.
- Replay в узком context: `Ravaged Remake v1.2`, Cortex, Cortex Bot Lab.

Откройте BAR launcher и выберите **Open install directory**. Это BAR data directory, который нужно передать в `-BarDataDir`. Следующие команды выполняются из корня clone репозитория.

## Установка или обновление

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File ".\scripts\install.ps1" `
  -BarDataDir "C:\path\to\Beyond-All-Reason"
```

Повторный запуск обновляет оба entrypoints и production helpers. Tests, build-power modules и replay research harnesses не устанавливаются. Единый allowlist хранится в `scripts/production-files.psd1`.

## Выбор team для replay

Создайте в BAR data directory файл `LuaUI/Config/bar_replay_coach.lua`:

```lua
return {
    targetTeamID = 0,
}
```

Замените `0` на engine team ID анализируемого игрока. Если config отсутствует или team неверен, панель показывает доступные пары `teamID=player`. После изменения config перезагрузите LuaUI или replay. Выбор сохраняется внутри одной analysis session; смена team начинает новую session без старых episodes.

## Запуск Replay Coach

1. Откройте replay в BAR.
2. Через Widget Selector (`F11`) включите **BAR Replay Coach**.
3. Проверьте в панели выбранный team и статус `supported`/`analyzing`.
4. Досмотрите replay до конца или выполните `/luaui replaycoach report`.
5. Используйте `/luaui replaycoach hide` и `/luaui replaycoach show`, чтобы скрыть или вернуть панель без остановки analysis session.

Report остаётся в панели, кратко дублируется в `infolog.txt` и сохраняется через стандартный widget config mechanism. В обычном матче Replay Coach показывает нейтральный `unsupported_mode` и не собирает анализ.

## Opening practice

Для прежнего experiment включите **BAR Learning Coach**. Он работает только со своей live opening/recovery-card и не участвует в replay report. Подробности текущего lesson находятся в [opening-шпаргалке](OPENING_GUIDE.md).

## Проверка репозитория

```powershell
npm run check
```

Команда запускает standalone suite через `lua tests/run.lua`. Если Windows execution policy блокирует `npm.ps1`, используйте `npm.cmd run check`.

## Удаление

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File ".\scripts\uninstall.ps1" `
  -BarDataDir "C:\path\to\Beyond-All-Reason"
```

Скрипт удаляет только управляемые entrypoints/helpers и старый debug-entrypoint. Общий `LuaUI/Include`, другие custom widgets, неизвестные файлы и пользовательский `LuaUI/Config/bar_replay_coach.lua` сохраняются. Повторное удаление безопасно.

## Ручной fallback

Если скрипт запустить невозможно, скопируйте entrypoints и helpers из `scripts/production-files.psd1` в соответствующие BAR `LuaUI/Widgets` и `LuaUI/Include/bar_learning_coach`. Production manifest является единственным списком файлов; research/build-power modules вручную не копируйте.

## Troubleshooting

- `unsupported_mode`: открыт обычный матч, а не replay.
- `team_not_selected`: создайте config и выберите team из списка панели.
- `team_unavailable`: указан отсутствующий team или Gaia.
- `unsupported`: карта или faction не входят в первый context.
- `temporarily_unavailable`: нужные API-данные неизвестны; Coach намеренно не превращает это в проблему игрока.
- Report не появился автоматически: выполните `/luaui replaycoach report` до закрытия replay.
