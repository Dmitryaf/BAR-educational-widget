# Roadmap BAR Learning Coach

Обновлено: 2026-07-31.

## Текущий checkpoint

Технический фундамент ограниченного opening завершён до Phase 6I включительно. Реализованы context guard, наблюдение milestones, recovery override, expansion evidence и память завершения lesson. Пользовательской opening-card пока нет: текущий widget остаётся debug-интерфейсом.

Следующий отдельный блок — Phase 7. До его начала нужен собственный task-файл с точным scope и критериями готовности; существование пункта в roadmap не разрешает реализацию автоматически.

## Phase 7 — minimal practical opening card

Цель: подготовить минимальный live-вариант того же content, который доступен в короткой статической шпаргалке.

Граница:

- одна ближайшая milestone-card либо одна recovery-card;
- весь короткий текст раскрыт сразу;
- `unknown` и неподдерживаемый context не дают пользовательской рекомендации;
- без polish, новых diagnoses, второго opening и distribution work;
- статическая шпаргалка фиксируется до usefulness validation и использует те же milestones и формулировки.

Условие выхода: карточка и comparator технически готовы к проверке на начинающих игроках, а runtime smoke подтверждает supported, unsupported, recovery и lesson-complete paths.

## Phase 8 — guided opening usefulness

Статус: pending. Детальный рабочий scope ведётся локально; публичная граница этапа зафиксирована ниже.

Цель: сравнить статическую шпаргалку и live-widget с одинаковым opening-content, затем проверить повторение без обоих вариантов помощи.

Решение: `keep`, `revise` или `remove` для live-widget, thresholds, milestones и lesson. Малая выборка даёт решение по продукту, а не статистику всего сообщества.

## Phase 9 — distribution decision

Запускается только после `keep` в Phase 8. Отдельно решает installation friction, простой installer, community-каталог или предложение интеграции в BAR.

До этого запрещены community-ready claims и сложная distribution infrastructure.

## После первого lesson

Второй context, T2 lesson, post-match review и дальнейшая линейка recovery рассматриваются только после Phase 8 и отдельного evidence review.

## Завершённая история

Исторические отчёты Phase 0–5 и task-файлы сохраняются локально. Публичное runtime evidence Phase 6 маршрутизируется через [`runtime/`](runtime/). Завершённые шаги не дублируются в этом roadmap.
