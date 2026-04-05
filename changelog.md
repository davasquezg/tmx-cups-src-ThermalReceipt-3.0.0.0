# CHANGELOG

## [Unreleased]

- Mejoras menores en documentación de build.
- Ajustes menores en mensajes de error del script `build.sh`.

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