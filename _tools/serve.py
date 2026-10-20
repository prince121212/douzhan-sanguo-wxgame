#!/usr/bin/env python3
"""静态文件服务器：修正 .js 文件的 MIME 类型。

Python 内置的 http.server 只会按最后一个后缀猜类型，遇到
`brotli_wasm_bg.js` 这种「名字里含 .wasm 但真实是 JS」的文件会
错误地返回 application/wasm，导致浏览器的模块 MIME 校验失败。
这在真实的小游戏环境里不会出现，但会污染我们的验证结论。
"""
import sys
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import mimetypes

mimetypes.add_type('application/javascript', '.js')
mimetypes.add_type('application/javascript', '.mjs')
mimetypes.add_type('application/octet-stream', '.br')
mimetypes.add_type('application/octet-stream', '.wasm')
mimetypes.add_type('application/octet-stream', '.pck')
mimetypes.add_type('image/png', '.png')


class Handler(SimpleHTTPRequestHandler):
    def guess_type(self, path):
        # 只要真实后缀是 .js，就必须是 JS
        if str(path).endswith('.js'):
            return 'application/javascript'
        if str(path).endswith('.wasm'):
            return 'application/wasm'
        if str(path).endswith('.br'):
            return 'application/octet-stream'
        return super().guess_type(path)

    def end_headers(self):
        self.send_header('Cache-Control', 'no-store')
        super().end_headers()

    def log_message(self, fmt, *args):
        pass  # 静默


if __name__ == '__main__':
    port = int(sys.argv[1])
    root = sys.argv[2]
    import os
    os.chdir(root)
    srv = ThreadingHTTPServer(('127.0.0.1', port), Handler)
    print(f'serving {root} on http://127.0.0.1:{port}', flush=True)
    srv.serve_forever()