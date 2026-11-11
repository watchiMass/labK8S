/* Local CKA ExamUI frontend. */
(() => {
  "use strict";

  const TOTAL_SECONDS = 120 * 60;
  const STORAGE = {
    timer: "cka.timer.start",
    series: "cka.series",
    index: "cka.index.",
    flags: "cka.flags",
    panelWidth: "cka.panelWidth",
  };

  const els = {
    console: document.getElementById("console"),
    questionPanel: document.getElementById("question-panel"),
    questionScroll: document.getElementById("question-scroll"),
    questionContent: document.getElementById("question-content"),
    taskSelect: document.getElementById("task-select"),
    seriesSelect: document.getElementById("series-select"),
    prevTask: document.getElementById("prev-task"),
    nextTask: document.getElementById("next-task"),
    labHelperBody: document.getElementById("lab-helper-body"),
    flagTask: document.getElementById("flag-task"),
    copyTask: document.getElementById("copy-task"),
    satisfied: document.getElementById("satisfied"),
    splitter: document.getElementById("splitter"),
    novncFallback: document.getElementById("novnc-fallback"),
    startTimer: document.getElementById("start-timer"),
    endExam: document.getElementById("end-exam"),
    timerFill: document.getElementById("timer-fill"),
    timerLabel: document.getElementById("timer-label"),
    tabReadme: document.getElementById("tab-readme"),
    tabDesktop: document.getElementById("tab-desktop"),
    desktopFrame: document.getElementById("desktop-frame"),
    toast: document.getElementById("toast"),
  };

  const savedFlags = (() => {
    try {
      return JSON.parse(localStorage.getItem(STORAGE.flags) || "{}") || {};
    } catch {
      return {};
    }
  })();

  const state = {
    seriesList: [],
    series: null,
    questions: [],
    index: 0,
    flags: savedFlags,
    timerStart: Number(localStorage.getItem(STORAGE.timer) || 0) || null,
    alerts: {},
    toastTimer: null,
  };

  async function fetchJson(url, options) {
    const res = await fetch(url, options);
    if (!res.ok) {
      throw new Error(`HTTP ${res.status}`);
    }
    return res.json();
  }

  function toast(message) {
    els.toast.textContent = message;
    els.toast.hidden = false;
    clearTimeout(state.toastTimer);
    state.toastTimer = setTimeout(() => {
      els.toast.hidden = true;
    }, 4200);
  }

  function showError(message) {
    els.questionContent.innerHTML = "";
    const p = document.createElement("p");
    p.className = "error";
    p.textContent = message;
    els.questionContent.appendChild(p);
  }

  function flagKey() {
    const q = state.questions[state.index];
    return q ? `${state.series}/${q.slug}` : "";
  }

  function isDocsUrl(url) {
    try {
      const host = new URL(url).hostname.toLowerCase();
      return host === "kubernetes.io" || host.endsWith(".kubernetes.io");
    } catch {
      return false;
    }
  }

  function getRemoteRfb() {
    const frameWindow = els.desktopFrame && els.desktopFrame.contentWindow;
    if (!frameWindow) {
      return null;
    }
    // L'interface noVNC officielle expose UI.rfb ; l'ancien viewer custom rfb.
    return (frameWindow.UI && frameWindow.UI.rfb) || frameWindow.rfb || null;
  }

  function sendToDesktop(text) {
    const rfb = getRemoteRfb();
    if (!rfb || typeof rfb.clipboardPasteFrom !== "function") {
      toast("The remote desktop is not connected yet.");
      return;
    }
    try {
      rfb.clipboardPasteFrom(text);
    } catch {
      toast("The remote desktop is not connected yet.");
      return;
    }
    toast("Copied to the remote clipboard — press Ctrl+Shift+V in the terminal.");
  }

  async function openDocs(url) {
    try {
      const res = await fetch("/api/open-docs", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ url }),
      });
      const data = await res.json().catch(() => ({}));
      toast(data.message || (res.ok ? "Opened in Firefox." : "Could not open Firefox."));
    } catch {
      toast("Could not reach the exam console API.");
    }
  }

  function decorateQuestion() {
    els.questionContent.querySelectorAll("pre").forEach((pre) => {
      if (pre.querySelector(".copy-to-desktop")) {
        return;
      }
      const btn = document.createElement("button");
      btn.type = "button";
      btn.className = "copy-to-desktop";
      btn.textContent = "Copy to desktop";
      btn.addEventListener("click", (event) => {
        event.preventDefault();
        event.stopPropagation();
        const clone = pre.cloneNode(true);
        clone.querySelectorAll(".copy-to-desktop").forEach((b) => b.remove());
        const code = clone.querySelector("code");
        const text = (code ? code.textContent : clone.textContent).replace(/\n$/, "");
        sendToDesktop(text);
      });
      pre.appendChild(btn);
    });

    els.questionContent.querySelectorAll("a").forEach((anchor) => {
      const href = anchor.getAttribute("href") || "";
      let absolute;
      try {
        absolute = new URL(href, window.location.href).href;
      } catch {
        return;
      }
      if (isDocsUrl(absolute)) {
        anchor.setAttribute("href", "#");
        anchor.addEventListener("click", (event) => {
          event.preventDefault();
          openDocs(absolute);
        });
      } else if (/^https?:/i.test(href)) {
        anchor.target = "_blank";
        anchor.rel = "noopener";
      }
    });
  }

  function renderLabHelper(dir) {
    els.labHelperBody.textContent = "";
    const intro = document.createElement("p");
    intro.textContent =
      "Run these in the remote terminal (use Copy, then Ctrl+Shift+V there):";
    els.labHelperBody.appendChild(intro);

    [
      `cd ~/cka-practice-labs/${dir}`,
      "bash setup.sh",
      "cat question.md",
      "bash validate.sh",
      "bash cleanup.sh",
    ].forEach((command) => {
      const row = document.createElement("div");
      row.className = "helper-command";

      const code = document.createElement("code");
      code.textContent = command;

      const btn = document.createElement("button");
      btn.type = "button";
      btn.className = "btn btn-small";
      btn.textContent = "Copy";
      btn.addEventListener("click", () => sendToDesktop(command));

      row.append(code, btn);
      els.labHelperBody.appendChild(row);
    });
  }

  function updateTaskSelectLabels() {
    [...els.taskSelect.options].forEach((option, index) => {
      const question = state.questions[index];
      if (!question) {
        return;
      }
      const flagged = Boolean(state.flags[`${state.series}/${question.slug}`]);
      option.textContent = `${flagged ? "⚑ " : ""}Task ${index + 1} of ${state.questions.length}`;
    });
  }

  function updateFlagButton() {
    const flagged = Boolean(state.flags[flagKey()]);
    els.flagTask.classList.toggle("active", flagged);
    els.flagTask.textContent = flagged
      ? "⚑ Flagged — click to unflag"
      : "⚑ Flag this to return later";
  }

  function populateSeriesSelect() {
    els.seriesSelect.textContent = "";
    state.seriesList.forEach((series) => {
      const option = document.createElement("option");
      option.value = series.id;
      option.textContent = series.title;
      els.seriesSelect.appendChild(option);
    });
  }

  function populateTaskSelect() {
    els.taskSelect.textContent = "";
    if (!state.questions.length) {
      const option = document.createElement("option");
      option.textContent = "No tasks";
      els.taskSelect.appendChild(option);
      return;
    }
    state.questions.forEach((question, index) => {
      const option = document.createElement("option");
      option.value = String(index);
      option.textContent = `Task ${index + 1} of ${state.questions.length}`;
      els.taskSelect.appendChild(option);
    });
    updateTaskSelectLabels();
  }

  async function loadQuestion() {
    if (!state.questions.length) {
      showError("No questions found in ~/cka-practice-labs.");
      return;
    }
    state.index = Math.min(Math.max(state.index, 0), state.questions.length - 1);
    els.taskSelect.value = String(state.index);
    localStorage.setItem(STORAGE.index + state.series, String(state.index));

    const question = state.questions[state.index];
    try {
      const data = await fetchJson(
        `/api/question?series=${encodeURIComponent(state.series)}&q=${encodeURIComponent(question.slug)}`
      );
      els.questionContent.innerHTML = data.html;
      decorateQuestion();
      renderLabHelper(data.dir);
      updateFlagButton();
      updateTaskSelectLabels();
      els.questionScroll.scrollTop = 0;
    } catch {
      showError(`Could not load ${state.series}/${question.slug}.`);
    }
  }

  async function selectSeries(seriesId) {
    const series = state.seriesList.find((item) => item.id === seriesId);
    if (!series) {
      return;
    }
    state.series = seriesId;
    state.questions = series.questions || [];
    localStorage.setItem(STORAGE.series, seriesId);
    els.seriesSelect.value = seriesId;

    const savedIndex = Number(localStorage.getItem(STORAGE.index + seriesId));
    state.index =
      Number.isInteger(savedIndex) && savedIndex >= 0 && savedIndex < state.questions.length
        ? savedIndex
        : 0;

    populateTaskSelect();
    await loadQuestion();
  }

  function copyTaskToDesktop() {
    if (!state.questions.length) {
      return;
    }
    const clone = els.questionContent.cloneNode(true);
    clone.querySelectorAll(".copy-to-desktop").forEach((button) => button.remove());
    sendToDesktop(clone.textContent.trim());
  }

  function startTimer() {
    state.timerStart = Date.now();
    state.alerts = {};
    localStorage.setItem(STORAGE.timer, String(state.timerStart));
    els.startTimer.textContent = "Reset timer";
    updateTimer();
  }

  function stopTimer() {
    state.timerStart = null;
    state.alerts = {};
    localStorage.removeItem(STORAGE.timer);
    els.startTimer.textContent = "Start exam";
    updateTimer();
  }

  function updateTimer() {
    let remaining = TOTAL_SECONDS;
    if (state.timerStart) {
      remaining = Math.max(
        0,
        TOTAL_SECONDS - Math.floor((Date.now() - state.timerStart) / 1000)
      );
    }

    const percent = Math.max(0, Math.min(100, (remaining / TOTAL_SECONDS) * 100));
    els.timerFill.style.width = `${percent}%`;

    let color = "#4caf50";
    if (remaining <= 5 * 60) {
      color = "#b71c1c";
    } else if (remaining <= 15 * 60) {
      color = "#d9534f";
    } else if (remaining <= 30 * 60) {
      color = "#f0a500";
    }
    els.timerFill.style.background = color;

    if (!state.timerStart) {
      els.timerLabel.textContent = "Time remaining: 120 minutes";
    } else if (remaining <= 0) {
      els.timerLabel.textContent = "Time is up";
    } else if (remaining >= 60) {
      els.timerLabel.textContent = `Time remaining: ${Math.ceil(remaining / 60)} minutes`;
    } else {
      els.timerLabel.textContent = `Time remaining: ${remaining} seconds`;
    }

    if (state.timerStart && remaining > 0) {
      [30, 15, 5].forEach((minutes) => {
        if (remaining <= minutes * 60 && !state.alerts[minutes]) {
          state.alerts[minutes] = true;
          toast(`${minutes} minutes remaining.`);
        }
      });
    }
  }

  function seedAlerts() {
    state.alerts = {};
    if (!state.timerStart) {
      return;
    }
    const remaining = Math.max(
      0,
      TOTAL_SECONDS - Math.floor((Date.now() - state.timerStart) / 1000)
    );
    [30, 15, 5].forEach((minutes) => {
      if (remaining <= minutes * 60) {
        state.alerts[minutes] = true;
      }
    });
  }

  function restoreTimer() {
    state.timerStart = Number(localStorage.getItem(STORAGE.timer) || 0) || null;
    els.startTimer.textContent = state.timerStart ? "Reset timer" : "Start exam";
    seedAlerts();
    updateTimer();
  }

  function wireTabs() {
    document.querySelectorAll(".tab").forEach((tab) => {
      tab.addEventListener("click", () => {
        const target = tab.dataset.tab;
        document.querySelectorAll(".tab").forEach((item) => {
          item.classList.toggle("active", item === tab);
        });
        els.tabReadme.hidden = target !== "readme";
        els.tabDesktop.hidden = target !== "desktop";
        els.tabReadme.classList.toggle("active", target === "readme");
        els.tabDesktop.classList.toggle("active", target === "desktop");

        if (target === "desktop") {
          setTimeout(() => {
            try {
              const rfb = getRemoteRfb();
              if (rfb) {
                rfb.scaleViewport = true;
                rfb.focus();
              }
            } catch {
              /* ignore */
            }
          }, 100);
        }
      });
    });
  }

  function wireSplitter() {
    let dragging = false;
    const savedWidth = Number(localStorage.getItem(STORAGE.panelWidth));
    if (savedWidth >= 20 && savedWidth <= 55) {
      els.questionPanel.style.width = `${savedWidth}%`;
    }

    els.splitter.addEventListener("mousedown", (event) => {
      event.preventDefault();
      dragging = true;
      document.body.classList.add("resizing");
    });

    document.addEventListener("mousemove", (event) => {
      if (!dragging) {
        return;
      }
      const total = els.console.clientWidth;
      const left = Math.min(Math.max(event.clientX, total * 0.2), total * 0.55);
      const percent = (left / total) * 100;
      els.questionPanel.style.width = `${percent}%`;
      localStorage.setItem(STORAGE.panelWidth, String(percent));
    });

    document.addEventListener("mouseup", () => {
      dragging = false;
      document.body.classList.remove("resizing");
    });
  }

  function wireUi() {
    els.seriesSelect.addEventListener("change", (event) => {
      selectSeries(event.target.value);
    });

    els.taskSelect.addEventListener("change", (event) => {
      state.index = Number(event.target.value) || 0;
      loadQuestion();
    });

    els.prevTask.addEventListener("click", () => {
      if (state.index > 0) {
        state.index -= 1;
        loadQuestion();
      }
    });

    els.nextTask.addEventListener("click", () => {
      if (state.index < state.questions.length - 1) {
        state.index += 1;
        loadQuestion();
      }
    });

    els.satisfied.addEventListener("click", () => {
      if (state.index < state.questions.length - 1) {
        state.index += 1;
        loadQuestion();
      } else {
        toast("Last task of this series.");
      }
    });

    els.flagTask.addEventListener("click", () => {
      const key = flagKey();
      if (!key) {
        return;
      }
      state.flags[key] = !state.flags[key];
      localStorage.setItem(STORAGE.flags, JSON.stringify(state.flags));
      updateFlagButton();
      updateTaskSelectLabels();
    });

    els.copyTask.addEventListener("click", copyTaskToDesktop);

    els.novncFallback.addEventListener("click", () => {
      const url =
        `${window.location.protocol}//${window.location.hostname}:6080/` +
        "vnc.html?autoconnect=true&resize=scale";
      window.open(url, "_blank", "noopener");
    });

    els.startTimer.addEventListener("click", () => {
      if (state.timerStart) {
        if (window.confirm("Reset the timer to 120 minutes?")) {
          startTimer();
        }
      } else {
        startTimer();
      }
    });

    els.endExam.addEventListener("click", () => {
      if (!window.confirm("End this exam session? The timer will stop.")) {
        return;
      }
      stopTimer();
      toast("Exam ended. Use “Start exam” to begin a new session.");
    });

    wireTabs();
    wireSplitter();
  }

  async function init() {
    wireUi();
    restoreTimer();

    try {
      const data = await fetchJson("/api/series");
      state.seriesList = data.series || [];
    } catch {
      showError("Cannot reach the exam console API.");
      return;
    }

    if (!state.seriesList.length) {
      showError("No lab questions found. Check ~/cka-practice-labs on base.");
      return;
    }

    populateSeriesSelect();

    const savedSeries = localStorage.getItem(STORAGE.series);
    const seriesId = state.seriesList.some((series) => series.id === savedSeries)
      ? savedSeries
      : state.seriesList[0].id;
    els.seriesSelect.value = seriesId;
    await selectSeries(seriesId);

    setInterval(updateTimer, 1000);
    updateTimer();
  }

  init();
})();
