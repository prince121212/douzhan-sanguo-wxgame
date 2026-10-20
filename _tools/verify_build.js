#!/usr/bin/env node
// ============================================================================
// 包体优化对比验证脚本  verify_build.js
// ----------------------------------------------------------------------------
// 用途：对同一游戏的「优化前 / 优化后」两个构建做可量化对比，任何一项不达标即判定 FAIL。
// 设计原则：
//   1. 绝不依赖人眼看截图下结论，全部指标化。
//   2. 只要游戏没能真正启动（引擎报错 / 画面全黑 / 无任何帧推进），一律 FAIL。
//   3. 输出 JSON 报告，便于逐项 diff。
//
// 用法：
//   NODE_PATH=/tmp/dzsg_pp/node_modules node verify_build.js --url http://localhost:8765/index.html --label BASELINE
//   NODE_PATH=/tmp/dzsg_pp/node_modules node verify_build.js --url http://localhost:8766/index.html --label BROTLI
// ============================================================================

const puppeteer = require('puppeteer-core');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

// ---------------------------------------------------------------- 参数解析
const args = {};
process.argv.slice(2).forEach((a, i, arr) => {
  if (a.startsWith('--')) args[a.slice(2)] = arr[i + 1];
});
const URL = args.url || 'http://localhost:8765/index.html';
const LABEL = args.label || 'RUN';
const OUT = args.out || `/tmp/dzsg_verify/${LABEL}`;
const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';

// 判定阈值
const TH = {
  loadTimeoutMs: 120000,   // 引擎启动超时
  settleMs: 12000,         // 启动后观察窗口：标题画面可能有动画，需拉开采样
  frameSamples: 5,         // 采样次数
  minUniqueFrames: 3,      // 5 次采样中至少 3 帧内容不同 -> 证明游戏循环在推进
  minNonBlackRatio: 0.02,  // 画面非黑像素占比下限（证明真的渲染了东西）
};

fs.mkdirSync(OUT, { recursive: true });

// ---------------------------------------------------------------- 工具函数
const log = (...a) => console.log(...a);

async function sha256File(p) {
  const h = crypto.createHash('sha256');
  h.update(fs.readFileSync(p));
  return h.digest('hex');
}

// 统计实际网络传输量（这是包体/流量的真实口径）
function makeNetMeter() {
  const byUrl = new Map();
  let totalBytes = 0;
  return {
    onEntry(e) {
      const url = e.request ? e.request.url : e.url;
      const rec = byUrl.get(url) || { url, encoded: 0, decoded: 0, status: null, fromDisk: false };
      rec.encoded += e.encodedDataLength || 0;
      if (e.response) {
        rec.status = e.response.status;
        rec.decoded = e.response.contentLength || rec.decoded;
        rec.fromDisk = !!(e.response.fromDiskCache || e.response.fromPrefetchCache);
        rec.mime = e.response.mimeType;
      }
      byUrl.set(url, rec);
    },
    result() {
      // 累加 encoded（传输量）
      for (const r of byUrl.values()) totalBytes += r.encoded;
      return {
        totalEncodedBytes: totalBytes,
        entries: [...byUrl.values()]
          .map((r) => ({ ...r, encoded: r.encoded }))
          .sort((a, b) => b.encoded - a.encoded),
      };
    },
  };
}

// 分析 canvas 像素：非黑占比 + 内容指纹
async function analyzeCanvas(page) {
  return await page.evaluate(() => {
    const c = document.querySelector('canvas');
    if (!c) return { ok: false, reason: 'no canvas' };
    const w = c.width, h = c.height;
    let data;
    try {
      // WebGL canvas 需要 preserveDrawingBuffer 才能直接读，失败则回退到截图比对
      const tmp = document.createElement('canvas');
      tmp.width = w; tmp.height = h;
      const ctx = tmp.getContext('2d');
      ctx.drawImage(c, 0, 0);
      data = ctx.getImageData(0, 0, w, h).data;
    } catch (e) {
      return { ok: false, reason: 'cannot read canvas: ' + e.message, w, h };
    }
    let nonBlack = 0, sum = 0, samples = 0;
    const uniq = new Set();
    for (let i = 0; i < data.length; i += 4 * 97) { // 抽样统计
      const r = data[i], g = data[i + 1], b = data[i + 2];
      const lum = 0.2126 * r + 0.7152 * g + 0.0722 * b;
      if (lum > 8) nonBlack++;
      sum += lum; samples++;
      uniq.add(((r >> 4) << 8) | ((g >> 4) << 4) | (b >> 4));
    }
    return {
      ok: true, w, h, samples,
      nonBlackRatio: nonBlack / samples,
      avgLuma: sum / samples,
      colorBuckets: uniq.size,
    };
  });
}

async function hashCanvas(page) {
  const buf = await page.screenshot({ type: 'png' });
  const h = crypto.createHash('sha256').update(buf).digest('hex');
  fs.writeFileSync(path.join(OUT, 'shot_final.png'), buf);
  return h;
}

// ---------------------------------------------------------------- 主流程
// 单独跑一次「带 CDP 计量的冷加载」，专门测真实网络传输字节数。
// CDP 会话必须在 goto 之前建立，否则连接会被导航打断。
async function measureNetwork(url) {
  const browser = await puppeteer.launch({
    executablePath: CHROME,
    headless: true,
    args: ['--use-angle=metal', '--enable-gpu', '--ignore-gpu-blocklist',
           '--autoplay-policy=no-user-gesture-required', '--window-size=1280,720', '--no-sandbox'],
    defaultViewport: { width: 1280, height: 720 },
    protocolTimeout: 240000,
  });
  try {
    const page = await browser.newPage();
    const client = await page.createCDPSession();
    await client.send('Network.enable');
    const sizes = new Map();
    const urls = new Map();
    client.on('Network.requestWillBeSent', (e) => urls.set(e.requestId, e.request.url));
    client.on('Network.responseReceived', (e) => urls.set(e.requestId, e.response.url));
    client.on('Network.loadingFinished', (e) => sizes.set(e.requestId, e.encodedDataLength));

    const t = Date.now();
    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 60000 });
    // 等引擎起来，确保大文件都下载完
    let up = 0;
    while (up < 120000) {
      const gone = await page.evaluate(() => {
        const s = document.getElementById('status');
        if (!s) return true;
        const cs = getComputedStyle(s);
        return cs.display === 'none' || cs.visibility === 'hidden';
      }).catch(() => false);
      if (gone) break;
      await new Promise((r) => setTimeout(r, 500));
      up += 500;
    }
    const ms = Date.now() - t;
    let total = 0;
    const entries = [];
    for (const [rid, len] of sizes) {
      total += len;
      entries.push({ url: (urls.get(rid) || '').split('/').pop(), encoded: len });
    }
    entries.sort((a, b) => b.encoded - a.encoded);
    return { total, entries, loadMs: ms };
  } finally {
    await browser.close();
  }
}

(async () => {
  const report = { label: LABEL, url: URL, ts: new Date().toISOString(), checks: {}, pass: true };

  const browser = await puppeteer.launch({
    executablePath: CHROME,
    headless: true,
    args: [
      '--use-angle=metal', '--enable-gpu', '--ignore-gpu-blocklist',
      '--autoplay-policy=no-user-gesture-required',
      '--window-size=1280,720', '--disable-dev-shm-usage', '--no-sandbox',
    ],
    defaultViewport: { width: 1280, height: 720 },
    protocolTimeout: 240000,
  });

  try {
    const page = await browser.newPage();
    const consoleLogs = [];
    const pageErrors = [];
    const net = makeNetMeter();

    page.on('console', (m) => consoleLogs.push({ type: m.type(), text: m.text().slice(0, 400) }));
    page.on('pageerror', (e) => pageErrors.push(String(e.message).slice(0, 500)));
    page.on('requestfailed', (r) => consoleLogs.push({ type: 'reqfail', text: r.url() + ' :: ' + (r.failure() && r.failure().errorText) }));
    page.on('response', (res) => net.onEntry({ url: res.url(), response: res, encodedDataLength: 0, request: res.request() }));

    // ---- 导航（必须在建 CDP 会话之前完成，否则会触发 Connection closed）
    const t0 = Date.now();
    await page.goto(URL, { waitUntil: 'domcontentloaded', timeout: 60000 });
    const tDomReady = Date.now() - t0;

    // ---- 等引擎启动。
    // 注意：Godot 引擎一旦启动就会把 #status 元素整个移除，此时 getElementById 返回 null，
    // 这属于「已启动」，不能当成失败。判定条件：#status 消失（被移除或隐藏）即视为启动完成。
    let engineStarted = false, waited = 0, statusGoneBy = null;
    while (waited < TH.loadTimeoutMs) {
      const st = await page.evaluate(() => {
        const s = document.getElementById('status');
        if (!s) return { gone: true, removed: true, text: '' };
        const cs = getComputedStyle(s);
        return {
          gone: cs.display === 'none' || cs.visibility === 'hidden',
          removed: false,
          text: (s.textContent || '').trim().slice(0, 120),
        };
      }).catch((e) => ({ gone: false, removed: false, text: 'eval-error:' + e.message, evalErr: true }));
      if (st.gone) { engineStarted = true; statusGoneBy = st.removed ? 'removed' : 'hidden'; break; }
      await new Promise((r) => setTimeout(r, 500));
      waited += 500;
    }
    const engineMs = Date.now() - t0;
    report.checks.domReadyMs = tDomReady;
    report.checks.engineStartMs = engineMs;
    report.checks.engineStarted = engineStarted;

    if (!engineStarted) {
      report.pass = false;
      report.failReason = '引擎未在 ' + TH.loadTimeoutMs + 'ms 内启动';
    }

    // ---- 帧推进验证：确认游戏循环真的在跑（比较两次画面指纹）
    const frames = [];
    for (let i = 0; i < TH.frameSamples; i++) {
      await new Promise((r) => setTimeout(r, TH.settleMs / TH.frameSamples));
      frames.push(await hashCanvas(page));
    }
    const uniqFrames = new Set(frames);
    report.checks.frameSamples = frames.length;
    report.checks.uniqueFrames = uniqFrames.size;
    report.checks.frameAdvanced = uniqFrames.size >= TH.minUniqueFrames;
    if (uniqFrames.size < TH.minUniqueFrames) {
      report.pass = false;
      report.failReason = (report.failReason || '') +
        ` 画面未推进(${TH.frameSamples} 次采样只有 ${uniqFrames.size} 个不同画面 < ${TH.minUniqueFrames})，疑似卡死`;
    }

    // ---- 画面内容验证
    const px = await analyzeCanvas(page);
    report.checks.pixels = px;
    if (!px.ok) {
      report.pass = false;
      report.failReason = (report.failReason || '') + ' 无法读取画面: ' + px.reason;
    } else if (px.nonBlackRatio < TH.minNonBlackRatio) {
      report.pass = false;
      report.failReason = (report.failReason || '') + ` 画面几乎全黑(非黑占比 ${(px.nonBlackRatio * 100).toFixed(2)}% < ${(TH.minNonBlackRatio * 100).toFixed(0)}%)`;
    }

    // ---- 网络传输量（核心指标）：独立冷加载一次测量
    try {
      const nm = await measureNetwork(URL);
      report.checks.networkBytes = nm.total;
      report.checks.netLoadMs = nm.loadMs;
      report.checks.topTransfers = nm.entries.slice(0, 8);
    } catch (e) {
      report.checks.networkError = String(e.message);
    }

    // ---- 引擎运行期报错
    const errs = consoleLogs.filter((l) => l.type === 'error');
    report.checks.pageErrors = pageErrors;
    report.checks.consoleErrors = errs.slice(0, 10);
    if (pageErrors.length) {
      report.pass = false;
      report.failReason = (report.failReason || '') + ` 页面异常 ${pageErrors.length} 条: ${pageErrors[0]}`;
    }

    // ---- 截图留证
    await page.screenshot({ path: path.join(OUT, 'title.png') });
    await page.mouse.click(640, 400);
    await new Promise((r) => setTimeout(r, 4000));
    const px2 = await analyzeCanvas(page);
    report.checks.pixelsAfterClick = px2;
    if (!px2.ok || px2.nonBlackRatio < TH.minNonBlackRatio) {
      report.pass = false;
      report.failReason = (report.failReason || '') + ' 点击后画面异常';
    }
    await page.screenshot({ path: path.join(OUT, 'after_click.png') });

    report.consoleLogCount = consoleLogs.length;
  } catch (e) {
    report.pass = false;
    report.failReason = '测试脚本异常: ' + e.message + '\n' + String(e.stack || '').slice(0, 800);
  } finally {
    await browser.close();
  }

  fs.writeFileSync(path.join(OUT, 'report.json'), JSON.stringify(report, null, 2));

  // ---- 控制台摘要
  log('');
  log('==================== ' + LABEL + ' ====================');
  log('引擎启动        :', report.checks.engineStarted ? `✅ ${report.checks.engineStartMs}ms` : '❌ 未启动');
  log('画面帧推进      :', report.checks.frameAdvanced ? `✅ ${report.checks.uniqueFrames}/${report.checks.frameSamples} 唯一帧` : '❌ 未推进');
  if (report.checks.pixels) {
    log('画面非黑占比    :', (report.checks.pixels.nonBlackRatio * 100).toFixed(2) + '%',
        `均亮度 ${report.checks.pixels.avgLuma.toFixed(1)} 色彩 ${report.checks.pixels.colorBuckets}`);
  }
  if (report.checks.networkBytes != null) {
    log('网络传输总量    :', (report.checks.networkBytes / 1048576).toFixed(2), 'MB');
    for (const t of report.checks.topTransfers) {
      log('   -', t.url, (t.encoded / 1024).toFixed(0) + ' KB');
    }
  }
  log('页面异常        :', report.checks.pageErrors ? report.checks.pageErrors.length : 0, '条');
  log('');
  log(report.pass ? '✅ 判定：PASS' : '❌ 判定：FAIL — ' + report.failReason);
  log('截图与报告      :', OUT);
  log('=================================================');

  process.exit(report.pass ? 0 : 2);
})().catch((e) => { console.error('FATAL', e); process.exit(1); });