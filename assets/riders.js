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
        <td><strong>${rider.name}</strong><br><span class="small">${rider.country}</span></td>
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
