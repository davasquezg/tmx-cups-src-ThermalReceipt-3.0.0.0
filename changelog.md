# CHANGELOG

## [Unreleased]

---

## [1.3.0] - 2026-04-05

### Añadido

- PPDs específicos por modelo para mayor claridad en CUPS:
  - `tm-t88v-rastertotmtr-180.ppd` — EPSON TM-T88V (180dpi), verificado con UB-E04
  - `tm-t88vi-rastertotmtr-180.ppd` — EPSON TM-T88VI (180dpi)
  - `tm-t88vii-rastertotmtr-180.ppd` — EPSON TM-T88VII (180dpi)
  - `tm-t70ii-rastertotmtr-180.ppd` — EPSON TM-T70II (180dpi)
  - `tm-m30-rastertotmtr-203.ppd` — EPSON TM-m30 (203dpi)
  - `tm-m30ii-rastertotmtr-203.ppd` — EPSON TM-m30II (203dpi)
  - `tm-t20iii-rastertotmtr-203.ppd` — EPSON TM-T20III (203dpi)
- `install.sh`: instrucciones de ejemplo para registrar TM-T88V por red y USB.
- `readme.md`: reescrito con tabla de modelos compatibles, instrucciones de red/UB-E04,
  tabla de opciones PPD y documentación de arquitectura del driver.

### Notas técnicas

- Los modelos de la familia TM-T88 (V, VI, VII) usan los mismos parámetros ESC/POS
  (180 dpi, motion units 180/180, ancho de papel idéntico). Solo difieren en velocidad
  de impresión y características adicionales (grayscale, Server Direct Print, etc.) que
  no afectan al filtro raster.
- Para conexión de red vía UB-E04 usar device URI `socket://IP:9100`.

---

## [1.2.1] - 2026-04-05

### Corregido

- `CMakeLists.txt`: agregado `find_library(cupsimage)` como fallback cuando `cupsimage` no tiene archivo `.pc` para pkg-config (caso común en Debian/Ubuntu actual con `libcupsimage2-dev`).
- `CMakeLists.txt`: agregado enlace explícito con `-lm` (libmath), necesario para `math.h` en GCC 14+.
- `TmThermalReceipt.c`: migrado `cupsRasterReadHeader()` → `cupsRasterReadHeader2()` y `cups_page_header_t` → `cups_page_header2_t` (APIs modernas disponibles desde CUPS 1.5, eliminan el warning de deprecated en CUPS 2.4.x).

### Verificado

- Build: GCC 14.2.0 / CMake 3.31.6 / CUPS 2.4.10 — **0 errores, 0 warnings**.
- Dependencias dinámicas resueltas: `libcupsimage.so.2`, `libcups.so.2`, `libm.so.6`.

---

## [1.2.0] - 2026-04-05

### Añadido

- Compatibilidad dual **CUPS 2.x / CUPS 3.x** en `filter/TmThermalReceipt.c`:
  - Ruta CUPS 2.x: mantiene flujo original basado en PPD con supresión de warnings deprecated.
  - Ruta CUPS 3.x: nueva función `GetParametersFromOptions()` que lee todas las opciones
    directamente desde `cupsParseOptions(argv[5])` / `cupsGetOption()`, sin dependencia de
    `cups/ppd.h` ni APIs PPD.
  - Detección automática de versión CUPS mediante `#if CUPS_VERSION_MAJOR < 3`.
  - Valores por defecto sensatos para la ruta sin PPD (TmxMotionUnit 180, PaperReduction Bottom,
    BuzzerAndDrawer NotUsed, PaperCut NoCut).
- Directiva `*cupsFilter2:` en ambos archivos PPD para compatibilidad con CUPS 2.5+/3.x.
- Detección de `libcupsimage` como opcional en CMakeLists.txt (puede no existir en CUPS 3.x).
- Reglas de instalación con `GNUInstallDirs` en CMakeLists.txt.
- Verificación de existencia del binario `rastertotmtr` antes de instalar en `install.sh`.
- Soporte para `systemctl reload cups` como método preferido de reinicio en `install.sh`.

### Cambiado

- `*cupsVersion:` de `1.2` a `2.2` en ambos archivos PPD.
- `*FileVersion:` de `"2.0"` a `"3.0.0.0"` en ambos archivos PPD.
- `CMakeLists.txt` modernizado:
  - `cmake_minimum_required` de 2.8 a 3.10.
  - Detección de CUPS vía `pkg-config` (`pkg_check_modules`).
  - Estándar C99 explícito.
  - Enlace condicional de `cupsimage` (solo si está disponible).
- `install.sh`: prioriza `systemctl` para reinicio de CUPS en sistemas modernos (Ubuntu 25.10+).

---

## [1.1.0] - 2026-04-05

### Añadido

- Soporte explícito para **Ubuntu 25.10** como entorno de compilación principal.
- Documentación de build en `BUILD.md`, incluyendo:
  - Paquetes requeridos: `cmake`, `build-essential`, `libcups2-dev`, `libcupsimage2-dev`.
  - Tabla de equivalencias de paquetes entre CentOS/openSUSE y Ubuntu/Debian.
  - Flujo recomendado de build fuera del árbol fuente (`cmake -S . -B build`).[file:1][code_file:3]
- Script de compilación automatizado `build.sh` que:
  - Verifica la presencia de `CMakeLists.txt` y `filter/TmThermalReceipt.c` antes de compilar.
  - Detecta sistemas Ubuntu/Debian e instala paquetes faltantes con `apt-get` cuando es posible.
  - Ejecuta CMake en modo out-of-source (`build/`) y compila usando todos los núcleos disponibles.
  - Comprueba que el ejecutable `rastertotmtr` se genere correctamente y muestra sus dependencias dinámicas con `ldd` cuando está disponible.[file:1][code_file:3]

### Cambiado

- Estandarización del flujo de build:
  - Se deja de recomendar la compilación directa en el árbol fuente.
  - Se formaliza el uso de `BUILD_TYPE` (`Release`, `Debug`, etc.) a través de variable de entorno.
- Unificación de instrucciones de build para entornos interactivos y automatizados (CI, contenedores, asistentes de desarrollo).[code_file:3]

### Corregido

- Casos donde el build fallaba de forma poco explícita por falta de:
  - `libcups2-dev` (errores en `cups/cups.h`).
  - `libcupsimage2-dev` (errores de enlace con `-lcupsimage`).
  - Toolchain básica (`gcc`, `g++`, `make`).[file:1][code_file:3]

---

## [1.0.0] - 2025-xx-xx

### Añadido

- Definición inicial de `CMakeLists.txt` para construir el ejecutable `rastertotmtr` a partir de `filter/TmThermalReceipt.c` y enlazarlo con `cupsimage` y `cups`.[file:1]
- Instrucciones básicas iniciales de compilación orientadas a distribuciones basadas en RPM (CentOS/openSUSE).[file:1]