/* ==========================================================================
 * brotli_loader.js —— Brotli 解压加载层
 * --------------------------------------------------------------------------
 * 为什么是这个方案（踩坑记录，改动前务必读完）：
 *
 *  1. 引擎零改动。只包装 window.fetch，把 index.wasm / index.pck 的请求
 *     改道到 .br 文件并解压。Godot 拿到的始终是解压后的原始字节，
 *     它完全不需要知道自己被压缩过。
 *
 *  2. 解码器用【纯 JS】实现（npm "brotli" 2.1.0，esbuild 打成单文件 88.7KB）。
 *     这里换过两次实现，都是被逼的：
 *       · brotli-wasm (1MB)：胶水用 `import * as wasm from './x.wasm'`，
 *         wasm 模块无法通过 ESM import 加载，浏览器直接拒绝 -> 启动失败。
 *       · brotli-dec-wasm (204KB)：实测解压结果错误（4 字节），不可用。
 *     纯 JS 版本已做字节级往返验证，且无任何 ESM / wasm 依赖，
 *     在微信小游戏这种受限环境里最稳。
 *
 *  3. 88.7KB 的解码器保持在【未压缩】状态。它是启动链路第一个依赖，
 *     不值得为省 30KB 去冒险。
 *
 *  4. 白名单精确匹配 index.wasm.br / index.pck.br，其余一律放行。
 * ========================================================================== */
(function () {
  'use strict';

  // 引擎请求名 -> 实际磁盘上的压缩文件
  const MAP = { 'index.wasm': 'index.wasm.br', 'index.pck': 'index.pck.br' };

  const stats = { hits: 0, bytesIn: 0, bytesOut: 0, errors: [] };

  function getDecoder() {
    // brotli_decoder.js 由 <script> 标签同步加载，理论上此处已就绪。
    // 这里加一层兜底：万一加载顺序被外部改动影响，也能给出明确报错而不是 undefined。
    if (typeof window.__brotliDecompress !== 'function') {
      throw new Error('brotli 解码器未就绪（brotli_decoder.js 未成功加载）');
    }
    return window.__brotliDecompress;
  }

  // ---------------------------------------------------------------- 解压
  function decompressToArrayBuffer(compBuf) {
    const decompress = getDecoder();
    const out = decompress(new Uint8Array(compBuf)); // 纯 JS，返回独立 Uint8Array
    // 仍做一次拷贝，确保不与内部缓冲区共享内存
    const copied = new Uint8Array(out.length);
    copied.set(out);
    return copied.buffer;
  }

  // ---------------------------------------------------------------- fetch 拦截
  function installFetchInterceptor() {
    const origFetch = window.fetch.bind(window);

    window.fetch = async function (input, init) {
      const url =
        typeof input === 'string' ? input : input && input.url ? input.url : String(input);

          // 引擎请求的仍是原名 index.wasm / index.pck（我们已撤销 patchConfig），
      // 这里按【原名】识别，然后去取对应的 .br 文件。
      const base = url.split('?')[0].split('/').pop();
      if (!MAP[base]) {
        return origFetch(input, init);   // 解码器自身与其它请求原样放行
      }

      try {
        const resp = await origFetch(MAP[base]);
        if (!resp.ok) return resp;

        const compBuf = await resp.arrayBuffer();
        stats.hits++;
        stats.bytesIn += compBuf.byteLength;

        const decompressed = decompressToArrayBuffer(compBuf);
        stats.bytesOut += decompressed.byteLength;

        // wasm 必须带 application/wasm，Godot 依赖它走 instantiateStreaming 快速编译路径
        const mime = base === 'index.wasm' ? 'application/wasm' : 'application/octet-stream';

        return new Response(decompressed, {
          status: 200,
          statusText: 'OK',
          headers: {
            'Content-Type': mime,
            'Content-Length': String(decompressed.byteLength),
          },
        });
      } catch (e) {
        stats.errors.push(String(e && e.message ? e.message : e));
        throw e;
      }
    };
  }

  // Emscripten 用 locateFile(path) 决定 wasm / pck 的真实 URL。
  // 引擎内部（含 --main-pack 参数与 fileSizes）保持原名不动，
  // 只在这里把 index.wasm / index.pck 改道到 .br，改动面最小。
  function locateFileHook(path, prefix) {
    const base = String(path).split('/').pop();
    if (MAP[base]) return (prefix || '') + MAP[base];
    return (prefix || '') + path;
  }

  window.__BrotliLoader = {
    ready: getDecoder,
    stats: stats,
    locateFile: locateFileHook,
  };

  installFetchInterceptor();
})();