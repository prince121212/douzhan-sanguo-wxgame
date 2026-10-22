/* ==========================================================================
 * game.js —— 斗战三国 · 微信小游戏入口
 * --------------------------------------------------------------------------
 * 这个文件是「小游戏宿主适配层」，负责三件事：
 *   1. 宿主垫片：小游戏没有 window/document/fetch/WebAssembly 等浏览器能力，
 *      这里补齐 Godot Web 胶水需要的最小实现（canvas / fetch / WXWebAssembly）。
 *   2. 触摸桥：小游戏触摸只能从 wx.onTouch* 拿到，而胶水用
 *      canvas.addEventListener('touchstart') —— 这里把两者接起来。
 *   3. 音频旁路：微信里 Godot 的 WebAudio 总线链路到扬声器是哑的，
 *      改成音源直连 destination，并按总线增益跟随音量。
 *
 * 启动日志写在 wx.env.USER_DATA_PATH + '/dzsg_boot.log'，同时输出到 console。
 * ========================================================================== */

const g = GameGlobal;

// ---------------------------------------------------------------------------
// 0) 诊断日志设施（必须最先就绪，且自身容错，不能影响主流程）
// ---------------------------------------------------------------------------
var __LOG_PATH = null;
try { __LOG_PATH = wx.env.USER_DATA_PATH + '/dzsg_boot.log'; } catch (e) {}
try { if (!__LOG_PATH) __LOG_PATH = 'dzsg_boot.log'; } catch (e) {}

// 日志缓冲：同步 appendFileSync 每行都落盘，在真机上很拖性能。
// 改成攒 300ms 批量写一次；启动阶段的关键行用 __logNow 立即落盘。
var __logBuf = [];
var __logTimer = null;
var __logBusy = false;

function __flushLog() {
  __logTimer = null;
  if (!__logBuf.length) return;
  var text = __logBuf.join('\n') + '\n';
  __logBuf.length = 0;
  try {
    var fs = wx.getFileSystemManager();
    try {
      fs.appendFileSync(__LOG_PATH, text, 'utf8');
    } catch (e2) {
      fs.writeFileSync(__LOG_PATH, text, 'utf8');
    }
  } catch (e3) {}
}

function __log(msg) {
  if (__logBusy) return;
  __logBusy = true;
  var line;
  try { line = '[BOOT ' + new Date().toISOString() + '] ' + msg; } catch (e) { line = '[BOOT] ' + msg; }
  try { console.log(line); } catch (e) {}
  try {
    __logBuf.push(line);
    if (__logBuf.length > 200) __logBuf.shift();
    if (__logTimer === null) __logTimer = setTimeout(__flushLog, 300);
  } catch (e4) {}
  __logBusy = false;
}

// 启动关键节点：立即落盘（崩溃时也能留下证据）
function __logNow(msg) {
  __log(msg);
  try { __flushLog(); } catch (e) {}
}

function __probeEnv() {
  __log('===== game.js 开始执行 =====');
  try { __log('USER_DATA_PATH=' + wx.env.USER_DATA_PATH); } catch (e) {}
  try {
    var sys = wx.getSystemInfoSync();
    __log('systemInfo: platform=' + sys.platform + ', model=' + (sys.model || '') + ', SDKVersion=' + sys.SDKVersion);
    __log('屏幕: ' + sys.windowWidth + 'x' + sys.windowHeight + ' @dpr=' + sys.pixelRatio);
  } catch (e) { __log('getSystemInfoSync 失败: ' + e); }
  try { __log('环境: fetch=' + (typeof fetch) + ', WebAssembly=' + (typeof WebAssembly) + ', WXWebAssembly=' + (typeof g.WXWebAssembly)); } catch (e) {}
}

__probeEnv();

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

// ---------------------------------------------------------------------------
// 0.5) 存档桥（给 Godot 的 JavaScriptBridge 用）
// ---------------------------------------------------------------------------
// 为什么不直接在 GDScript 里 eval "wx.setStorageSync(...)"：
//   · Godot 的 eval 跑在引擎胶水的模块作用域，未必能直接看到 wx；
//   · 平台对 eval 的限制也更难排查。
// 这里在 game.js（一定能拿到 wx）里挂一个极小的同步接口，GDScript 只调它。
g.__dzsgStorage = {
  dzsgGet: function (key) {
    try { var v = wx.getStorageSync(key); return (typeof v === 'string') ? v : ''; }
    catch (e) { return ''; }
  },
  dzsgSet: function (key, val) {
    try { wx.setStorageSync(key, val); return '1'; }
    catch (e) { return 'ERR:' + (e && e.message || e); }
  },
  dzsgDel: function (key) {
    try { wx.removeStorageSync(key); return '1'; }
    catch (e) { return 'ERR:' + (e && e.message || e); }
  },
};

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

// ---------------------------------------------------------------------------
// 自检探针：帧率 + 像素采样
// ---------------------------------------------------------------------------
// 目的：日志里「引擎启动完成」只证明 startGame 的 Promise resolve 了，
//       不证明画面真的有内容。这里每约 5 秒读一次默认帧缓冲中心像素，
//       配合画布尺寸，能一眼看出「黑屏空转」（canvas 0x0 或像素全黑）。
function installFrameProbe() {
  try {
    var origRaf = g.requestAnimationFrame;
    if (typeof origRaf !== 'function') { __log('无 requestAnimationFrame，跳过自检探针'); return; }
    var frames = 0;
    var t0 = Date.now();
    var sampleCount = 0;
    function sampleFrame() {
      try {
        var gl = g.__DZSG.gl;
        var cv = g.__DZSG.canvas;
        if (!gl || !cv) return;
        sampleCount++;
        if (sampleCount % 240 !== 1) return;   // 约 5 秒采一次
        gl.bindFramebuffer(gl.FRAMEBUFFER, null);
        var px = new Uint8Array(4);
        gl.readPixels((gl.drawingBufferWidth / 2) | 0, (gl.drawingBufferHeight / 2) | 0, 1, 1,
                      gl.RGBA, gl.UNSIGNED_BYTE, px);
        __log('像素采样#' + sampleCount + ': RGBA=' + px[0] + ',' + px[1] + ',' + px[2] + ',' + px[3]
          + ' | 画布=' + cv.width + 'x' + cv.height
          + ' | drawingBuffer=' + gl.drawingBufferWidth + 'x' + gl.drawingBufferHeight);
      } catch (e) {
        if (sampleCount % 1200 === 1) __log('像素采样失败: ' + (e && e.message));
      }
    }
    g.requestAnimationFrame = function (cb) {
      frames++;
      return origRaf.call(g, function (ts) {
        try { cb(ts); } finally { sampleFrame(); }
      });
    };
    setInterval(function () {
      var dt = Date.now() - t0;
      if (dt < 5000) return;
      __log('帧率: ' + (frames * 1000 / dt).toFixed(1) + ' fps');
      frames = 0;
      t0 = Date.now();
    }, 5000);
    __log('自检探针已安装（帧率 + 像素采样）');
  } catch (e) { __log('自检探针安装失败: ' + (e && e.message)); }
}

// ---------------------------------------------------------------------------
// 触摸桥：wx.onTouch* -> canvas.addEventListener 派发
// ---------------------------------------------------------------------------
function installTouchBridge(canvas) {
  if (typeof wx === 'undefined' || typeof wx.onTouchStart !== 'function') {
    __log('触摸桥: 环境没有 wx.onTouch*，跳过');
    return;
  }
  // 小游戏里触摸事件只能从 wx.onTouch* 拿到。画布即便自带 addEventListener，
  // 也不保证会派发 DOM 触摸事件（真机上多半不会），所以统一走 wx.onTouch*，
  // 再把事件转发给 Godot 胶水注册的回调。鼠标等其它事件仍走原生。
  var origAdd = (typeof canvas.addEventListener === 'function') ? canvas.addEventListener : null;
  var origRemove = (typeof canvas.removeEventListener === 'function') ? canvas.removeEventListener : null;
  var handlers = { touchstart: [], touchmove: [], touchend: [], touchcancel: [] };

  canvas.addEventListener = function (type, fn, opts) {
    var k = String(type);
    if (k.indexOf('touch') === 0) {
      if (!handlers[k]) handlers[k] = [];
      if (handlers[k].indexOf(fn) === -1) {
        handlers[k].push(fn);
        __log('触摸桥: 引擎注册了 ' + k + ' 监听（共 ' + handlers[k].length + ' 个）');
      }
      return;
    }
    if (origAdd) { try { origAdd.call(canvas, type, fn, opts); } catch (e) {} }
  };
  canvas.removeEventListener = function (type, fn, opts) {
    var k = String(type);
    if (k.indexOf('touch') === 0) {
      var arr = handlers[k];
      if (!arr) return;
      var i = arr.indexOf(fn);
      if (i >= 0) arr.splice(i, 1);
      return;
    }
    if (origRemove) { try { origRemove.call(canvas, type, fn, opts); } catch (e) {} }
  };
  // 胶水在 touchstart 里会调用 canvas.focus()，小游戏画布没有这个方法
  if (typeof canvas.focus !== 'function') canvas.focus = function () {};
  // 让引擎的触摸能力探测（"ontouchstart" in window）返回真
  try { if (!('ontouchstart' in g)) g.ontouchstart = null; } catch (e) {}

  function toDomTouches(list) {
    var out = [];
    for (var i = 0; i < (list ? list.length : 0); i++) {
      var t = list[i] || {};
      var x = (typeof t.clientX === 'number') ? t.clientX : (t.x || 0);
      var y = (typeof t.clientY === 'number') ? t.clientY : (t.y || 0);
      out.push({ identifier: (t.identifier === undefined) ? i : t.identifier,
                 clientX: x, clientY: y, pageX: x, pageY: y, screenX: x, screenY: y });
    }
    return out;
  }

  function dispatch(type, evt) {
    var changed = (evt && evt.changedTouches && evt.changedTouches.length) ? evt.changedTouches : (evt && evt.touches);
    var domEvt = {
      type: type, target: canvas, currentTarget: canvas,
      changedTouches: toDomTouches(changed),
      touches: toDomTouches(evt && evt.touches),
      cancelable: true,
      preventDefault: function () {}, stopPropagation: function () {},
    };
    var arr = handlers[type] || [];
    for (var i = 0; i < arr.length; i++) {
      try { arr[i].call(canvas, domEvt); } catch (e) { __log('触摸回调异常(' + type + '): ' + (e && e.message)); }
    }
  }

  wx.onTouchStart(function (e) { dispatch('touchstart', e); });
  wx.onTouchMove(function (e) { dispatch('touchmove', e); });
  wx.onTouchEnd(function (e) { dispatch('touchend', e); });
  if (typeof wx.onTouchCancel === 'function') wx.onTouchCancel(function (e) { dispatch('touchcancel', e); });
  __log('触摸桥: 已把 wx.onTouch* 接到画布事件（虚拟摇杆/按钮可用）');
}

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
    // 捕获 WebGL 上下文：自检探针用它读像素，区分「真渲染」和「黑屏空转」
    try {
      var origGetContext = canvas.getContext;
      if (typeof origGetContext === 'function' && !canvas.__dzsgCtxHooked) {
        canvas.__dzsgCtxHooked = true;
        canvas.getContext = function (type, attrs) {
          var c = origGetContext.call(canvas, type, attrs);
          try {
            if (c && !g.__DZSG.gl && String(type).indexOf('webgl') !== -1) g.__DZSG.gl = c;
          } catch (e) {}
          return c;
        };
      }
    } catch (e) { __log('getContext 钩子失败: ' + (e && e.message)); }
    g.__DZSG.canvas = canvas;
    // 胶水 updateSize() 会写 canvas.style.width/height；输入法定位用 getBoundingClientRect
    if (!canvas.style) canvas.style = {};
    if (typeof canvas.getBoundingClientRect !== 'function') {
      canvas.getBoundingClientRect = function () {
        return { left: 0, top: 0, right: sw, bottom: sh, width: sw, height: sh };
      };
    }
    __log('setupHostShim: 显示垫片 innerWidth=' + sw + ' innerHeight=' + sh + ' dpr=' + dpr);
  } catch (e) { __log('setupHostShim: 显示垫片失败: ' + (e && e.message)); }

  // 触摸桥：Godot 的 Web 胶水用 canvas.addEventListener('touchstart'...) 收触摸，
  // 而小游戏的画布是 wx.createCanvas() 造的对象，触摸只能从 wx.onTouchStart 拿。
  // 若画布没有 addEventListener，就在这里补一套：记录监听器，把 wx 的触摸事件
  // 转成 DOM 风格事件派发过去。这样虚拟摇杆和招式按钮在微信里才按得动。
  try {
    installTouchBridge(canvas);
  } catch (e) { __log('触摸桥安装失败: ' + (e && e.message)); }

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
        __log('WXWebAssembly.instantiate 完成');
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
// 解压逻辑全部在本垫片内，不再单独 require 解码脚本。
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
 * 音量：旁路增益不是写死的，而是播放时从 source 沿节点图找到「到扬声器」的通路，
 *       把路上所有 GainNode 的值相乘（= Godot 本来要施加的总音量），
 *       并每 400ms 重算一次。因此「音乐/音效音量」滑条、BGM 淡入淡出、
 *       静音全部照常生效（2026-10-21 修复：此前固定 0.5，滑条拖了没反应）。
 *
 * 关闭：把 g.__dzsgAudioBypass 设为 0（或删掉整段）即恢复 Godot 原生链路。
 * ========================================================================== */
var DZSG_AUDIO_BYPASS = 0.5;   // 兜底增益：算不出链路音量时用它

/* --------------------------------------------------------------------------
 * 音量跟随：旁路必须复制「Godot 本来要用的音量」。
 * --------------------------------------------------------------------------
 * 老版本把每个音源用固定增益 0.5 直连扬声器，于是：
 *   · 设置里的「音乐音量 / 音效音量」完全失效（滑条怎么拖都一样响）；
 *   · 单个音效的相对音量（Sfx.play 的 vol_db）也丢了。
 *
 * 现在：给 WebAudio 节点图记一份「谁连到谁」的边；播放时从 source 出发 BFS，
 * 取所有能到扬声器的通路里增益最大的那条，把路上 GainNode 的 gain 相乘。
 * 每 400ms 对正在播的源重算一次，滑条拖动 / BGM 淡入淡出即时生效。
 * -------------------------------------------------------------------------- */

function dzsgEnsureGraphHook(ctx) {
  if (!ctx || g.__dzsgGraphHooked) return true;
  try {
    // 注意：createGain / createChannelSplitter 这些方法挂在 BaseAudioContext 原型上，
    // connect 挂在 AudioNode 原型上。必须沿原型链找到真正持有方法的对象，
    // 在实例上包会被引擎后续的调用绕过（实测包装会“消失”）。
    // 必须找「自己拥有」这个方法的原型（hasOwnProperty）。
    // 只判断 typeof p[name] 会停在 GainNode.prototype 上（connect 是继承来的），
    // 结果只给 GainNode 打了补丁，ChannelSplitter/Merger 的连线就记不到。
    function ownerProto(obj, name) {
      var p = Object.getPrototypeOf(obj);
      while (p && p !== Object.prototype) {
        if (Object.prototype.hasOwnProperty.call(p, name) && typeof p[name] === 'function') return p;
        p = Object.getPrototypeOf(p);
      }
      return null;
    }

    // connect / disconnect 在 AudioNode 原型上
    var probe = null;
    try { probe = ctx.createGain(); } catch (e) {}
    var nodeProto = probe ? ownerProto(probe, 'connect') : null;
    if (nodeProto) {
      if (!nodeProto.__dzsgConnectPatched) {
        nodeProto.__dzsgConnectPatched = true;
        var origConnect = nodeProto.connect;
        var origDisconnect = nodeProto.disconnect;
        nodeProto.connect = function (dest) {
          var r = origConnect.apply(this, arguments);
          try {
            // 连到扬声器的节点打标记。
            // 注意：微信里 ctx.destination 每次访问可能返回不同包装对象，不能靠 === 判断，
            // 用构造器名（AudioDestinationNode）识别最稳。
            if (dest && typeof dest === 'object') {
              var ctorName = '';
              try { ctorName = dest.constructor && dest.constructor.name; } catch (e2) {}
              if (ctorName === 'AudioDestinationNode' ||
                  (g.__audioCtx && dest === g.__audioCtx.destination)) {
                this.__dzsgToDest = true;
              }
            }
            if (dest && typeof dest === 'object') {
              if (!this.__dzsgOut) this.__dzsgOut = [];
              var outs = this.__dzsgOut;
              var seen = false;
              for (var k = 0; k < outs.length; k++) { if (outs[k] === dest) { seen = true; break; } }
              if (!seen) outs.push(dest);
            }
          } catch (e) {}
          return r;
        };
        if (typeof origDisconnect === 'function') {
          nodeProto.disconnect = function () {
            try { this.__dzsgOut = []; } catch (e) {}
            return origDisconnect.apply(this, arguments);
          };
        }
      }
    }
    g.__dzsgGraphHooked = true;
    return true;
  } catch (e) {
    __log('🔊修复: 节点图 hook 安装失败 ' + (e && e.message));
    return false;
  }
}

/* 从 source 到 destination 的增益乘积。
 * 用「最大增益路径」而不是最短路径：Godot 的样本总线是
 * splitter → 6 个声道增益(L/R/SL/SR/C/LFE) → merger，
 * 单声道音效只有 L 那路非零，若走最短路径可能先撞上增益为 0 的声道，
 * 误判成静音。取所有路径里增益最大的那条才是真实听感。
 * 返回 -1 表示找不到到 destination 的通路。 */
function dzsgPathGain(src) {
  var ctx = g.__audioCtx;
  if (!ctx) return -1;
  // 微信的 ctx.destination 每次访问可能返回不同的包装对象，不能靠 === 比较。
  // 所以在 connect 时给「连到扬声器」的节点打 __dzsgToDest 标记，
  // BFS 走到带标记的节点就收工，取所有通路里增益最大的那条。
  var best = new Map();
  var queue = [{ n: src, g: 1.0 }];
  best.set(src, 1.0);
  var answer = -1;
  var guard = 0;
  while (queue.length && guard++ < 4096) {
    var cur = queue.shift();
    var n = cur.n;
    if (n.__dzsgToDest) {
      if (cur.g > answer) answer = cur.g;
      continue;
    }
    var outs = n.__dzsgOut;
    if (!outs) continue;
    for (var i = 0; i < outs.length; i++) {
      var nx = outs[i];
      if (!nx || nx.__dzsgBypass) continue;
      var gg = cur.g;
      try {
        if (nx.gain && typeof nx.gain.value === 'number') gg *= nx.gain.value;
      } catch (e) {}
      if (gg < 0) gg = 0;
      var prev = best.get(nx);
      if (prev === undefined || gg > prev + 1e-9) {
        best.set(nx, gg);
        queue.push({ n: nx, g: gg });
      }
    }
  }
  return answer;
}

function dzsgSyncLiveGains() {
  var live = g.__dzsgLive;
  if (!live || !live.length) return;
  // 上限保护：短音效很多，超出就丢掉最旧的并断开，避免节点越积越多
  while (live.length > 64) {
    var old = live.shift();
    try { if (old.gg) old.gg.disconnect(); } catch (e) {}
  }
  for (var i = live.length - 1; i >= 0; i--) {
    var item = live[i];
    var src = item.src, gg = item.gg;
    if (!src || !gg) { live.splice(i, 1); continue; }
    var v = dzsgPathGain(src);
    if (v < 0) {
      // 找不到路径 = 源已经播完被断开，直接回收
      try { gg.disconnect(); } catch (e) {}
      live.splice(i, 1);
      continue;
    }
    try { gg.gain.value = Math.max(0, Math.min(1, v)); } catch (e) {}
  }
}

function installAudioBypass() {
  try {
    // 只有微信小游戏才需要旁路：普通浏览器里 Godot 的原生链路是正常的，
    // 再叠一路会变成双份音量。
    if (typeof wx === 'undefined' || typeof wx.getSystemInfoSync !== 'function') {
      __log('🔊修复: 非小游戏环境，保持 Godot 原生音频链路');
      return;
    }
    var AC = null;
    try { AC = g.AudioContext; } catch (e) {}
    if (!AC && g.window) { try { AC = g.window.AudioContext; } catch (e) {} }
    if (!AC) { __log('🔊修复: 环境无 AudioContext，跳过'); return; }
    // createBufferSource 在 BaseAudioContext.prototype 上（不是 AudioContext.prototype），
    // 沿原型链找真正拥有它的对象。这里只走原型、不 new 实例，避免多建一个音频上下文。
    var proto = null;
    try {
      var pp = AC.prototype;
      while (pp && pp !== Object.prototype) {
        if (typeof pp.createBufferSource === 'function') { proto = pp; break; }
        pp = Object.getPrototypeOf(pp);
      }
    } catch (e) {}
    if (!proto) {
      __log('🔊修复: 找不到 createBufferSource，跳过'); return;
    }
    if (g.__dzsgAudioBypassInstalled) { __log('🔊修复: 已安装过，跳过'); return; }
    g.__dzsgAudioBypassInstalled = true;
    g.__dzsgAudioBypass = DZSG_AUDIO_BYPASS;
    g.__dzsgLive = g.__dzsgLive || [];

    // 1) 在 AudioContext 创建的那一刻就挂上「节点连线记录」。
    //    总线节点是在音频初始化时创建的，必须赶在它们 connect 之前 hook 好，
    //    否则 BFS 找不到总线增益，音量滑条还是会失效。
    var RealAC = AC;
    function WrappedAC(opts) {
      var c = new RealAC(opts);
      try {
        if (!g.__audioCtx) { g.__audioCtx = c; dzsgEnsureGraphHook(c); }
      } catch (e) {}
      return c;
    }
    WrappedAC.prototype = RealAC.prototype;
    try { Object.defineProperty(WrappedAC, 'name', { value: 'AudioContext' }); } catch (e) {}
    try { g.AudioContext = WrappedAC; } catch (e) {}
    if (g.window) { try { g.window.AudioContext = WrappedAC; } catch (e) {} }
    // 若上下文已经建好（理论上不会），补 hook
    if (g.__audioCtx) dzsgEnsureGraphHook(g.__audioCtx);

    // 3) 每个音源播放时另接一路 源 → 增益(跟随总线音量) → 扬声器
    var origCreate = proto.createBufferSource;
    proto.createBufferSource = function () {
      var node = origCreate.apply(this, arguments);
      try {
        if (!g.__audioCtx) { g.__audioCtx = this; dzsgEnsureGraphHook(this); }
        var ctx = g.__audioCtx;
        if (g.__dzsgGainTimer === undefined) {
          g.__dzsgGainTimer = setInterval(dzsgSyncLiveGains, 400);
        }
        var origStart = node.start;
        node.start = function () {
          try {
            if (!node.__dzsgBypassed && g.__dzsgAudioBypass > 0) {
              node.__dzsgBypassed = true;
              var gg = ctx.createGain();
              gg.__dzsgBypass = true;
              var v = dzsgPathGain(node);
              if (v < 0) v = DZSG_AUDIO_BYPASS;   // 找不到总线时用兜底增益
              gg.gain.value = Math.max(0, Math.min(1, v));
              node.connect(gg);
              gg.connect(ctx.destination);
              var item = { src: node, gg: gg };
              g.__dzsgLive.push(item);
              // 播完 / 停止 / 被显式断开时立刻回收旁路，避免节点堆积
              var cleanup = function () {
                try {
                  var idx = g.__dzsgLive.indexOf(item);
                  if (idx >= 0) g.__dzsgLive.splice(idx, 1);
                  gg.disconnect();
                } catch (e) {}
              };
              try { node.addEventListener('ended', cleanup); } catch (eA) { try { node.onended = cleanup; } catch (eB) {} }
              var origStop = node.stop;
              node.stop = function () {
                cleanup();
                return origStop.apply(node, arguments);
              };
            }
          } catch (e) {}
          return origStart.apply(node, arguments);
        };
      } catch (e) {}
      return node;
    };
    __log('🔊修复: 已启用「音频源直连扬声器」旁路（音量跟随总线，滑条/淡入淡出/静音均生效）');
  } catch (e) { __log('🔊修复: 安装异常 ' + (e && e.message)); }
}

function boot() {
  __logNow('boot() 进入');
  teeConsole();
  let canvas;
  try {
    canvas = setupHostShim();
  } catch (e) {
    __log('setupHostShim 异常: ' + (e && (e.stack || e.message) || e));
    throw e;
  }
  g.__DZSG.log('宿主垫片就绪, 画布', canvas.width + 'x' + canvas.height);
  installFrameProbe();
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
        fileSizes: { 'index.pck': 11432596, 'index.wasm': 39514754 },
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
        __logNow('===== 引擎启动完成 =====');
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
