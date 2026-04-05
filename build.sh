#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_NAME="rastertotmtr"
SOURCE_FILE="filter/TmThermalReceipt.c"
BUILD_DIR="build"
BUILD_TYPE="${BUILD_TYPE:-Release}"
JOBS="${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || nproc || echo 1)}"

REQUIRED_PACKAGES=(
  cmake
  build-essential
  libcups2-dev
  libcupsimage2-dev
)

log() {
  echo -e "[INFO] $*"
}

warn() {
  echo -e "[WARN] $*" >&2
}

die() {
  echo -e "[ERROR] $*" >&2
  exit 1
}

on_error() {
  local exit_code=$?
  echo
  echo "[ERROR] La compilación falló con código ${exit_code}" >&2
  echo "[ERROR] Revisa especialmente:" >&2
  echo "        - Dependencias de CUPS instaladas" >&2
  echo "        - Existencia de ${SOURCE_FILE}" >&2
  echo "        - Errores de compilación en el código fuente" >&2
  exit "${exit_code}"
}
trap on_error ERR

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "No se encontró el comando requerido: $1"
}

is_root() {
  [[ "${EUID:-$(id -u)}" -eq 0 ]]
}

have_sudo() {
  command -v sudo >/dev/null 2>&1
}

run_privileged() {
  if is_root; then
    "$@"
  elif have_sudo; then
    sudo "$@"
  else
    die "Se requieren privilegios para instalar paquetes y no se encontró sudo"
  fi
}

detect_os() {
  if [[ -r /etc/os-release ]]; then
    . /etc/os-release
    echo "${ID:-unknown}"
    return
  fi
  echo "unknown"
}

ensure_apt_packages() {
  local missing=()
  for pkg in "${REQUIRED_PACKAGES[@]}"; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
      missing+=("$pkg")
    fi
  done

  if [[ ${#missing[@]} -eq 0 ]]; then
    log "Todas las dependencias ya están instaladas"
    return
  fi

  log "Faltan paquetes: ${missing[*]}"
  log "Actualizando índices APT..."
  run_privileged apt-get update

  log "Instalando dependencias..."
  DEBIAN_FRONTEND=noninteractive run_privileged apt-get install -y "${missing[@]}"
}

verify_project_files() {
  [[ -f "CMakeLists.txt" ]] || die "No se encontró CMakeLists.txt en el directorio actual"
  [[ -f "${SOURCE_FILE}" ]] || die "No se encontró el archivo fuente requerido: ${SOURCE_FILE}"
}

verify_tools() {
  need_cmd cmake
  need_cmd gcc
  need_cmd g++
  need_cmd make
}

configure_build() {
  log "Limpiando directorio ${BUILD_DIR}..."
  rm -rf "${BUILD_DIR}"

  log "Configurando proyecto con CMake..."
  cmake -S . -B "${BUILD_DIR}" -DCMAKE_BUILD_TYPE="${BUILD_TYPE}"
}

build_project() {
  log "Compilando con ${JOBS} hilo(s)..."
  cmake --build "${BUILD_DIR}" -- -j"${JOBS}"
}

find_binary() {
  find "${BUILD_DIR}" -type f -name "${PROJECT_NAME}" 2>/dev/null | head -n 1
}

verify_binary() {
  local bin
  bin="$(find_binary)"

  [[ -n "${bin}" ]] || die "La compilación terminó pero no se encontró el ejecutable ${PROJECT_NAME}"
  [[ -x "${bin}" ]] || die "Se encontró ${bin}, pero no tiene permisos de ejecución"

  log "Build exitoso"
  log "Ejecutable: ${bin}"

  if command -v file >/dev/null 2>&1; then
    file "${bin}" || true
  fi

  if command -v ldd >/dev/null 2>&1; then
    log "Dependencias dinámicas:"
    ldd "${bin}" || true
  fi
}

main() {
  log "Proyecto: ${PROJECT_NAME}"
  log "Tipo de build: ${BUILD_TYPE}"

  verify_project_files

  case "$(detect_os)" in
    ubuntu|debian)
      ensure_apt_packages
      ;;
    *)
      warn "Sistema no Ubuntu/Debian detectado; se omite instalación automática"
      ;;
  esac

  verify_tools
  configure_build
  build_project
  verify_binary
}

main "$@"