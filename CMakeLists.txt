cmake_minimum_required(VERSION 3.24)
project(SnipShot LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
find_program(ZIG_EXECUTABLE zig REQUIRED)
find_package(Qt6 6.5 REQUIRED COMPONENTS Quick Qml Multimedia DBus)
find_package(LayerShellQt REQUIRED)
qt_policy(SET QTP0001 NEW)
qt_policy(SET QTP0004 NEW)

set(CORE_LIBRARY "${CMAKE_CURRENT_BINARY_DIR}/libsnipshot_core.a")
add_custom_command(
    OUTPUT "${CORE_LIBRARY}"
    COMMAND "${CMAKE_COMMAND}" -E env "ZIG_GLOBAL_CACHE_DIR=${CMAKE_CURRENT_BINARY_DIR}/zig-cache"
        "${ZIG_EXECUTABLE}" build-lib "${CMAKE_CURRENT_SOURCE_DIR}/src/core.zig"
        -static -lc -O ReleaseFast "-femit-bin=${CORE_LIBRARY}"
    DEPENDS src/core.zig
    VERBATIM
)
add_custom_target(snipshot_core_build DEPENDS "${CORE_LIBRARY}")
add_library(snipshot_core STATIC IMPORTED GLOBAL)
set_target_properties(snipshot_core PROPERTIES IMPORTED_LOCATION "${CORE_LIBRARY}")
add_dependencies(snipshot_core snipshot_core_build)

set_source_files_properties(ui/Main.qml PROPERTIES QT_RESOURCE_ALIAS Main.qml)
set_source_files_properties(ui/VideoPreview.qml PROPERTIES QT_RESOURCE_ALIAS VideoPreview.qml)
qt_add_executable(snipshot
    app/main.cpp
    app/capturebackend.cpp
    app/capturebackend.h
)
qt_add_qml_module(snipshot
    URI SnipShot
    VERSION 1.0
    QML_FILES
        ui/Main.qml
        ui/VideoPreview.qml
)
add_dependencies(snipshot snipshot_core_build)
target_include_directories(snipshot PRIVATE src)
target_link_libraries(snipshot PRIVATE snipshot_core Qt6::Quick Qt6::Qml Qt6::DBus LayerShellQt::Interface)
install(TARGETS snipshot RUNTIME DESTINATION bin)
