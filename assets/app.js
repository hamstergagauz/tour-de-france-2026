(function () {
  const data = window.TDF_DATA;
  const byId = (id) => document.getElementById(id);

  function tag(value, className) {
    return `<span class="tag ${className || "info"}">${value}</span>`;
  }

  function localDateKey(date) {
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, "0");
    const day = String(date.getDate()).padStart(2, "0");
    return `${year}-${month}-${day}`;
  }

  function selectedStageForToday() {
    const today = localDateKey(new Date());
    const latestCompleted = latestCompletedResult();
    const exact = data.stages.find((stage) => stage.date === today);
    if (exact) {
      const exactResult = stageResult(exact.number);
      if (exactResult && ["preliminary", "official"].includes(exactResult.status)) return exact;
      if (latestCompleted) {
        const completedStage = data.stages.find((stage) => stage.number === latestCompleted.stage);
        if (completedStage) return completedStage;
      }
      return exact;
    }

    const upcoming = data.stages.find((stage) => stage.date > today);
    if (upcoming) return upcoming;

    if (latestCompleted) {
      const completedStage = data.stages.find((stage) => stage.number === latestCompleted.stage);
      if (completedStage) return completedStage;
    }

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

    if (!highlights.length) {
      byId("stageHighlights").innerHTML = `
        <p class="empty-note">Обзор этого этапа пока не найден. Автопроверка TNT Sports Cycling идет отдельным потоком.</p>
      `;
      return;
    }

    byId("stageHighlights").innerHTML = highlights.map(renderHighlightLink).join("");
  }

  function stageResults() {
    return Array.isArray(data.stageResults) ? data.stageResults : Object.values(data.stageResults || {});
  }

  function stageResult(stageNumber) {
    return (data.stageResults && data.stageResults[String(stageNumber)]) || stageResults().find((item) => item.stage === stageNumber);
  }

  function completedStageResults() {
    return stageResults()
      .filter((result) => ["preliminary", "official"].includes(result.status))
      .sort((a, b) => a.stage - b.stage);
  }

  function latestCompletedResult() {
    const results = completedStageResults();
    return results[results.length - 1];
  }

  function resultStatusLabel(status) {
    if (status === "official") return "Official";
    if (status === "preliminary") return "Preliminary";
    if (status === "live") return "Live";
    return "Scheduled";
  }

  function riderLabel(entry) {
    if (!entry) return "не подтверждено";
    const wornBy = entry.wornByRiderId ? " · носит другой гонщик" : "";
    return `${entry.name}${wornBy}`;
  }

  function nextStageAfter(stage) {
    return data.stages.find((item) => item.number > stage.number) || null;
  }

  function renderStageResult(stage) {
    const result = stageResult(stage.number);
    const card = byId("stageSummaryCard");

    if (!result || !["preliminary", "official"].includes(result.status)) {
      card.hidden = true;
      byId("stageResultPill").textContent = "Результат ожидается";
      byId("stageResultPill").className = "tag warn";
      return;
    }

    card.hidden = false;
    byId("stageResultPill").textContent = resultStatusLabel(result.status);
    byId("stageResultPill").className = `tag ${result.status === "official" ? "ok" : "warn"}`;
    const winnerHeading = byId("stageWinner");
    const winnerRider = (data.riders || []).find((rider) => rider.id === result.winner.riderId);
    winnerHeading.replaceChildren();
    if (winnerRider) {
      const winnerLink = document.createElement("a");
      winnerLink.href = `riders.html#rider-${encodeURIComponent(winnerRider.id)}`;
      winnerLink.textContent = result.winner.name;
      winnerHeading.append(winnerLink, `: победа на этапе ${stage.number}`);
    } else {
      winnerHeading.textContent = `${result.winner.name}: победа на этапе ${stage.number}`;
    }
    byId("stageResultStatus").textContent = resultStatusLabel(result.status);
    byId("stageResultStatus").className = `tag ${result.status === "official" ? "ok" : "warn"}`;
    byId("stageWinnerTeam").textContent = result.winner.team || "не подтверждено";
    byId("stageWinningTime").textContent = result.winningTime || "не подтверждено";
    byId("stageTop3").innerHTML = (result.top3 || [])
      .map((item) => `<li><strong>${item.name}</strong><br><small>${item.team || ""}${item.time ? ` · ${item.time}` : ""}${item.gap ? ` · ${item.gap}` : ""}</small></li>`)
      .join("");
    byId("stageResultSummary").textContent = result.summary || "";
  }

  function renderJerseySnapshot() {
    const result = latestCompletedResult();
    const jerseys = result && result.jerseysAfterStage ? result.jerseysAfterStage : {};

    byId("jerseySnapshotStage").textContent = result
      ? `После этапа ${result.stage} · ${resultStatusLabel(result.status)}`
      : "Официальные майки появятся после первого результата.";
    byId("jerseyYellow").textContent = riderLabel(jerseys.yellow);
    byId("jerseyGreen").textContent = riderLabel(jerseys.green);
    byId("jerseyPolkaDot").textContent = riderLabel(jerseys.polkaDot);
    byId("jerseyWhite").textContent = riderLabel(jerseys.white);
  }

  function renderNextStage(stage) {
    const next = nextStageAfter(stage);
    const card = byId("nextStageCard");

    if (!next) {
      card.hidden = true;
      return;
    }

    card.hidden = false;
    byId("nextStageDate").textContent = next.label;
    byId("nextStageTitle").textContent = `Этап ${next.number}: ${next.route}`;
    byId("nextStageType").textContent = next.type;
    byId("nextStageDistance").textContent = next.distance;
    byId("nextStageGc").textContent = next.gcImpact;
    byId("nextStageAdvice").textContent = next.viewingAdvice;
  }

  function renderRiderPreview(stage) {
    const picked = [];

    stage.favorites.forEach((favorite) => {
      const rider = findRiderByFavorite(favorite);
      if (rider && !picked.some((item) => item.id === rider.id)) picked.push(rider);
    });

    data.riders
      .filter((rider) => (rider.roles || []).includes("GC"))
      .forEach((rider) => {
        if (picked.length < 6 && !picked.some((item) => item.id === rider.id)) picked.push(rider);
      });

    byId("ridersPreview").innerHTML = picked.slice(0, 6).map((rider) => `
      <li>
        <a href="riders.html">${rider.name}</a>
        <span>${rider.team} · ${(rider.roles || []).join(", ")}</span>
      </li>
    `).join("");
  }

  function renderStage(stage) {
    byId("stageDate").textContent = stage.label;
    byId("stageTitle").textContent = `Этап ${stage.number}: ${stage.route}`;
    byId("stageMeta").textContent = `${stage.type} · ${stage.distance}`;
    byId("stageStatus").textContent = stage.status;
    byId("watchPriority").textContent = `Просмотр ${stage.watchPriority}`;
    byId("stageStartTime").textContent = stage.startTime || "уточнить перед этапом";
    byId("stageFinishWindow").textContent = stage.finishWindow || "уточнить перед этапом";
    byId("keyKilometers").textContent = stage.keyKilometers;
    byId("gcImpact").textContent = stage.gcImpact;
    byId("difficulty").textContent = stage.difficulty;
    byId("stageGuide").textContent = stage.guide;

    byId("highlightChannel").href = data.videoSource.channelUrl;
    byId("resultsLink").href = data.links.results;
    byId("liveTracker").href = data.links.live;

    renderStageHighlights(stage);
    renderStageResult(stage);
    renderNextStage(stage);
    renderRiderPreview(stage);
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

  function renderStagesTable() {
    const tbody = byId("stagesTable").querySelector("tbody");
    tbody.innerHTML = data.stages
      .map((stage) => {
        const result = stageResult(stage.number);
        const highlights = stageHighlights(stage.number).filter((item) => !item.isShort);
        const resultCell = result && ["preliminary", "official"].includes(result.status)
          ? `${tag(resultStatusLabel(result.status), result.status === "official" ? "ok" : "warn")} ${result.winner.name}`
          : tag("Ожидается", "warn");
        const highlightCell = highlights.length
          ? `<a href="${highlights[0].url}" target="_blank" rel="noreferrer">${highlights.length} видео</a>`
          : "нет";

        return `
          <tr>
            <td>${stage.label}</td>
            <td>${stage.number}</td>
            <td><a href="${stage.map}" target="_blank" rel="noreferrer">${stage.route}</a></td>
            <td>${stage.type}</td>
            <td>${resultCell}</td>
            <td>${highlightCell}</td>
          </tr>
        `;
      })
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
    byId("resultsStatus").textContent = status.results || "не настроено";
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
    renderJerseySnapshot();
    renderStageSelect();
    renderStagesTable();
    renderLatestHighlights();
    renderDataStatus();
  }

  init();
})();
