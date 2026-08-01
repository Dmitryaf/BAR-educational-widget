# Документация BAR Learning Coach

Это публичный индекс документации проекта. Он разделяет текущие контракты, evidence, историю решений и локальные рабочие материалы.

## Current product/system docs

Эти файлы владеют текущим публичным описанием продукта и системы. При расхождении runtime-отчёта или старого task с ними сначала проверяется актуальность evidence, а не молча меняется контракт.

| Документ | Контракт и владелец |
| --- | --- |
| [`PRODUCT.md`](PRODUCT.md) | Продукт, аудитория, проверяемая гипотеза и границы обещания. |
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | Слои системы, зависимости и границы runtime/domain/UI. |
| [`LEARNING_MODEL.md`](LEARNING_MODEL.md) | Lesson, milestone, recovery и снижение помощи. |
| [`MVP.md`](MVP.md) | Exact context, runtime-контракт и критерии текущего MVP. |
| [`ROADMAP.md`](ROADMAP.md) | Текущий checkpoint и следующие продуктовые решения. |
| [`NOT_NOW.md`](NOT_NOW.md) | Явно замороженные направления и non-goals. |

## Installation

[`INSTALLATION.md`](INSTALLATION.md) — публичное руководство по установке, включению, статической проверке, обновлению и удалению widget. Оно описывает переносимую структуру файлов, но не заменяет runtime-проверку в BAR.

Условия участия описаны в [`CONTRIBUTING.md`](../CONTRIBUTING.md), условия распространения — в корневом [`LICENSE`](../LICENSE).

## Research

Research хранит проверяемые основания и ограничения. Он может инициировать изменение текущего контракта, но сам по себе его не заменяет.

| Документ | Область evidence |
| --- | --- |
| [`research/BAR_API_RESEARCH.md`](research/BAR_API_RESEARCH.md) | Подтверждённый BAR/Recoil API и версии источников. |
| [`research/BEGINNER_PAIN_RESEARCH.md`](research/BEGINNER_PAIN_RESEARCH.md) | Качественные сигналы о beginner pain и границы продуктовых выводов. |
| [`research/REPLAY_RESEARCH_POLICY.md`](research/REPLAY_RESEARCH_POLICY.md) | Требования к выборке, воспроизводимости и формулировке replay-выводов. |

## Runtime evidence

[`runtime/README.md`](runtime/README.md) ведёт к публичным кратким отчётам по подсистемам. Они подтверждают только описанный technical run и не доказывают usefulness, причинность или универсальность gameplay-решения.

Raw CSV и infolog остаются локальными. Публичные отчёты могут указывать их имена и хеши для provenance, но отсутствие raw-файла в репозитории не превращает summary в самостоятельный продуктовый контракт.

## Decisions

[`decisions/`](decisions/) хранит короткие устойчивые решения, которые всё ещё нужны для понимания текущих документов. Decision record фиксирует вопрос, принятое решение, evidence и ограничения; статус продукта по-прежнему принадлежит current docs.

## Historical archive

`docs/archive/` остаётся локальным. В нём находятся завершённые phase-отчёты, датированные product reviews и заменённые process-документы. Архив сохраняет provenance, но не задаёт текущее поведение. Долговечный вывод переносится в current doc или отдельный decision record, а исходный исторический файл не переписывается.

## Local working material

Локальными остаются временные task scopes, исторический архив, raw runtime evidence и подробные replay-разборы с контекстом игроков.

Эти материалы помогают воспроизвести работу, но research, runtime reports и historical documents не переопределяют текущие product/system contracts.
