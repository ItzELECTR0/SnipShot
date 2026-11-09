cmake_minimum_required(VERSION 3.24)
project(SnipShot VERSION 0.0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
find_program(ZIG_EXECUTABLE zig REQUIRED)
find_package(Qt6 6.8 REQUIRED COMPONENTS Quick Qml QuickControls2 Multimedia DBus)
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

set(QML_SOURCES
    ui/App.qml
    ui/Theme.qml
    ui/FluentIcon.qml
    ui/IconButton.qml
    ui/FluentField.qml
    ui/FluentCombo.qml
    ui/Surface.qml
    ui/CaptureOverlay.qml
    ui/CaptureBar.qml
    ui/RecordBar.qml
    ui/RecordControls.qml
    ui/RecordFrame.qml
    ui/StatusPill.qml
    ui/TextFlyout.qml
    ui/MainWindow.qml
    ui/SettingsWindow.qml
    ui/SnipWindow.qml
    ui/VideoPreview.qml
    ui/icons/Icons.js
)
foreach(source IN LISTS QML_SOURCES)
    get_filename_component(alias "${source}" NAME)
    set_source_files_properties("${source}" PROPERTIES QT_RESOURCE_ALIAS "${alias}")
endforeach()
set_source_files_properties(ui/Theme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_executable(snipshot
    app/main.cpp
    app/capturebackend.cpp
    app/capturebackend.h
    app/instance.h
    app/overlaycontroller.cpp
    app/overlaycontroller.h
    app/settings.cpp
    app/settings.h
    app/themesource.cpp
    app/themesource.h
)
qt_add_qml_module(snipshot
    URI SnipShot
    VERSION 1.0
    QML_FILES ${QML_SOURCES}
)
add_dependencies(snipshot snipshot_core_build)
target_include_directories(snipshot PRIVATE src app)
target_compile_definitions(snipshot PRIVATE SNIPSHOT_VERSION="${PROJECT_VERSION}")
target_link_libraries(snipshot PRIVATE
    snipshot_core Qt6::Quick Qt6::Qml Qt6::QuickControls2 Qt6::DBus LayerShellQt::Interface)
install(TARGETS snipshot RUNTIME DESTINATION bin)
install(FILES data/io.github.ItzELECTR0.SnipShot.desktop DESTINATION share/applications)
