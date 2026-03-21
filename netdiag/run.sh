#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${ROOT_DIR}"

if command -v python3.11 >/dev/null 2>&1; then
  PY_BIN="python3.11"
  VENV_DIR=".venv311"
elif command -v python3.10 >/dev/null 2>&1; then
  PY_BIN="python3.10"
  VENV_DIR=".venv310"
else
  PY_BIN="python3"
  VENV_DIR=".venv"
fi

if [[ ! -d "${VENV_DIR}" ]]; then
  "${PY_BIN}" -m venv "${VENV_DIR}"
fi

VENV_PY="${VENV_DIR}/bin/python"
if [[ ! -x "${VENV_PY}" ]]; then
  echo "[WARN] ${VENV_DIR} is invalid; recreating..."
  rm -rf "${VENV_DIR}"
  "${PY_BIN}" -m venv "${VENV_DIR}"
  VENV_PY="${VENV_DIR}/bin/python"
fi

"${VENV_PY}" -m pip install --upgrade pip
"${VENV_PY}" -m pip install -r requirements.txt

# Auto-inject CA bundle for cloud LLM HTTPS when enterprise trust chain is incomplete.
if [[ -z "${OPENAI_CA_BUNDLE:-}" ]]; then
  CA_BUNDLE="$("${VENV_PY}" - <<'PY'
try:
    import certifi
    print(certifi.where())
except Exception:
    print("")
PY
)"
  if [[ -n "${CA_BUNDLE}" && -f "${CA_BUNDLE}" ]]; then
    export OPENAI_CA_BUNDLE="${CA_BUNDLE}"
    echo "[INFO] OPENAI_CA_BUNDLE=${OPENAI_CA_BUNDLE}"
  fi
fi

export PYTHONPATH=.
exec "${VENV_PY}" -m uvicorn app.main:app --host 0.0.0.0 --port 8001 --reload
