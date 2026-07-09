(function () {
  const data = window.TDF_DATA || {};
  const gc = data.generalClassification;

  function byId(id) {
    return document.getElementById(id);
  }

  function formatDateTime(value) {
    if (!value) return "не проверялось";
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

  function setText(parent, selector, value) {
    const element = parent.querySelector(selector);
    element.textContent = value || "";
  }

  function stageResults() {
    return Array.isArray(data.stageResults) ? data.stageResults : Object.values(data.stageResults || {});
  }

  function latestCompletedResult() {
    const results = stageResults()
      .filter((result) => ["preliminary", "official"].includes(result.status))
      .sort((a, b) => a.stage - b.stage);
    return results[results.length - 1];
  }

  function setLeader(id, value) {
    const element = byId(id);
    if (element) element.textContent = value || "не подтверждено";
  }

  function renderClassificationLeaders() {
    const leaders = byId("classificationLeaders");
    const result = latestCompletedResult();
    const jerseys = result && result.jerseysAfterStage ? result.jerseysAfterStage : null;

    if (!leaders || !jerseys) return;

    setLeader("leaderYellow", jerseys.yellow?.name);
    setLeader("leaderGreen", jerseys.green?.name);
    setLeader("leaderPolkaDot", jerseys.polkaDot?.name);
    setLeader("leaderWhite", jerseys.white?.name);
    leaders.hidden = false;
  }

  function renderGeneralClassification() {
    const section = byId("generalClassificationSection");
    const tbody = byId("generalClassificationTable");

    if (!section || !tbody || !gc || !Array.isArray(gc.standings) || !gc.standings.length) {
      return;
    }

    byId("generalClassificationTitle").textContent = `Общий зачёт после этапа ${gc.stage}`;
    byId("generalClassificationMeta").textContent = `${gc.status || "не подтверждено"} · обновлено ${formatDateTime(gc.checkedAt)}`;
    byId("generalClassificationSource").href = gc.sourceUrl || data.links?.results || "https://www.letour.fr/en/rankings";

    const rows = gc.standings.slice(0, 10).map((standing) => {
      const row = document.createElement("tr");
      row.innerHTML = `
        <td class="gc-position"></td>
        <td><strong class="gc-rider"></strong></td>
        <td class="gc-team"></td>
        <td class="gc-time"></td>
      `;
      setText(row, ".gc-position", standing.position);
      setText(row, ".gc-rider", standing.name);
      setText(row, ".gc-team", standing.team);
      row.querySelector(".gc-team").title = standing.team || "";
      setText(row, ".gc-time", standing.position === 1 ? standing.totalTime : (standing.gap || standing.totalTime));
      return row;
    });

    tbody.replaceChildren(...rows);
    section.hidden = false;
  }

  renderClassificationLeaders();
  renderGeneralClassification();
})();
