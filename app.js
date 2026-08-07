(function () {
  const state = {
    plugins: [],
    filter: "all",
    generatedAt: ""
  };

  const grid = document.getElementById("plugins");
  const emptyState = document.getElementById("emptyState");
  const filterButtons = Array.from(document.querySelectorAll(".filter-button"));
  const manifestButtons = Array.from(document.querySelectorAll("[data-open-manifest]"));
  const manifestCloseButtons = Array.from(document.querySelectorAll("[data-close-manifest]"));
  const manifestDialog = document.getElementById("manifestDialog");
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
              <span>${formatSize(plugin.sizeBytes)}</span>
              <span>${escapeHtml(plugin.status)}</span>
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
    const fileCount = plugin.fileCount ? `${plugin.fileCount} 个文件` : "待生成";
    const files = renderPackageFiles(plugin);
    const downloadUrl = escapeHtml(plugin.downloadUrl || "");

    return `
      <article class="plugin-card glass-panel reveal" data-category="${escapeHtml(plugin.category)}">
        <div class="card-band" aria-hidden="true"></div>
        <div class="card-body">
          <div class="tag-row">
            <span class="tag">${categoryName(plugin.category)}</span>
            ${apps}
            <span class="tag">${escapeHtml(plugin.type)}</span>
          </div>
          <h2>${escapeHtml(plugin.name)}</h2>
          <p class="summary">${escapeHtml(plugin.summary)}</p>
          <ul class="meta-list">
            <li><span>版本</span><strong>${escapeHtml(plugin.version)}</strong></li>
            <li><span>更新</span><strong>${escapeHtml(plugin.updatedAt)}</strong></li>
            <li><span>状态</span><strong>${escapeHtml(plugin.status)}</strong></li>
            <li><span>ZIP</span><strong>${formatSize(plugin.sizeBytes)} / ${escapeHtml(fileCount)}</strong></li>
          </ul>
          <div class="card-actions">
            <a class="download-link" href="${downloadUrl}" download>下载 ZIP</a>
            <button class="details-button" type="button">详情</button>
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
    const visible = state.plugins.filter(matches);
    grid.innerHTML = visible.map(renderCard).join("");
    emptyState.hidden = visible.length > 0;
    attachCardEvents();
    observeReveals(grid);
  }

  function setupMagneticHover() {
    const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    if (reduceMotion) return;

    document.addEventListener("pointermove", (event) => {
      const target = event.target.closest(".magnetic");
      if (!target) return;
      const rect = target.getBoundingClientRect();
      const x = ((event.clientX - rect.left) / rect.width - 0.5) * 8;
      const y = ((event.clientY - rect.top) / rect.height - 0.5) * 8;
      target.style.transform = `translate(${x}px, ${y - 2}px)`;
    });

    document.addEventListener("pointerout", (event) => {
      const target = event.target.closest(".magnetic");
      if (!target) return;
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

  if (manifestDialog) {
    manifestDialog.addEventListener("click", (event) => {
      if (event.target === manifestDialog) closeManifest();
    });

    manifestDialog.addEventListener("close", () => {
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
