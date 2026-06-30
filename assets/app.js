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

  function renderStage(stage) {
    byId("stageDate").textContent = stage.label;
    byId("stageTitle").textContent = `Этап ${stage.number}: ${stage.route}`;
    byId("stageMeta").textContent = `${stage.type} · ${stage.distance}`;
    byId("watchPriority").textContent = stage.watchPriority;
    byId("stageType").textContent = stage.type;
    byId("stageDistance").textContent = stage.distance;
    byId("stageElevation").textContent = stage.elevation;
    byId("stageFinishWindow").textContent = stage.finishWindow;
    byId("stageGuide").textContent = stage.guide;
    byId("keyKilometers").textContent = stage.keyKilometers;
    byId("gcImpact").textContent = stage.gcImpact;
    byId("difficulty").textContent = stage.difficulty;
    byId("weatherNote").textContent = "обновить утром перед этапом";

    const primary = data.services.find((service) => service.name === "HBO Max");
    const backup = data.services.find((service) => service.name === "France TV");
    byId("primaryWatch").href = primary.url;
    byId("backupWatch").href = backup.url;
    byId("liveTracker").href = data.links.live;
    byId("replayLink").href = data.links.youtube;
    byId("highlightsLink").href = data.links.youtube;
    byId("resultsLink").href = data.links.results;

    byId("dailyFavorites").innerHTML = stage.favorites.map((item) => `<li>${item}</li>`).join("");
  }

  function renderStageSelect() {
    const select = byId("stageSelect");
    select.innerHTML = data.stages
      .map((stage) => `<option value="${stage.number}">Этап ${stage.number} · ${stage.label} · ${stage.route}</option>`)
      .join("");
    select.addEventListener("change", () => {
      const stage = data.stages.find((item) => item.number === Number(select.value));
      renderStage(stage);
    });
  }

  function renderRecommendations() {
    const ranked = [...data.services].sort((a, b) => serviceScore(a) - serviceScore(b)).slice(0, 5);
    byId("recommendations").innerHTML = ranked
      .map((service) => `<li><strong>${service.name}</strong><br><small>${service.result}. ${service.notes}</small></li>`)
      .join("");
  }

  function renderBroadcasts() {
    const tbody = byId("broadcastTable").querySelector("tbody");
    tbody.innerHTML = [...data.services]
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
          <td>${rider.role}</td>
          <td>${rider.strengths}</td>
          <td>${rider.weakness}</td>
          <td>${rider.watch}</td>
        </tr>
      `)
      .join("");
  }

  function renderCountdown() {
    const now = new Date();
    const start = new Date("2026-07-04T18:05:00+03:00");
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
    } else {
      byId("countdownLabel").textContent = "Гонка идет или завершена";
    }
  }

  function init() {
    byId("updatedAt").textContent = data.updatedAt;
    renderCountdown();
    renderStageSelect();
    renderStage(data.stages[0]);
    renderRecommendations();
    renderBroadcasts();
    renderStagesTable();
    renderRiders();
  }

  init();
})();
