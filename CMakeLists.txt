cmake_minimum_required(VERSION 3.10)
project(rastertotmtr C)

set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED ON)

# Detectar CUPS con pkg-config
find_package(PkgConfig REQUIRED)
pkg_check_modules(CUPS REQUIRED cups)

# Intentar detectar libcupsimage (puede no existir en CUPS 3.x)
pkg_check_modules(CUPSIMAGE cupsimage)

add_executable(rastertotmtr filter/TmThermalReceipt.c)

target_include_directories(rastertotmtr PRIVATE ${CUPS_INCLUDE_DIRS})
target_compile_options(rastertotmtr PRIVATE ${CUPS_CFLAGS_OTHER})

if(CUPSIMAGE_FOUND)
    target_include_directories(rastertotmtr PRIVATE ${CUPSIMAGE_INCLUDE_DIRS})
    target_link_libraries(rastertotmtr PRIVATE ${CUPSIMAGE_LIBRARIES} ${CUPS_LIBRARIES})
else()
    target_link_libraries(rastertotmtr PRIVATE ${CUPS_LIBRARIES})
    target_compile_definitions(rastertotmtr PRIVATE CUPS_NO_IMAGE)
endif()

# Configuración de instalación
include(GNUInstallDirs)
install(TARGETS rastertotmtr
    RUNTIME DESTINATION ${CMAKE_INSTALL_LIBDIR}/cups/filter)
install(FILES ppd/tm-ba-thermal-rastertotmtr-180.ppd
              ppd/tm-ba-thermal-rastertotmtr-203.ppd
    DESTINATION ${CMAKE_INSTALL_DATADIR}/cups/model)
