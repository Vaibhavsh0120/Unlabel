// Start only the first screen's public artwork while Flutter itself downloads.
// Fetch preloads match CanvasKit's asset requests (rather than HTML img requests).
(() => {
  let welcome = true;
  let appearance = 'light';
  try {
    welcome = JSON.parse(localStorage.getItem('unlabel.client.v1.welcomeDone')) !== '1';
    appearance = JSON.parse(localStorage.getItem('unlabel.client.v1.appearance')) || 'light';
  } catch (_) { /* Storage is optional; a blocked store keeps the welcome defaults. */ }
  const missing = document.documentElement.dataset.unlabelPage === 'not-found';
  const desktop = window.matchMedia('(min-width: 1200px)').matches;
  const dark = appearance === 'dark' ||
    (appearance === 'system' && window.matchMedia('(prefers-color-scheme: dark)').matches);
  const assets = missing ? ['not-found-art.webp'] : welcome
    ? ['welcome-scan-package.webp']
    : [desktop ? 'desktop-scan-hero.webp' : `scan-hero-${dark ? 'dark' : 'light'}.webp`,
       ...(desktop ? ['recent-scans-empty.webp', 'sidebar-mint-leaves.webp'] : [])];
  for (const asset of assets) {
    const link = document.createElement('link');
    link.rel = 'preload';
    link.as = 'fetch';
    link.type = 'image/webp';
    link.crossOrigin = 'anonymous';
    link.href = `assets/assets/artwork/${asset}`;
    document.head.appendChild(link);
  }
})();
