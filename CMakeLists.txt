cmake_minimum_required(VERSION 3.10)
project(rastertotmtr C)

set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED ON)

find_package(PkgConfig REQUIRED)

# ─────────────────────────────────────────────────────────────────────────────
# CUPS — detección robusta para sistemas con CUPS snap (Ubuntu 25.10+)
#
# En Ubuntu con CUPS instalado como snap, el cups.pc puede declarar
# dependencias privadas (gnutls, avahi-client) que no están disponibles
# como .pc en el sistema host. pkg_check_modules en modo REQUIRED falla.
# Solución: intentar pkg-config primero; si falla, usar find_library/find_path.
# ─────────────────────────────────────────────────────────────────────────────
pkg_check_modules(CUPS cups)

if(NOT CUPS_FOUND)
    message(STATUS "pkg-config no encontró cups (posible entorno CUPS snap) — usando find_library")
    find_library(CUPS_LIB NAMES cups REQUIRED)
    find_path(CUPS_INCLUDE NAMES cups/cups.h REQUIRED)
    set(CUPS_LIBRARIES ${CUPS_LIB})
    set(CUPS_INCLUDE_DIRS ${CUPS_INCLUDE})
    set(CUPS_CFLAGS_OTHER "")
    message(STATUS "libcups encontrada via find_library: ${CUPS_LIB}")
    message(STATUS "CUPS headers en: ${CUPS_INCLUDE}")
else()
    # En entornos normales (deb puro) pkg-config funciona correctamente.
    # Usar solo las flags de enlace dinámico (no arrastar deps privadas).
    message(STATUS "CUPS encontrado via pkg-config: ${CUPS_VERSION}")
endif()

# ─────────────────────────────────────────────────────────────────────────────
# libcupsimage — también puede no tener .pc (común en Ubuntu/Debian)
# ─────────────────────────────────────────────────────────────────────────────
pkg_check_modules(CUPSIMAGE cupsimage)

if(NOT CUPSIMAGE_FOUND)
    find_library(CUPSIMAGE_LIB NAMES cupsimage)
    find_path(CUPSIMAGE_INCLUDE NAMES cups/raster.h)
    if(CUPSIMAGE_LIB)
        set(CUPSIMAGE_FOUND TRUE)
        set(CUPSIMAGE_LIBRARIES ${CUPSIMAGE_LIB})
        if(CUPSIMAGE_INCLUDE)
            set(CUPSIMAGE_INCLUDE_DIRS ${CUPSIMAGE_INCLUDE})
        endif()
        message(STATUS "libcupsimage encontrada via find_library: ${CUPSIMAGE_LIB}")
    else()
        message(STATUS "libcupsimage no encontrada — compilando sin ella (modo CUPS 3.x)")
    endif()
endif()

# ─────────────────────────────────────────────────────────────────────────────
# Target
# ─────────────────────────────────────────────────────────────────────────────
add_executable(rastertotmtr filter/TmThermalReceipt.c)

target_include_directories(rastertotmtr PRIVATE ${CUPS_INCLUDE_DIRS})

if(CUPS_CFLAGS_OTHER)
    target_compile_options(rastertotmtr PRIVATE ${CUPS_CFLAGS_OTHER})
endif()

if(CUPSIMAGE_FOUND)
    if(CUPSIMAGE_INCLUDE_DIRS)
        target_include_directories(rastertotmtr PRIVATE ${CUPSIMAGE_INCLUDE_DIRS})
    endif()
    target_link_libraries(rastertotmtr PRIVATE ${CUPSIMAGE_LIBRARIES} ${CUPS_LIBRARIES})
    message(STATUS "Enlazando con cupsimage + cups")
else()
    target_link_libraries(rastertotmtr PRIVATE ${CUPS_LIBRARIES})
    target_compile_definitions(rastertotmtr PRIVATE CUPS_NO_IMAGE)
    message(STATUS "Enlazando con cups (sin cupsimage — CUPS_NO_IMAGE)")
endif()

# libm requerida por el filtro (funciones matemáticas de raster)
target_link_libraries(rastertotmtr PRIVATE m)

# ─────────────────────────────────────────────────────────────────────────────
# Instalación
# ─────────────────────────────────────────────────────────────────────────────
include(GNUInstallDirs)

install(TARGETS rastertotmtr
    RUNTIME DESTINATION ${CMAKE_INSTALL_LIBDIR}/cups/filter)

install(DIRECTORY ppd/
    DESTINATION ${CMAKE_INSTALL_DATADIR}/cups/model
    FILES_MATCHING PATTERN "*.ppd")
