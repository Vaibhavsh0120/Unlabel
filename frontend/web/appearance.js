// Called by Flutter after restoring or changing its non-secret appearance choice.
// A new browser uses light. System is an explicit choice and tracks OS changes.
(() => {
  let mode = 'light';
  const media = window.matchMedia('(prefers-color-scheme: dark)');
  function update() {
    const dark = mode === 'dark' || (mode === 'system' && media.matches);
    const name = dark ? 'dark' : 'light';
    document.getElementById('unlabel-favicon').href = `favicon-${name}.png`;
    document.getElementById('unlabel-touch-icon').href = `icons/apple-touch-${name}.png`;
    document.getElementById('unlabel-manifest').href = dark ? 'manifest-dark.json' : 'manifest.json';
    document.getElementById('unlabel-theme-color').content = dark ? '#101214' : '#FBFDFC';
    document.documentElement.style.colorScheme = name;
  }
  window.unlabelSetAppearance = (value) => {
    mode = ['light', 'dark', 'system'].includes(value) ? value : 'light';
    update();
  };
  media.addEventListener('change', update);
  update();
})();
