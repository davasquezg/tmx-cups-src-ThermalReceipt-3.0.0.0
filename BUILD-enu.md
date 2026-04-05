# BUILD-enu.md

# Build guide for Ubuntu 25.10

This project builds the `rastertotmtr` executable using CMake and links against the CUPS libraries `cupsimage` and `cups`.[file:1]

## Overview

The main build definition creates the `rastertotmtr` binary from `filter/TmThermalReceipt.c` and links it with `cupsimage` and `cups`.[file:1]

This guide documents the recommended build process for **Ubuntu 25.10**, including package translation from RPM-based distributions and a safer automated build workflow.[file:1]

## Required packages

Install the required development tools and CUPS headers with:

```bash
sudo apt update
sudo apt install \
  cmake \
  build-essential \
  libcups2-dev \
  libcupsimage2-dev
```

### Package mapping

If the original project documentation referenced CentOS or openSUSE packages, the Ubuntu 25.10 equivalents are:

| CentOS / openSUSE | Ubuntu 25.10 |
|---|---|
| `cmake` | `cmake` |
| `gcc` | `build-essential` |
| `gcc-c++` | `build-essential` |
| `cups-devel` | `libcups2-dev` |
| `cups image development` | `libcupsimage2-dev` |

## Project files

The build expects the following files to exist:

- `CMakeLists.txt`
- `filter/TmThermalReceipt.c`

The current CMake definition is:

```cmake
cmake_minimum_required(VERSION 2.8)

add_executable(rastertotmtr
    filter/TmThermalReceipt.c
)

target_link_libraries(rastertotmtr cupsimage cups)
```

## Recommended build script

The repository should include a `build.sh` script that:

- Verifies required project files exist.
- Detects whether the system is Ubuntu/Debian.
- Installs missing dependencies automatically when possible.
- Configures an out-of-source build in `build/`.
- Compiles using all available CPU cores.
- Verifies that the final binary was generated successfully.

Example:

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
  echo "[ERROR] Build failed with exit code ${exit_code}" >&2
  echo "[ERROR] Check CUPS development packages, source files, and compiler output." >&2
  exit "${exit_code}"
}
trap on_error ERR

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
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
    die "Root or sudo access is required to install missing packages"
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
    log "All required packages are already installed"
    return
  fi

  log "Missing packages: ${missing[*]}"
  run_privileged apt-get update
  DEBIAN_FRONTEND=noninteractive run_privileged apt-get install -y "${missing[@]}"
}

verify_project_files() {
  [[ -f "CMakeLists.txt" ]] || die "CMakeLists.txt not found in project root"
  [[ -f "${SOURCE_FILE}" ]] || die "Source file not found: ${SOURCE_FILE}"
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

  [[ -n "${bin}" ]] || die "Build finished but ${PROJECT_NAME} was not found"
  [[ -x "${bin}" ]] || die "Generated file exists but is not executable: ${bin}"

  log "Build completed successfully"
  log "Binary: ${bin}"

  if command -v ldd >/dev/null 2>&1; then
    ldd "${bin}" || true
  fi
}

main() {
  log "Project: ${PROJECT_NAME}"
  log "Build type: ${BUILD_TYPE}"

  verify_project_files

  case "$(detect_os)" in
    ubuntu|debian)
      ensure_apt_packages
      ;;
    *)
      warn "Non-Debian system detected, automatic package installation skipped"
      ;;
  esac

  verify_tools
  configure_build
  build_project
  verify_binary
}

main "$@"
```

## Build steps

Make the script executable:

```bash
chmod +x build.sh
```

Run the default build:

```bash
./build.sh
```

Run a debug build:

```bash
BUILD_TYPE=Debug ./build.sh
```

Limit parallel jobs manually if needed:

```bash
JOBS=4 ./build.sh
```

## What changed

Compared with older CentOS/openSUSE-oriented instructions, the Ubuntu 25.10 workflow introduces:

- Ubuntu package names for CUPS development headers and libraries.
- `build-essential` instead of manually listing compiler packages one by one.
- Automatic dependency installation for Ubuntu/Debian systems.
- Out-of-source builds using `cmake -S . -B build`.
- Final binary verification after compilation.

These changes make the build easier to reproduce in fresh machines, containers, CI environments, and automated assistants.

## Troubleshooting

### `fatal error: cups/cups.h: No such file or directory`

Install the CUPS development package:

```bash
sudo apt install libcups2-dev
```

### `cannot find -lcupsimage`

Install the CUPS image development package:

```bash
sudo apt install libcupsimage2-dev
```

### `cmake: command not found`

Install CMake:

```bash
sudo apt install cmake
```

### `g++: command not found`

Install the standard compiler toolchain:

```bash
sudo apt install build-essential
```

### Binary not generated after build

Check that:

- `filter/TmThermalReceipt.c` exists.
- The source file compiles without errors.
- The target name in `CMakeLists.txt` is still `rastertotmtr`.[file:1]

## Notes

This guide documents the Ubuntu 25.10 build path based on the current `CMakeLists.txt` that builds `rastertotmtr` from `filter/TmThermalReceipt.c` and links against `cupsimage` and `cups`.[file:1]