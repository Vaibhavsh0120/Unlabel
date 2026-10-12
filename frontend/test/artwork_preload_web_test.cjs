const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const source = fs.readFileSync(path.join(__dirname, '../web/artwork-preload.js'), 'utf8');

function preload({ desktop = false, dark = false, welcome = '1', appearance = 'light', missing = false, blocked = false } = {}) {
  const links = [];
  vm.runInNewContext(source, {
    window: { matchMedia: query => ({ matches: query.includes('1200') ? desktop : dark }) },
    localStorage: { getItem: key => {
      if (blocked) throw Error('Storage blocked');
      return JSON.stringify(key.endsWith('welcomeDone') ? welcome : appearance);
    } },
    document: {
      documentElement: { dataset: { unlabelPage: missing ? 'not-found' : undefined } },
      createElement: () => ({}),
      head: { appendChild: link => links.push(link) },
    },
  });
  return links;
}

test('first-screen artwork starts as CanvasKit-compatible fetch preloads', () => {
  const links = preload({ desktop: true });
  assert.deepEqual(links.map(link => link.href), [
    'assets/assets/artwork/desktop-scan-hero.webp',
    'assets/assets/artwork/recent-scans-empty.webp',
    'assets/assets/artwork/sidebar-mint-leaves.webp',
  ]);
  for (const link of links) {
    assert.equal(link.rel, 'preload');
    assert.equal(link.as, 'fetch');
    assert.equal(link.crossOrigin, 'anonymous');
    assert.ok(fs.existsSync(path.join(__dirname, '..', link.href.replace('assets/assets/', 'assets/'))));
  }
});

test('phone preloads only the selected appearance and welcome stays optional-storage safe', () => {
  assert.match(preload({ appearance: 'system', dark: true })[0].href, /scan-hero-dark.webp$/);
  assert.equal(preload({ appearance: 'dark' }).length, 1);
  assert.deepEqual(preload({ blocked: true }).map(link => link.href.split('/').at(-1)),
    ['welcome-scan-package.webp']);
});

test('missing page prioritizes its own illustration without downloading Home artwork', () => {
  assert.deepEqual(preload({ missing: true, desktop: true }).map(link => link.href.split('/').at(-1)),
    ['not-found-art.webp']);
});
