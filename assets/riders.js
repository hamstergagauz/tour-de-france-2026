(function () {
  const data = window.TDF_DATA || {};
  const allRiders = Array.isArray(data.riders) ? data.riders : [];
  const grid = document.getElementById("riderGrid");
  const tbody = document.querySelector("#riderTable tbody");
  const buttons = document.querySelectorAll("[data-filter]");

  function roleClass(role) {
    if (role === "GC") return "gc";
    if (role === "Спринтер") return "sprint";
    if (role === "Этапы") return "stage";
    return "risk";
  }

  function socialLinks(rider) {
    const social = rider.social || {};
    const links = [];
    if (social.instagram) {
      links.push(`<a href="https://www.instagram.com/${social.instagram}/" target="_blank" rel="noopener">Instagram</a>`);
    }
    if (social.facebook) {
      links.push(`<a href="https://www.facebook.com/${social.facebook}" target="_blank" rel="noopener">Facebook</a>`);
    }
    if (social.x) {
      links.push(`<a href="https://x.com/${social.x}" target="_blank" rel="noopener">X</a>`);
    }
    return links.length ? links.join("") : `<span class="small">нет проверенной ссылки</span>`;
  }

  function includedRiders() {
    const latestWinnerId = latestCompletedResult()?.winner?.riderId;

    return allRiders
      .filter((rider) => {
        const inclusion = rider.inclusion || {};
        return inclusion.editorial || inclusion.stageWinner || inclusion.jerseyHolder;
      })
      .sort((left, right) => {
        if (left.id === latestWinnerId && right.id !== latestWinnerId) return -1;
        if (right.id === latestWinnerId && left.id !== latestWinnerId) return 1;

        const leftCurated = left.entryType === "curated";
        const rightCurated = right.entryType === "curated";
        if (leftCurated && rightCurated) {
          return Number(left.editorialOrder || 0) - Number(right.editorialOrder || 0);
        }
        if (leftCurated !== rightCurated) {
          return leftCurated ? -1 : 1;
        }

        const stageDelta = Number(right.latestQualifyingStage || 0) - Number(left.latestQualifyingStage || 0);
        if (stageDelta !== 0) return stageDelta;
        return String(left.name || "").localeCompare(String(right.name || ""), "ru");
      });
  }

  function stageResults() {
    return Array.isArray(data.stageResults) ? data.stageResults : Object.values(data.stageResults || {});
  }

  function latestCompletedResult() {
    return [...stageResults()]
      .filter((result) => ["preliminary", "official"].includes(result.status))
      .sort((a, b) => b.stage - a.stage)[0];
  }

  function raceSourceTags(rider) {
    const tags = [];
    const inclusion = rider.inclusion || {};
    if (inclusion.editorial) tags.push({ label: "Редакция", className: "info" });
    if ((rider.stageWinnerStages || []).length) tags.push({ label: "Победитель этапа", className: "stage" });
    if (inclusion.jerseyHolder) tags.push({ label: "Лидер классификации", className: "gc" });
    if (rider.entryType === "derived") tags.push({ label: "Добавлен по ходу гонки", className: "derived" });
    if (rider.reviewNeeded) tags.push({ label: "Нужна проверка", className: "warn" });
    return tags;
  }

  function riderResultBadges(rider) {
    const wonStages = [...(rider.stageWinnerStages || [])].sort((a, b) => a - b);
    const latest = latestCompletedResult();
    const badges = [];

    if (wonStages.length === 1) badges.push({ label: `Победа: этап ${wonStages[0]}`, className: "win" });
    if (wonStages.length > 1) badges.push({ label: `Победы: этапы ${wonStages.join(", ")}`, className: "win" });

    if (latest && latest.jerseysAfterStage) {
      const jerseys = latest.jerseysAfterStage;
      if (jerseys.yellow && jerseys.yellow.riderId === rider.id) badges.push({ label: "Жёлтая майка", className: "yellow" });
      if (jerseys.green && jerseys.green.riderId === rider.id) badges.push({ label: "Зелёная майка", className: "green" });
      if (jerseys.polkaDot && jerseys.polkaDot.riderId === rider.id) badges.push({ label: "Гороховая майка", className: "polka" });
      if (jerseys.white && jerseys.white.riderId === rider.id) badges.push({ label: "Белая майка", className: "white" });
    }

    return badges;
  }

  function stageList(stages, singular, plural) {
    if (stages.length === 1) return `${singular} ${stages[0]}`;
    return `${plural} ${stages.join(", ")}`;
  }

  function riderHistory(rider) {
    const history = [
      {
        label: "Победа",
        pluralLabel: "Победы",
        singular: "этап",
        plural: "этапы",
        stages: [...(rider.stageWinnerStages || [])]
      },
      {
        label: "Жёлтая майка",
        pluralLabel: "Жёлтая майка",
        singular: "после этапа",
        plural: "после этапов",
        stages: [...((rider.jerseyHistory && rider.jerseyHistory.yellow) || [])]
      },
      {
        label: "Зелёная майка",
        pluralLabel: "Зелёная майка",
        singular: "после этапа",
        plural: "после этапов",
        stages: [...((rider.jerseyHistory && rider.jerseyHistory.green) || [])]
      },
      {
        label: "Гороховая майка",
        pluralLabel: "Гороховая майка",
        singular: "после этапа",
        plural: "после этапов",
        stages: [...((rider.jerseyHistory && rider.jerseyHistory.polkaDot) || [])]
      },
      {
        label: "Белая майка",
        pluralLabel: "Белая майка",
        singular: "после этапа",
        plural: "после этапов",
        stages: [...((rider.jerseyHistory && rider.jerseyHistory.white) || [])]
      }
    ];

    return history
      .map((item) => ({ ...item, stages: item.stages.sort((a, b) => a - b) }))
      .filter((item) => item.stages.length);
  }

  function resultBadgesHtml(rider) {
    const badges = riderResultBadges(rider);
    if (!badges.length) return "";
    return `<div class="result-badges">${badges.map((badge) => `<span class="result-badge ${badge.className}">${badge.label}</span>`).join("")}</div>`;
  }

  function riderHistoryHtml(rider) {
    const history = riderHistory(rider);
    if (!history.length) return "";
    return `
      <div class="race-history">
        ${history.map((item) => `<span><strong>${item.stages.length === 1 ? item.label : item.pluralLabel}:</strong> ${stageList(item.stages, item.singular, item.plural)}</span>`).join("")}
      </div>
    `;
  }

  function sourceTagsHtml(rider) {
    const tags = raceSourceTags(rider);
    if (!tags.length) return "";
    return `<div class="meta source-meta">${tags.map((tag) => `<span class="tag ${tag.className}">${tag.label}</span>`).join("")}</div>`;
  }

  function cssUrl(value) {
    return String(value).replace(/\\/g, "\\\\").replace(/'/g, "\\'");
  }

  function riderImageHtml(rider) {
    if (rider.image) {
      return `
        <div class="photo" style="--photo-url: url('${cssUrl(rider.image)}')">
          <img src="${rider.image}" alt="${rider.name}" loading="lazy" style="object-position: ${rider.imagePosition || "center center"}" onerror="this.onerror=null;this.remove();this.closest('.photo').classList.add('photo-placeholder');">
          <span class="badge">${rider.entryType === "derived" ? "По гонке" : (rider.chance || "Редакция")}</span>
        </div>
      `;
    }

    return `
        <div class="photo photo-placeholder">
        <div class="placeholder-mark">Гонщик</div>
        <span class="badge">${rider.entryType === "derived" ? "По гонке" : (rider.chance || "Редакция")}</span>
      </div>
    `;
  }

  function riderDescriptionHtml(rider) {
    if (rider.entryType === "derived") {
      return `
        <p>Этот профиль был добавлен автоматически по официальным результатам Tour de France, чтобы страница включала победителей этапов и держателей маек без ручной задержки.</p>
        <p class="small"><strong>Статус:</strong> ${rider.reviewNeeded ? "нужна ручная проверка личности и карточки" : "официально добавлен по результатам"}</p>
      `;
    }

    return `
      <div class="meta">
        ${(rider.roles || []).map((role) => `<span class="tag ${roleClass(role)}">${role}</span>`).join("")}
      </div>
      <p>${rider.why || ""}</p>
      <p class="small"><strong>Результаты:</strong> ${rider.results || "уточнить"}</p>
      <p class="small"><strong>Смотреть:</strong> этапы ${rider.watch || "уточнить"}</p>
      <p class="small social"><strong>Проверить:</strong> ${socialLinks(rider)}</p>
      <p class="small"><strong>Риск:</strong> ${rider.risk || "уточнить"}</p>
    `;
  }

  function render(filter = "all") {
    const riders = includedRiders();
    const filtered = filter === "all" ? riders : riders.filter((rider) => (rider.roles || []).includes(filter));

    grid.innerHTML = filtered.map((rider) => `
      <article id="rider-${rider.id}" class="card ${rider.entryType === "derived" ? "card-derived" : ""}" tabindex="-1">
        ${riderImageHtml(rider)}
        <div class="card-body">
          <h3>${rider.name}</h3>
          <p class="team">${rider.team || "Команда не подтверждена"}${rider.country ? ` · ${rider.country}` : ""}</p>
          ${sourceTagsHtml(rider)}
          ${resultBadgesHtml(rider)}
          ${riderHistoryHtml(rider)}
          ${riderDescriptionHtml(rider)}
        </div>
      </article>
    `).join("");

    focusRiderFromHash();

    tbody.innerHTML = riders.map((rider) => `
      <tr>
        <td><strong>${rider.name}</strong><br><span class="small">${rider.country || "страна не подтверждена"}</span>${sourceTagsHtml(rider)}${resultBadgesHtml(rider)}${riderHistoryHtml(rider)}</td>
        <td>${rider.team || "не подтверждено"}</td>
        <td>${rider.entryType === "derived" ? "Добавлен по ходу гонки" : ((rider.roles || []).join(", ") || "Редакция")}</td>
        <td>${rider.entryType === "derived" ? "Автодобавлен по официальным результатам Tour de France." : (rider.why || "—")}</td>
        <td>${rider.entryType === "derived" ? (rider.reviewNeeded ? "Нужна проверка" : "Покрытие по официальным результатам") : (rider.results || "—")}</td>
        <td>${rider.entryType === "derived" ? (rider.latestQualifyingStage ? `последний этап включения ${rider.latestQualifyingStage}` : "—") : (rider.watch || "—")}</td>
        <td class="social">${rider.entryType === "derived" ? `<span class="small">нет curated links</span>` : socialLinks(rider)}</td>
      </tr>
    `).join("");
  }

  function focusRiderFromHash() {
    const targetId = window.location.hash.slice(1);
    if (!targetId.startsWith("rider-")) return;

    const card = document.getElementById(targetId);
    if (!card) return;

    requestAnimationFrame(() => {
      card.scrollIntoView({ block: "center" });
      card.focus({ preventScroll: true });
    });
  }

  buttons.forEach((button) => {
    button.addEventListener("click", () => {
      buttons.forEach((item) => item.classList.remove("active"));
      button.classList.add("active");
      render(button.dataset.filter);
    });
  });

  window.addEventListener("hashchange", focusRiderFromHash);

  render();
})();
