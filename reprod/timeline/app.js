"use strict";

const DATA_URL = "../08-tool-code-occurrences-results.json";
const SVG_NS = "http://www.w3.org/2000/svg";
const WORLD = { width: 1000, height: 700 };

const elements = {
  svg: document.querySelector("#ecosystem-map"),
  viewport: document.querySelector("#viewport-layer"),
  edgeLayer: document.querySelector("#edge-layer"),
  nodeLayer: document.querySelector("#node-layer"),
  loadState: document.querySelector("#load-state"),
  loadMessage: document.querySelector("#load-message"),
  search: document.querySelector("#tool-search"),
  options: document.querySelector("#tool-options"),
  clearSelection: document.querySelector("#clear-selection"),
  inspectorMode: document.querySelector("#inspector-mode"),
  inspectorTitle: document.querySelector("#inspector-title"),
  comparisonLabel: document.querySelector("#comparison-label"),
  inspectorContent: document.querySelector("#inspector-content"),
  play: document.querySelector("#play-toggle"),
  monthSlider: document.querySelector("#month-slider"),
  monthOutput: document.querySelector("#month-output"),
  timelineStart: document.querySelector("#timeline-start"),
  timelineEnd: document.querySelector("#timeline-end"),
  compareMode: document.querySelector("#compare-mode"),
  threshold: document.querySelector("#edge-threshold"),
  thresholdOutput: document.querySelector("#threshold-output"),
  status: document.querySelector("#status-summary"),
  zoomIn: document.querySelector("#zoom-in"),
  zoomOut: document.querySelector("#zoom-out"),
  resetView: document.querySelector("#reset-view"),
};

const state = {
  data: null,
  months: [],
  nodes: [],
  positions: new Map(),
  monthIndex: 0,
  selected: null,
  threshold: 0.05,
  compareMode: "previous",
  playing: false,
  timer: null,
  view: { x: 0, y: 0, scale: 1 },
  pan: null,
};

function svgElement(tag, attributes = {}) {
  const node = document.createElementNS(SVG_NS, tag);
  for (const [name, value] of Object.entries(attributes)) {
    node.setAttribute(name, value);
  }
  return node;
}

function htmlElement(tag, className, text) {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text !== undefined) node.textContent = text;
  return node;
}

function parseMonth(month) {
  const [year, monthNumber] = month.split("-").map(Number);
  return new Date(Date.UTC(year, monthNumber - 1, 1));
}

function formatMonth(month, short = false) {
  return new Intl.DateTimeFormat("en", {
    month: short ? "short" : "long",
    year: "numeric",
    timeZone: "UTC",
  }).format(parseMonth(month));
}

function validTimeline(data) {
  if (!data || typeof data !== "object" || Array.isArray(data)) return false;
  const months = Object.keys(data).filter((key) => /^\d{4}-\d{2}$/.test(key)).sort();
  return months.length > 1 && months.every((month) => data[month] && typeof data[month] === "object");
}

function collectNodes(data, months) {
  const names = new Set();
  for (const month of months) {
    for (const [source, related] of Object.entries(data[month])) {
      names.add(source);
      for (const target of Object.keys(related)) names.add(target);
    }
  }
  return [...names].sort((a, b) => a.localeCompare(b));
}

function edgeKey(source, target) {
  return `${source}\u0000${target}`;
}

function edgesForMonth(month, threshold = state.threshold) {
  const edges = new Map();
  const monthData = state.data[month] || {};

  for (const [source, related] of Object.entries(monthData)) {
    const total = Object.values(related).reduce((sum, count) => sum + count, 0);
    if (!total) continue;

    for (const [target, count] of Object.entries(related)) {
      const weight = count / total;
      if (weight < threshold) continue;
      edges.set(edgeKey(source, target), { source, target, count, weight });
    }
  }
  return edges;
}

function comparisonIndex() {
  if (state.compareMode === "start") return 0;
  return Math.max(0, state.monthIndex - 1);
}

function hashNumber(value) {
  let hash = 2166136261;
  for (let index = 0; index < value.length; index += 1) {
    hash ^= value.charCodeAt(index);
    hash = Math.imul(hash, 16777619);
  }
  return hash >>> 0;
}

function aggregateLayoutEdges() {
  const aggregate = new Map();
  for (const month of state.months) {
    for (const edge of edgesForMonth(month, 0.015).values()) {
      const key = edgeKey(edge.source, edge.target);
      const previous = aggregate.get(key);
      if (!previous || edge.weight > previous.weight) aggregate.set(key, edge);
    }
  }
  return [...aggregate.values()];
}

function computeStableLayout() {
  const nodes = state.nodes.map((name, index) => {
    const angle = (index / state.nodes.length) * Math.PI * 2;
    const jitter = ((hashNumber(name) % 101) - 50) * 0.6;
    const radius = 220 + jitter;
    return {
      name,
      x: WORLD.width / 2 + Math.cos(angle) * radius,
      y: WORLD.height / 2 + Math.sin(angle) * radius,
      vx: 0,
      vy: 0,
    };
  });
  const byName = new Map(nodes.map((node) => [node.name, node]));
  const links = aggregateLayoutEdges()
    .map((edge) => ({ ...edge, sourceNode: byName.get(edge.source), targetNode: byName.get(edge.target) }))
    .filter((edge) => edge.sourceNode && edge.targetNode);

  for (let iteration = 0; iteration < 420; iteration += 1) {
    const cooling = 1 - iteration / 420;

    for (let first = 0; first < nodes.length; first += 1) {
      for (let second = first + 1; second < nodes.length; second += 1) {
        const a = nodes[first];
        const b = nodes[second];
        let dx = b.x - a.x;
        let dy = b.y - a.y;
        const distanceSquared = Math.max(64, dx * dx + dy * dy);
        const distance = Math.sqrt(distanceSquared);
        const force = (16000 / distanceSquared) * cooling;
        dx /= distance;
        dy /= distance;
        a.vx -= dx * force;
        a.vy -= dy * force;
        b.vx += dx * force;
        b.vy += dy * force;
      }
    }

    for (const link of links) {
      const dx = link.targetNode.x - link.sourceNode.x;
      const dy = link.targetNode.y - link.sourceNode.y;
      const distance = Math.max(1, Math.hypot(dx, dy));
      const desired = 140 + (1 - Math.min(1, link.weight)) * 110;
      const force = (distance - desired) * (0.0015 + link.weight * 0.007) * cooling;
      const nx = dx / distance;
      const ny = dy / distance;
      link.sourceNode.vx += nx * force;
      link.sourceNode.vy += ny * force;
      link.targetNode.vx -= nx * force;
      link.targetNode.vy -= ny * force;
    }

    for (const node of nodes) {
      node.vx += (WORLD.width / 2 - node.x) * 0.0003 * cooling;
      node.vy += (WORLD.height / 2 - node.y) * 0.0003 * cooling;
      node.vx *= 0.82;
      node.vy *= 0.82;
      node.x = Math.max(42, Math.min(WORLD.width - 42, node.x + node.vx));
      node.y = Math.max(42, Math.min(WORLD.height - 42, node.y + node.vy));
    }
  }

  state.positions = new Map(nodes.map((node) => [node.name, { x: node.x, y: node.y }]));
}

function nodeScores(edges) {
  const scores = new Map(state.nodes.map((name) => [name, 0.5]));
  for (const edge of edges.values()) {
    scores.set(edge.target, (scores.get(edge.target) || 0.5) + Math.sqrt(edge.weight));
  }
  return scores;
}

function nodeRadius(score) {
  return 6 + Math.min(15, Math.sqrt(score) * 5.2);
}

function joinedEdges(current, baseline) {
  const keys = new Set([...current.keys(), ...baseline.keys()]);
  return [...keys].map((key) => {
    const now = current.get(key);
    const before = baseline.get(key);
    const edge = now || before;
    return {
      ...edge,
      current: now,
      baseline: before,
      delta: (now?.weight || 0) - (before?.weight || 0),
      kind: !before ? "new" : !now ? "removed" : "current",
    };
  });
}

function connectedNames(edges, selected) {
  const names = new Set([selected]);
  for (const edge of edges) {
    if (edge.source === selected) names.add(edge.target);
    if (edge.target === selected) names.add(edge.source);
  }
  return names;
}

function renderGraph() {
  const month = state.months[state.monthIndex];
  const baselineMonth = state.months[comparisonIndex()];
  const current = edgesForMonth(month);
  const baseline = edgesForMonth(baselineMonth);
  const joined = joinedEdges(current, baseline);
  const scores = nodeScores(current);
  const connected = state.selected ? connectedNames(joined, state.selected) : null;

  elements.edgeLayer.replaceChildren();
  elements.nodeLayer.replaceChildren();

  for (const edge of joined.sort((a, b) => (a.current?.weight || 0) - (b.current?.weight || 0))) {
    const source = state.positions.get(edge.source);
    const target = state.positions.get(edge.target);
    if (!source || !target) continue;

    const sourceRadius = nodeRadius(scores.get(edge.source) || 0.5);
    const targetRadius = nodeRadius(scores.get(edge.target) || 0.5);
    const dx = target.x - source.x;
    const dy = target.y - source.y;
    const distance = Math.max(1, Math.hypot(dx, dy));
    const nx = dx / distance;
    const ny = dy / distance;
    const currentWeight = edge.current?.weight || 0;
    const baselineWeight = edge.baseline?.weight || 0;
    const visibleWeight = Math.max(currentWeight, baselineWeight);
    const line = svgElement("line", {
      x1: source.x + nx * sourceRadius,
      y1: source.y + ny * sourceRadius,
      x2: target.x - nx * (targetRadius + 4),
      y2: target.y - ny * (targetRadius + 4),
      "stroke-width": Math.max(0.8, Math.min(4.5, visibleWeight * 11)),
    });
    line.classList.add("edge", `is-${edge.kind}`);
    line.style.opacity = String(0.16 + Math.min(0.54, visibleWeight * 1.3));
    if (edge.kind === "new") line.setAttribute("marker-end", "url(#arrow-new)");
    if (edge.kind === "current") line.setAttribute("marker-end", "url(#arrow-current)");
    if (state.selected) {
      if (edge.source === state.selected || edge.target === state.selected) line.classList.add("is-connected");
      else line.classList.add("is-dimmed");
    }
    elements.edgeLayer.append(line);
  }

  for (const name of state.nodes) {
    const position = state.positions.get(name);
    const radius = nodeRadius(scores.get(name) || 0.5);
    const group = svgElement("g", {
      class: "node",
      transform: `translate(${position.x} ${position.y})`,
      tabindex: "0",
      role: "button",
      "aria-label": `Select ${name}`,
    });
    if (name === state.selected) group.classList.add("is-selected");
    if (connected && !connected.has(name)) group.classList.add("is-dimmed");

    group.append(
      svgElement("circle", { class: "node-hit", r: Math.max(20, radius + 8) }),
      svgElement("circle", { class: "node-dot", r: radius }),
    );
    const label = svgElement("text", {
      class: "node-label",
      x: radius + 6,
      y: 4,
    });
    label.textContent = name;
    group.append(label);

    const title = svgElement("title");
    title.textContent = `${name} · score ${(scores.get(name) || 0.5).toFixed(2)}`;
    group.append(title);

    group.addEventListener("click", () => selectTool(name));
    group.addEventListener("keydown", (event) => {
      if (event.key === "Enter" || event.key === " ") {
        event.preventDefault();
        selectTool(name);
      }
    });
    elements.nodeLayer.append(group);
  }

  renderInspector(current, baseline);
  updateStatus(current);
}

function formatDelta(delta) {
  const value = Math.abs(delta * 100);
  return `${delta >= 0 ? "+" : "−"}${value.toFixed(value >= 10 ? 0 : 1)} pp`;
}

function renderInspector(current, baseline) {
  const currentMonth = state.months[state.monthIndex];
  const baselineMonth = state.months[comparisonIndex()];
  elements.comparisonLabel.textContent = `${formatMonth(currentMonth, true)} − ${formatMonth(baselineMonth, true)}`;
  elements.inspectorContent.replaceChildren();

  if (!state.selected) {
    elements.inspectorMode.textContent = "MONTHLY CHANGE";
    elements.inspectorTitle.textContent = "Largest shifts";
    renderLargestShifts(current, baseline);
    return;
  }

  elements.inspectorMode.textContent = "TOOL DETAIL";
  elements.inspectorTitle.textContent = state.selected;

  const outgoing = [...current.values()]
    .filter((edge) => edge.source === state.selected)
    .sort((a, b) => b.weight - a.weight);
  const incoming = [...current.values()]
    .filter((edge) => edge.target === state.selected)
    .sort((a, b) => b.weight - a.weight);

  renderRelationSection("Refers to", outgoing, baseline, "target");
  renderRelationSection("Referred by", incoming, baseline, "source");
  if (!outgoing.length && !incoming.length) {
    elements.inspectorContent.append(htmlElement("p", "empty-inspector", "No edges above the current floor."));
  }
}

function renderLargestShifts(current, baseline) {
  const changes = joinedEdges(current, baseline)
    .filter((edge) => Math.abs(edge.delta) > 0.0001)
    .sort((a, b) => Math.abs(b.delta) - Math.abs(a.delta))
    .slice(0, 14);

  if (!changes.length) {
    elements.inspectorContent.append(htmlElement("p", "empty-inspector", "No changes at this comparison point."));
    return;
  }

  const list = htmlElement("div", "change-list");
  for (const edge of changes) {
    const row = htmlElement("button", "change-row");
    row.type = "button";
    const copy = htmlElement("span");
    copy.append(
      htmlElement("strong", "", `${edge.source} → ${edge.target}`),
      htmlElement("small", "", `${edge.current?.count || 0} matches`),
    );
    const value = htmlElement("span", `comparison-value ${edge.delta >= 0 ? "is-rise" : "is-fall"}`);
    value.textContent = `${edge.delta >= 0 ? "↑" : "↓"} ${formatDelta(edge.delta)}`;
    row.append(copy, value);
    row.addEventListener("click", () => selectTool(edge.target));
    list.append(row);
  }
  elements.inspectorContent.append(list);
}

function renderRelationSection(title, edges, baseline, otherEnd) {
  if (!edges.length) return;
  const section = htmlElement("section", "relation-section");
  section.append(htmlElement("h3", "", title));
  const list = htmlElement("div", "relation-list");

  for (const edge of edges) {
    const previous = baseline.get(edgeKey(edge.source, edge.target));
    const delta = edge.weight - (previous?.weight || 0);
    const row = htmlElement("button", "relation-row");
    row.type = "button";
    const copy = htmlElement("span");
    copy.append(
      htmlElement("strong", "", edge[otherEnd]),
      htmlElement("small", "", `${edge.count} matches`),
    );
    const value = htmlElement("span", "edge-value", `${(edge.weight * 100).toFixed(1)}%`);
    value.title = `${formatDelta(delta)} from comparison month`;
    row.append(copy, value);
    row.addEventListener("click", () => selectTool(edge[otherEnd]));
    list.append(row);
  }
  section.append(list);
  elements.inspectorContent.append(section);
}

function selectTool(name) {
  state.selected = name;
  elements.search.value = name || "";
  elements.clearSelection.disabled = !name;
  renderGraph();
}

function updateStatus(edges) {
  const monthData = state.data[state.months[state.monthIndex]] || {};
  const activeNodes = new Set(Object.keys(monthData));
  for (const edge of edges.values()) {
    activeNodes.add(edge.source);
    activeNodes.add(edge.target);
  }
  elements.status.textContent = `${activeNodes.size} tools · ${edges.size} edges · floor ${Math.round(state.threshold * 100)}%`;
}

function updateTimeline() {
  const month = state.months[state.monthIndex];
  elements.monthSlider.value = String(state.monthIndex);
  elements.monthOutput.textContent = formatMonth(month);
  renderGraph();
}

function setMonth(index) {
  state.monthIndex = Math.max(0, Math.min(state.months.length - 1, index));
  updateTimeline();
}

function setPlaying(playing) {
  state.playing = playing;
  elements.play.setAttribute("aria-pressed", String(playing));
  elements.play.setAttribute("aria-label", playing ? "Pause timeline" : "Play timeline");
  if (state.timer) window.clearInterval(state.timer);
  state.timer = null;

  if (playing) {
    if (state.monthIndex === state.months.length - 1) setMonth(0);
    const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    state.timer = window.setInterval(() => {
      if (state.monthIndex >= state.months.length - 1) {
        setPlaying(false);
        return;
      }
      setMonth(state.monthIndex + 1);
    }, reducedMotion ? 1400 : 850);
  }
}

function applyView() {
  const { x, y, scale } = state.view;
  elements.viewport.setAttribute("transform", `translate(${x} ${y}) scale(${scale})`);
}

function zoomAt(factor, point = { x: WORLD.width / 2, y: WORLD.height / 2 }) {
  const oldScale = state.view.scale;
  const scale = Math.max(0.55, Math.min(3.5, oldScale * factor));
  state.view.x = point.x - ((point.x - state.view.x) * scale) / oldScale;
  state.view.y = point.y - ((point.y - state.view.y) * scale) / oldScale;
  state.view.scale = scale;
  applyView();
}

function svgPoint(clientX, clientY) {
  const point = elements.svg.createSVGPoint();
  point.x = clientX;
  point.y = clientY;
  return point.matrixTransform(elements.svg.getScreenCTM().inverse());
}

function resetView() {
  state.view = { x: 0, y: 0, scale: 1 };
  applyView();
}

function bindControls() {
  elements.monthSlider.addEventListener("input", (event) => {
    setPlaying(false);
    setMonth(Number(event.target.value));
  });

  elements.play.addEventListener("click", () => setPlaying(!state.playing));
  elements.compareMode.addEventListener("change", (event) => {
    state.compareMode = event.target.value;
    renderGraph();
  });
  elements.threshold.addEventListener("input", (event) => {
    state.threshold = Number(event.target.value) / 100;
    elements.thresholdOutput.textContent = `${event.target.value}%`;
    renderGraph();
  });
  elements.clearSelection.addEventListener("click", () => selectTool(null));

  elements.search.addEventListener("change", () => {
    const query = elements.search.value.trim().toLocaleLowerCase();
    const match = state.nodes.find((name) => name.toLocaleLowerCase() === query);
    if (match) selectTool(match);
  });
  elements.search.addEventListener("keydown", (event) => {
    if (event.key !== "Enter") return;
    const query = elements.search.value.trim().toLocaleLowerCase();
    const match = state.nodes.find((name) => name.toLocaleLowerCase().startsWith(query));
    if (match) selectTool(match);
  });

  elements.zoomIn.addEventListener("click", () => zoomAt(1.22));
  elements.zoomOut.addEventListener("click", () => zoomAt(1 / 1.22));
  elements.resetView.addEventListener("click", resetView);

  elements.svg.addEventListener("wheel", (event) => {
    event.preventDefault();
    zoomAt(event.deltaY < 0 ? 1.12 : 1 / 1.12, svgPoint(event.clientX, event.clientY));
  }, { passive: false });

  elements.svg.addEventListener("pointerdown", (event) => {
    if (event.target.closest(".node")) return;
    elements.svg.setPointerCapture(event.pointerId);
    elements.svg.classList.add("is-panning");
    state.pan = { pointerId: event.pointerId, x: event.clientX, y: event.clientY, viewX: state.view.x, viewY: state.view.y };
  });
  elements.svg.addEventListener("pointermove", (event) => {
    if (!state.pan || state.pan.pointerId !== event.pointerId) return;
    const rect = elements.svg.getBoundingClientRect();
    state.view.x = state.pan.viewX + ((event.clientX - state.pan.x) / rect.width) * WORLD.width;
    state.view.y = state.pan.viewY + ((event.clientY - state.pan.y) / rect.height) * WORLD.height;
    applyView();
  });
  const endPan = (event) => {
    if (!state.pan || state.pan.pointerId !== event.pointerId) return;
    state.pan = null;
    elements.svg.classList.remove("is-panning");
  };
  elements.svg.addEventListener("pointerup", endPan);
  elements.svg.addEventListener("pointercancel", endPan);

  document.addEventListener("keydown", (event) => {
    if (event.target.matches("input, select, button")) return;
    if (event.key === "ArrowLeft") setMonth(state.monthIndex - 1);
    if (event.key === "ArrowRight") setMonth(state.monthIndex + 1);
    if (event.key === " ") {
      event.preventDefault();
      setPlaying(!state.playing);
    }
  });
}

async function initialize() {
  bindControls();
  try {
    const response = await fetch(DATA_URL);
    if (!response.ok) throw new Error(`Dataset request returned ${response.status}.`);
    const data = await response.json();
    if (!validTimeline(data)) {
      throw new Error("The results file is still a static snapshot. Run script 07, then reload this page.");
    }

    state.data = data;
    state.months = Object.keys(data).filter((key) => /^\d{4}-\d{2}$/.test(key)).sort();
    state.nodes = collectNodes(data, state.months);
    state.monthIndex = state.months.length - 1;
    computeStableLayout();

    elements.options.replaceChildren(...state.nodes.map((name) => {
      const option = document.createElement("option");
      option.value = name;
      return option;
    }));
    elements.monthSlider.max = String(state.months.length - 1);
    elements.monthSlider.disabled = false;
    elements.timelineStart.textContent = formatMonth(state.months[0], true);
    elements.timelineEnd.textContent = formatMonth(state.months.at(-1), true);
    elements.loadState.hidden = true;
    updateTimeline();
  } catch (error) {
    elements.loadState.classList.add("is-error");
    elements.loadMessage.textContent = error.message;
    elements.status.textContent = "Dataset unavailable";
    elements.play.disabled = true;
  }
}

initialize();
