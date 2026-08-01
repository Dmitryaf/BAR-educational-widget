# Архитектура

## Поток данных

```text
BAR/Recoil API и widget call-ins
→ adapters и normalized observations
→ temporal tracker и domain evaluation
→ pure coach presentation
→ одна пользовательская карточка
```

Domain и presentation-модули не обращаются к `Spring`, `VFS` или `gl`. Entry point связывает слои, обновляет состояние и рисует уже выбранную карточку. UI не определяет milestone и не конкурирует с recovery отдельной поверхностью.

## Production-модули

| Модуль | Ответственность |
| --- | --- |
| `snapshot_collector.lua` | Нормализует team-resource snapshot |
| `history_buffer.lua`, `energy_stall.lua` | Хранят ограниченную историю и lifecycle `ENERGY_STALL` |
| `energy_stall_recommendation.lua` | Формирует recovery-рекомендацию из подтверждённого состояния |
| `opening_context.lua` | Задаёт exact lesson, milestones и provisional thresholds |
| `opening_adapter.lua` | Преобразует BAR scan собственной team в opening observation |
| `opening_tracker.lua` | Ведёт factory idle history и completion memory текущей timeline |
| `opening_progress.lua` | Выбирает `milestone`, `recovery`, completion или безопасный status |
| `coach_presentation.lua` | Чисто преобразует решение в одну карточку |
| `bar_learning_coach.lua` | Интеграция, invalidation, polling и rendering |

Build-power и replay collectors не входят в production dependency graph.

## Контекст и честная граница поддержки

Runtime guard подтверждает точное имя карты `Ravaged Remake v1.2` и наличие собственного Cortex commander. Локальная 1v1 practice — рекомендуемая среда проверки, а Cortex Bot Lab — выбранный путь lesson; текущий adapter не проверяет их как отдельные условия до показа первого шага.

Adapter читает только собственную team. Неполные внешние данные сохраняются как unknown и приводят к временно недоступной подсказке, а не к уверенному совету. Unsupported map или faction дают нейтральную карточку без gameplay-рекомендации.

## State и обновление

Ресурсы обновляются раз в `0.5` секунды, полный opening scan — не чаще раза в `2` секунды. Изменение energy state и factory lifecycle call-ins помечают opening как dirty. Tracker сбрасывает temporal confidence при смене team/context, rewind, unknown factory activity и явной invalidation; достигнутые milestones запоминаются только в текущей timeline.

Презентация имеет взаимоисключающие состояния: milestone, recovery, lesson complete, unsupported setup, temporarily unavailable или none. После lesson complete recovery больше не показывается.

## Проверка

Чистые Lua-specs проверяют adapters, domain state и presenter отдельно от BAR. Runtime-проверка нужна для совместимости с конкретной версией BAR/Recoil, но сама по себе не доказывает продуктовую полезность.
