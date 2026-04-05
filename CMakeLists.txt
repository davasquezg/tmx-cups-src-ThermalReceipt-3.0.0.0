cmake_minimum_required(VERSION 3.10)
project(rastertotmtr C)

set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED ON)

# Detectar CUPS con pkg-config
find_package(PkgConfig REQUIRED)
pkg_check_modules(CUPS REQUIRED cups)

# Intentar detectar libcupsimage via pkg-config (puede no tener .pc en algunos sistemas)
pkg_check_modules(CUPSIMAGE cupsimage)

# Si pkg-config no lo encontró, buscar la biblioteca directamente
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
        message(STATUS "libcupsimage no encontrada - compilando sin ella (modo CUPS 3.x)")
    endif()
endif()

add_executable(rastertotmtr filter/TmThermalReceipt.c)

target_include_directories(rastertotmtr PRIVATE ${CUPS_INCLUDE_DIRS})
target_compile_options(rastertotmtr PRIVATE ${CUPS_CFLAGS_OTHER})

if(CUPSIMAGE_FOUND)
    if(CUPSIMAGE_INCLUDE_DIRS)
        target_include_directories(rastertotmtr PRIVATE ${CUPSIMAGE_INCLUDE_DIRS})
    endif()
    target_link_libraries(rastertotmtr PRIVATE ${CUPSIMAGE_LIBRARIES} ${CUPS_LIBRARIES})
    message(STATUS "Enlazando con cupsimage")
else()
    target_link_libraries(rastertotmtr PRIVATE ${CUPS_LIBRARIES})
    target_compile_definitions(rastertotmtr PRIVATE CUPS_NO_IMAGE)
    message(STATUS "Compilando sin cupsimage (CUPS_NO_IMAGE)")
endif()

# math library (usada por el filtro)
target_link_libraries(rastertotmtr PRIVATE m)

# Configuración de instalación
include(GNUInstallDirs)
install(TARGETS rastertotmtr
    RUNTIME DESTINATION ${CMAKE_INSTALL_LIBDIR}/cups/filter)
install(FILES ppd/tm-ba-thermal-rastertotmtr-180.ppd
              ppd/tm-ba-thermal-rastertotmtr-203.ppd
    DESTINATION ${CMAKE_INSTALL_DATADIR}/cups/model)
