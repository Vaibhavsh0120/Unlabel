// Keep the initial HTTP 404 and URL while the real app renders its recovery view.
window.unlabelNotFound = true;
window.addEventListener('flutter-first-frame', () => {
  document.getElementById('not-found-fallback')?.remove();
}, { once: true });
