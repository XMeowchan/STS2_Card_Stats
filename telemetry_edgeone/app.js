const API_ENDPOINT = "/v1/stats";
const MAX_TABLE_ROWS = 14;

const fields = {
  totalInstallations: document.querySelector('[data-field="totalInstallations"]'),
  latestNewUsers: document.querySelector('[data-field="latestNewUsers"]'),
  latestActiveUsers: document.querySelector('[data-field="latestActiveUsers"]'),
  avgActiveUsers: document.querySelector('[data-field="avgActiveUsers"]'),
  generatedAt: document.querySelector('[data-field="generatedAt"]'),
  rangeDays: document.querySelector('[data-field="rangeDays"]'),
};

const chartSvg = document.getElementById("trend-chart");
const chartLoading = document.getElementById("chart-loading");
const tableBody = document.getElementById("stats-table-body");
const insightList = document.getElementById("insight-list");
const insightTemplate = document.getElementById("insight-item-template");
const rangeButtons = Array.from(document.querySelectorAll(".range-chip"));
const supportedRanges = new Set([30, 90, 365]);

let currentDays = getInitialDays();

function formatNumber(value) {
  return new Intl.NumberFormat("zh-CN").format(Number(value) || 0);
}

function formatDateLabel(dateString) {
  const date = new Date(`${dateString}T00:00:00`);
  return new Intl.DateTimeFormat("zh-CN", { month: "short", day: "numeric" }).format(date);
}

function formatTimestamp(value) {
  const date = new Date(value);
  return new Intl.DateTimeFormat("zh-CN", {
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
  }).format(date);
}

function average(values) {
  if (!values.length) {
    return 0;
  }

  return values.reduce((sum, item) => sum + item, 0) / values.length;
}

function setLoadingState(isLoading) {
  chartLoading.hidden = !isLoading;
  if (isLoading) {
    chartLoading.textContent = "正在加载趋势数据…";
  }
}

function setRange(days) {
  currentDays = days;
  const url = new URL(window.location.href);
  url.searchParams.set("days", String(days));
  window.history.replaceState({}, "", url);
  rangeButtons.forEach((button) => {
    button.classList.toggle("is-active", Number(button.dataset.days) === days);
  });
}

function getInitialDays() {
  const queryValue = Number(new URLSearchParams(window.location.search).get("days"));
  return supportedRanges.has(queryValue) ? queryValue : 365;
}

function renderSummary(data) {
  const latest = data.latest || {};
  const recentDays = data.days.slice(-7);

  fields.totalInstallations.textContent = formatNumber(data.total_installations);
  fields.latestNewUsers.textContent = formatNumber(latest.new_users);
  fields.latestActiveUsers.textContent = formatNumber(latest.active_users);
  fields.avgActiveUsers.textContent = average(recentDays.map((item) => item.active_users)).toFixed(1);
  fields.generatedAt.textContent = formatTimestamp(data.generated_at);
  fields.rangeDays.textContent = formatNumber(data.range_days);
}

function renderInsights(data) {
  insightList.innerHTML = "";

  const days = data.days;
  const latest = days[days.length - 1] || { new_users: 0, active_users: 0, cumulative_users: 0 };
  const previous = days[days.length - 2] || latest;
  const peakActive = days.reduce((best, item) => (item.active_users > best.active_users ? item : best), days[0] || latest);
  const peakNew = days.reduce((best, item) => (item.new_users > best.new_users ? item : best), days[0] || latest);
  const growth = previous.cumulative_users > 0
    ? ((latest.cumulative_users - previous.cumulative_users) / previous.cumulative_users) * 100
    : latest.cumulative_users > 0
      ? 100
      : 0;

  const insightItems = [
    {
      label: "累计增长",
      value: `${growth >= 0 ? "+" : ""}${growth.toFixed(1)}%`,
      note: `相较 ${previous.day || latest.day || "最近一期"} 的累计安装量变化。`,
    },
    {
      label: "活跃峰值",
      value: `${formatNumber(peakActive.active_users)} / ${peakActive.day || "--"}`,
      note: "帮助快速定位最近最热的一天。",
    },
    {
      label: "新增峰值",
      value: `${formatNumber(peakNew.new_users)} / ${peakNew.day || "--"}`,
      note: "适合对照推广动作或版本发布时间。",
    },
  ];

  for (const item of insightItems) {
    const node = insightTemplate.content.firstElementChild.cloneNode(true);
    node.querySelector(".insight-label").textContent = item.label;
    node.querySelector(".insight-value").textContent = item.value;
    node.querySelector(".insight-note").textContent = item.note;
    insightList.appendChild(node);
  }
}

function renderTable(data) {
  const rows = data.days.slice(-MAX_TABLE_ROWS).reverse();

  if (!rows.length) {
    tableBody.innerHTML = '<tr><td colspan="4" class="table-empty">暂无可展示的数据。</td></tr>';
    return;
  }

  tableBody.innerHTML = rows.map((item) => `
    <tr>
      <td>${item.day}</td>
      <td data-type="number">${formatNumber(item.new_users)}</td>
      <td data-type="number">${formatNumber(item.active_users)}</td>
      <td data-type="number">${formatNumber(item.cumulative_users)}</td>
    </tr>
  `).join("");
}

function createSvgElement(tagName, attributes = {}) {
  const element = document.createElementNS("http://www.w3.org/2000/svg", tagName);
  Object.entries(attributes).forEach(([key, value]) => element.setAttribute(key, String(value)));
  return element;
}

function buildLinePoints(data, valueKey, width, height, padding, maxValue) {
  if (!data.length) {
    return "";
  }

  const innerWidth = width - padding.left - padding.right;
  const innerHeight = height - padding.top - padding.bottom;
  const stepX = data.length === 1 ? 0 : innerWidth / (data.length - 1);

  return data.map((item, index) => {
    const x = padding.left + stepX * index;
    const y = padding.top + innerHeight - (item[valueKey] / maxValue) * innerHeight;
    return `${x},${y}`;
  }).join(" ");
}

function renderChart(data) {
  const days = data.days;
  chartSvg.innerHTML = "";

  if (!days.length) {
    chartSvg.appendChild(createSvgElement("text", { x: 40, y: 60, class: "chart-axis-text" }));
    chartSvg.lastChild.textContent = "暂无可视化数据";
    return;
  }

  const width = 1000;
  const height = 420;
  const padding = { top: 26, right: 30, bottom: 60, left: 56 };
  const maxValue = Math.max(
    1,
    ...days.flatMap((item) => [item.new_users, item.active_users, item.cumulative_users]),
  );
  const innerHeight = height - padding.top - padding.bottom;
  const ticks = 4;

  for (let index = 0; index <= ticks; index += 1) {
    const y = padding.top + (innerHeight / ticks) * index;
    const value = Math.round(maxValue - (maxValue / ticks) * index);
    chartSvg.appendChild(createSvgElement("line", {
      x1: padding.left,
      x2: width - padding.right,
      y1: y,
      y2: y,
      class: "chart-grid-line",
    }));

    const text = createSvgElement("text", {
      x: padding.left - 12,
      y: y + 5,
      class: "chart-axis-text",
      "text-anchor": "end",
    });
    text.textContent = formatNumber(value);
    chartSvg.appendChild(text);
  }

  const xLabels = [0, Math.floor((days.length - 1) / 2), days.length - 1]
    .filter((value, index, array) => array.indexOf(value) === index);
  const innerWidth = width - padding.left - padding.right;
  const stepX = days.length === 1 ? 0 : innerWidth / (days.length - 1);

  for (const labelIndex of xLabels) {
    const x = padding.left + stepX * labelIndex;
    const text = createSvgElement("text", {
      x,
      y: height - 22,
      class: "chart-axis-text",
      "text-anchor": labelIndex === 0 ? "start" : labelIndex === days.length - 1 ? "end" : "middle",
    });
    text.textContent = formatDateLabel(days[labelIndex].day);
    chartSvg.appendChild(text);
  }

  const series = [
    { key: "new_users", className: "chart-series chart-series--new", dotClass: "chart-dot chart-dot--new" },
    { key: "active_users", className: "chart-series chart-series--active", dotClass: "chart-dot chart-dot--active" },
    { key: "cumulative_users", className: "chart-series chart-series--cumulative", dotClass: "chart-dot chart-dot--cumulative" },
  ];

  for (const item of series) {
    const points = buildLinePoints(days, item.key, width, height, padding, maxValue);
    chartSvg.appendChild(createSvgElement("polyline", { points, class: item.className }));
  }

  const latestIndex = days.length - 1;
  const latestX = padding.left + stepX * latestIndex;
  const latestItems = [
    { key: "new_users", className: "chart-dot chart-dot--new" },
    { key: "active_users", className: "chart-dot chart-dot--active" },
    { key: "cumulative_users", className: "chart-dot chart-dot--cumulative" },
  ];

  latestItems.forEach((item) => {
    const y = padding.top + innerHeight - (days[latestIndex][item.key] / maxValue) * innerHeight;
    chartSvg.appendChild(createSvgElement("circle", {
      cx: latestX,
      cy: y,
      r: 6,
      class: item.className,
    }));
  });
}

function renderError(message) {
  const safeMessage = message || "加载失败，请稍后再试。";
  chartSvg.innerHTML = "";
  insightList.innerHTML = `<div class="error-state">${safeMessage}</div>`;
  tableBody.innerHTML = `<tr><td colspan="4" class="table-empty">${safeMessage}</td></tr>`;
}

async function fetchStats(days) {
  const response = await fetch(`${API_ENDPOINT}?days=${days}`, {
    headers: {
      Accept: "application/json",
    },
  });

  if (!response.ok) {
    throw new Error(`接口返回 ${response.status}`);
  }

  const payload = await response.json();
  if (!payload.ok) {
    throw new Error("接口返回失败状态");
  }

  return payload;
}

async function loadDashboard(days) {
  setRange(days);
  setLoadingState(true);

  try {
    const data = await fetchStats(days);
    renderSummary(data);
    renderInsights(data);
    renderChart(data);
    renderTable(data);
  } catch (error) {
    renderError(error instanceof Error ? error.message : String(error));
  } finally {
    setLoadingState(false);
  }
}

rangeButtons.forEach((button) => {
  button.addEventListener("click", () => {
    const nextDays = Number(button.dataset.days);
    if (nextDays !== currentDays) {
      loadDashboard(nextDays);
    }
  });
});

loadDashboard(currentDays);

