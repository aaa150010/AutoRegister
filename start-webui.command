#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

HOST="${AUTOREGISTER_HOST:-127.0.0.1}"
PORT="${AUTOREGISTER_PORT:-5000}"
PYTHON_BIN="${PYTHON_BIN:-python3}"
OPEN_BROWSER="${AUTOREGISTER_OPEN_BROWSER:-1}"
VENV_DIR="$ROOT_DIR/.venv"
VENV_PYTHON="$VENV_DIR/bin/python"
DEPENDENCY_STAMP="$VENV_DIR/.requirements-installed"
WEBUI_URL="http://$HOST:$PORT"

fail() {
  printf '\n启动失败：%s\n' "$1" >&2
  printf '按回车关闭窗口。'
  read -r _ || true
  exit 1
}

webui_is_ready() {
  command -v curl >/dev/null 2>&1 \
    && curl --silent --show-error --fail --max-time 2 "$WEBUI_URL/login" >/dev/null 2>&1
}

open_webui() {
  if [[ "$OPEN_BROWSER" == "1" ]] && command -v open >/dev/null 2>&1; then
    open "$WEBUI_URL" >/dev/null 2>&1 || true
  fi
}

if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
  fail "未找到 Python 3。请先安装 Python 3.10 或更高版本。"
fi

if [[ ! -x "$VENV_PYTHON" ]]; then
  printf '首次启动，正在创建 Python 虚拟环境...\n'
  "$PYTHON_BIN" -m venv "$VENV_DIR" || fail "创建虚拟环境失败。"
fi

if [[ ! -f "$DEPENDENCY_STAMP" ]] || ! cmp -s requirements.txt "$DEPENDENCY_STAMP"; then
  printf '正在安装或更新项目依赖，这一步首次启动可能需要几分钟...\n'
  "$VENV_PYTHON" -m pip install -r requirements.txt || fail "依赖安装失败，请检查网络后重试。"
  cp requirements.txt "$DEPENDENCY_STAMP"
fi

if [[ ! -f "$ROOT_DIR/.env" ]]; then
  cp "$ROOT_DIR/.env.example" "$ROOT_DIR/.env" || fail "无法创建 .env 配置文件。"
  printf '已从 .env.example 创建 .env，请在 WebUI 配置页填写密钥。\n'
fi

if webui_is_ready; then
  printf 'WebUI 已在运行：%s\n' "$WEBUI_URL"
  open_webui
  exit 0
fi

mkdir -p "$ROOT_DIR/logs"

args=("web.py" "--host" "$HOST" "--port" "$PORT")
if [[ "$OPEN_BROWSER" == "1" ]]; then
  args+=("--open-browser")
fi

printf '正在启动 WebUI：%s\n' "$WEBUI_URL"
printf '此窗口会显示运行日志；关闭窗口将停止 WebUI。\n\n'

set +e
"$VENV_PYTHON" "${args[@]}" 2>&1 | tee -a "$ROOT_DIR/logs/webui.log"
status=${PIPESTATUS[0]}
set -e

if [[ "$status" -ne 0 ]]; then
  fail "WebUI 已退出，错误详情见上方内容或 logs/webui.log。"
fi
