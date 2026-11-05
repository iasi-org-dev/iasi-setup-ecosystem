function setupEmbeddedView() {
  if (window.self === window.top) return;

  document.documentElement.classList.add("iasi-embedded");

  const link = document.querySelector('a[href$="#iasi-open-external"]');

  if (link) {
    link.addEventListener("click", function (event) {
      event.preventDefault();
      window.open(window.location.href, "_blank", "noopener");
    });
  }
}

async function setupExportsMenu() {
  const marker = document.querySelector('a[href$="#iasi-exports"]');

  if (!marker) return;

  const markerItem = marker.closest("li");
  const menu = markerItem?.parentElement;

  if (!markerItem || !menu) return;

  const offset =
    document.querySelector('meta[name="quarto:offset"]')?.content || "";

  const exportsUrl = new URL(
    `${offset}exports.json`,
    window.location.href
  );

  try {
    const response = await fetch(exportsUrl);

    if (!response.ok) return;

    const data = await response.json();
    const exports = Array.isArray(data.exports) ? data.exports : [];

    for (const entry of exports) {
      const newItem = markerItem.cloneNode(true);
      const link = newItem.querySelector("a");
      const text = newItem.querySelector(".dropdown-text");

      const href = new URL(entry.href, exportsUrl).href;

      link.href = href;
      link.dataset.originalHref = href;

      if (text) {
        text.textContent = entry.text;

        if (entry.icon) {
          const icon = document.createElement("i");

          icon.className = `bi bi-${entry.icon}`;
          icon.setAttribute("aria-hidden", "true");

          link.insertBefore(icon, text);
          link.insertBefore(document.createTextNode(" "), text);
        }
      }

      menu.insertBefore(newItem, markerItem);
    }

    markerItem.remove();
  } catch {
    return;
  }
}

function setupAnnouncementBanner() {
  const banner = document.querySelector(
    "#quarto-announcement .iasi-ants-image"
  );

  if (!banner) return;

  const offset =
    document.querySelector('meta[name="quarto:offset"]')?.content || "";

  banner.src = new URL(
    `${offset}resources/images/ants.png`,
    window.location.href
  ).href;
}

function setupIASI() {
  setupAnnouncementBanner();
  setupEmbeddedView();
  setupExportsMenu();
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", setupIASI);
} else {
  setupIASI();
}