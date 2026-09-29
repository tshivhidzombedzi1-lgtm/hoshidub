const cap = document.getElementById('cap');

function report() {
  // the overlay has a fixed width set by the main process; only its height follows the text
  const h = Math.ceil(document.body.getBoundingClientRect().height);
  window.captions.reportSize(cap.textContent ? { width: 1, height: h } : { width: 0, height: 0 });
}

window.captions.onCaption(({ text, size }) => {
  if (size) cap.dataset.size = size;
  if (!text) {
    cap.classList.remove('on');
    setTimeout(() => { if (!cap.classList.contains('on')) { cap.textContent = ''; report(); } }, 200);
    return;
  }
  cap.textContent = text;
  report();
  requestAnimationFrame(() => cap.classList.add('on'));
});

new ResizeObserver(report).observe(document.body);
