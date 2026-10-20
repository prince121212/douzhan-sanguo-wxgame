/* ==========================================================================
 * game.js —— 斗战三国 · 微信小游戏入口（诊断插桩版）
 * --------------------------------------------------------------------------
 * 本版本在原有逻辑外增加了「启动诊断日志」，用于定位小游戏运行时
 * 启动失败/白屏问题。所有日志同时写入：
 *   1. console（开发者工具调试器可见）
 *   2. wx.env.USER_DATA_PATH + '/dzsg_boot.log'（磁盘文件，可事后读取）
 *
 * 模拟器磁盘位置（本机）：
 *   ~/Library/Application Support/微信开发者工具/<hash>/WeappSimulator/
 *     WeappFileSystem/<openid>/wx13f8272f953e806a/usr/dzsg_boot.log
 *
 * 排查完成后可还原：mv game.js.pre-diag game.js
 * ========================================================================== */

const g = GameGlobal;

// ---------------------------------------------------------------------------
// 0) 诊断日志设施（必须最先就绪，且自身容错，不能影响主流程）
// ---------------------------------------------------------------------------
var __LOG_PATH = null;
try { __LOG_PATH = wx.env.USER_DATA_PATH + '/dzsg_boot.log'; } catch (e) {}
try { if (!__LOG_PATH) __LOG_PATH = 'dzsg_boot.log'; } catch (e) {}

function __log(msg) {
  if (__logBusy) return; // 防止 console tee 递归
  __logBusy = true;
  var line;
  try { line = '[BOOT ' + new Date().toISOString() + '] ' + msg; } catch (e) { line = '[BOOT] ' + msg; }
  try { console.log(line); } catch (e) {}
  try {
    var fs = wx.getFileSystemManager();
    try {
      fs.appendFileSync(__LOG_PATH, line + '\n', 'utf8');
    } catch (e2) {
      // 首次写入时文件不存在会抛错，退回 writeFileSync 创建
      fs.writeFileSync(__LOG_PATH, line + '\n', 'utf8');
    }
  } catch (e3) {}
  __logBusy = false;
}
var __logBusy = false;

function __probeEnv() {
  __log('===== game.js 开始执行 =====');
  try { __log('USER_DATA_PATH=' + wx.env.USER_DATA_PATH); } catch (e) { __log('USER_DATA_PATH 获取失败: ' + e); }
  try { __log('typeof fetch=' + (typeof fetch) + ', Response=' + (typeof Response) + ', Request=' + (typeof Request)); } catch (e) {}
  try { __log('typeof WebAssembly=' + (typeof WebAssembly) + ', instantiateStreaming=' + (typeof WebAssembly.instantiateStreaming)); } catch (e) {}
  try { __log('typeof globalThis=' + (typeof globalThis) + ', WXWebAssembly=' + (typeof g.WXWebAssembly) + ', window.WXWebAssembly=' + (typeof g.window.WXWebAssembly)); } catch (e) { __log('globalThis/WXWebAssembly 探测失败: ' + e); }
  try { __log('typeof WebAssembly = ' + (typeof WebAssembly)); } catch (e) { __log('WebAssembly 探测本身抛错: ' + e); }
  try { __log('typeof XMLHttpRequest=' + (typeof XMLHttpRequest)); } catch (e) {}
  try { __log('typeof wx.loadSubpackage=' + (typeof wx.loadSubpackage)); } catch (e) {}
  try { __log('typeof wx.getFileSystemManager=' + (typeof wx.getFileSystemManager)); } catch (e) {}
  try { __log('typeof wx.createCanvas=' + (typeof wx.createCanvas)); } catch (e) {}
  try {
    __log('window===GameGlobal? ' + (g.window === g) + '; self===g? ' + (g.self === g) + '; top===g? ' + (g.top === g) + '; parent===g? ' + (g.parent === g));
  } catch (e) { __log('window 身份探测失败: ' + e); }
  try { __log('window keys: ' + Object.keys(g.window).slice(0, 60).join(',')); } catch (e) { __log('window keys 失败: ' + e); }
  try { __log('document keys: ' + Object.keys(g.document).slice(0, 60).join(',')); } catch (e) { __log('document keys 失败: ' + e); }
  try {
    var dc = g.document.createElement('canvas');
    __log('document.createElement(canvas) -> ' + (dc && dc.constructor && dc.constructor.name) + ', width=' + (dc && dc.width));
  } catch (e) { __log('document.createElement(canvas) 失败: ' + e); }
  try { __log('document.body=' + (typeof g.document.body) + ', document.head=' + (typeof g.document.head)); } catch (e) {}
  try { __log('location.href=' + JSON.stringify(g.location.href) + ', location keys=' + Object.keys(g.location).slice(0,20).join(',')); } catch (e) { __log('location 探测失败: ' + e); }
  try { __log('navigator keys: ' + Object.keys(g.navigator).join(',')); } catch (e) {}
  try { __log('typeof g.addEventListener=' + (typeof g.addEventListener) + ', window.addEventListener=' + (typeof g.window.addEventListener)); } catch (e) {}
  try { __log('typeof g.performance.now=' + (typeof g.performance.now) + ', g.requestAnimationFrame=' + (typeof g.requestAnimationFrame)); } catch (e) {}
  try { __log('typeof g.indexedDB=' + (typeof g.indexedDB) + ', g.localStorage=' + (typeof g.localStorage)); } catch (e) {}
  try {
    var keys = Object.keys(g).join(',');
    __log('FULL GameGlobal keys: ' + keys);
  } catch (e) {}
  try {
    var sys = wx.getSystemInfoSync();
    __log('systemInfo: platform=' + sys.platform + ', brand=' + (sys.brand || '') + ', model=' + (sys.model || '') + ', SDKVersion=' + sys.SDKVersion + ', version=' + sys.version);
  } catch (e) { __log('getSystemInfoSync 失败: ' + e); }
  try {
    var di = wx.getDeviceInfo ? wx.getDeviceInfo() : {};
    __log('deviceInfo: ' + JSON.stringify({ platform: di.platform, system: di.system, benchmarkLevel: di.benchmarkLevel }));
  } catch (e) {}
}

__probeEnv();

// WXWebAssembly 行为探测（不影响主流程）
try {
  var WXA = g.WXWebAssembly;
  __log('WXWebAssembly keys: ' + Object.keys(WXA).join(','));
  __log('WXA.instantiate=' + (typeof WXA.instantiate) + ', compile=' + (typeof WXA.compile) + ', Module=' + (typeof WXA.Module) + ', Memory=' + (typeof WXA.Memory));

  // 测试 A：主包内 8 字节合法 wasm（空模块）
  var t0 = Date.now();
  var doneA = false;
  WXA.instantiate('test_min.wasm', {}).then(function (r) {
    doneA = true;
    __log('WXA 测试A（主包 test_min.wasm）成功: ' + (Date.now() - t0) + 'ms, keys=' + Object.keys(r || {}).join(','));
  }, function (e) {
    doneA = true;
    __log('WXA 测试A 失败: ' + (Date.now() - t0) + 'ms, ' + (e && (e.message || e)));
  });
  setTimeout(function () { if (!doneA) __log('WXA 测试A 超时(15s 未返回)'); }, 15000);

  // 测试 B：不存在的文件
  var doneB = false;
  var t1 = Date.now();
  WXA.instantiate('pkg_engine/nope.wasm', {}).then(function (r) {
    doneB = true;
    __log('WXA 测试B（不存在文件）竟然成功: keys=' + Object.keys(r || {}).join(','));
  }, function (e) {
    doneB = true;
    __log('WXA 测试B（不存在文件）失败: ' + (Date.now() - t1) + 'ms, ' + (e && (e.message || e)));
  });
  setTimeout(function () { if (!doneB) __log('WXA 测试B 超时(15s 未返回)'); }, 15000);

  // 测试 C：USER_DATA_PATH 路径（8 字节文件写进去再实例化）
  try {
    var fsm = wx.getFileSystemManager();
    fsm.writeFileSync(wx.env.USER_DATA_PATH + '/test_min.wasm', new Uint8Array([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00]).buffer, 'utf8');
    __log('测试C: 已写 USER_DATA_PATH/test_min.wasm');
    var doneC = false;
    var t2 = Date.now();
    WXA.instantiate(wx.env.USER_DATA_PATH + '/test_min.wasm', {}).then(function (r) {
      doneC = true;
      __log('WXA 测试C（USER_DATA_PATH）成功: ' + (Date.now() - t2) + 'ms');
    }, function (e) {
      doneC = true;
      __log('WXA 测试C（USER_DATA_PATH）失败: ' + (Date.now() - t2) + 'ms, ' + (e && (e.message || e)));
    });
    setTimeout(function () { if (!doneC) __log('WXA 测试C 超时(20s 未返回)'); }, 20000);
  } catch (e) { __log('测试C 准备失败: ' + (e && e.message)); }

  // 测试 D：主包内小 .br（13 字节）
  try {
    var doneD = false;
    var t3 = Date.now();
    WXA.instantiate('test_min.wasm.br', {}).then(function (r) {
      doneD = true;
      __log('WXA 测试D（主包 test_min.wasm.br）成功: ' + (Date.now() - t3) + 'ms, keys=' + Object.keys(r || {}).join(','));
    }, function (e) {
      doneD = true;
      __log('WXA 测试D（主包 .br）失败: ' + (Date.now() - t3) + 'ms, ' + (e && (e.message || e)));
    });
    setTimeout(function () { if (!doneD) __log('WXA 测试D 超时(20s 未返回)'); }, 20000);
  } catch (e) { __log('测试D 异常: ' + (e && e.message)); }

  // 测试 E：主包内真实大 .br（6.9MB，隔离"分包"因素）
  try {
    var doneE = false;
    var t4 = Date.now();
    WXA.instantiate('index_main.wasm.br', {}).then(function (r) {
      doneE = true;
      __log('WXA 测试E（主包 6.9MB .br）成功: ' + (Date.now() - t4) + 'ms');
    }, function (e) {
      doneE = true;
      __log('WXA 测试E（主包 6.9MB .br）失败: ' + (Date.now() - t4) + 'ms, ' + (e && (e.message || e)));
    });
    setTimeout(function () { if (!doneE) __log('WXA 测试E 超时(20s 未返回)'); }, 20000);
  } catch (e) { __log('测试E 异常: ' + (e && e.message)); }

  // 测试 F：分包内大 .br 的可读性与体积（FileSystemManager 直读）
  try {
    var fsm2 = wx.getFileSystemManager();
    var t5 = Date.now();
    var brBuf = fsm2.readFileSync('pkg_engine/index.wasm.br');
    __log('测试F: FS 读 pkg_engine/index.wasm.br 成功, ' + brBuf.byteLength + ' bytes, ' + (Date.now() - t5) + 'ms');
  } catch (e) { __log('测试F: FS 读分包 .br 失败: ' + (e && e.message)); }

  // 测试 G：WXWebAssembly.Memory 大内存分配（验证是否为内存瓶颈）
  try {
    var mem = new WXA.Memory({ initial: 512, maximum: 1024 }); // 32MB -> 64MB
    __log('测试G: new WXA.Memory(512页=32MB) 成功, buffer=' + mem.buffer.byteLength);
  } catch (e) { __log('测试G: Memory 分配失败: ' + (e && e.message)); }

  // 测试 H：SIMD 支持（Godot wasm 很可能带 SIMD 指令）
  try {
    var doneH = false;
    var t7 = Date.now();
    WXA.instantiate('test_simd.wasm', {}).then(function (r) {
      doneH = true;
      var f = (r.instance || r).exports && (r.instance || r).exports.f;
      var v = f ? f() : 'n/a';
      __log('WXA 测试H（SIMD 模块）成功: ' + (Date.now() - t7) + 'ms, f()=' + v);
    }, function (e) {
      doneH = true;
      __log('WXA 测试H（SIMD 模块）失败: ' + (Date.now() - t7) + 'ms, ' + (e && (e.message || e)));
    });
    setTimeout(function () { if (!doneH) __log('WXA 测试H 超时(15s 未返回)'); }, 15000);
  } catch (e) { __log('测试H 异常: ' + (e && e.message)); }

  // 测试 I：WXWebAssembly.compile 大 .br 的编译耗时（判别是否惰性编译）
  try {
    var doneI = false;
    var t8 = Date.now();
    var cp = WXA.compile ? WXA.compile('pkg_engine/index.wasm.br') : Promise.reject(new Error('no compile'));
    cp.then(function (m) {
      doneI = true;
      __log('WXA 测试I（compile 6.9MB .br）成功: ' + (Date.now() - t8) + 'ms');
    }, function (e) {
      doneI = true;
      __log('WXA 测试I（compile）失败: ' + (Date.now() - t8) + 'ms, ' + (e && (e.message || e)));
    });
    setTimeout(function () { if (!doneI) __log('WXA 测试I 超时(30s 未返回，compile 超过 30s)'); }, 30000);
  } catch (e) { __log('测试I 异常: ' + (e && e.message)); }

  // 测试 K：新版 EH 编码（try_table 0x1F）——Godot 4.7 的 Emscripten 很可能用新编码
  try {
    var doneK = false;
    var t10 = Date.now();
    WXA.instantiate('test_eh2.wasm', {}).then(function (r) {
      doneK = true;
      var f = (r.instance || r).exports && (r.instance || r).exports.t;
      var v = 'n/a';
      try { v = f ? f() : 'n/a'; } catch (e2) { v = '调用异常:' + (e2 && e2.message); }
      __log('WXA 测试K（try_table 模块）成功: ' + (Date.now() - t10) + 'ms, t()=' + v);
    }, function (e) {
      doneK = true;
      __log('WXA 测试K（try_table 模块）失败: ' + (Date.now() - t10) + 'ms, ' + (e && (e.message || e)));
    });
    setTimeout(function () { if (!doneK) __log('WXA 测试K 超时(15s 未返回)'); }, 15000);
  } catch (e) { __log('测试K 异常: ' + (e && e.message)); }
} catch (e) { __log('WXWebAssembly 探测异常: ' + (e && (e.stack || e.message) || e)); }

// 全局错误兜底：任何未捕获异常都要落盘
try {
  wx.onError(function (err) {
    var msg = (err && err.message) ? err.message : String(err);
    __log('wx.onError: ' + msg + (err && err.stack ? ' | stack: ' + String(err.stack).slice(0, 800) : ''));
  });
  __log('wx.onError 已挂钩');
} catch (e) { __log('wx.onError 挂钩失败: ' + e); }

try {
  g.onerror = function (msg, src, line, col, err) {
    __log('window.onerror: ' + msg + ' @' + line + ':' + col + ' err=' + (err && (err.stack || err.message) || err));
    return false;
  };
  __log('window.onerror 已挂钩');
} catch (e) { __log('window.onerror 挂钩失败: ' + e); }

try {
  g.addEventListener('unhandledrejection', function (e) {
    var r = e && e.reason;
    __log('unhandledrejection: ' + (r && (r.stack || r.message) || r));
  });
  __log('unhandledrejection 已挂钩');
} catch (e) {}

g.__DZSG = {
  log: function () {
    const a = Array.prototype.slice.call(arguments);
    try { console.log.apply(console, ['[DZSG]'].concat(a)); } catch (e) {}
    try { __log('[DZSG] ' + a.map(function (x) { return String(x); }).join(' ')); } catch (e) {}
  },
  error: function () {
    const a = Array.prototype.slice.call(arguments);
    try { console.error.apply(console, ['[DZSG]'].concat(a)); } catch (e) {}
    try { __log('[DZSG-ERROR] ' + a.map(function (x) { return String(x); }).join(' ')); } catch (e) {}
  },
};

// ---------------------------------------------------------------------------
// 1) 宿主垫片：必须在任何引擎代码执行前完成
// ---------------------------------------------------------------------------
function setupHostShim() {
  __log('setupHostShim: 开始');
  const canvas = wx.createCanvas();
  __log('setupHostShim: 画布 ' + canvas.width + 'x' + canvas.height);

  // 黑屏修复：Godot 胶水 GodotDisplayScreen.updateSize() 在 canvasResizePolicy=2
  // （自适应全窗口）下用 window.innerWidth/innerHeight 计算画布尺寸。
  // 微信小游戏没有这两个全局 -> undefined*dpr=NaN -> canvas.width 被写成 0，
  // 引擎向 0x0 画布渲染 -> 画面全黑（日志/帧率完全正常，极难察觉）。
  try {
    var sysInfo = wx.getSystemInfoSync();
    var sw = sysInfo.windowWidth || sysInfo.screenWidth;
    var sh = sysInfo.windowHeight || sysInfo.screenHeight;
    var dpr = sysInfo.pixelRatio || 2;
    g.innerWidth = sw; g.innerHeight = sh;
    g.devicePixelRatio = dpr;
    g.screen = { width: sw, height: sh, availWidth: sw, availHeight: sh };
    if (g.window && g.window !== g) {
      try { g.window.innerWidth = sw; g.window.innerHeight = sh; g.window.devicePixelRatio = dpr; } catch (e2) {}
    }
    // 胶水 updateSize() 会写 canvas.style.width/height；输入法定位用 getBoundingClientRect
    if (!canvas.style) canvas.style = {};
    if (typeof canvas.getBoundingClientRect !== 'function') {
      canvas.getBoundingClientRect = function () {
        return { left: 0, top: 0, right: sw, bottom: sh, width: sw, height: sh };
      };
    }
    __log('setupHostShim: 显示垫片 innerWidth=' + sw + ' innerHeight=' + sh + ' dpr=' + dpr);
  } catch (e) { __log('setupHostShim: 显示垫片失败: ' + (e && e.message)); }

  // --- 浏览器全局补齐（胶水边缘路径，缺失即 ReferenceError）-------------------
  // crypto：Emscripten randomFill -> crypto.getRandomValues
  function setG(name, value) {
    try {
      g[name] = value;
      if (g.window && g.window !== g) { try { g.window[name] = value; } catch (e2) {} }
    } catch (e3) {}
  }
  try {
    if (typeof g.crypto === 'undefined' || !g.crypto || typeof g.crypto.getRandomValues !== 'function') {
      setG('crypto', {
        getRandomValues: function (view) {
          for (var i = 0; i < view.length; i++) view[i] = (Math.random() * 256) | 0;
          return view;
        },
      });
      __log('crypto.getRandomValues 已补齐');
    }
  } catch (e) { __log('crypto 补齐失败: ' + (e && e.message)); }
  // alert
  setG('alert', function (msg) { __log('window.alert: ' + msg); });
  // URL：小游戏可能有真实 URL 构造器（平台模块加载器要 new URL()，绝不能整体
  // shadow）。真实 createObjectURL 只接受真 Blob，会拒绝假 Blob 并抛
  // "Overload resolution failed"——只把静态方法换成哑元，构造器保持原样。
  try {
    if (typeof g.URL === 'function' && typeof g.URL.createObjectURL === 'function') {
      try {
        g.URL.createObjectURL = function () { return 'blob:minigame'; };
        g.URL.revokeObjectURL = function () {};
      } catch (e2) {
        Object.defineProperty(g.URL, 'createObjectURL', { value: function () { return 'blob:minigame'; }, writable: true, configurable: true });
        Object.defineProperty(g.URL, 'revokeObjectURL', { value: function () {}, writable: true, configurable: true });
      }
      __log('URL.createObjectURL 已替换为哑元（构造器保持原样）');
    }
  } catch (e) { __log('URL 静态方法替换失败: ' + (e && e.message)); }
  // Blob（引擎加载 pck / 设置窗口图标等路径会 new Blob()）
  if (typeof g.Blob === 'undefined') {
    var BlobShim = function Blob(parts, opts) {
      this.parts = parts || [];
      this.type = (opts && opts.type) || '';
      this.size = 0;
      for (var i = 0; i < this.parts.length; i++) {
        var p = this.parts[i];
        this.size += (p && p.length) || 0;
      }
    };
    setG('Blob', BlobShim);
    __log('Blob 垫片已安装');
  }
  // Image（胶水边缘路径会 new Image()）
  if (typeof g.Image === 'undefined') {
    var ImageShim = function Image() {
      this.style = {};
      this.onload = null;
      this.onerror = null;
      this._src = '';
    };
    Object.defineProperty(ImageShim.prototype, 'src', {
      set: function (v) { this._src = v; },
      get: function () { return this._src; },
    });
    setG('Image', ImageShim);
    __log('Image 垫片已安装');
  }

  // Godot 的 getGodotConfig 会做 `canvas instanceof HTMLCanvasElement` 判断，
  // subcontext 里没有这个构造器，直接 ReferenceError。给一个哑元构造器，
  // 让判断走「不是 HTMLCanvasElement」分支（再用 document 里的 canvas 兜底）。
  if (typeof g.HTMLCanvasElement === 'undefined') {
    try {
      function HTMLCanvasElementDummy() {}
      g.HTMLCanvasElement = HTMLCanvasElementDummy;
      if (g.window && g.window !== g) g.window.HTMLCanvasElement = HTMLCanvasElementDummy;
      __log('HTMLCanvasElement 哑元构造器已安装');
    } catch (e) { __log('HTMLCanvasElement 安装失败: ' + e); }
  }

  // subcontext 可能自带极简 document（原型上只读属性），普通赋值在严格模式下
  // 直接抛 "Cannot assign to read only property"，导致胶水取
  // document.getElementsByTagName 时报 "is not a function" -> 引擎启动失败。
  // 对策：用 defineProperty 在实例上打补丁（shadow 原型属性）；
  // 关键方法仍缺失时整体替换为假文档。
  function makeFakeDoc() {
    return {
      createElement: function (tag) {
        if (String(tag).toLowerCase() === 'canvas') return canvas;
        return { style: {}, addEventListener: function () {}, removeEventListener: function () {}, appendChild: function () {}, getContext: function () { return null; } };
      },
      createElementNS: function (ns, tag) { return g.document.createElement(tag); },
      getElementById: function (id) { return String(id).toLowerCase() === 'canvas' ? canvas : null; },
      getElementsByTagName: function (tag) { return String(tag).toLowerCase() === 'canvas' ? [canvas] : []; },
      querySelector: function (sel) {
        var s = String(sel == null ? '' : sel).toLowerCase();
        if (s === '#canvas' || s === 'canvas' || s.indexOf('canvas') !== -1) return canvas;
        return null;
      },
      querySelectorAll: function () { return []; },
      addEventListener: function () {},
      removeEventListener: function () {},
      exitPointerLock: function () {},
      body: { appendChild: function () {}, style: {} },
      head: { appendChild: function () {} },
      title: '',
      activeElement: null,
      visibilityState: 'visible',
      hidden: false,
      location: { href: '', protocol: 'file:' },
      referrer: '',
    };
  }
  if (!g.document) g.document = makeFakeDoc();
  try {
    var doc = g.document;
    function defDoc(name, fn) {
      try {
        if (typeof doc[name] !== 'function') {
          Object.defineProperty(doc, name, { value: fn, writable: true, configurable: true });
          __log('document.' + name + ' 已补齐（defineProperty）');
        }
      } catch (e) { __log('document.' + name + ' 补齐失败: ' + (e && e.message)); }
    }
    defDoc('querySelector', function (sel) {
      var s = String(sel == null ? '' : sel).toLowerCase();
      if (s === '#canvas' || s === 'canvas' || s.indexOf('canvas') !== -1) return canvas;
      return null;
    });
    defDoc('querySelectorAll', function () { return []; });
    defDoc('getElementsByTagName', function (tag) {
      return String(tag).toLowerCase() === 'canvas' ? [canvas] : [];
    });
    defDoc('getElementById', function (id) {
      return String(id).toLowerCase() === 'canvas' ? canvas : null;
    });
    defDoc('createElement', function (tag) {
      if (String(tag).toLowerCase() === 'canvas') return canvas;
      return { style: {}, addEventListener: function () {}, appendChild: function () {} };
    });
    defDoc('createElementNS', function (ns, tag) { return g.document.createElement(tag); });
    defDoc('addEventListener', function () {});
    defDoc('removeEventListener', function () {});
    defDoc('exitPointerLock', function () {});
    // document.title 是只读属性（_godot_js_display_window_title_set 会写它）
    try { Object.defineProperty(doc, 'title', { value: typeof doc.title === 'string' ? doc.title : '', writable: true, configurable: true }); } catch (e) {}
    try { if (typeof doc.visibilityState === 'undefined') Object.defineProperty(doc, 'visibilityState', { value: 'visible', writable: true, configurable: true }); } catch (e) {}
    try { if (typeof doc.hidden === 'undefined') Object.defineProperty(doc, 'hidden', { value: false, writable: true, configurable: true }); } catch (e) {}
    if (!doc.body) doc.body = { appendChild: function () {}, style: {} };
    if (!doc.head) doc.head = { appendChild: function () {} };

    // 关键方法仍缺失 -> 整体替换为假文档
    if (typeof doc.getElementsByTagName !== 'function' || typeof doc.querySelector !== 'function') {
      g.document = makeFakeDoc();
      __log('document 整体替换为假文档');
    }
  } catch (e) { __log('document 补齐失败: ' + (e && e.message)); }

  // navigator 语言信息（getGodotConfig 读 navigator.languages/language）
  try {
    if (g.navigator && typeof g.navigator.language === 'undefined') g.navigator.language = 'zh-CN';
    if (g.navigator && typeof g.navigator.languages === 'undefined') g.navigator.languages = ['zh-CN'];
  } catch (e) {}

  // 小游戏没有 AudioWorklet。引擎会探测 ctx.audioWorklet（WeChat 假装存在、
  // addModule "成功"），随后胶水会 new AudioWorkletNode 建两种 worklet：
  //   godot-processor（输出驱动）、godot-position-reporting-processor（位置旁路）
  // 全局没有这个类 -> 每个声音启动刷 "Failed to create PositionWorklet" +
  // 启动期 unhandledrejection，且 sample 的 start() 走不到 -> 无声。
  // 这里给一个以【真实 GainNode】为化身的假 AudioWorkletNode：
  //   - 必须是真实 AudioNode：胶水会把真实声源 connect() 到它，普通 JS 对象
  //     会让 connect() 抛 "Overload resolution failed"；
  //   - 音频流入即消失（不接 destination），游戏声音仍走正常的总线链路；
  //   - port/parameters 给哑实现，覆盖胶水用到的全部接口。
  if (typeof g.AudioWorkletNode === 'undefined') {
    g.AudioWorkletNode = function FakeAudioWorkletNode(ctx, name, opts) {
      var node = null;
      try { node = ctx.createGain(); } catch (e) { node = null; }
      if (!node) node = { connect: function () {}, disconnect: function () {} };
      var fakeParam = {
        value: 0,
        setValueAtTime: function () { return this; },
        linearRampToValueAtTime: function () { return this; },
        exponentialRampToValueAtTime: function () { return this; },
        setTargetAtTime: function () { return this; },
        setValueCurveAtTime: function () { return this; },
        cancelScheduledValues: function () {},
        cancelAndHoldAtTime: function () {},
      };
      node.parameters = {
        get: function () { return fakeParam; },
        has: function () { return true; },
        keys: function () { return ['reset']; },
      };
      node.port = {
        onmessage: null,
        postMessage: function () {},
        addEventListener: function () {},
        removeEventListener: function () {},
        start: function () {},
        stop: function () {},
        close: function () {},
      };
      node.__fakeWorklet = true;
      return node;
    };
    g.webkitAudioContext = undefined;
  }

  // IDBFS 在小游戏里不存在，标记为已同步，否则引擎会反复尝试写入
  g.__idbfsSync = {
    sync: function () {},
    waitForCompletion: function () {},
  };

  // 禁止引擎尝试安装 Service Worker（小游戏无此概念）
  if (typeof g.navigator === 'undefined') {
    let di = {};
    try { di = wx.getDeviceInfo ? wx.getDeviceInfo() : wx.getSystemInfoSync(); } catch (e) {}
    g.navigator = {
      userAgent: (di && di.platform) ? 'MiniGame-' + di.platform : 'MiniGame',
      language: 'zh-CN',
      platform: 'MiniGame',
      hardwareConcurrency: (di && di.benchmarkLevel) ? 4 : 4,
    };
  }

  // window/self/top 在小游戏 subcontext 已存在，且 window 是 getter-only 属性，
  // 直接赋值会抛 "Cannot set property window of #<Window>" 直接崩掉启动。
  // 这里只做「不存在才补」，绝不覆盖运行时已有对象。
  try { if (typeof g.window === 'undefined') g.window = g; } catch (e) { __log('g.window 跳过(已存在且只读): ' + (e && e.message)); }
  try { if (typeof g.self === 'undefined') g.self = g; } catch (e) { __log('g.self 跳过: ' + (e && e.message)); }
  try { if (typeof g.top === 'undefined') g.top = g; } catch (e) { __log('g.top 跳过: ' + (e && e.message)); }
  g.__canvas = canvas;
  __log('setupHostShim: 完成 (window===g? ' + (g.window === g) + ')');
  return canvas;
}

// ---------------------------------------------------------------------------
// 1.4) WebAssembly 垫片
// --------------------------------------------------------------------------
// 小游戏 subcontext 没有全局 WebAssembly，只有 WXWebAssembly（基础库 v2.13.0+，
// Worker 内 v2.15.0+）。WXWebAssembly.instantiate(path, imports) 直接接受
// 【代码包路径】，且原生支持 .wasm.br（brotli）——比 JS 解压 39MB 快得多。
//
// Godot 4.7 getModuleConfig 提供的 instantiateWasm：
//   if (typeof WebAssembly.instantiateStreaming !== 'undefined')
//     WebAssembly.instantiateStreaming(Promise.resolve(r), imports).then(done)
//   else r.arrayBuffer().then(b => WebAssembly.instantiate(b, imports).then(done))
// 其中 done(result) => onSuccess(result['instance'], result['module'])，
// 所以 instantiateStreaming 必须解析成 {instance, module} 形状。
// --------------------------------------------------------------------------
var __WASM_PKG_PATH = 'pkg_engine/index.wasm.br';

function installWebAssemblyShim() {
  var WXA = null;
  try { WXA = g.WXWebAssembly; } catch (e) {}
  try { if (!WXA && g.window && g.window !== g) WXA = g.window.WXWebAssembly; } catch (e) {}
  __log('installWebAssemblyShim: WXWebAssembly=' + (typeof WXA));

  if (typeof g.WebAssembly !== 'undefined') {
    __log('WebAssembly 已存在，跳过垫片');
    return;
  }
  if (typeof WXA === 'undefined') {
    __log('❌ WXWebAssembly 不存在，无法加载 WASM 引擎');
    return;
  }

  function toResult(res) {
    // WXWebAssembly.instantiate 可能返回 instance 或 {module, instance}，统一形状
    if (res && res.instance) return { instance: res.instance, module: res.module };
    return { instance: res, module: res && res.module };
  }

  var shim = {
    instantiateStreaming: function (responseOrPromise, imports) {
      __log('WebAssembly.instantiateStreaming -> WXWebAssembly.instantiate(' + __WASM_PKG_PATH + ')');
      return WXA.instantiate(__WASM_PKG_PATH, imports).then(function (res) {
        var inst = (res && res.instance) ? res.instance : res;
        try {
          var exp = inst && inst.exports;
          if (exp) {
            var keys = Object.keys(exp);
            __log('WXWebAssembly.instantiate 已解析: exports 数量=' + keys.length + ', pf=' + (typeof exp.pf) + ', rf=' + (typeof exp.rf) + ', sf=' + (typeof exp.sf) + ', of=' + (typeof exp.of));
            // 关键判别：先调用几个纯 wasm 导出，看 wasm 调用/内存增长是否顺畅。
            // 若 malloc 也卡住 -> wasm 执行/编译层面有问题（如惰性编译慢）；
            // 若 malloc 顺畅而 pf 卡住 -> 静态构造函数本身的问题。
            try {
              __log('简单导出测试: exp.tf(_malloc)(8) ...');
              var ta = Date.now();
              var ptr = exp.tf(8);
              __log('malloc(8) -> ' + ptr + ', ' + (Date.now() - ta) + 'ms');
              var tb = Date.now();
              exp.qf(ptr);
              __log('free 完成, ' + (Date.now() - tb) + 'ms');
              // 测试 1：wasm 执行速度（10 万次 malloc/free 循环）
              var tc = Date.now();
              var p2;
              for (var i = 0; i < 100000; i++) { p2 = exp.tf(16); exp.qf(p2); }
              __log('10万次 malloc/free 耗时: ' + (Date.now() - tc) + 'ms');
              // 测试 2：直接测试 wasm memory.grow（Godot 静态构造会大量分配，
              // 跨过 32MB 初始内存时会走 _emscripten_resize_heap -> memory.grow）
              try {
                var mem = exp.of;
                __log('memory.grow 测试: 当前 ' + mem.buffer.byteLength + ' bytes');
                var td = Date.now();
                var gr = mem.grow(1024); // +64MB
                __log('memory.grow(1024页) -> ' + gr + ', ' + (Date.now() - td) + 'ms, 新大小 ' + mem.buffer.byteLength);
                var te = Date.now();
                var gr2 = mem.grow(1024);
                __log('memory.grow 再次 -> ' + gr2 + ', ' + (Date.now() - te) + 'ms, 新大小 ' + mem.buffer.byteLength);
              } catch (e3) { __log('memory.grow 异常: ' + (e3 && e3.message)); }
            } catch (e2) { __log('简单导出调用异常: ' + (e2 && e2.message)); }
            // wasm exports 属性只读且 non-configurable，Proxy 不能返回不同值，
            // 只能观察读取顺序；pf 是否返回由下面的主动调用来验证
            var expProxy = new Proxy(exp, {
              get: function (target, prop) {
                try { if (typeof prop === 'string' && prop.length <= 4) __log('exports.' + prop + ' 被读取'); } catch (e) {}
                return target[prop];
              },
            });
            // 主动调用 pf（__wasm_call_ctors）：若卡死，线程阻塞、心跳停止，
            // 且看不到「pf 返回」日志 -> 坐实静态构造函数死循环
            try {
              __log('>>> 主动调用 exp.pf() 开始');
              var tpf = Date.now();
              exp.pf();
              __log('<<< 主动调用 exp.pf() 返回, ' + (Date.now() - tpf) + 'ms');
            } catch (e4) { __log('主动调用 pf 异常: ' + (e4 && (e4.message || e4))); }
            var instProxy = {
              get exports() {
                __log('>>> instance.exports 被访问（receiveInstance 开始）');
                return expProxy;
              },
            };
            __log('exports Proxy 已安装（instance 代理就绪）');
            return { instance: instProxy, module: (res && res.module) || undefined };
          }
          __log('WXWebAssembly.instantiate 已解析但拿不到 exports');
        } catch (e) { __log('exports 代理异常: ' + (e && e.message)); }
        return toResult(res);
      }, function (e) {
        __log('WXWebAssembly.instantiate 失败: ' + (e && (e.message || e)));
        throw e;
      });
    },
    instantiate: function (bytesOrPath, imports) {
      if (typeof bytesOrPath === 'string') {
        __log('WebAssembly.instantiate(path) -> WXWebAssembly.instantiate(' + bytesOrPath + ')');
        return WXA.instantiate(bytesOrPath, imports).then(toResult);
      }
      return Promise.reject(new Error('WXWebAssembly 不支持字节输入，仅支持代码包路径（.wasm/.wasm.br）'));
    },
    compile: function (bytesOrPath) {
      if (typeof bytesOrPath === 'string' && WXA.compile) return WXA.compile(bytesOrPath);
      return Promise.reject(new Error('WXWebAssembly 不支持字节 compile'));
    },
    compileStreaming: function (responseOrPromise) {
      return WXA.compile(__WASM_PKG_PATH);
    },
    Module: WXA.Module,
    Memory: WXA.Memory,
    Table: WXA.Table,
    Global: WXA.Global,
    RuntimeError: (typeof WXA.RuntimeError !== 'undefined') ? WXA.RuntimeError : Error,
    CompileError: (typeof WXA.CompileError !== 'undefined') ? WXA.CompileError : Error,
    LinkError: (typeof WXA.LinkError !== 'undefined') ? WXA.LinkError : Error,
    validate: function () { return true; },
  };

  try { g.WebAssembly = shim; __log('g.WebAssembly 垫片已安装'); } catch (e) { __log('g.WebAssembly 安装失败: ' + e); }
  try { if (g.window && g.window !== g) { g.window.WebAssembly = shim; __log('window.WebAssembly 垫片已安装'); } } catch (e) { __log('window.WebAssembly 安装失败: ' + e); }
}

// ---------------------------------------------------------------------------
// 1.5) fetch / Response / ReadableStream 垫片
// --------------------------------------------------------------------------
// 小游戏 subcontext 实测没有 fetch / Response / XMLHttpRequest（见启动日志），
// 而 Godot/Emscripten 的 wasm 与 pck 加载全走 fetch。这里用
// FileSystemManager.readFileSync 读分包内文件 + 纯 JS brotli 解码器解压，
// 伪造一个够用的 Response（ok/status/arrayBuffer/text）。
// brotli_loader.js 的职责已折叠进本垫片，不再单独 require。
// --------------------------------------------------------------------------
function installFetchShim() {
  __log('installFetchShim: 开始');
  var fs = null;
  try { fs = wx.getFileSystemManager(); } catch (e) { __log('getFileSystemManager 失败: ' + e); }

  // 最小 ReadableStream：支持 new ReadableStream({start(controller)})
  // 坑：closed/failed 必须放在共享 state 对象里——早期版本把布尔值拷进 state，
  // 控制器 close() 改的是闭包变量，读端永远看不到 done，导致 Godot 的 pck
  // arrayBuffer() 永久轮询、preloadFile 永不 resolve、游戏永远不启动。
  function MiniReadableStream(underlyingSource) {
    var state = { queue: [], closed: false, failed: null };
    var controller = {
      enqueue: function (chunk) { state.queue.push(chunk); },
      close: function () { state.closed = true; },
      error: function (e) { state.failed = e || new Error('stream error'); },
    };
    if (underlyingSource && typeof underlyingSource.start === 'function') {
      try { underlyingSource.start(controller); } catch (e) { state.failed = e; }
    }
    this._state = state;
  }
  MiniReadableStream.prototype.getReader = function () {
    var st = this._state;
    return {
      read: function () {
        if (st.failed) { var e = st.failed; st.failed = null; return Promise.reject(e); }
        if (st.queue.length > 0) return Promise.resolve({ value: st.queue.shift(), done: false });
        if (st.closed) return Promise.resolve({ value: undefined, done: true });
        // 生产者是 Promise 链（Godot 的 onloadprogress），轮询等待入队
        return new Promise(function (resolve, reject) {
          (function poll() {
            if (st.queue.length > 0) return resolve({ value: st.queue.shift(), done: false });
            if (st.failed) { var e2 = st.failed; st.failed = null; return reject(e2); }
            if (st.closed) return resolve({ value: undefined, done: true });
            setTimeout(poll, 0);
          })();
        });
      },
      cancel: function () { return Promise.resolve(); },
    };
  };

  function toArrayBuffer(u8) {
    var buf = new ArrayBuffer(u8.byteLength);
    new Uint8Array(buf).set(u8);
    return buf;
  }

  function normalizeHeaders(init) {
    var h = {};
    var src = (init && init.headers) || {};
    if (Array.isArray(src)) {
      for (var i = 0; i < src.length; i++) { if (src[i] && src[i].length >= 2) h[String(src[i][0]).toLowerCase()] = src[i][1]; }
    } else if (typeof src === 'object') {
      for (var k in src) { if (typeof src[k] !== 'function') h[String(k).toLowerCase()] = src[k]; }
    }
    return h;
  }

  // body: Uint8Array | ArrayBuffer | string | MiniReadableStream | null(空心)
  function makeResponse(body, init) {
    init = init || {};
    var headers = normalizeHeaders(init);
    var stream = null;
    var directBytes = null;

    if (body instanceof MiniReadableStream) {
      stream = body;
    } else if (body == null) {
      stream = makeBodyStream(null);
    } else if (typeof body === 'string') {
      var u = new Uint8Array(body.length);
      for (var i = 0; i < body.length; i++) u[i] = body.charCodeAt(i) & 0xff;
      directBytes = u;
      stream = makeBodyStream(u);
    } else if (body instanceof Uint8Array) {
      directBytes = body;
      stream = makeBodyStream(body);
    } else if (body instanceof ArrayBuffer) {
      directBytes = new Uint8Array(body);
      stream = makeBodyStream(directBytes);
    } else if (body && body.buffer) {
      directBytes = new Uint8Array(body.buffer, body.byteOffset, body.byteLength);
      stream = makeBodyStream(directBytes);
    } else {
      directBytes = new Uint8Array(0);
      stream = makeBodyStream(directBytes);
    }

    function drain() {
      if (directBytes) return Promise.resolve(toArrayBuffer(directBytes));
      var reader = stream.getReader();
      var chunks = [];
      var total = 0;
      function pump() {
        return reader.read().then(function (r) {
          if (r.done) return;
          if (r.value) { chunks.push(r.value); total += r.value.length; }
          return pump();
        });
      }
      return pump().then(function () {
        var out = new Uint8Array(total);
        var off = 0;
        for (var i = 0; i < chunks.length; i++) { out.set(chunks[i], off); off += chunks[i].length; }
        return out.buffer;
      });
    }

    return {
      ok: true,
      status: 200,
      statusText: 'OK',
      type: 'basic',
      url: '',
      redirected: false,
      headers: {
        get: function (k) { var kk = String(k).toLowerCase(); return headers[kk] !== undefined ? headers[kk] : null; },
        has: function (k) { return headers[String(k).toLowerCase()] !== undefined; },
      },
      body: stream,
      clone: function () { return makeResponse(body, init); },
      arrayBuffer: drain,
      text: function () { return drain().then(function (buf) { return new TextDecoder().decode(new Uint8Array(buf)); }); },
      json: function () { return drain().then(function (buf) { return JSON.parse(new TextDecoder().decode(new Uint8Array(buf))); }); },
    };
  }

  function makeBodyStream(data) {
    var CHUNK = 512 * 1024;
    var pos = 0;
    return new MiniReadableStream({
      start: function (controller) {
        if (!data || data.length === 0) { controller.close(); return; }
        while (pos < data.length) {
          var end = Math.min(pos + CHUNK, data.length);
          controller.enqueue(data.subarray(pos, end));
          pos = end;
        }
        controller.close();
      },
    });
  }

  // basename -> 包内 .br 文件
  var BR_MAP = {
    'index.wasm': 'pkg_engine/index.wasm.br',
    'index.pck': 'pkg_assets/index.pck.br',
  };

  function readLocal(path) {
    try { return fs.readFileSync(path); } catch (e) { return null; }
  }

  function decompressBr(u8) {
    if (typeof g.__brotliDecompress !== 'function') {
      throw new Error('brotli 解码器未就绪');
    }
    return new Uint8Array(g.__brotliDecompress(u8));
  }

  function fakeFetch(input, init) {
    var url = (typeof input === 'string') ? input : (input && input.url) || String(input);
    var base = String(url).split('?')[0].split('#')[0].split('/').pop();
    return new Promise(function (resolve, reject) {
      try {
        if (base === 'index.wasm') {
          // 空心响应：真实加载走 WXWebAssembly.instantiate('pkg_engine/index.wasm.br')
          __log('fetch -> index.wasm（空心响应，实际由 WXWebAssembly 加载 .br）');
          resolve(makeResponse(null, { headers: { 'content-type': 'application/wasm' } }));
          return;
        }
        if (BR_MAP[base]) {
          __log('fetch -> ' + base + ' 读取 ' + BR_MAP[base]);
          var buf = readLocal(BR_MAP[base]);
          if (buf == null) { reject(new Error('fetch: 读不到分包文件 ' + BR_MAP[base])); return; }
          var t0 = Date.now();
          var out = decompressBr(new Uint8Array(buf));
          __log('fetch -> ' + base + ' brotli 解压: ' + buf.byteLength + ' -> ' + out.byteLength + ' bytes, ' + (Date.now() - t0) + 'ms');
          resolve(makeResponse(out, { headers: { 'content-type': 'application/octet-stream' } }));
          return;
        }
        // 其它请求：尝试按包内相对路径读盘
        var p = String(url).split('?')[0].split('#')[0].replace(/^[a-z][a-z0-9+.-]*:\/\/[^/]*\//i, '');
        var m = p.match(/(pkg_[^/]+\/[^?#]*|game\.js|game\.json|project\.config\.json)$/);
        var path = m ? m[1] : p.replace(/^\/+/, '');
        var buf2 = readLocal(path);
        if (buf2 == null) {
          reject(new Error('fetch: 包内找不到文件 ' + path + ' (url=' + url + ')'));
          return;
        }
        __log('fetch -> 包内文件 ' + path + ' (' + buf2.byteLength + ' bytes)');
        resolve(makeResponse(new Uint8Array(buf2), { headers: { 'content-type': 'application/octet-stream' } }));
      } catch (e) {
        reject(e);
      }
    });
  }

  try { g.ReadableStream = MiniReadableStream; } catch (e) {}
  try { if (g.window && g.window !== g) g.window.ReadableStream = MiniReadableStream; } catch (e) {}
  try { g.Response = makeResponse; __log('Response 垫片已安装'); } catch (e) { __log('Response 安装失败: ' + e); }
  try { if (g.window && g.window !== g) g.window.Response = makeResponse; } catch (e) {}
  try { g.fetch = fakeFetch; __log('g.fetch 垫片已安装'); } catch (e) { __log('g.fetch 安装失败: ' + e); }
  try { if (g.window && g.window !== g) { g.window.fetch = fakeFetch; __log('window.fetch 垫片已安装'); } } catch (e) { __log('window.fetch 安装失败: ' + e); }
  __log('installFetchShim: 完成');
}

// ---------------------------------------------------------------------------
// 2) 分包加载
// ---------------------------------------------------------------------------
function loadSubpackage(name) {
  return new Promise(function (resolve, reject) {
    if (typeof wx.loadSubpackage !== 'function') { __log('loadSubpackage: 无此 API，按单包模式继续'); return resolve(); }
    const task = wx.loadSubpackage({
      name: name,
      success: function () {
        g.__DZSG.log('分包加载完成:', name);
        resolve();
      },
      fail: function (err) {
        __log('loadSubpackage FAIL: ' + name + ' -> ' + JSON.stringify(err));
        reject(new Error('分包 ' + name + ' 加载失败: ' + (err && (err.errMsg || err.message))));
      },
    });
    if (task && typeof task.onProgressUpdate === 'function') {
      task.onProgressUpdate(function (p) {
        if (p && p.totalBytesExpectedToWrite) {
          const pct = Math.floor((p.totalBytesWritten / p.totalBytesExpectedToWrite) * 100);
          if (pct % 20 === 0) g.__DZSG.log('  下载', pct + '%');
        }
      });
    }
  });
}

// ---------------------------------------------------------------------------
// 3) 主流程
// ---------------------------------------------------------------------------
// 已知噪音判定：微信不支持 AudioWorklet，引擎（已 catch 此错误）每个声音
// 启动都会打印 "Failed to create PositionWorklet."——纯噪音，直接吞掉
function __isNoise(args) {
  for (var i = 0; i < args.length; i++) {
    var a = args[i];
    var s = '';
    try { s = (a && a.message) ? a.message : String(a); } catch (e) { continue; }
    if (s.indexOf('PositionWorklet') !== -1) return true;
  }
  return false;
}

// console tee：把引擎（Godot C++ print/printErr）和一切 console 输出收进日志
function teeConsole() {
  try {
    var c = g.console;
    if (!c) { __log('console 不存在，跳过 tee'); return; }
    ['log', 'warn', 'error', 'info', 'debug'].forEach(function (k) {
      var orig = c[k];
      if (typeof orig !== 'function') return;
      c[k] = function () {
        try {
          // 已知噪音过滤：微信无 AudioWorklet，引擎每个声音启动都会刷
          // "Failed to create PositionWorklet."（已被胶水 catch，不影响运行）
          if (k === 'error' && __isNoise(arguments)) return;
          var args = Array.prototype.slice.call(arguments);
          var text = args.map(function (x) { try { return typeof x === 'string' ? x : JSON.stringify(x); } catch (e) { return String(x); } }).join(' ').slice(0, 600);
          if (text.indexOf('[BOOT') !== 0 && text.indexOf('[DZSG') !== 0) __log('[console.' + k + '] ' + text);
        } catch (e) {}
        try { return orig.apply(c, arguments); } catch (e) {}
      };
    });
    __log('console tee 已安装');
  } catch (e) { __log('console tee 失败: ' + e); }
  try {
    var gc = g.gameSubContextConsole;
    if (gc && typeof gc.log === 'function') {
      ['log', 'warn', 'error', 'info'].forEach(function (k) {
        var orig2 = gc[k];
        if (typeof orig2 !== 'function') return;
        gc[k] = function () {
          try {
            if (k === 'error' && __isNoise(arguments)) return;
            var a2 = Array.prototype.slice.call(arguments).map(String).join(' ').slice(0, 600);
            if (a2.indexOf('[BOOT') !== 0 && a2.indexOf('[DZSG') !== 0) __log('[subconsole.' + k + '] ' + a2);
          } catch (e) {}
          try { return orig2.apply(gc, arguments); } catch (e) {}
        };
      });
      __log('gameSubContextConsole tee 已安装');
    }
  } catch (e) {}
}

/* ==========================================================================
 * 【音频修复】微信小游戏里 Godot 音频无声
 * --------------------------------------------------------------------------
 * 现象：BGM / 音效 / 配音在微信小游戏里一点声音都没有，而编辑器里同一份音频
 *       数据是有内容的（缓冲 RMS 非零、BufferSource 也真的 start 了）。
 *
 * 实测定位（2026-10-16）：
 *   1. Godot Web 胶水把每个音效注册成一个 WebAudio 音频缓冲，再经
 *      「样本总线(6 声道分路/合并) → 混音总线增益 → AudioContext.destination」
 *      这条节点链送出去；
 *   2. 这条链在微信里全程无声：把主总线出口另行放大 12dB 再接到扬声器仍然没声，
 *      连把 6 声道链路降混成 2 声道也无济于事；
 *   3. 而把音频源「直接」接到 AudioContext.destination，立刻一切正常
 *      （BGM、音效、配音全部可闻）。
 *   结论：问题出在 Godot 搭的那条总线节点链在微信环境下的传输上，不在音频数据。
 *
 * 做法：给每个音频源在播放时另接一路「源 → 增益 → 扬声器」，把声音直接送出去。
 *       只改本文件（不动 pkg_engine/index.js），所以重新从 Godot 导出 Web 包也不会丢。
 *
 * 代价：运行时的混音台音量 / 淡入淡出不再生效，每个声音按原始文件电平播放。
 *       听感实测正常；若将来微信侧修好了这条链，把 g.__dzsgAudioBypass 设为 0
 *       即可关闭本旁路。
 * ========================================================================== */
var DZSG_AUDIO_BYPASS = 0.5;

function installAudioBypass() {
  try {
    var AC = null;
    try { AC = g.AudioContext; } catch (e) {}
    if (!AC && g.window) { try { AC = g.window.AudioContext; } catch (e) {} }
    if (!AC) { __log('🔊修复: 环境无 AudioContext，跳过'); return; }
    var proto = AC.prototype;
    if (!proto || typeof proto.createBufferSource !== 'function') {
      __log('🔊修复: AudioContext.prototype.createBufferSource 不存在，跳过');
      return;
    }
    if (proto.__dzsgAudioBypass) { __log('🔊修复: 已安装过，跳过'); return; }
    proto.__dzsgAudioBypass = true;
    g.__dzsgAudioBypass = DZSG_AUDIO_BYPASS;

    var origCreate = proto.createBufferSource;
    proto.createBufferSource = function () {
      var node = origCreate.apply(this, arguments);
      try {
        if (!g.__audioCtx) g.__audioCtx = this;
        var ctx = g.__audioCtx;
        var origStart = node.start;
        node.start = function () {
          try {
            var gain = g.__dzsgAudioBypass;
            if (gain > 0 && !node.__dzsgBypassed) {
              node.__dzsgBypassed = true;
              var gg = ctx.createGain();
              gg.gain.value = gain;
              node.connect(gg);
              gg.connect(ctx.destination);
            }
          } catch (e) {}
          return origStart.apply(node, arguments);
        };
      } catch (e) {}
      return node;
    };
    __log('🔊修复: 已启用「音频源直连扬声器」旁路 (增益 ' + DZSG_AUDIO_BYPASS + ')');
  } catch (e) { __log('🔊修复: 安装异常 ' + (e && e.message)); }
}

function boot() {
  __log('boot() 进入');
  teeConsole();
  let canvas;
  try {
    canvas = setupHostShim();
  } catch (e) {
    __log('setupHostShim 异常: ' + (e && (e.stack || e.message) || e));
    throw e;
  }
  g.__DZSG.log('宿主垫片就绪, 画布', canvas.width + 'x' + canvas.height);
  installAudioBypass();

  try {
    installWebAssemblyShim();
  } catch (e) {
    __log('installWebAssemblyShim 异常: ' + (e && (e.stack || e.message) || e));
  }

  try {
    installFetchShim();
  } catch (e) {
    __log('installFetchShim 异常: ' + (e && (e.stack || e.message) || e));
  }

  Promise.all([loadSubpackage('engine'), loadSubpackage('assets')])
    .then(function () {
      g.__DZSG.log('分包全部就绪, 加载脚本...');

      // 探测：分包文件能否通过 FileSystemManager 直接读（fetch 垫片的地基）
      try {
        var fsm = wx.getFileSystemManager();
        var probe = fsm.readFileSync('pkg_engine/game.js');
        __log('分包读盘探测: pkg_engine/game.js 可读, ' + (probe && probe.byteLength) + ' bytes');
      } catch (e) {
        __log('分包读盘探测失败(相对路径): ' + (e && (e.message || e)));
        try {
          var fsm2 = wx.getFileSystemManager();
          var probe2 = fsm2.readFileSync('/pkg_engine/game.js');
          __log('分包读盘探测: /pkg_engine/game.js 可读, ' + (probe2 && probe2.byteLength) + ' bytes');
        } catch (e2) {
          __log('分包读盘探测失败(前导斜杠): ' + (e2 && (e2.message || e2)));
        }
      }

      // 顺序敏感：解码器必须先于引擎存在（fetch 垫片在解压时才用它）
      try {
        require('./pkg_engine/brotli_decoder.js');
        __log('require brotli_decoder.js 成功, __brotliDecompress=' + (typeof g.__brotliDecompress) + ', window.__brotliDecompress=' + (typeof g.window.__brotliDecompress));
      } catch (e) {
        __log('require brotli_decoder.js 异常: ' + (e && (e.stack || e.message) || e));
        throw e;
      }

      try {
        var EngineModule = require('./pkg_engine/index.js');
        __log('require index.js 返回: typeof=' + (typeof EngineModule) + ', keys=' + (EngineModule ? Object.keys(EngineModule).slice(0, 20).join(',') : 'null'));
        // 注意：require 返回的是 Godot 工厂（UMD: module.exports=Godot），
        // 真正的 Engine 类由胶水在文件末尾 `window['Engine'] = Engine` 挂载
        // （subcontext 里 window===GameGlobal，所以就是 g.Engine）。
        var EngineClass = null;
        if (typeof g.Engine === 'function') EngineClass = g.Engine;
        else if (g.window && typeof g.window.Engine === 'function') EngineClass = g.window.Engine;
        else if (EngineModule && typeof EngineModule === 'function') EngineClass = EngineModule;
        g.Engine = EngineClass;
        __log('Engine 解析结果: typeof=' + (typeof g.Engine) + ', startGame=' + (g.Engine && g.Engine.prototype ? typeof g.Engine.prototype.startGame : 'n/a'));
      } catch (e) {
        __log('require index.js 异常: ' + (e && (e.stack || e.message) || e));
        throw e;
      }

      if (typeof g.Engine !== 'function') {
        throw new Error('Godot Engine 未定义，index.js 可能加载失败');
      }

      // 让 locateFile 指向分包内路径
      var loader = { locateFile: null };
      var rawLocate = function (path, prefix) { return (prefix || '') + path; };
      loader.locateFile = function (path, prefix) {
        var base = String(path).split('/').pop();
        if (base === 'index.wasm') return 'pkg_engine/index.wasm.br';
        if (base === 'index.pck') return 'pkg_assets/index.pck.br';
        return rawLocate ? rawLocate(path, prefix) : ((prefix || '') + path);
      };
      g.__DZSG.log('locateFile 已指向分包路径');

      var CONFIG = {
        canvas: canvas,
        locateFile: loader.locateFile,
        canvasResizePolicy: 2,
        executable: 'index',
        args: [],
        fileSizes: { 'index.pck': 10434340, 'index.wasm': 39514754 },
        focusCanvas: false,
        emscriptenPoolSize: 0,
        godotPoolSize: 0,
        ensureCrossOriginIsolationHeaders: false,
        gdextensionLibs: [],
        experimentalVK: false,
        // 小游戏无 indexedDB：持久化路径置空，initFS 直接 resolve，
        // 否则 GodotFS.init 会挂 IDBFS 并 FS.syncfs，在无 IDB 环境可能永远不回调
        persistentPaths: [],
      };

      g.__DZSG.log('启动 Godot 引擎...');
      __log('new Engine() 开始');
      var engine;
      try {
        engine = new g.Engine(CONFIG);
        __log('new Engine() 完成');
      } catch (e) {
        __log('new Engine() 异常: ' + (e && (e.stack || e.message) || e));
        throw e;
      }

      engine.startGame({
        onProgress: function (cur, total) {
          if (cur > 0 && total > 0) {
            var pct = Math.floor((cur / total) * 100);
            if (pct % 25 === 0) g.__DZSG.log('引擎加载', pct + '%');
          }
        },
      }).then(function () {
        g.__DZSG.log('✅ 引擎启动完成，游戏运行中');
        __log('===== 引擎启动完成 =====');
      }).catch(function (e) {
        g.__DZSG.error('❌ 引擎启动失败:', (e && (e.message || e)) || e);
        __log('startGame reject: ' + (e && (e.stack || e.message) || e));
      });
    })
    .catch(function (e) {
      g.__DZSG.error('❌ 启动流程失败:', (e && e.message) || e);
      __log('boot catch: ' + (e && (e.stack || e.message) || e));
    });
}

try {
  if (typeof Game !== 'undefined') {
    __log('检测到 Game 全局对象，使用 onCreate 生命周期');
    var game = new Game();
    game.onCreate = function () { try { boot(); } catch (e) { __log('onCreate boot 异常: ' + (e && (e.stack || e.message) || e)); } };
    game.onShow = function () {};
    game.onHide = function () {};
  } else {
    __log('无 Game 全局对象，直接 boot()');
    boot();
  }
} catch (e) {
  __log('顶层异常: ' + (e && (e.stack || e.message) || e));
}
