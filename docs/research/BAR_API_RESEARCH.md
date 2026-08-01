# BAR API Research

Реестр подтверждённого API evidence, накопленного в Phase 0–6. Версии источников зафиксированы по разделам; перед новым или изменившимся вызовом нужно проверить актуальный BAR/Recoil source. Неподтверждённый API не считается доступным.

## 1. Версии и источники

- Репозиторий BAR: `https://github.com/beyond-all-reason/Beyond-All-Reason`
- BAR commit: `210e6f2b48a2403ae08548fdfc0b5a5975ed58d5`
- Recoil LuaLS library: `https://github.com/beyond-all-reason/recoil-lua-library`
- Recoil LuaLS commit: `2d2f34cf142b5af66dce69466f5e5c4ef2575c79`
- Recoil Engine HEAD на момент проверки: `708f0748b78ebc0e3ba45f9b31cceed88c98ac6f`
- Дата исследования: 2026-07-18
- Использованные документы:
  - `https://recoilengine.org/docs/lua-api/`
  - `https://github.com/beyond-all-reason/Beyond-All-Reason/blob/master/README.md`
  - `https://github.com/beyond-all-reason/Beyond-All-Reason/tree/master/luaui/Widgets`

## 2. Загрузка LuaUI-виджета

### Подтверждённый способ

- Каталог BAR-виджетов: `luaui/Widgets/*.lua`.
- Entry point виджета: `function widget:GetInfo() return { name, desc, author, date, license, layer, enabled } end`.
- Основной LuaUI entry point BAR: `luaui/main.lua`; он подключает `luaui/barwidgets.lua`.
- Включение/отключение:
  - через стандартный LuaUI widget handler / F11;
  - через команды `/luaui enablewidget <name>`, `/luaui disablewidget <name>`, `/luaui reload`;
  - пользовательские виджеты Spring обычно кладутся в `LuaUI/Widgets`.
- Для разработки BAR README описывает `.sdd` dev-copy: клонировать BAR в `data/games/BAR.sdd`, включить `devmode.txt`, выбрать `Beyond All Reason Dev`.

### Источники

- `luaui/main.lua:20-30` подключает init/setup/debug/layout/barwidgets.
- `luaui/main.lua:42-72` прокидывает `Update`, `Shutdown`, `DrawScreen` в `widgetHandler`.
- `luaui/barwidgets.lua:103-130` содержит flexible call-ins, включая `GameFrame`, `UnitCreated`, `UnitFinished`, `UnitDestroyed`.
- `luaui/barwidgets.lua:187-200` содержит fixed call-ins, включая `GameStart`, `Shutdown`, `Update`, `DrawScreen`.
- `luaui/barwidgets.lua:1059-1070` добавляет widget в call-in lists и вызывает `widget:Initialize()`.
- `luaui/barwidgets.lua:1085-1091` сохраняет config и вызывает `widget:Shutdown()` при удалении.
- Пример виджета: `luaui/Widgets/gui_ecostats.lua:8-17`.
- README BAR: `README.md:27-43`, `README.md:92-116`.

### Ограничения

- Стандартный путь пользовательских виджетов нужно проверить на установленной BAR-сборке: BAR менял структуру `luaui/Widgets` в 2025 году.
- Текущая production-структура использует один widget entrypoint в `LuaUI/Widgets` и helper modules в `LuaUI/Include/bar_learning_coach`, не меняя BAR core files.

## 3. Ресурсы команды

### Metal

- API: `Spring.GetTeamResources(teamID, "metal")`.
- Сигнатура: `Spring.GetTeamResources(teamID: integer, resource: ResourceName)`.
- Возвращаемые значения по Recoil LuaLS:
  1. `currentLevel`;
  2. `storage`;
  3. `pull`;
  4. `income`;
  5. `expense`;
  6. `share`;
  7. `sent`;
  8. `received`;
  9. `excess`.
- Пример BAR: `luaui/Widgets/snd_notifications.lua:281-283`, `luaui/Widgets/snd_notifications.lua:648-649`.
- LuaUI-доступность: подтверждена использованием в BAR LuaUI widgets.
- Ограничения:
  - BAR-виджеты часто читают только первые 8 значений и игнорируют `excess`;
  - `pull` и `expense` имеют разную семантику: `pull` - запрошенное потребление, `expense` - реально потраченное.

### Energy

- API: `Spring.GetTeamResources(teamID, "energy")`.
- Сигнатура и возвращаемые значения такие же, как для metal.
- Пример BAR: `luaui/Widgets/snd_notifications.lua:281-283`, `luaui/Widgets/unit_dgun_stall_assist.lua:138-140`.
- LuaUI-доступность: подтверждена использованием в BAR LuaUI widgets.
- Ограничение: для `ENERGY_STALL` нужно хранить историю, потому что одиночный snapshot не доказывает устойчивый дефицит.

### Income / expense

- API: `Spring.GetTeamResources`.
- Семантика:
  - `income` - ресурс, генерируемый в секунду;
  - `pull` - запрошенное потребление в секунду;
  - `expense` - фактическое потребление в секунду, может быть меньше `pull` при нехватке ресурса.
- Источник сигнатуры: `recoil-lua-library/library/generated/rts/Lua/LuaSyncedRead.cpp.lua:374-387`.
- Возможный дополнительный API: `Spring.GetTeamResourceStats(teamID, resource)` возвращает accumulated/stat values `used, produced, excessed, received, sent`; это не замена текущему income/expense.
- Источник stats: `recoil-lua-library/library/generated/rts/Lua/LuaSyncedRead.cpp.lua:400-409`.

### Phase 1 runtime observations: energy stall semantics

Ручная проверка технического spike внутри BAR подтвердила, что виджет загружается и возвращает реальные данные BAR.

Получены наблюдения:

| Game time | Energy current / storage | income | expense | pull | Интерпретация |
|---|---:|---:|---:|---:|---|
| 01:42 | 622.5 / 1101.5 | 70.5 | 78.4 | 78.4 | Временный отрицательный баланс при заметном запасе |
| 02:26 | 0.9 / 1101.5 | 70.0 | 70.3 | 163.4 | Настоящий energy stall: хранилище почти пустое, фактический расход ограничен доступным доходом |
| 03:23 | 1.0 / 1152.0 | 92.3 | 91.8 | 117.4 | Продолжающийся stall: `pull` всё ещё выше `income`, но `expense` близок к `income` |
| 05:52 | 1304.0 / 1304.0 | 204.4 | 6.0 | 6.0 | Полный запас и wasting energy, дефицита нет |

Ключевой вывод:

- `income` показывает доступную генерацию энергии;
- `pull` показывает желаемое потребление энергии;
- `expense` показывает фактически удовлетворённое потребление и при stall может быть ограничен доступным `income`;
- HUD BAR во время проверки показывал отрицательное значение, соответствующее `pull - income`, а не `expense - income`.

Следствие для `ENERGY_STALL`: нельзя определять stall только условием `expense > income`. Во время настоящего stall `expense` может быть близок к `income`, потому что игра уже ограничила фактическое потребление. Для диагностики нужен набор условий:

- низкий `current / storage`;
- устойчивое `pull > income`;
- минимальный абсолютный дефицит `pull - income`;
- минимальная длительность состояния.

Не реализовывать прогноз времени до stall на основании этих данных без отдельного этапа: текущие наблюдения подтверждают диагностику состояния, но не точность прогноза.

## 4. Собственные юниты

- API получения текущей команды игрока:
  - Recoil-confirmed: `Spring.GetLocalTeamID() -> integer`.
  - BAR-used alias: `Spring.GetMyTeamID()` используется массово и подтверждён ручным запуском Phase 1. В коде всё равно сохранять fallback на `GetLocalTeamID`.
- API списка: `Spring.GetTeamUnits(teamID) -> number[]?`.
- Фильтрация: использовать `teamID == localTeamID` / `myTeamID`; не читать enemy units.
- Определение типа: `Spring.GetUnitDefID(unitID) -> number?`, затем `UnitDefs[unitDefID]`.
- Примеры BAR:
  - `luaui/Widgets/api_shared_state.lua:17-23`, `luaui/Widgets/api_shared_state.lua:28-35`;
  - `luaui/Widgets/api_resource_spot_builder.lua:483-487`;
  - `luaui/Widgets/unit_clean_builder_queue.lua:82-87`.
- Источники сигнатур:
  - `recoil-lua-library/library/generated/rts/Lua/LuaUnsyncedRead.cpp.lua:776-792`;
  - `recoil-lua-library/library/generated/rts/Lua/LuaSyncedRead.cpp.lua:561-565`;
  - `recoil-lua-library/library/generated/rts/Lua/LuaSyncedRead.cpp.lua:899-903`.

## 5. Unit definitions

Использовать runtime `UnitDefs`, потому что BAR-виджеты работают именно с нормализованными полями `isBuilder`, `isFactory`, `buildOptions`, `extractsMetal`, `windGenerator`, `customParams`.

Подтверждённые категории:

- extractor:
  - runtime: `UnitDefs[id].extractsMetal > 0`;
  - unit file example: `units/ArmBuildings/LandEconomy/armmex.lua:16`, `armmex.lua:33-40`;
  - BAR usage: `luaui/configs/unit_buildmenu_config.lua:38-39`, `luaui/Widgets/api_resource_spot_builder.lua:62-65`.
- wind generator:
  - runtime: `UnitDefs[id].windGenerator > 0`;
  - unit file example: `units/ArmBuildings/LandEconomy/armwin.lua:27`, `armwin.lua:29-40`;
  - BAR usage: `luaui/Widgets/snd_notifications.lua:371-373`.
- solar generator:
  - unit file example: `units/ArmBuildings/LandEconomy/armsolar.lua:14-15`, `armsolar.lua:41-43`;
  - safe runtime signal: `energyMake > 0` / negative `energyUpkeep` in raw defs needs runtime verification; `customParams.solar` exists in raw file.
- energy storage:
  - raw field: `energystorage`;
  - example: `units/ArmBuildings/LandEconomy/armestor.lua:12-14`, `armestor.lua:29-40`.
- metal storage:
  - raw field: `metalstorage`;
  - example: `units/ArmBuildings/LandEconomy/armmstor.lua:21-23`, `armmstor.lua:29-40`.
- factory/lab:
  - runtime: `UnitDefs[id].isFactory`;
  - unit file example: `units/ArmBuildings/LandFactories/armlab.lua:4`, `armlab.lua:31-42`;
  - BAR usage: `luaui/Widgets/cmd_factoryqmanager.lua:145-154`, `luaui/configs/unit_buildmenu_config.lua:34-35`.
- constructor:
  - runtime: `UnitDefs[id].isBuilder`, `buildSpeed > 0`, `buildOptions[1]`, `canAssist`;
  - unit file example: `units/ArmBots/armck.lua:3-4`, `armck.lua:37-69`;
  - BAR usage: `luaui/Widgets/gui_idle_builders.lua:100-108`, `luaui/Widgets/unit_clean_builder_queue.lua:73-87`.
- commander:
  - runtime/raw custom params: `customParams.iscommander`;
  - unit file example: `units/armcom.lua:5-7`, `armcom.lua:21-23`, `armcom.lua:60-69`;
  - BAR usage: `luaui/Widgets/snd_notifications.lua:365-367`, `luaui/Widgets/gui_ecostats.lua:189-197`.
- combat unit:
  - no single perfect flag confirmed;
  - BAR example heuristic: mobile, not builder, has weapons, or `customParams.selectable_as_combat_unit`;
  - source: `luaui/Widgets/unit_smart_select.lua:97-112`;
  - MVP should avoid combat-unit reasoning.

## 6. Заводы и очереди

- Как определить factory:
  - `UnitDefs[unitDefID].isFactory`;
  - example: `luaui/Widgets/cmd_factoryqmanager.lua:145-154`.
- Как получить очередь factory:
  - `Spring.GetFactoryCommands(unitID, count) -> Command[]`;
  - `Spring.GetFactoryCommandCount(unitID) -> integer`;
  - `Spring.GetFactoryCounts(unitID, count?, addCmds?) -> table<number, number>?`;
  - deprecated/legacy: `Spring.GetCommandQueue` is same as `GetUnitCommands`.
- Существующий BAR usage:
  - `luaui/Widgets/cmd_factoryqmanager.lua:286-297` использует `Spring.GetRealBuildQueue(uid)` для selected factory queues. Этот API не найден в Recoil LuaLS, поэтому для проекта он остаётся неподтверждённым и не используется как основа domain-решения.
  - `luaui/Widgets/gui_selectedunits_gl4.lua:548-557` использует `builderID` + `UnitDefs[builderDefID].isFactory` для отметки unit built by factory.
- Источник сигнатур:
  - `recoil-lua-library/library/generated/rts/Lua/LuaSyncedRead.cpp.lua:1532-1585`.
- Как отличить полезную очередь:
  - confirmed: `GetFactoryCommandCount > 0` или непустой `GetFactoryCommands`;
  - unclear: как надежно отличать паузу/ресурсный stall от намеренной остановки без дополнительных state fields.
- Ограничения:
  - idle factory нельзя показывать при ENERGY_STALL;
  - недавно завершённый завод нужно подавлять по `UnitFinished` time;
  - самостоятельная idle-factory рекомендация не входит в текущий продукт; factory activity используется только внутри opening evidence.

## 7. Idle builders

- Как определить builder:
  - `UnitDefs[unitDefID].isBuilder`;
  - лучше ограничить до mobile builders: `isBuilder`, `canMove`, `not isFactory`, `canAssist or canResurrect`.
  - example: `luaui/Widgets/unit_auto_repair_idle_builders.lua:64-65`.
- Доступные события/состояния:
  - BAR widget `snd_notifications.lua` использует `widget:UnitIdle(unitID)` и `widget:UnitCommand(...)`;
  - `snd_notifications.lua:689-696` снимает idle при команде и ставит delayed idle marker при `UnitIdle`.
- Как получить текущие команды:
  - `Spring.GetUnitCurrentCommand(unitID, cmdIndex?)`;
  - `Spring.GetUnitCommands(unitID, count)`;
  - `Spring.GetUnitCommandCount(unitID)`;
  - `Spring.GetUnitWorkerTask(unitID)` для build-related task.
- Источники сигнатур:
  - `recoil-lua-library/library/generated/rts/Lua/LuaSyncedRead.cpp.lua:1144-1162`;
  - `recoil-lua-library/library/generated/rts/Lua/LuaSyncedRead.cpp.lua:1504-1520`;
  - `recoil-lua-library/library/generated/rts/Lua/LuaSyncedRead.cpp.lua:1554-1560`.
- Ограничения:
  - `GetUnitCurrentCommand` не равно фактической работе; Recoil explicitly documents this for builder tasks.
  - Один idle builder не должен считаться проблемой по продуктовым правилам.
  - BAR имеет автоматические idle-builder widgets; нам нельзя копировать автоматические `GiveOrder*` действия.

## 8. Build power

- Прямой показатель суммарного team build power не подтверждён.
- Подтверждённые building blocks:
  - `UnitDefs[unitDefID].buildSpeed` / raw `workertime`;
  - `Spring.GetUnitIsBuilding(unitID) -> buildeeUnitID or nil`;
  - `Spring.GetUnitCurrentBuildPower(unitID)` exists in LuaLS but без documented return annotation in current library; old Recoil changelog mentions `number 0..1`.
  - `Spring.GetUnitWorkerTask(unitID)` may identify actual build/repair/reclaim task.
- Безопасный текущий вывод:
  - точный team-level build power остаётся `unknown`;
  - approximate available/active build speed допустим только по полностью классифицированным собственным builders/factories и только как debug/recovery evidence.
- Риск:
  - assist, guard, distance-to-target and resource stall can make naive command-based build power wrong.

## 9. Параметры карты

- Стартовая позиция собственной команды:
  - `Spring.GetTeamStartPosition(teamID) -> x, y, z, valid`;
  - актуальный Recoil master `rts/Lua/LuaSyncedRead.cpp` возвращает позицию только для allied team;
  - локальный официальный пример `recoil_2026.06.12/examples/Widgets/init_start_marker.lua` вызывает API для `Spring.GetMyTeamID()`;
  - использовать только для exact context и сохранять `nil`, если call неуспешен, координаты не finite или `valid ~= true`.

- Размер карты:
  - `Game.mapSizeX`, `Game.mapSizeZ`;
  - source: `recoil-lua-library/library/generated/rts/Lua/LuaConstGame.cpp.lua:75-83`.
- Wind min/max:
  - `Game.windMin`, `Game.windMax`;
  - source: `recoil-lua-library/library/generated/rts/Lua/LuaConstGame.cpp.lua:88-95`.
- Текущий ветер:
  - `Spring.GetWind() -> windSpeedX, windSpeedY, windSpeedZ, windStrength, windDirX, windDirY, windDirZ`;
  - source: `recoil-lua-library/library/generated/rts/Lua/LuaSyncedRead.cpp.lua:95-104`.
- Tidal:
  - `Game.tidal`;
  - `Spring.GetTidal() -> tidalStrength`;
  - sources: `LuaConstGame.cpp.lua:88-89`, `LuaSyncedRead.cpp.lua:90-93`.
- Metal map / spots:
  - `Spring.GetGroundInfo(x, z)` can expose ground metal; BAR resource spot finder uses third return value as `groundMetal`;
  - source: `common/upgets/api_resource_spot_finder.lua:50-55`, `api_resource_spot_finder.lua:312-316`.
- Ограничение:
  - metal spot safety/pathing is out of MVP; use this only for debug/research, not expansion strategy.

## 10. Игровые события

Подтверждённые call-ins:

- `widget:GameStart()`
  - source: `recoil-lua-library/library/generated/rts/Lua/LuaHandle.cpp.lua:102-107`;
  - BAR handler list: `luaui/barwidgets.lua:187-191`.
- `widget:GameFrame(frame)`
  - signature: frame number, 30 simulation frames per second;
  - source: `LuaHandle.cpp.lua:124-129`;
  - BAR usage: `luaui/Widgets/api_shared_state.lua:71-72`.
- `widget:Update(dt)`
  - BAR fixed call-in; source: `luaui/main.lua:42-45`, `luaui/barwidgets.lua:187-193`.
- `widget:UnitCreated(unitID, unitDefID, unitTeam, builderID?)`
  - source: `LuaHandle.cpp.lua:194-199`;
  - BAR handler: `luaui/barwidgets.lua:2475-2481`.
- `widget:UnitFinished(unitID, unitDefID, unitTeam)`
  - source: `LuaHandle.cpp.lua:201-208`;
  - BAR handler: `luaui/barwidgets.lua:2486-2490`.
- `widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID?, attackerDefID?, attackerTeam?, weaponDefID)`
  - source: `LuaHandle.cpp.lua:249-254`;
  - BAR handler: `luaui/barwidgets.lua:2505-2509`.
- `widget:UnitCommand(...)`
  - BAR usage: `luaui/Widgets/snd_notifications.lua:689-691`;
  - exact signature not yet copied from LuaLS in this pass; keep as partially confirmed.
- `widget:UnitIdle(unitID)`
  - BAR usage: `luaui/Widgets/snd_notifications.lua:693-696`;
  - exact LuaLS signature not yet copied in this pass; keep as partially confirmed.
- `widget:GameOver(winningAllyTeams)`
  - source: `LuaHandle.cpp.lua:109-114`;
  - BAR usage: `luaui/Widgets/snd_notifications.lua:1000-1026`;
  - BAR handler: `luaui/barwidgets.lua:2195-2199`.
- `widget:PlayerChanged(playerID)`
  - BAR usage: `luaui/Widgets/api_shared_state.lua:62-64`;
  - in BAR flexible call-ins: `luaui/barwidgets.lua:111-115`.
- `widget:Shutdown()`
  - source: `LuaHandle.cpp.lua:62-67`;
  - BAR usage: `luaui/Widgets/api_shared_state.lua:58-60`;
  - BAR handler: `luaui/barwidgets.lua:1085-1091`.

## 11. UI

- Простая панель возможна через classic `gl.*` in `widget:DrawScreen`.
- BAR `main.lua` passes `DrawScreen(vsx, vsy)` to `widgetHandler`, and handler calls each widget's `w:DrawScreen()`.
- Sources:
  - `luaui/main.lua:67-72`;
  - `luaui/barwidgets.lua:1605-1620`;
  - `luaui/Widgets/cmd_factoryqmanager.lua:775-783`;
  - `luaui/Widgets/gui_ecostats.lua:8-17`;
  - `recoil-lua-library/library/generated/rts/Lua/LuaHandle.cpp.lua:843-848`.
- Useful API:
  - `Spring.GetViewGeometry() -> viewSizeX, viewSizeY, viewPosX, viewPosY`;
  - source: `recoil-lua-library/library/generated/rts/Lua/LuaUnsyncedRead.cpp.lua:150-157`.
- Ограничения:
  - RmlUI существует в BAR (`luaui/RmlWidgets`), но текущий debug widget использует classic `gl.Rect/gl.Text`; выбор UI для opening-card относится к отдельному Phase 7.
  - UI must not contain detection logic.

## 12. Настройки

- Widget config persistence is via widget methods:
  - `function widget:GetConfigData() return table end`;
  - `function widget:SetConfigData(data) ... end`.
- BAR handler:
  - saves per-widget config: `luaui/barwidgets.lua:340-352`;
  - sends loaded config: `luaui/barwidgets.lua:354-361`;
  - applies config during load: `luaui/barwidgets.lua:656-660`;
  - captures config during removal: `luaui/barwidgets.lua:1085-1088`.
- Existing widgets:
  - `luaui/Widgets/snd_notifications.lua:1038-1055`;
  - `luaui/Widgets/cmd_factoryqmanager.lua:786-792`.
- Ограничения:
  - format/size limits are not confirmed;
  - сохранять только небольшой versioned UI state: enabled, panel position, scale.

## 13. Тестирование

- BAR uses Lua 5.1 and Busted for automated tests.
- Commands from BAR README:
  - `busted`;
  - `busted -t focus`;
  - `lx test`;
  - `lx check`.
- Sources:
  - `README.md:53-88`;
  - `README.md:92-116`.
- Existing test builders:
  - synced mock has `GetTeamResources`, `GetTeamUnits`, `GetUnitDefID`: `spec/builders/spring_synced_builder.lua:385-388`, `spec/builders/spring_synced_builder.lua:475-487`, `spec/builders/spring_synced_builder.lua:503-507`;
  - unsynced builder can load widget and call `Initialize`: `spec/builders/spring_unsynced_builder.lua:169-178`.
- Decision:
  - domain/application logic should be pure Lua and testable with Busted fixtures;
  - infrastructure needs manual BAR scenario + debug panel because engine runtime cannot be fully mocked in this repo yet.

## 14. Подтверждённые API

| Задача | API | Источник | Уверенность | Ограничения |
|---|---|---|---|---|
| Widget load | `widget:GetInfo`, `Initialize`, `Shutdown` | `gui_ecostats.lua:8-17`, `barwidgets.lua:1059-1091` | High | exact user install path still needs runtime check |
| Game time | `Spring.GetGameFrame`, `Spring.GetGameSeconds` | `LuaSyncedRead.cpp.lua:73-82` | High | frame-based logic should use `Game.gameSpeed` or 30 fps assumption from call-in docs |
| Resource snapshot | `Spring.GetTeamResources(teamID, resource)` | `LuaSyncedRead.cpp.lua:374-387`, `snd_notifications.lua:281-283`, Phase 1 manual BAR run | High | `pull` is requested consumption; `expense` is actual satisfied consumption and can be capped near `income` during stall; ninth return often ignored |
| Own team id | `Spring.GetLocalTeamID`; BAR alias `Spring.GetMyTeamID` | `LuaUnsyncedRead.cpp.lua:776-780`, many BAR widgets, Phase 1 manual BAR run | High | `GetMyTeamID` returned team ID in BAR runtime; keep `GetLocalTeamID` fallback |
| Own units | `Spring.GetTeamUnits(teamID)` | `LuaSyncedRead.cpp.lua:561-565` | High | only use local team |
| Unit type | `Spring.GetUnitDefID`, `UnitDefs[id]` | `LuaSyncedRead.cpp.lua:899-903`, BAR widgets | High | unitDef can be nil for invalid/unseen unit |
| Factory detection | `UnitDefs[id].isFactory` | `cmd_factoryqmanager.lua:149-154` | High | factory queues still need separate API |
| Factory queue | `GetFactoryCommands`, `GetFactoryCommandCount`, `GetFactoryCounts` | `LuaSyncedRead.cpp.lua:1532-1585` | Medium | not yet verified in a BAR widget for our exact use |
| Unit commands | `GetUnitCurrentCommand`, `GetUnitCommands`, `GetUnitCommandCount` | `LuaSyncedRead.cpp.lua:1504-1560` | High | command queue is not actual work |
| Builder task | `GetUnitWorkerTask`, `GetUnitIsBuilding` | `LuaSyncedRead.cpp.lua:1138-1162` | Medium | exact nil behavior needs runtime check |
| Unit events | `UnitCreated`, `UnitFinished`, `UnitDestroyed` | `LuaHandle.cpp.lua:194-254`, `barwidgets.lua:2475-2509` | High | attacker fields visibility-limited |
| Map/start/wind | `Game.mapSizeX/Z`, `Spring.GetTeamStartPosition`, `Game.windMin/Max`, `Spring.GetWind`, `Spring.GetTidal` | Recoil `LuaSyncedRead.cpp`, local `init_start_marker.lua`, `LuaConstGame.cpp.lua:75-95` | High | start position только allied team; использовать после exact context/map check |
| UI panel | `DrawScreen`, `Spring.GetViewGeometry`, `gl.*` | `main.lua:67-72`, `barwidgets.lua:1605-1620` | High | need manual visual check |
| Settings | `GetConfigData`, `SetConfigData` | `barwidgets.lua:340-361`, `snd_notifications.lua:1038-1055` | High | keep small |
| Match end | `GameOver(winningAllyTeams)` | `LuaHandle.cpp.lua:109-114`, `snd_notifications.lua:1000-1026` | High | undecided game returns empty list |
| Tests | Busted/Lux | `README.md:92-116`, `spec/builders/*` | High | локальный Lua 5.1 harness добавлен в `tests/run.lua` |

## 15. Неподтверждённые места

| Вопрос | Что найдено | Почему недостаточно | Безопасная альтернатива |
|---|---|---|---|
| `Spring.GetMyTeamID` exact LuaLS signature | 244 BAR usages and Phase 1 runtime success | absent from current Recoil LuaLS search | use `Spring.GetMyTeamID or Spring.GetLocalTeamID`, keep debug status |
| `Spring.GetRealBuildQueue` | BAR factory queue manager uses it | absent from LuaLS search | prefer `GetFactoryCommands/GetFactoryCommandCount`; mark `GetRealBuildQueue` unsupported |
| Factory paused vs resource-starved | queue APIs confirmed | no reliable direct signal found yet | не делать отдельную карточку; для final opening milestone сохранять `unknown` без temporal evidence |
| Idle builder exact engine signal | BAR uses `UnitIdle`/`UnitCommand` | отдельный пользовательский смысл не подтверждён | не делать отдельную карточку; worker task использовать только как debug/recovery evidence |
| Build power team total | no direct team API found | per-unit build speed/task is inferential | keep `economy.buildPower = nil` until dedicated spike |
| `GetUnitCurrentBuildPower` return | RecoilEngine `NanoPieceCache::GetBuildPower()` возвращает долю установленных битов активности nano-piece за окно около 0,5 секунды, то есть `0..1`, а не build speed | RecoilEngine `48e9b007`, `LuaSyncedRead.cpp:4771-4798`, `NanoPieceCache.h/.cpp` | Не суммировать как build power; использовать только как debug activity signal |

### Phase 5 update — 2026-07-22

Проверены актуальные RecoilEngine `48e9b007`, recoil-lua-library `3a0f3001` и BAR `d68bd660`.

- `GetUnitWorkerTask` действительно читает текущую внутреннюю задачу `CBuilder`/`CFactory`, а не только первую команду queue. Construction и assist возвращаются отрицательным `UnitDefID` строящегося target и его unit ID.
- `UnitDef.buildSpeed` экспортирован в Lua и соответствует `workerTime`; внутри builder/factory он переводится в значение на simulation frame.
- `GetUnitIsStunned` позволяет отдельно исключить незавершённые и stunned units.
- Точного team-level build power по-прежнему нет. Доказуемый total строится только суммой полностью классифицированных собственных units.
- Номинальная active construction capacity не равна фактическому приросту progress при resource stall. Classifier остаётся вне Phase 5.
| Direct “player has started correction” signal | partial event/command data | mapping action to intent is not direct | store `unknown` when not reliable |
| Persistent stats size/version | config hooks exist | no size limits found | small config only, versioned table |

## 16. Phase 6A — practical opening surface

Проверено 2026-07-22 по Beyond-All-Reason master `d68bd6605a1b177a9464f2eaa056d505ae4fd6bd` и локальному архиву `ravaged_remake_v1.2.sd7` без запуска игры.

Подтверждены widget call-ins:

- `UnitCreated(unitID, unitDefID, unitTeam, builderID)`;
- `UnitFinished(unitID, unitDefID, unitTeam)`;
- `UnitDestroyed(...)`;
- `UnitGiven(...)`;
- `UnitTaken(...)`;
- `UnitFromFactory(unitID, unitDefID, unitTeam, factID, factDefID, userOrders)`.

Подтверждены read-only API, уже используемые официальными BAR widgets:

- `Spring.GetTeamUnits(teamID)`;
- `Spring.GetUnitDefID(unitID)`;
- `Spring.GetUnitIsBeingBuilt(unitID)`;
- `Spring.GetUnitPosition(unitID)`;
- `Spring.GetWind()`.

Дополнительно для offline opening adapter подтверждены:

- `UnitDefs[unitDefID].name` массово используется официальными BAR widgets;
- `UnitDefs[unitDefID].customParams.iscommander` используется для commander detection;
- `units/corcom.lua` задаёт `customparams.iscommander = true`;
- `corcom` build options включают `corsolar`, `corwin`, `cormex`, `corlab` и другие Cortex T1 buildings.

Актуальные unit definitions подтверждают:

- `corlab` строит `corck`, `corak`, `cornecro`, `corstorm`, `corthud`, `corcrash`;
- `corck` может строить `cormex`, `corwin`, `corsolar`, `corrad` и другие T1 buildings;
- `cormex.customparams.metal_extractor = 1`;
- `corwin.customparams.unitgroup = "energy"` и `windgenerator = 25`;
- `corsolar.customparams.unitgroup = "energy"`;
- `corrad.radardistance = 2100`.

Локальный `mapinfo.lua` подтверждает точное имя `Ravaged Remake v1.2`, описание `10x10 Duel 1v1/2v2 map`, `minWind = 5` и `maxWind = 15`.

Текущее состояние после Phase 6I:

- usefulness и переносимость provisional `expansionRadius=900` за пределы exact replay и нижней start position Ravaged;
- [Phase 6I](../runtime/opening/phase6i_completion_memory_2026-07-25.md) подтвердила completion semantics для текущей timeline: достигнутый milestone остаётся `complete` после потери unit, а текущий регресс сохраняется как `observedState`; reset, team/context change и rewind очищают память;
- достаточный temporal idle window для factory;
- полезность combat thresholds.

## 17. Phase 6F — replay extraction surface

Проверено 2026-07-22 на точном Recoil `2025.06.24`, game archive `test-30617-51933b6` и восьмиминутном replay.

Runtime подтвердил для явно заданной target team:

- `Spring.GetTeamResources(teamID, resource)`;
- `Spring.GetTeamUnits(teamID)`;
- `Spring.GetUnitDefID(unitID)`;
- `Spring.GetUnitIsBeingBuilt(unitID)`;
- `Spring.GetUnitPosition(unitID)`;
- `Spring.GetUnitWorkerTask(unitID)`;
- `Spring.GetGameSeconds()` и `Spring.GetGameFrame()`;
- `UnitCreated`, `UnitFinished` и `UnitDestroyed` с фильтрацией по `unitTeam`;
- `UnitDefs[unitDefID].name`, `isFactory`, `isBuilder`, `buildSpeed` и `customParams.iscommander`.

Официальный Recoil source tag `2025.06.24`, `rts/Lua/LuaUnsyncedCtrl.cpp`, подтверждает `Spring.SendCommands(command)`. `spring.exe --list-unsynced-commands` той же версии подтверждает command `pause` как toggle pause/unpause. Этот write-capable API разрешён только исследовательскому replay harness для снятия начальной паузы; gameplay и production widget его не используют.

Runtime обнаружил, что setup side может не совпадать с фактическим commander: team 0 имела setup side `Armada`, но `corcom` и Cortex unit sequence. Поэтому Phase 6F определяет factual faction по собственному commander, а setup side сохраняет только как metadata evidence.

## 18. Phase 6F — public replay catalog

Проверено 2026-07-23 read-only запросами, без запуска BAR и без скачивания replay.

Наблюдаемые endpoints:

- `GET https://api.bar-rts.com/replays` — paginated list metadata;
- `GET https://api.bar-rts.com/replays/{32-hex-id}` — detail metadata конкретного replay;
- detail `fileName` позволяет сформировать storage URI, но наличие metadata не считается доказательством целостности файла: размер и gameplay context всё равно проверяются перед runtime.

Подтверждённые detail fields текущего ответа: replay id/file name, engine/game version, start time, duration/full duration, normal end, bots, preset, map metadata, ally teams, result, player name/user/team id, faction, skill и uncertainty. Клиент использует optional-property access: отсутствие поля остаётся `null`.

List response беднее detail: в проверенной выдаче player entries не содержали faction, user/team id, skill и uncertainty. Эти значения нельзя восстанавливать по setup side или считать нулевыми; выбранный replay нужно подтверждать detail-запросом.

Detail field `faction` тоже не является безусловным factual commander evidence: среди десяти проверенных replay значение одного игрока осталось `Random`. В длинном Isidis значение Cortex совпало с независимо наблюдавшимся runtime `corcom`; в Archsimkats API `Random` фактически разрешён runtime commander `armcom` как Armada. Остальные replay всё равно классифицируются по commander во время extraction, а не только по API field.

Live-проверка совместных query parameters `players` и `maps` вернула пять server rows, одна из которых не содержала указанного игрока. Поэтому API-фильтры нельзя считать гарантированным AND-контрактом. `tools/query_bar_replays.ps1` локально применяет пересечение известных player/map полей и явно возвращает server/filtered counts. Ограничение остаётся: API применяет pagination до локальной фильтрации, поэтому один page не доказывает полноту выборки.

Это research surface, а не BAR/Recoil Lua API и не production dependency. Стабильность и версионирование публичного контракта не подтверждены официальной документацией; extractor должен оставаться устойчивым к отсутствующим optional fields.
