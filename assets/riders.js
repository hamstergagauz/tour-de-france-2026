(function () {
  const riders = window.TDF_DATA.riders;
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

  function stageResults() {
    return Array.isArray(window.TDF_DATA.stageResults) ? window.TDF_DATA.stageResults : Object.values(window.TDF_DATA.stageResults || {});
  }

  function latestCompletedResult() {
    return [...stageResults()]
      .filter((result) => ["preliminary", "official"].includes(result.status))
      .sort((a, b) => b.stage - a.stage)[0];
  }

  function riderResultBadges(rider) {
    const results = stageResults();
    const wonStages = results
      .filter((result) => result.winner && result.winner.riderId === rider.id)
      .map((result) => result.stage)
      .sort((a, b) => a - b);
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
    const results = stageResults()
      .filter((result) => ["preliminary", "official"].includes(result.status))
      .sort((a, b) => a.stage - b.stage);
    const history = [
      {
        label: "Победа",
        pluralLabel: "Победы",
        singular: "этап",
        plural: "этапы",
        stages: results
          .filter((result) => result.winner && result.winner.riderId === rider.id)
          .map((result) => result.stage)
      },
      {
        label: "Жёлтая майка",
        pluralLabel: "Жёлтая майка",
        singular: "после этапа",
        plural: "после этапов",
        stages: results
          .filter((result) => result.jerseysAfterStage && result.jerseysAfterStage.yellow && result.jerseysAfterStage.yellow.riderId === rider.id)
          .map((result) => result.stage)
      },
      {
        label: "Зелёная майка",
        pluralLabel: "Зелёная майка",
        singular: "после этапа",
        plural: "после этапов",
        stages: results
          .filter((result) => result.jerseysAfterStage && result.jerseysAfterStage.green && result.jerseysAfterStage.green.riderId === rider.id)
          .map((result) => result.stage)
      },
      {
        label: "Гороховая майка",
        pluralLabel: "Гороховая майка",
        singular: "после этапа",
        plural: "после этапов",
        stages: results
          .filter((result) => result.jerseysAfterStage && result.jerseysAfterStage.polkaDot && result.jerseysAfterStage.polkaDot.riderId === rider.id)
          .map((result) => result.stage)
      },
      {
        label: "Белая майка",
        pluralLabel: "Белая майка",
        singular: "после этапа",
        plural: "после этапов",
        stages: results
          .filter((result) => result.jerseysAfterStage && result.jerseysAfterStage.white && result.jerseysAfterStage.white.riderId === rider.id)
          .map((result) => result.stage)
      }
    ];

    return history.filter((item) => item.stages.length);
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

  function cssUrl(value) {
    return String(value).replace(/\\/g, "\\\\").replace(/'/g, "\\'");
  }

  function render(filter = "all") {
    const filtered = filter === "all" ? riders : riders.filter((rider) => rider.roles.includes(filter));
    grid.innerHTML = filtered.map((rider) => `
      <article class="card">
        <div class="photo" style="--photo-url: url('${cssUrl(rider.image)}')">
          <img src="${rider.image}" alt="${rider.name}" loading="lazy" style="object-position: ${rider.imagePosition || "center center"}" onerror="this.onerror=null;this.src='assets/riders/placeholder.jpg';this.closest('.photo').style.setProperty('--photo-url', 'url(assets/riders/placeholder.jpg)');">
          <span class="badge">${rider.chance}</span>
        </div>
        <div class="card-body">
          <h3>${rider.name}</h3>
          <p class="team">${rider.team} · ${rider.country}</p>
          ${resultBadgesHtml(rider)}
          ${riderHistoryHtml(rider)}
          <div class="meta">
            ${rider.roles.map((role) => `<span class="tag ${roleClass(role)}">${role}</span>`).join("")}
          </div>
          <p>${rider.why}</p>
          <p class="small"><strong>Результаты:</strong> ${rider.results}</p>
          <p class="small"><strong>Смотреть:</strong> этапы ${rider.watch}</p>
          <p class="small social"><strong>Проверить:</strong> ${socialLinks(rider)}</p>
          <p class="small"><strong>Риск:</strong> ${rider.risk}</p>
        </div>
      </article>
    `).join("");

    tbody.innerHTML = riders.map((rider) => `
      <tr>
        <td><strong>${rider.name}</strong><br><span class="small">${rider.country}</span>${resultBadgesHtml(rider)}${riderHistoryHtml(rider)}</td>
        <td>${rider.team}</td>
        <td>${rider.roles.join(", ")}</td>
        <td>${rider.why}</td>
        <td>${rider.results}</td>
        <td>${rider.watch}</td>
        <td class="social">${socialLinks(rider)}</td>
      </tr>
    `).join("");
  }

  buttons.forEach((button) => {
    button.addEventListener("click", () => {
      buttons.forEach((item) => item.classList.remove("active"));
      button.classList.add("active");
      render(button.dataset.filter);
    });
  });

  render();
})();
