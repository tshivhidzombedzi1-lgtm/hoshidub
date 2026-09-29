// Runs before paint so the saved theme never flashes the wrong colours.
try { const t = localStorage.getItem('theme'); if (t) document.documentElement.dataset.theme = t; } catch (e) { /* storage blocked */ }
