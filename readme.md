# Proceso de build y evolución del soporte Ubuntu 25.10

Este documento describe cómo compilar el filtro `rastertotmtr`, las dependencias necesarias en Ubuntu 25.10 y los cambios introducidos en el flujo de build respecto a configuraciones anteriores (CentOS/openSUSE).

---

## Antecedentes

Originalmente este proyecto se documentó para distribuciones como CentOS y openSUSE, usando paquetes de desarrollo específicos de cada ecosistema (por ejemplo, `gcc-c++`, `cups-devel`, etc.).

En la migración a Ubuntu 25.10 se realizó:

- La **traducción de dependencias** a nombres de paquetes Debian/Ubuntu.
- La **automatización del proceso de compilación** mediante un `build.sh` robusto.
- La incorporación de **validaciones previas y posterior al build** para reducir errores en tiempo de ejecución y facilitar diagnósticos.

El objetivo es que, en entornos tipo Debian/Ubuntu (y, en particular, Ubuntu 25.10), el build sea prácticamente reproducible con un solo comando.

---

## Dependencias en Ubuntu 25.10

Para compilar el proyecto en Ubuntu 25.10 se requieren:

```bash
sudo apt update
sudo apt install \
  cmake \
  build-essential \
  libcups2-dev \
  libcupsimage2-dev
```

### Equivalencias con CentOS/openSUSE

- `cmake`  
  Equivalente directo en todas las distribuciones.

- `build-essential`  
  Sustituye a la combinación `gcc` + `gcc-c++` + utilidades básicas de compilación.  
  En CentOS/openSUSE esto estaba disperso en varios paquetes (`gcc`, `gcc-c++`, etc.).

- `libcups2-dev`  
  Equivalente funcional de `cups-devel` (cabeceras y librerías de CUPS).

- `libcupsimage2-dev`  
  Proporciona las cabeceras y librerías necesarias para `cupsimage`, que se usa explícitamente en el enlace del ejecutable.

Este set garantiza que el enlazado contra `cupsimage` y `cups` funcione correctamente en el entorno Ubuntu.

---

## Estructura del proyecto relevante para el build

El proyecto se estructura de forma que:

- El `CMakeLists.txt` principal se ubica en la raíz del repositorio.
- El ejecutable principal se llama `rastertotmtr`.
- El archivo fuente clave es `filter/TmThermalReceipt.c`.
- El enlace se realiza contra las librerías `cupsimage` y `cups`.

Ejemplo de definición en CMake:

```cmake
cmake_minimum_required(VERSION 2.8)

add_executable(rastertotmtr
    filter/TmThermalReceipt.c
)

target_link_libraries(rastertotmtr cupsimage cups)
```

---

## Evolución del `build.sh`

### Antes

En versiones anteriores el proceso de compilación solía ser:

- Manual o con un script simple que:
  - Ejecutaba `cmake` y `make` dentro de un directorio.
  - No validaba la presencia del código fuente ni de CMake.
  - No comprobaba que las dependencias de sistema estuvieran instaladas.
  - No verificaba el binario final más allá de la ausencia de errores en compilación.

Esto hacía que:

- Errores de entorno (falta de paquetes, CUPS sin headers de desarrollo, etc.) se detectaran tardíamente.
- Fuese más difícil recrear el build en máquinas nuevas o en entornos automatizados (CI, contenedores, etc.).

### Ahora

El nuevo `build.sh` está diseñado para:

1. **Validar el proyecto** antes de compilar:
   - Comprueba que existan:
     - `CMakeLists.txt` en la raíz.
     - `filter/TmThermalReceipt.c` en la ruta esperada.
2. **Verificar herramientas de build**:
   - Confirma la presencia de:
     - `cmake`
     - `gcc`
     - `g++`
     - `make`
3. **Detectar la familia de sistema operativo**:
   - Si es Ubuntu/Debian:
     - Revisa si están instalados:
       - `cmake`
       - `build-essential`
       - `libcups2-dev`
       - `libcupsimage2-dev`
     - Si faltan paquetes, ejecuta:
       - `apt-get update`
       - `apt-get install -y <paquetes faltantes>`
   - Si no es Ubuntu/Debian:
     - Muestra una advertencia y **no intenta instalar paquetes**, dejando al usuario la instalación manual.
4. **Limpiar y regenerar el directorio de build**:
   - Elimina el directorio `build/` previo (si existe).
   - Crea un nuevo `build/`.
5. **Configurar CMake fuera del árbol fuente**:
   - Usa la forma recomendada:
     - `cmake -S . -B build -DCMAKE_BUILD_TYPE=<tipo>`
   - Esto evita ensuciar la raíz con archivos intermedios y favorece builds reproducibles.
6. **Compilar aprovechando todos los núcleos disponibles**:
   - Detecta el número de CPUs y ejecuta:
     - `cmake --build build -- -j<N>`
   - Esto reduce significativamente el tiempo de compilación en máquinas multicore.
7. **Verificar el binario final**:
   - Localiza el ejecutable `rastertotmtr` dentro de `build/`.
   - Comprueba que sea ejecutable.
   - Opcionalmente, muestra:
     - Información de tipo de binario (`file`).
     - Dependencias dinámicas (`ldd`), útil para inspeccionar vínculo con CUPS.
8. **Manejo robusto de errores**:
   - El script se ejecuta con modo estricto (`set -euo pipefail`).
   - Se define un handler global de errores que:
     - Muestra un mensaje claro cuando algo falla.
     - Sugiere revisar:
       - Dependencias de CUPS.
       - Existencia del código fuente.
       - Mensajes de error de compilación.

---

## Ejemplo de `build.sh` actual

Este es el esquema general del script (puedes adaptarlo según tus necesidades locales):

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

# ... funciones de logging, detección de OS, instalación de paquetes, etc. ...

main() {
  echo "[INFO] Proyecto: ${PROJECT_NAME}"
  echo "[INFO] Tipo de build: ${BUILD_TYPE}"

  # 1) Verificar archivos del proyecto
  # 2) Instalar dependencias en Ubuntu/Debian si faltan
  # 3) Verificar herramientas de compilación
  # 4) Configurar CMake (-S . -B build)
  # 5) Compilar (cmake --build ...)
  # 6) Verificar ejecutable generado
}

main "$@"
```

> Nota: En el repositorio debe incluirse la versión completa del script con todas las funciones auxiliares (detección de OS, instalación de paquetes, verificación de binario, etc.).

---

## Uso del nuevo flujo de build

### Build estándar (Release)

```bash
chmod +x build.sh
./build.sh
```

Este flujo:

1. Instala dependencias faltantes (en Ubuntu/Debian, si tiene permisos para hacerlo).
2. Configura CMake en modo Release.
3. Compila usando todos los núcleos disponibles.
4. Verifica el binario `rastertotmtr`.

### Build de depuración

```bash
BUILD_TYPE=Debug ./build.sh
```

Esto genera el proyecto con símbolos de depuración y sin optimizaciones agresivas, facilitando el uso de herramientas como `gdb` o `valgrind`.

### Control de paralelismo

```bash
JOBS=4 ./build.sh
```

Limita el número de hilos usados en la compilación, útil en máquinas con pocos recursos o en entornos compartidos.

---

## Cambios clave respecto a versiones anteriores

1. **Entorno objetivo documentado**  
   - Se explicita el soporte para **Ubuntu 25.10** y, en general, para la familia Debian/Ubuntu.
   - Se documentan claramente las equivalencias de paquetes con CentOS/openSUSE.

2. **Instalación automática de dependencias**  
   - El script ahora puede realizar:
     - `apt-get update`
     - `apt-get install -y cmake build-essential libcups2-dev libcupsimage2-dev`
   - Esto reduce el tiempo de preparación en máquinas nuevas o contenedores.

3. **Compilación fuera del árbol fuente**  
   - Se estandariza el uso de `cmake -S . -B build`.
   - El árbol fuente se mantiene limpio y reproducible.

4. **Verificación explícita del ejecutable**  
   - Ya no se asume que la compilación exitosa implica un binario correcto.
   - Se comprueba que el archivo `rastertotmtr` exista y sea ejecutable.

5. **Manejo de errores mejorado**  
   - El script termina tan pronto ocurre un error.
   - Se muestran mensajes más claros para facilitar depuración.

---

## Recomendaciones para integración con Perplexity Computer / entornos automatizados

- Mantener este documento (`BUILD.md`) y el script `build.sh` en la raíz del repositorio.
- Asegurarse de que:
  - El script tenga permisos de ejecución (`chmod +x build.sh`).
  - El flujo de CI (si existe) utilice **exactamente** las mismas dependencias y comandos descritos aquí.
- En entornos reproducibles (contenedores, plantillas de VM):
  - Preinstalar los paquetes:
    - `cmake`
    - `build-essential`
    - `libcups2-dev`
    - `libcupsimage2-dev`
  - Esto permite que el script se enfoque en el build y las verificaciones, sin necesidad de instalación en cada ejecución.

---

## Resumen

La actualización del flujo de build a Ubuntu 25.10 introduce:

- Un **mapa claro de dependencias** para Debian/Ubuntu.
- Un **script de build más robusto**, automatizado y verificable.
- Una mejor **observabilidad del estado del binario**, incluyendo dependencias dinámicas.
- Un flujo adecuado tanto para uso interactivo como para entornos automatizados (por ejemplo, Perplexity Computer, CI/CD, contenedores).

Con estos cambios, la compilación del filtro `rastertotmtr` debería ser reproducible, menos propensa a errores de entorno y más fácil de integrar en pipelines automatizados.