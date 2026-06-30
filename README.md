# Tour de France 2026 — личный центр сопровождения

Локальный рабочий центр для ежедневного просмотра и сопровождения Tour de France 2026 из Молдовы.

## Быстрый старт

Откройте файл:

`index.html`

Страница работает локально без сервера. Данные лежат в `assets/data.js`, логика интерфейса — в `assets/app.js`.

## Что уже есть

- Главная страница с выбором этапа.
- Таблица всех 21 этапов по официальному маршруту Tour de France 2026.
- Отдельная страница `riders.html` с гонщиками, за которыми стоит следить.
- Отдельная страница `stage-guide.html` с кратким гидом по ключевым этапам.
- Первичная оценка трансляций и резервных вариантов.
- Таблица фаворитов генеральной классификации.
- Ежедневный шаблон: до этапа, во время этапа, после этапа.
- PowerShell-скрипт для быстрой проверки доступности сайтов.

## Основные источники

- Official route: https://www.letour.fr/en/overall-route
- Official broadcasters: https://www.letour.fr/en/broadcasters
- Official live center: https://www.letour.fr/en/live

## Последняя Chrome-проверка трансляций

- Дата: 2026-06-30.
- Chrome-профиль: `Роман`.
- Результаты: `reports/broadcast-research.md`.
- Техническая таблица: `reports/site-checks.csv`.

## Важные ограничения

- Прямые эфиры нельзя полностью проверить до фактического окна трансляции этапа.
- Доступность видео из Молдовы нужно дополнительно проверять через Chrome-профиль `Hamster Gagauz`.
- Платные сервисы, регистрация, 2FA, CAPTCHA и VPN-настройки требуют вашего отдельного подтверждения.

## Статус данных

- Маршрут Tour de France 2026: **Verified**. Источник — официальный маршрут Tour de France.
- Информация о трансляциях: **Preliminary**. Требуется практическая проверка сайтов, плееров, replay/live и доступности из Молдовы.
- Фавориты GC, `watchPriority`, ключевые километры и рекомендации по просмотру: **Opinion / Forecast**. Это рабочие экспертные оценки до старта гонки.

## Operator Checklist: проверка трансляций в Chrome

Проверку выполнять только в подготовленном Chrome-профиле проекта. На этом этапе не выполнять входы в аккаунты, не оформлять подписки, не включать VPN, не вводить пароли, 2FA или платежные данные.

Открыть и проверить:

- HBO Max — https://www.hbomax.com/
- Eurosport — https://www.eurosport.com/cycling/tour-de-france/
- France TV — https://www.france.tv/sport/cyclisme/tour-de-france/
- ARD Sportschau — https://www.sportschau.de/radsport/tourdefrance
- SBS On Demand — https://www.sbs.com.au/ondemand/sport/cycling
- RaiPlay — https://www.raiplay.it/
- RTVE Play — https://www.rtve.es/play/
- RTBF Auvio — https://auvio.rtbf.be/
- VRT — https://www.vrt.be/vrtnu/
- SRG SSR / SRF — https://www.srf.ch/sport
- ServusTV — https://www.servustv.com/sport/
- Discovery+ — https://www.discoveryplus.com/
- FloBikes — https://www.flobikes.com/
- Peacock — https://www.peacocktv.com/sports/cycling
- TNT Sports — https://www.tntsports.co.uk/cycling/tour-de-france/
- Okko — https://okko.tv/sport
- Чемпионат — https://www.championat.com/

На каждом сайте фиксировать:

- сайт открывается или нет;
- есть ли страница/раздел Tour de France 2026;
- требуется ли регистрация;
- требуется ли платная подписка;
- появляется ли геоблокировка для Молдовы;
- виден ли видеоплеер без входа;
- доступны ли записи, хайлайты или прошлые этапы;
- есть ли прямой эфир или расписание прямого эфира;
- итоговая оценка: `✅ Работает`, `⚠️ Работает только через VPN`, `❌ Не подходит`, `⏳ Проверить во время live`.

Результаты сохранять в:

- `reports/broadcast-research.md` — итоговые выводы и ранжирование;
- `reports/site-checks.csv` — техническая таблица проверок доступности;
- при ручной проверке Chrome добавлять короткие заметки в раздел соответствующего сервиса в `reports/broadcast-research.md`.

## Журнал изменений

### 2026-06-30 — Baseline 1

- Создан первый рабочий baseline проекта.
- Добавлена локальная страница `index.html` с выбором этапа, таблицей трансляций, таблицей этапов и GC-ориентирами.
- Добавлены основные данные в `assets/data.js`.
- Добавлены отчеты `reports/broadcast-research.md`, `reports/stage-guide.md`, `reports/official-route-latest.json` и `reports/site-checks.csv`.
- Добавлены PowerShell-скрипты для обновления официального маршрута и базовой проверки доступности сайтов.
- Зафиксировано разделение статусов данных: маршрут — Verified, трансляции — Preliminary, прогнозы и рекомендации — Opinion / Forecast.

### 2026-06-30 — Riders page cleanup

- Добавлена HTML-страница `riders.html` с карточками и таблицей гонщиков.
- Фото гонщиков сохранены локально в `assets/riders/`, где это удалось надежно сделать.
- Для временно недоступных локальных фото используется внешний fallback с Wikimedia Commons.
- Добавлены ссылки на проверенные соцсети из Wikidata/Wikimedia.
- Добавлена HTML-страница `stage-guide.html`, чтобы шапка не открывала сырой Markdown-файл.

## Следующие шаги

1. Открыть Chrome с профилем `Hamster Gagauz`.
2. Проверить, что расширение Codex активно в этом профиле.
3. Провести практический тест каждого сервиса из `reports/broadcast-research.md`.
4. Перед стартом гонки обновить погоду, ссылки на прямые эфиры и ссылки на записи.
