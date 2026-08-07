(function () {
  const state = {
    plugins: [],
    filter: "all",
    generatedAt: ""
  };

  const untestedSlugs = new Set([
    "ps-white-ink-layer",
    "ai-locate-object-hotkey",
    "ai-auto-cutline"
  ]);

  const grid = document.getElementById("plugins");
  const emptyState = document.getElementById("emptyState");
  const filterButtons = Array.from(document.querySelectorAll(".filter-button"));
  const manifestButtons = Array.from(document.querySelectorAll("[data-open-manifest]"));
  const manifestCloseButtons = Array.from(document.querySelectorAll("[data-close-manifest]"));
  const contactButtons = Array.from(document.querySelectorAll("[data-open-contact]"));
  const contactCloseButtons = Array.from(document.querySelectorAll("[data-close-contact]"));
  const manifestDialog = document.getElementById("manifestDialog");
  const contactDialog = document.getElementById("contactDialog");
  const manifestSummary = document.getElementById("manifestSummary");
  const manifestList = document.getElementById("manifestList");
  const totalCount = document.getElementById("totalCount");
  const zipCount = document.getElementById("zipCount");
  const heroTotal = document.getElementById("heroTotal");
  const heroZip = document.getElementById("heroZip");
  const generatedAt = document.getElementById("generatedAt");

  function escapeHtml(value) {
    return String(value || "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#039;");
  }

  function formatSize(bytes) {
    if (!bytes || bytes < 1) return "待生成";
    if (bytes >= 1024 * 1024) return `${(bytes / 1024 / 1024).toFixed(1)} MB`;
    return `${Math.ceil(bytes / 1024)} KB`;
  }

  function categoryName(category) {
    const names = {
      photoshop: "Photoshop",
      illustrator: "Illustrator",
      bridge: "PS+AI 联动",
      assistant: "独立助手"
    };
    return names[category] || category;
  }

  function renderManifest() {
    const packageTotal = state.plugins.filter((plugin) => plugin.downloadUrl).length;
    manifestSummary.textContent = `${state.plugins.length} 个工具 · ${packageTotal} 个 ZIP · 更新于 ${state.generatedAt || "待生成"}`;
    manifestList.innerHTML = state.plugins.map((plugin) => {
      const apps = (plugin.apps || []).join(" / ");
      return `
        <article class="manifest-item">
          <div class="manifest-item-main">
            <span class="tag">${categoryName(plugin.category)}</span>
            <h3>${escapeHtml(plugin.name)}</h3>
            <p>${escapeHtml(plugin.summary)}</p>
            <div class="manifest-meta">
              <span>${escapeHtml(apps)}</span>
              <span>v${escapeHtml(plugin.version)}</span>
            </div>
          </div>
          <a class="download-link manifest-download" href="${escapeHtml(plugin.downloadUrl)}" download>下载 ZIP</a>
        </article>
      `;
    }).join("");
  }

  function openManifest() {
    if (!manifestDialog) return;
    renderManifest();
    if (manifestDialog.open) return;
    if (typeof manifestDialog.showModal === "function") {
      manifestDialog.showModal();
    } else {
      manifestDialog.setAttribute("open", "");
    }
    document.body.classList.add("is-dialog-open");
  }

  function closeManifest() {
    if (!manifestDialog) return;
    if (typeof manifestDialog.close === "function") {
      manifestDialog.close();
    } else {
      manifestDialog.removeAttribute("open");
    }
    document.body.classList.remove("is-dialog-open");
  }

  function openContact() {
    if (!contactDialog) return;
    if (contactDialog.open) return;
    if (typeof contactDialog.showModal === "function") {
      contactDialog.showModal();
    } else {
      contactDialog.setAttribute("open", "");
    }
    document.body.classList.add("is-dialog-open");
  }

  function closeContact() {
    if (!contactDialog) return;
    if (typeof contactDialog.close === "function") {
      contactDialog.close();
    } else {
      contactDialog.removeAttribute("open");
    }
    document.body.classList.remove("is-dialog-open");
  }

  function renderPackageFiles(plugin) {
    return (plugin.files || []).map((file) => `
      <div class="file-item">
        <span class="file-name">${escapeHtml(file.name)}</span>
        <span class="file-size">${formatSize(file.sizeBytes)}</span>
      </div>
    `).join("");
  }

  function renderCard(plugin) {
    const notes = (plugin.notes || []).map((note) => `<li>${escapeHtml(note)}</li>`).join("");
    const apps = (plugin.apps || []).map((app) => `<span class="tag">${escapeHtml(app)}</span>`).join("");
    const files = renderPackageFiles(plugin);
    const downloadUrl = escapeHtml(plugin.downloadUrl || "");
    const isUntested = untestedSlugs.has(plugin.slug);
    const statusTag = isUntested ? `<span class="tag tag-status-untested">未测试</span>` : "";
    const testState = isUntested ? "untested" : "checked";
    const tutorialLink = plugin.slug === "ps-artboard-four-piece"
      ? `<a class="details-button tutorial-link" href="https://kurogame.feishu.cn/docx/GSMKdlfqdo3os3xjr68cmE9NndQ" target="_blank" rel="noopener noreferrer">教程文档</a>`
      : "";

    return `
      <article class="plugin-card glass-panel reveal" data-category="${escapeHtml(plugin.category)}" data-test-state="${testState}">
        <div class="card-band" aria-hidden="true"></div>
        <div class="card-body">
          <div class="tag-row">
            <span class="tag">${categoryName(plugin.category)}</span>
            ${apps}
            <span class="tag">${escapeHtml(plugin.type)}</span>
            ${statusTag}
          </div>
          <h2>${escapeHtml(plugin.name)}</h2>
          <p class="summary">${escapeHtml(plugin.summary)}</p>
          <ul class="meta-list">
            <li><span>版本</span><strong>${escapeHtml(plugin.version)}</strong></li>
            <li><span>更新</span><strong>${escapeHtml(plugin.updatedAt)}</strong></li>
          </ul>
          <div class="card-actions">
            <a class="download-link" href="${downloadUrl}" download>下载 ZIP</a>
            <button class="details-button" type="button">详情</button>
            ${tutorialLink}
          </div>
          <div class="details">
            <div class="details-inner">
              <div class="details-inner-content">
                <p><strong>安装：</strong>${escapeHtml(plugin.install)}</p>
                <p><strong>要求：</strong>${escapeHtml(plugin.requirements)}</p>
                ${notes ? `<p><strong>注意：</strong></p><ul>${notes}</ul>` : ""}
                <p><strong>ZIP 包内容：</strong></p>
                <div class="file-list">${files}</div>
              </div>
            </div>
          </div>
        </div>
      </article>
    `;
  }

  function matches(plugin) {
    const categoryOk = state.filter === "all" || plugin.category === state.filter;
    return categoryOk;
  }

  function sortByTestState(a, b) {
    const aUntested = untestedSlugs.has(a.slug);
    const bUntested = untestedSlugs.has(b.slug);
    if (aUntested === bUntested) return 0;
    return aUntested ? 1 : -1;
  }

  function observeReveals(scope) {
    const items = Array.from((scope || document).querySelectorAll(".reveal:not(.is-visible)"));
    if (!("IntersectionObserver" in window)) {
      items.forEach((item) => item.classList.add("is-visible"));
      return;
    }

    const observer = new IntersectionObserver((entries, currentObserver) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add("is-visible");
          currentObserver.unobserve(entry.target);
        }
      });
    }, { rootMargin: "0px 0px -8% 0px", threshold: 0.12 });

    items.forEach((item) => observer.observe(item));
  }

  function attachCardEvents() {
    grid.querySelectorAll(".details-button").forEach((button) => {
      button.addEventListener("click", () => {
        const card = button.closest(".plugin-card");
        card.classList.toggle("is-open");
      });
    });
  }

  function render() {
    const visible = state.plugins.filter(matches).sort(sortByTestState);
    grid.innerHTML = visible.map(renderCard).join("");
    emptyState.hidden = visible.length > 0;
    attachCardEvents();
    observeReveals(grid);
  }

  function setupMagneticHover() {
    const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    if (reduceMotion) return;
    const selector = ".primary-link, .download-link";

    document.addEventListener("pointermove", (event) => {
      const target = event.target.closest(selector);
      if (!target) return;
      const rect = target.getBoundingClientRect();
      const x = ((event.clientX - rect.left) / rect.width - 0.5) * 10;
      const y = ((event.clientY - rect.top) / rect.height - 0.5) * 8;
      target.style.transform = `translate3d(${x}px, ${y - 3}px, 0)`;
    });

    document.addEventListener("pointerout", (event) => {
      const target = event.target.closest(selector);
      if (!target) return;
      if (event.relatedTarget && target.contains(event.relatedTarget)) return;
      target.style.transform = "";
    });
  }

  function setupScrollMotion() {
    const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    if (reduceMotion) return;

    let ticking = false;
    const update = () => {
      const max = Math.max(document.body.scrollHeight - window.innerHeight, 1);
      document.documentElement.style.setProperty("--scroll", Math.min(window.scrollY / max, 1).toFixed(4));
      ticking = false;
    };

    window.addEventListener("scroll", () => {
      if (!ticking) {
        window.requestAnimationFrame(update);
        ticking = true;
      }
    }, { passive: true });
    update();
  }

  filterButtons.forEach((button) => {
    button.addEventListener("click", () => {
      state.filter = button.dataset.filter;
      filterButtons.forEach((item) => item.classList.toggle("is-active", item === button));
      render();
    });
  });

  manifestButtons.forEach((button) => {
    button.addEventListener("click", openManifest);
  });

  manifestCloseButtons.forEach((button) => {
    button.addEventListener("click", closeManifest);
  });

  contactButtons.forEach((button) => {
    button.addEventListener("click", openContact);
  });

  contactCloseButtons.forEach((button) => {
    button.addEventListener("click", closeContact);
  });

  if (manifestDialog) {
    manifestDialog.addEventListener("click", (event) => {
      if (event.target === manifestDialog) closeManifest();
    });

    manifestDialog.addEventListener("close", () => {
      document.body.classList.remove("is-dialog-open");
    });
  }

  if (contactDialog) {
    contactDialog.addEventListener("click", (event) => {
      if (event.target === contactDialog) closeContact();
    });

    contactDialog.addEventListener("close", () => {
      document.body.classList.remove("is-dialog-open");
    });
  }

  setupMagneticHover();
  setupScrollMotion();
  observeReveals(document);

  fetch("plugins.json", { cache: "no-store" })
    .then((response) => {
      if (!response.ok) throw new Error("plugins.json not found");
      return response.json();
    })
    .then((data) => {
      state.plugins = data.plugins || [];
      state.generatedAt = data.generatedAt || "待生成";
      const packageTotal = state.plugins.filter((plugin) => plugin.downloadUrl).length;
      totalCount.textContent = state.plugins.length;
      zipCount.textContent = packageTotal;
      heroTotal.textContent = state.plugins.length;
      heroZip.textContent = packageTotal;
      generatedAt.textContent = state.generatedAt;
      renderManifest();
      render();
    })
    .catch((error) => {
      grid.innerHTML = `<p class="empty-state glass-panel">清单读取失败：${escapeHtml(error.message)}</p>`;
      emptyState.hidden = true;
    });
})();
