#!/usr/bin/env python3
"""
数值控制台 · 本地服务
============================================================================
启动后自动打开浏览器，改数值 → 保存 → 点「重新构建」→ 微信开发者工具自动刷新。

设计要点：
  1. 只监听 127.0.0.1，不对外网开放。
  2. 保存前强制跑 check_config.py；不通过就自动回滚，绝不让坏配置落盘。
  3. 「重新构建」调用 _tools/export_wxgame.sh，导出 + brotli + 替换资源包。
     微信开发者工具监听工程文件变化，替换后会自己重编译。
  4. 零第三方依赖，只用 Python 标准库。

用法：
  python3 _tools/config_server.py            # 默认 8770，自动开浏览器
  python3 _tools/config_server.py --port 8780 --no-open
============================================================================
"""
import argparse
import json
import os
import re
import socket
import subprocess
import sys
import threading
import time
import webbrowser
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parent.parent
CFG = ROOT / "godot" / "config"
SCHEMA = CFG / "schema"
HTML_FILE = Path(__file__).resolve().parent / "config_console.html"
CHECK_SCRIPT = ROOT / "_tools" / "check_config.py"
EXPORT_SCRIPT = ROOT / "_tools" / "export_wxgame.sh"

# 允许通过界面编辑的配置文件
EDITABLE = ["balance.json", "characters.json", "arena.json", "progression.json"]
MOVES_DIR = CFG / "moves"

JOB = {"state": "idle", "log": "", "started": 0.0, "elapsed": 0.0, "ok": None}
JOB_LOCK = threading.Lock()


def read_json(path: Path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def write_json(path: Path, data) -> None:
    text = json.dumps(data, ensure_ascii=False, indent="\t")
    with open(path, "w", encoding="utf-8") as f:
        f.write(text + "\n")


def list_config_files():
    """返回 [(相对路径, 绝对路径)]"""
    out = []
    for name in EDITABLE:
        p = CFG / name
        if p.exists():
            out.append((name, p))
    if MOVES_DIR.is_dir():
        for p in sorted(MOVES_DIR.glob("*.json")):
            if p.name.startswith("_"):
                continue
            out.append((f"moves/{p.name}", p))
    return out


def build_state():
    configs = {}
    for rel, p in list_config_files():
        try:
            configs[rel] = read_json(p)
        except Exception as e:
            configs[rel] = {"__error__": str(e)}
    schemas = {}
    for p in sorted(SCHEMA.glob("*.schema.json")):
        try:
            schemas[p.name.replace(".schema.json", "")] = read_json(p)
        except Exception:
            pass
    return {
        "configs": configs,
        "schemas": schemas,
        "meta": {
            "root": str(ROOT),
            "godot_running": godot_editor_running(),
            "ide_running": wechat_ide_running(),
        },
    }


def godot_editor_running() -> bool:
    try:
        r = subprocess.run(["pgrep", "-f", "Godot.*--editor"], capture_output=True, text=True, timeout=3)
        return bool(r.stdout.strip())
    except Exception:
        return False


def wechat_ide_running() -> bool:
    try:
        r = subprocess.run(["pgrep", "-f", "wechatwebdevtools"], capture_output=True, text=True, timeout=3)
        return bool(r.stdout.strip())
    except Exception:
        return False


class CoerceError(Exception):
    pass


def set_dotted(data, dotted: str, value):
    """按 "a.b.0.c" 写入嵌套结构，保持原有类型。失败抛 CoerceError。"""
    parts = dotted.split(".")
    cur = data
    for p in parts[:-1]:
        if isinstance(cur, dict):
            if p not in cur:
                raise CoerceError(f"找不到字段 {p}（{dotted}）")
            cur = cur[p]
        elif isinstance(cur, list) and p.isdigit() and int(p) < len(cur):
            cur = cur[int(p)]
        else:
            raise CoerceError(f"找不到字段 {p}（{dotted}）")
    last = parts[-1]
    if isinstance(cur, dict):
        if last not in cur:
            raise CoerceError(f"字段不存在: {last}（{dotted}）")
        cur[last] = coerce(value, cur[last], dotted)
        return True
    if isinstance(cur, list) and last.isdigit() and int(last) < len(cur):
        idx = int(last)
        cur[idx] = coerce(value, cur[idx], dotted)
        return True
    raise CoerceError(f"无法写入: {dotted}")


def coerce(value, old, where=""):
    """按原值类型转换，避免 int 变 float。转不了就报错，绝不静默吞掉。"""
    if isinstance(old, bool):
        if isinstance(value, str):
            return value.strip().lower() in ("1", "true", "yes", "on")
        return bool(value)
    if isinstance(old, int) and not isinstance(old, bool):
        try:
            f = float(value)
        except (TypeError, ValueError):
            raise CoerceError(f"{where} 需要整数，收到 {value!r}")
        if not f == f or f in (float("inf"), float("-inf")):
            raise CoerceError(f"{where} 需要有限数值，收到 {value!r}")
        return int(round(f))
    if isinstance(old, float):
        try:
            f = float(value)
        except (TypeError, ValueError):
            raise CoerceError(f"{where} 需要数字，收到 {value!r}")
        if f != f or f in (float("inf"), float("-inf")):
            raise CoerceError(f"{where} 需要有限数值，收到 {value!r}")
        return f
    if isinstance(old, str):
        return str(value)
    return value


def validate() -> tuple:
    """跑配置校验器。返回 (ok, 输出)"""
    try:
        r = subprocess.run([sys.executable, str(CHECK_SCRIPT)],
                           capture_output=True, text=True, timeout=60, cwd=str(ROOT))
        out = (r.stdout or "") + (r.stderr or "")
        return r.returncode == 0, out
    except Exception as e:
        return False, f"校验器执行失败: {e}"


def apply_changes(changes: dict) -> dict:
    """
    changes: {"balance.json": {"round.time_limit_duel": 200}, ...}
    先备份原文 → 写入 → 校验 → 失败则回滚。
    """
    backups = {}
    touched = []
    try:
        for rel, paths in changes.items():
            target = (CFG / rel).resolve()
            # 防目录穿越
            if CFG.resolve() not in target.parents:
                return {"ok": False, "error": f"非法路径: {rel}"}
            if not target.exists():
                return {"ok": False, "error": f"文件不存在: {rel}"}
            backups[target] = target.read_text(encoding="utf-8")
            data = json.loads(backups[target])
            for dotted, val in paths.items():
                set_dotted(data, dotted, val)
            write_json(target, data)
            touched.append(rel)

        ok, out = validate()
        if not ok:
            for target, text in backups.items():
                target.write_text(text, encoding="utf-8")
            return {"ok": False, "error": "配置校验未通过，已自动回滚", "detail": out}
        return {"ok": True, "touched": touched, "check": out}
    except CoerceError as e:
        for target, text in backups.items():
            try:
                target.write_text(text, encoding="utf-8")
            except Exception:
                pass
        return {"ok": False, "error": str(e)}
    except Exception as e:
        for target, text in backups.items():
            try:
                target.write_text(text, encoding="utf-8")
            except Exception:
                pass
        return {"ok": False, "error": f"保存失败: {e}"}


def run_rebuild():
    with JOB_LOCK:
        JOB.update({"state": "running", "log": "", "started": time.time(), "elapsed": 0.0, "ok": None})

    def worker():
        lines = []
        try:
            lines.append("▶ 开始构建（导出 → brotli → 替换资源包）…")
            lines.append(f"  Godot 编辑器运行中: {godot_editor_running()}")
            if godot_editor_running():
                lines.append("  ⚠ 检测到 Godot 编辑器正在运行，构建可能与它争用缓存；建议先关掉编辑器。")
            proc = subprocess.Popen(
                ["bash", str(EXPORT_SCRIPT)],
                cwd=str(ROOT), stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                text=True, bufsize=1,
            )
            for line in proc.stdout:
                lines.append(line.rstrip())
                with JOB_LOCK:
                    JOB["log"] = "\n".join(lines)
                    JOB["elapsed"] = time.time() - JOB["started"]
            code = proc.wait()
            with JOB_LOCK:
                JOB["ok"] = (code == 0)
                JOB["state"] = "done" if code == 0 else "failed"
                JOB["elapsed"] = time.time() - JOB["started"]
                if code == 0:
                    lines.append("")
                    lines.append("✅ 构建完成。")
                    if wechat_ide_running():
                        lines.append("   微信开发者工具正在运行，工程文件已更新，它会自动重新编译（约 3 秒）。")
                    else:
                        lines.append("   微信开发者工具未运行。打开它并点一次「编译」即可看到效果。")
                else:
                    lines.append(f"❌ 构建失败（退出码 {code}）")
                JOB["log"] = "\n".join(lines)
        except Exception as e:
            with JOB_LOCK:
                JOB["state"] = "failed"
                JOB["ok"] = False
                lines.append(f"❌ 构建异常: {e}")
                JOB["log"] = "\n".join(lines)

    threading.Thread(target=worker, daemon=True).start()


class Handler(SimpleHTTPRequestHandler):
    def log_message(self, fmt, *args):
        pass  # 静默

    def _send_json(self, obj, code=200):
        body = json.dumps(obj, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def _read_body(self):
        n = int(self.headers.get("Content-Length", 0))
        if n <= 0:
            return {}
        raw = self.rfile.read(n).decode("utf-8")
        return json.loads(raw)

    def do_GET(self):
        path = urlparse(self.path).path
        if path in ("/", "/index.html"):
            try:
                body = HTML_FILE.read_bytes()
            except FileNotFoundError:
                self._send_json({"error": "找不到 config_console.html"}, 500)
                return
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(body)
            return
        if path == "/api/state":
            self._send_json(build_state())
            return
        if path == "/api/rebuild":
            with JOB_LOCK:
                self._send_json(dict(JOB))
            return
        self._send_json({"error": "not found"}, 404)

    def do_POST(self):
        path = urlparse(self.path).path
        try:
            body = self._read_body()
        except Exception as e:
            self._send_json({"ok": False, "error": f"请求体解析失败: {e}"}, 400)
            return

        if path == "/api/save":
            changes = body.get("changes", {})
            if not changes:
                self._send_json({"ok": False, "error": "没有改动"})
                return
            self._send_json(apply_changes(changes))
            return

        if path == "/api/rebuild":
            with JOB_LOCK:
                running = JOB["state"] == "running"
            if running:
                self._send_json({"ok": False, "error": "已有构建在进行中"})
                return
            run_rebuild()
            self._send_json({"ok": True})
            return

        self._send_json({"error": "not found"}, 404)


def find_port(preferred: int) -> int:
    for port in [preferred] + list(range(preferred + 1, preferred + 20)):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            try:
                s.bind(("127.0.0.1", port))
                return port
            except OSError:
                continue
    raise RuntimeError("找不到可用端口")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=8770)
    ap.add_argument("--no-open", action="store_true")
    args = ap.parse_args()

    if not HTML_FILE.exists():
        print(f"❌ 找不到界面文件: {HTML_FILE}")
        return 1
    if not CHECK_SCRIPT.exists():
        print(f"❌ 找不到校验器: {CHECK_SCRIPT}")
        return 1

    port = find_port(args.port)
    url = f"http://127.0.0.1:{port}/"
    srv = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    print(f"▶ 数值控制台已启动: {url}")
    print("  改数值 → 保存 → 点「重新构建」→ 微信开发者工具自动刷新")
    print("  Ctrl+C 停止服务")
    if not args.no_open:
        threading.Timer(0.6, lambda: webbrowser.open(url)).start()
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        print("\n已停止。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
