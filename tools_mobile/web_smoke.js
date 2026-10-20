// Web 版冒烟测试：用本机 Chrome 打开导出的页面，等加载完成后截图并收集控制台输出。
// 用法：NODE_PATH=/tmp/dzsg_pp/node_modules node web_smoke.js [url] [outdir]
const puppeteer = require('puppeteer-core');
const fs = require('fs');

const url = process.argv[2] || 'http://localhost:8765/index.html';
const out = process.argv[3] || '/tmp/dzsg_shots';
fs.mkdirSync(out, { recursive: true });

(async () => {
  const browser = await puppeteer.launch({
    executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    headless: 'new',
    args: ['--use-angle=metal', '--enable-gpu', '--ignore-gpu-blocklist',
      '--autoplay-policy=no-user-gesture-required', '--window-size=1280,720'],
    defaultViewport: { width: 1280, height: 720 },
  });
  const page = await browser.newPage();
  const logs = [];
  page.on('console', (m) => logs.push(`[${m.type()}] ${m.text()}`));
  page.on('pageerror', (e) => logs.push(`[pageerror] ${e.message}`));
  page.on('requestfailed', (r) => logs.push(`[reqfail] ${r.url()} ${r.failure() && r.failure().errorText}`));
  const t0 = Date.now();
  await page.goto(url, { waitUntil: 'load', timeout: 60000 });
  // 等 Godot 的加载遮罩消失（#status 隐藏）
  let loaded = false;
  for (let i = 0; i < 180; i++) {
    const hidden = await page.evaluate(() => {
      const s = document.getElementById('status');
      return !s || getComputedStyle(s).display === 'none' || getComputedStyle(s).visibility === 'hidden';
    });
    if (hidden) { loaded = true; break; }
    await new Promise((r) => setTimeout(r, 500));
  }
  console.log('loaded', loaded, 'after', ((Date.now() - t0) / 1000).toFixed(1), 's');
  const gl = await page.evaluate(() => {
    const c = document.querySelector('canvas');
    if (!c) return 'no canvas';
    return `${c.width}x${c.height}`;
  });
  console.log('canvas', gl);
  await new Promise((r) => setTimeout(r, 4000));
  await page.screenshot({ path: `${out}/01_title.png` });
  // 点一下屏幕中间（标题画面通常点任意处继续）
  await page.mouse.click(640, 400);
  await new Promise((r) => setTimeout(r, 3000));
  await page.screenshot({ path: `${out}/02_after_click.png` });
  await page.mouse.click(640, 400);
  await new Promise((r) => setTimeout(r, 5000));
  await page.screenshot({ path: `${out}/03_later.png` });
  const mem = await page.evaluate(() => (performance.memory ? Math.round(performance.memory.usedJSHeapSize / 1048576) + 'MB' : 'n/a'));
  console.log('js heap', mem);
  console.log('===== console (' + logs.length + ')');
  for (const l of logs.slice(0, 80)) console.log(l);
  await browser.close();
})().catch((e) => { console.error('SMOKE FAIL', e); process.exit(1); });
