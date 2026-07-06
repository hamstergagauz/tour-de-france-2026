(function () {
  const data = window.TDF_DATA;
  const byId = (id) => document.getElementById(id);

  function tag(value, className) {
    return `<span class="tag ${className || "info"}">${value}</span>`;
  }

  function serviceScore(service) {
    if (service.result.startsWith("✅")) return 0;
    if (service.name === "HBO Max") return 1;
    if (service.name === "Eurosport") return 2;
    if (service.result.startsWith("⚠️")) return 3;
    return 9;
  }

  function localDateKey(date) {
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, "0");
    const day = String(date.getDate()).padStart(2, "0");
    return `${year}-${month}-${day}`;
  }

  function selectedStageForToday() {
    const today = localDateKey(new Date());
    const exact = data.stages.find((stage) => stage.date === today);
    if (exact) return exact;

    const upcoming = data.stages.find((stage) => stage.date > today);
    if (upcoming) return upcoming;

    return data.stages[data.stages.length - 1];
  }

  function formatDateTime(value) {
    if (!value) return "уточнить";
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return value;
    return date.toLocaleString("ru-RU", {
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit"
    });
  }

  function findRiderByFavorite(favorite) {
    const needle = favorite.toLowerCase();
    return data.riders.find((rider) => {
      const name = rider.name.toLowerCase();
      return name.includes(needle) || needle.includes(name);
    });
  }

  function renderFavorite(item) {
    const rider = findRiderByFavorite(item);
    if (!rider) return `<li>${item}</li>`;
    return `<li><a href="riders.html">${rider.name}</a><span>${rider.team}</span></li>`;
  }

  function stageHighlights(stageNumber) {
    return (data.highlights || [])
      .filter((item) => item.stage === stageNumber)
      .sort((a, b) => String(a.type).localeCompare(String(b.type), "ru"));
  }

  function renderHighlightLink(item) {
    return `
      <a class="highlight-link" href="${item.url}" target="_blank" rel="noreferrer">
        <span>${item.type}</span>
        <strong>${item.title}</strong>
      </a>
    `;
  }

  function renderStageHighlights(stage) {
    const highlights = stageHighlights(stage.number).filter((item) => !item.isShort);
    byId("highlightChannel").href = data.videoSource.channelUrl;

    if (!highlights.length) {
      byId("stageHighlights").innerHTML = `
        <p class="empty-note">Обзор этого этапа пока не найден. Автопроверка канала запланирована на 04:00.</p>
      `;
      return;
    }

    byId("stageHighlights").innerHTML = highlights.map(renderHighlightLink).join("");
  }

  function renderStage(stage) {
    const primary = data.broadcasters.find((service) => service.name === "HBO Max");
    const backup = data.broadcasters.find((service) => service.name === "France TV");

    byId("stageDate").textContent = stage.label;
    byId("stageTitle").textContent = `Этап ${stage.number}: ${stage.route}`;
    byId("stageMeta").textContent = `${stage.type} · ${stage.distance}`;
    byId("stageStatus").textContent = stage.status;
    byId("watchPriority").textContent = stage.watchPriority;
    byId("stageType").textContent = stage.type;
    byId("stageDistance").textContent = stage.distance;
    byId("stageStartTime").textContent = stage.startTime || "уточнить перед этапом";
    byId("stageFinishWindow").textContent = stage.finishWindow || "уточнить перед этапом";
    byId("keyKilometers").textContent = stage.keyKilometers;
    byId("viewingAdvice").textContent = stage.viewingAdvice;
    byId("gcImpact").textContent = stage.gcImpact;
    byId("difficulty").textContent = stage.difficulty;
    byId("stageGuide").textContent = stage.guide;

    byId("primaryWatch").href = primary.url;
    byId("backupWatch").href = backup.url;
    byId("liveTracker").href = data.links.live;
    byId("replayLink").href = data.links.youtube;
    byId("highlightsLink").href = data.links.youtube;
    byId("resultsLink").href = data.links.results;
    byId("primaryWatchStatus").innerHTML = tag(primary.result, primary.className);
    byId("backupWatchStatus").innerHTML = tag(backup.result, backup.className);

    byId("dailyFavorites").innerHTML = stage.favorites.map(renderFavorite).join("");
    renderStageHighlights(stage);
  }

  function renderStageSelect() {
    const select = byId("stageSelect");
    select.innerHTML = data.stages
      .map((stage) => `<option value="${stage.number}">Этап ${stage.number} · ${stage.label} · ${stage.route}</option>`)
      .join("");

    const selected = selectedStageForToday();
    select.value = String(selected.number);
    renderStage(selected);

    select.addEventListener("change", () => {
      const stage = data.stages.find((item) => item.number === Number(select.value));
      renderStage(stage);
    });
  }

  function renderRecommendations() {
    const ranked = [...data.broadcasters].sort((a, b) => serviceScore(a) - serviceScore(b)).slice(0, 5);
    byId("recommendations").innerHTML = ranked
      .map((service) => `<li><strong>${service.name}</strong><br><small>${service.result}. ${service.notes}</small></li>`)
      .join("");
  }

  function renderBroadcasts() {
    const tbody = byId("broadcastTable").querySelector("tbody");
    tbody.innerHTML = [...data.broadcasters]
      .sort((a, b) => serviceScore(a) - serviceScore(b))
      .map((service) => `
        <tr>
          <td><a href="${service.url}" target="_blank" rel="noreferrer">${service.name}</a></td>
          <td>${service.free}</td>
          <td>${service.russian}</td>
          <td>${service.vpn}</td>
          <td>${service.registration}</td>
          <td>${service.replays}</td>
          <td>${service.live}</td>
          <td>${tag(service.result, service.className)}</td>
        </tr>
      `)
      .join("");
  }

  function renderStagesTable() {
    const tbody = byId("stagesTable").querySelector("tbody");
    tbody.innerHTML = data.stages
      .map((stage) => `
        <tr>
          <td>${stage.label}</td>
          <td>${stage.number}</td>
          <td><a href="${stage.map}" target="_blank" rel="noreferrer">${stage.route}</a></td>
          <td>${stage.distance}</td>
          <td>${stage.type}</td>
          <td>${stage.watchPriority}</td>
          <td>${stage.gcImpact}</td>
          <td>${stage.viewingAdvice}</td>
        </tr>
      `)
      .join("");
  }

  function renderRiders() {
    const tbody = byId("ridersTable").querySelector("tbody");
    tbody.innerHTML = data.riders
      .map((rider) => `
        <tr>
          <td>${rider.name}</td>
          <td>${rider.team}</td>
          <td>${(rider.roles || []).join(", ")}</td>
          <td>${rider.why}</td>
          <td>${rider.risk}</td>
          <td>${rider.watch}</td>
        </tr>
      `)
      .join("");
  }

  function renderLatestHighlights() {
    const latest = [...(data.highlights || [])]
      .filter((item) => !item.isShort)
      .sort((a, b) => String(b.publishedAt).localeCompare(String(a.publishedAt)))
      .slice(0, 6);

    byId("latestHighlights").innerHTML = latest.length
      ? latest.map((item) => `
        <li>
          <a href="${item.url}" target="_blank" rel="noreferrer">Этап ${item.stage}: ${item.type}</a>
          <span>${item.source}</span>
        </li>
      `).join("")
      : "<li>Обзоры пока не добавлены.</li>";
  }

  function renderDataStatus() {
    const status = data.meta.dataStatus;
    byId("routeStatus").textContent = status.route;
    byId("broadcasterStatus").textContent = status.broadcasters;
    byId("highlightsStatus").textContent = status.highlights || "не настроено";
    byId("predictionStatus").textContent = status.predictions;
    byId("routeCheckedAt").textContent = formatDateTime(data.meta.routeCheckedAt);
    byId("highlightsCheckedAt").textContent = data.meta.youtubeHighlightsCheckedAt || "еще не проверялось";
  }

  function renderCountdown() {
    const now = new Date();
    const start = new Date("2026-07-04T18:05:00+03:00");
    const end = new Date("2026-07-26T23:59:59+03:00");
    const diff = start - now;

    byId("todayLabel").textContent = now.toLocaleDateString("ru-RU", {
      weekday: "long",
      year: "numeric",
      month: "long",
      day: "numeric"
    });

    if (diff > 0) {
      const days = Math.ceil(diff / 86400000);
      byId("countdownLabel").textContent = `До старта: ${days} дн.`;
    } else if (now <= end) {
      byId("countdownLabel").textContent = "Гонка идет";
    } else {
      byId("countdownLabel").textContent = "Гонка завершена";
    }
  }

  function init() {
    byId("updatedAt").textContent = data.meta.updatedAt;
    renderCountdown();
    renderStageSelect();
    renderRecommendations();
    renderBroadcasts();
    renderStagesTable();
    renderRiders();
    renderLatestHighlights();
    renderDataStatus();
  }

  init();
})();
