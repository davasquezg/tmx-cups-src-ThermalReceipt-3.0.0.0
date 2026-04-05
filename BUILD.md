# BUILD.md

# Guía de build para Ubuntu 25.10

Este proyecto compila el ejecutable `rastertotmtr` usando CMake y enlazando contra las librerías CUPS `cupsimage` y `cups`.

## Descripción general

La definición principal de CMake crea el binario `rastertotmtr` a partir de `filter/TmThermalReceipt.c` y lo enlaza con `cupsimage` y `cups`.

Este documento describe el flujo de compilación recomendado para **Ubuntu 25.10**, incluyendo la traducción de dependencias desde distribuciones basadas en RPM y un flujo de build automatizado y más robusto.

## Paquetes requeridos

En Ubuntu 25.10 se requieren las siguientes dependencias:

```bash
sudo apt update
sudo apt install   cmake   build-essential   libcups2-dev   libcupsimage2-dev
```

### Equivalencias de paquetes

Si la documentación original hacía referencia a paquetes de CentOS u openSUSE, sus equivalentes en Ubuntu 25.10 son:

| CentOS / openSUSE         | Ubuntu 25.10       |
|---------------------------|--------------------|
| `cmake`                   | `cmake`           |
| `gcc`                     | `build-essential` |
| `gcc-c++`                 | `build-essential` |
| `cups-devel`             | `libcups2-dev`    |
| `cups image development` | `libcupsimage2-dev` |

## Archivos de proyecto relevantes

El build asume la existencia de los siguientes archivos:

- `CMakeLists.txt`
- `filter/TmThermalReceipt.c`

Definición actual de CMake:

```cmake
cmake_minimum_required(VERSION 2.8)

add_executable(rastertotmtr
    filter/TmThermalReceipt.c
)

target_link_libraries(rastertotmtr cupsimage cups)
```

## Script de build recomendado

Se recomienda incluir en la raíz del repositorio un script `build.sh` que:

- Verifique que existan los archivos de proyecto requeridos.
- Detecte si el sistema es Ubuntu/Debian.
- Instale automáticamente dependencias faltantes cuando sea posible.
- Configure un build fuera del árbol fuente en el directorio `build/`.
- Compile usando todos los núcleos disponibles.
- Verifique que el binario final se haya generado correctamente.

Ejemplo de `build.sh`:

```bash
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
  echo "[ERROR] Revise dependencias de CUPS, archivos fuente y salida del compilador." >&2
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
    die "Se requiere root o sudo para instalar paquetes faltantes"
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
    log "Todos los paquetes requeridos ya están instalados"
    return
  fi

  log "Faltan paquetes: ${missing[*]}"
  run_privileged apt-get update
  DEBIAN_FRONTEND=noninteractive run_privileged apt-get install -y "${missing[@]}"
}

verify_project_files() {
  [[ -f "CMakeLists.txt" ]] || die "No se encontró CMakeLists.txt en la raíz del proyecto"
  [[ -f "${SOURCE_FILE}" ]] || die "No se encontró el archivo fuente requerido: ${SOURCE_FILE}"
}

verify_tools() {
  need_cmd cmake
  need_cmd gcc
  need_cmd g++
  need_cmd make
}

configure_build() {
  rm -rf "${BUILD_DIR}"
  cmake -S . -B "${BUILD_DIR}" -DCMAKE_BUILD_TYPE="${BUILD_TYPE}"
}

build_project() {
  cmake --build "${BUILD_DIR}" -- -j"${JOBS}"
}

find_binary() {
  find "${BUILD_DIR}" -type f -name "${PROJECT_NAME}" 2>/dev/null | head -n 1
}

verify_binary() {
  local bin
  bin="$(find_binary)"

  [[ -n "${bin}" ]] || die "La compilación terminó pero no se encontró ${PROJECT_NAME}"
  [[ -x "${bin}" ]] || die "El archivo generado no es ejecutable: ${bin}"

  log "Build completado correctamente"
  log "Binario: ${bin}"

  if command -v ldd >/dev/null 2>&1; then
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
      warn "Sistema no Debian detectado, se omite instalación automática de paquetes"
      ;;
  esac

  verify_tools
  configure_build
  build_project
  verify_binary
}

main "$@"
```

## Pasos de compilación

Dar permisos de ejecución al script:

```bash
chmod +x build.sh
```

Build por defecto (Release):

```bash
./build.sh
```

Build de depuración:

```bash
BUILD_TYPE=Debug ./build.sh
```

Limitar el número de hilos de compilación:

```bash
JOBS=4 ./build.sh
```

## Cambios introducidos

En comparación con instrucciones antiguas orientadas a CentOS/openSUSE, el flujo Ubuntu 25.10 incorpora:

- Nombres de paquetes específicos para Debian/Ubuntu (`libcups2-dev`, `libcupsimage2-dev`, `build-essential`).
- Instalación automática de dependencias en sistemas Ubuntu/Debian cuando sea posible.
- Uso estándar de build fuera del árbol fuente (`cmake -S . -B build`).
- Verificación explícita del binario `rastertotmtr` tras la compilación.

## Problemas comunes

### `fatal error: cups/cups.h: No such file or directory`

Instalar el paquete de desarrollo de CUPS:

```bash
sudo apt install libcups2-dev
```

### `cannot find -lcupsimage`

Instalar el paquete de desarrollo de `cupsimage`:

```bash
sudo apt install libcupsimage2-dev
```

### `cmake: command not found`

Instalar CMake:

```bash
sudo apt install cmake
```

### `g++: command not found`

Instalar la toolchain de compilación estándar:

```bash
sudo apt install build-essential
```

### No se genera el binario tras el build

Verificar:

- Que `filter/TmThermalReceipt.c` exista y compile correctamente.
- Que el objetivo en `CMakeLists.txt` siga llamándose `rastertotmtr`.

## Nota

Esta guía está basada en el `CMakeLists.txt` actual que define el ejecutable `rastertotmtr` a partir de `filter/TmThermalReceipt.c` y lo enlaza con `cupsimage` y `cups`.
