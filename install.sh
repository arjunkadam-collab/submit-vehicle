#!/usr/bin/env bash
#
# Submit Vehicles - one-line installer for Ubuntu / Linux.
#
#   curl -fsSL https://raw.githubusercontent.com/arjunkadam-collab/submit-vehicle/main/install.sh | bash
#
# It downloads the prebuilt `submit-vehicles` binary from GitHub, installs it
# to ~/.local/bin, creates a `run_vehicle` command, and adds a desktop entry so
# it also appears in your applications menu.
#
# To uninstall:  run_vehicle --uninstall
#
set -euo pipefail

# ---------------------------------------------------------------------------
# CONFIG
# ---------------------------------------------------------------------------
REPO="arjunkadam-collab/submit-vehicle"
BRANCH="main"
BINARY_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}/submit-vehicles"

APP_NAME="submit-vehicles"
CMD_NAME="run_vehicle"
BIN_DIR="${HOME}/.local/bin"
BIN_PATH="${BIN_DIR}/${APP_NAME}"
CMD_PATH="${BIN_DIR}/${CMD_NAME}"
DESKTOP_DIR="${HOME}/.local/share/applications"
DESKTOP_FILE="${DESKTOP_DIR}/${APP_NAME}.desktop"
ICON_DIR="${HOME}/.local/share/icons"
ICON_PATH="${ICON_DIR}/${APP_NAME}.png"

say()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m  ok\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; }

# ---------------------------------------------------------------------------
# Uninstall
# ---------------------------------------------------------------------------
if [[ "${1:-}" == "--uninstall" ]]; then
  say "Uninstalling ${APP_NAME} ..."
  rm -f "${BIN_PATH}" "${CMD_PATH}" "${DESKTOP_FILE}" "${ICON_PATH}"
  command -v update-desktop-database >/dev/null 2>&1 && \
    update-desktop-database "${DESKTOP_DIR}" >/dev/null 2>&1 || true
  ok "Removed binary, command and desktop entry."
  exit 0
fi

# ---------------------------------------------------------------------------
# Sanity checks
# ---------------------------------------------------------------------------
if [[ "$(uname -s)" != "Linux" ]]; then
  err "This installer is for Linux only."
  exit 1
fi

ARCH="$(uname -m)"
if [[ "${ARCH}" != "x86_64" && "${ARCH}" != "amd64" ]]; then
  err "This build is for x86-64 Linux; detected '${ARCH}'."
  err "A separate build is needed for this architecture."
  exit 1
fi

DL=""
if command -v curl >/dev/null 2>&1; then
  DL="curl"
elif command -v wget >/dev/null 2>&1; then
  DL="wget"
else
  err "Need curl or wget installed."
  exit 1
fi

mkdir -p "${BIN_DIR}" "${DESKTOP_DIR}" "${ICON_DIR}"

# ---------------------------------------------------------------------------
# Download the binary from GitHub raw
# ---------------------------------------------------------------------------
say "Downloading ${APP_NAME} ..."
TMP="$(mktemp)"
if [[ "${DL}" == "curl" ]]; then
  curl -fsSL "${BINARY_URL}" -o "${TMP}"
else
  wget -q "${BINARY_URL}" -O "${TMP}"
fi

# validate it's actually an ELF binary, not an HTML/error page
if ! head -c 4 "${TMP}" | grep -q $'\x7fELF'; then
  err "Downloaded file is not a Linux executable."
  err "Check that ${BINARY_URL} is reachable."
  rm -f "${TMP}"
  exit 1
fi

mv "${TMP}" "${BIN_PATH}"
chmod +x "${BIN_PATH}"
ok "Installed binary -> ${BIN_PATH}"

# ---------------------------------------------------------------------------
# `run_vehicle` launcher command
# ---------------------------------------------------------------------------
cat > "${CMD_PATH}" <<EOF
#!/usr/bin/env bash
# Launcher for Submit Vehicles
if [[ "\${1:-}" == "--uninstall" ]]; then
  rm -f "${BIN_PATH}" "${CMD_PATH}" "${DESKTOP_FILE}" "${ICON_PATH}"
  echo "Submit Vehicles uninstalled."
  exit 0
fi
exec "${BIN_PATH}" "\$@"
EOF
chmod +x "${CMD_PATH}"
ok "Created command -> ${CMD_NAME}"

# ---------------------------------------------------------------------------
# Minimal icon (embedded placeholder PNG) for the menu entry
# ---------------------------------------------------------------------------
base64 -d > "${ICON_PATH}" <<'B64' 2>/dev/null || true
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAMElEQVR42mNgGAWjYBSM
glEwCkbBKBgFo2AUjIJRMApGwSgYBaNgFIyCUTAKRgEAHxkAAV8kq3EAAAAASUVORK5C
YII=
B64

# ---------------------------------------------------------------------------
# Desktop entry
# ---------------------------------------------------------------------------
cat > "${DESKTOP_FILE}" <<EOF
[Desktop Entry]
Type=Application
Name=Submit Vehicles
Comment=Device config manager
Exec=${BIN_PATH}
Icon=${ICON_PATH}
Terminal=false
Categories=Utility;Network;
EOF
chmod +x "${DESKTOP_FILE}"
command -v update-desktop-database >/dev/null 2>&1 && \
  update-desktop-database "${DESKTOP_DIR}" >/dev/null 2>&1 || true
ok "Created desktop entry -> applications menu"

# ---------------------------------------------------------------------------
# Make sure ~/.local/bin is on PATH
# ---------------------------------------------------------------------------
if ! printf '%s' ":${PATH}:" | grep -q ":${BIN_DIR}:"; then
  SHELL_RC="${HOME}/.bashrc"
  [[ -n "${ZSH_VERSION:-}" || "${SHELL:-}" == *zsh ]] && SHELL_RC="${HOME}/.zshrc"
  if ! grep -qs "${BIN_DIR}" "${SHELL_RC}" 2>/dev/null; then
    printf '\nexport PATH="%s:$PATH"\n' "${BIN_DIR}" >> "${SHELL_RC}"
  fi
  say "Added ${BIN_DIR} to PATH in ${SHELL_RC}"
  say "Open a new terminal (or run: source ${SHELL_RC}) to use 'run_vehicle'."
fi

printf '\n\033[1;32mDone!\033[0m Launch with: \033[1mrun_vehicle\033[0m  or find \033[1mSubmit Vehicles\033[0m in your apps menu.\n'
