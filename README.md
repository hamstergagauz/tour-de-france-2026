# Tour de France 2026 — личный центр сопровождения

Публичный рабочий центр для ежедневного просмотра и сопровождения Tour de France 2026 из Молдовы.

Production: https://tdf.halktoplushu.md

Current project status: **WAITING_FOR_TOUR_START**

## Быстрый старт

Откройте публичную страницу:

https://tdf.halktoplushu.md

Локально сайт по-прежнему можно открыть через `index.html`. Данные лежат в `assets/data.js`, логика главной страницы — в `assets/app.js`.

## Что уже есть

- Главная страница с ежедневным dashboard и выбором этапа.
- Таблица всех 21 этапов по официальному маршруту Tour de France 2026.
- Отдельная страница `riders.html` с гонщиками, за которыми стоит следить.
- Отдельная страница `stage-guide.html` с кратким гидом по ключевым этапам.
- Первичная оценка трансляций и резервных вариантов.
- Единая модель данных в `assets/data.js`: этапы, гонщики, трансляции и статусы данных.
- Ежедневный dashboard: что смотреть, когда включать, почему этап важен, фавориты дня и статус данных.
- Блок ежедневных YouTube-обзоров с канала TNT Sports Cycling.
- Адаптивная верстка для мобильного, планшета и desktop.
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

## Production Baseline

- GitHub Pages: **operational**.
- Custom domain: **operational** — https://tdf.halktoplushu.md
- HTTPS: **operational**.
- DNS: **verified and propagated**.
- Phase 2: **complete**.
- Homepage daily dashboard: **operational**.
- YouTube highlight workflow: **RSS monitored**.
- Responsive behavior: **validated locally and manually**.
- Current focus: **operational monitoring during the Tour de France**.

## Основной режим просмотра

С 2026-07-06 основной сценарий — смотреть не live-трансляции, а ежедневные обзоры.

- Primary source: https://www.youtube.com/@TNTSportsCycling
- Stable RSS source: `https://www.youtube.com/feeds/videos.xml?channel_id=UCfDfvvMARk4TKcC62ALi6eA`
- Update script: `scripts/Update-YoutubeHighlights.ps1`
- Daily automation target: 04:00 Europe/Bucharest.

Скрипт ищет новые ролики канала по RSS, фильтрует `Tour de France` + `Stage N`, добавляет ссылки в `assets/data.js` и не дублирует уже найденные `videoId`.

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

## Next Operator Workflow

До и во время гонки:

1. Утром проверить, появились ли ссылки на обзоры прошедшего этапа.
2. Если RSS не нашел обзор, проверить канал TNT Sports Cycling вручную.
3. Проверить фактическое время старта, финишное окно и ключевые километры текущего этапа.
4. Обновить stage data, если организаторы публикуют изменения маршрута, времени или профиля.
5. Фиксировать реальные UX-наблюдения для будущей Phase 3, не смешивая их с оперативными race-day правками.

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

### 2026-07-01 — Phase 2 production baseline

- GitHub Pages и custom domain `https://tdf.halktoplushu.md` подтверждены как рабочие.
- Реализована единая live-модель данных в `assets/data.js`.
- Главная страница переведена на ежедневный dashboard.
- `riders.html` использует единую модель `assets/data.js`; legacy-файл `assets/riders-data.js` удалён.
- Адаптивное поведение проверено для мобильного, планшета и desktop.
- Проект переведен в состояние `WAITING_FOR_TOUR_START`.

### 2026-07-06 — YouTube highlights workflow

- Основной режим просмотра смещен с live на ежедневные YouTube-обзоры.
- Добавлен канал TNT Sports Cycling как основной источник обзоров.
- Добавлен RSS-based скрипт `scripts/Update-YoutubeHighlights.ps1`.
- На главной странице добавлен блок обзоров выбранного этапа и список последних обзоров.

## Следующие шаги

1. Каждое утро проверять, что обзоры прошлого этапа появились на главной странице.
2. Если обзоров нет, проверить канал TNT Sports Cycling вручную.
3. Проверить stage timing текущего этапа.
4. Обновлять только оперативные race-day данные, если они реально изменились.
5. Собирать UX-наблюдения для будущей Phase 3.
