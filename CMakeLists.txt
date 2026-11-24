cmake_minimum_required(VERSION 3.21)
project(cinefy VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Release (optimised, no debug info) unless asked otherwise.
get_property(_multi_config GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(NOT _multi_config AND NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release CACHE STRING "Debug, Release, RelWithDebInfo or MinSizeRel" FORCE)
endif()

# Link-time optimisation for optimised builds, where the compiler supports it.
option(CINEFY_LTO "Link-time optimisation in Release builds" ON)
if(CINEFY_LTO)
    include(CheckIPOSupported)
    check_ipo_supported(RESULT _ipo_ok OUTPUT _ipo_msg LANGUAGES CXX)
    if(_ipo_ok)
        set(CMAKE_INTERPROCEDURAL_OPTIMIZATION_RELEASE ON)
        set(CMAKE_INTERPROCEDURAL_OPTIMIZATION_MINSIZEREL ON)
    else()
        message(STATUS "Link-time optimisation not available: ${_ipo_msg}")
    endif()
endif()

# Qt 6.8 or newer, from your distro, Homebrew, or the Qt online installer.
# A few private Qt headers are used on purpose (zip reading, lightmap baking).
set(QT_NO_PRIVATE_MODULE_WARNING ON)
find_package(Qt6 6.8 REQUIRED COMPONENTS
    Core CorePrivate Gui GuiPrivate Network Qml Quick QuickControls2 Quick3D Quick3DPrivate Multimedia ShaderTools)

qt_standard_project_setup(REQUIRES 6.8)

# --- data layer: export parsing, no GUI -------------------------------------
add_library(cinefy_core STATIC
    src/Csv.h src/Csv.cpp
    src/Film.h src/Film.cpp
    src/ExportLoader.h src/ExportLoader.cpp
)
target_include_directories(cinefy_core PUBLIC src)
target_link_libraries(cinefy_core PUBLIC Qt6::Core PRIVATE Qt6::CorePrivate)

# --- the app ------------------------------------------------------------------
qt_add_executable(cinefy
    src/main.cpp
    src/FilmModel.h src/FilmModel.cpp
    src/AisleModel.h src/AisleModel.cpp
    src/StoreLayout.h src/StoreLayout.cpp
    src/CoverAtlas.h src/CoverAtlas.cpp
    src/TapeInstancing.h src/TapeInstancing.cpp
    src/UmbrellaGeometry.h src/UmbrellaGeometry.cpp
    src/SurfaceDetail.h src/SurfaceDetail.cpp
    src/GlowTexture.h src/GlowTexture.cpp
    src/RoomProbe.h src/RoomProbe.cpp
    src/LetteringTexture.h src/LetteringTexture.cpp
    src/ShelvingGeometry.h src/ShelvingGeometry.cpp
    src/ListInstancing.h src/ListInstancing.cpp
    src/MatchCache.h src/MatchCache.cpp
    src/TmdbClient.h src/TmdbClient.cpp
    src/CachingNetwork.h
    src/PointerHelper.h src/PointerHelper.cpp
    src/SoundBank.h src/SoundBank.cpp
    src/LightBaker.h src/LightBaker.cpp
    src/Shop.h src/Shop.cpp
)

set(CINEFY_QML
    qml/Main.qml
    qml/Theme.qml
    qml/Storefront.qml
    qml/Store3D.qml
    qml/Store3DInterior.qml
    qml/Store3DStreet.qml
    qml/Store3DFacade.qml
    qml/Store3DForecourt.qml
    qml/Store3DBackWall.qml
    qml/Store3DWallRacks.qml
    qml/PostFx.qml
    qml/Store3DFrontHoldout.qml
    qml/Umbrella.qml
    qml/StoreMap.qml
    qml/PauseMenu.qml
    qml/BlankLabel.qml
    qml/VhsCase.qml
    qml/CoverPicker.qml
    qml/MemberCard.qml
    qml/DiaryPages.qml
    qml/HeldDiary.qml
    qml/Clerk.qml
    qml/MembershipCard3D.qml
    qml/ClerkDialog.qml
    qml/NeonText.qml
    qml/Carpet.qml
    qml/Scanlines.qml
    qml/RetroButton.qml
    qml/RetroField.qml
)
set_source_files_properties(qml/Theme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set(CINEFY_SHADERS
    qml/tape.vert
    qml/tape.frag
    qml/ascii.frag
    qml/holdout.frag
)
foreach(f ${CINEFY_QML} ${CINEFY_SHADERS})
    get_filename_component(name ${f} NAME)
    set_source_files_properties(${f} PROPERTIES QT_RESOURCE_ALIAS ${name})
endforeach()

qt_add_qml_module(cinefy
    URI Cinefy
    VERSION 1.0
    QML_FILES ${CINEFY_QML}
    RESOURCES ${CINEFY_SHADERS}
)

# A real app on Windows (no console window) and macOS (an .app bundle).
set_target_properties(cinefy PROPERTIES
    WIN32_EXECUTABLE ON
    MACOSX_BUNDLE ON
    MACOSX_BUNDLE_BUNDLE_NAME "Cinefy Video"
    MACOSX_BUNDLE_GUI_IDENTIFIER "app.cinefy.video"
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION})

# Post-processing shaders for the 2D effects (bloom, colour grade).
qt_add_shaders(cinefy "postfx"
    PREFIX "/qt/qml/Cinefy"
    FILES qml/shaders/bright.frag qml/shaders/grade.frag)

target_compile_definitions(cinefy PRIVATE CINEFY_VERSION="${PROJECT_VERSION}")

target_link_libraries(cinefy PRIVATE
    cinefy_core Qt6::Gui Qt6::GuiPrivate Qt6::Network Qt6::Qml Qt6::Quick Qt6::QuickControls2 Qt6::Quick3D Qt6::Quick3DPrivate)

# --- console check: load an export and print counts ---------------------------
add_executable(cinefy_loadtest tools/loadtest.cpp)
target_link_libraries(cinefy_loadtest PRIVATE cinefy_core)

# --- install -------------------------------------------------------------------
# Linux: the binary (QML and shaders are built in), a launcher entry and an icon.
# Windows/macOS: the app plus the Qt libraries it needs, ready to zip and share.
include(GNUInstallDirs)
install(TARGETS cinefy
    BUNDLE DESTINATION .
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})

if(UNIX AND NOT APPLE)
    # The launcher entry points at wherever it is installed (make install PREFIX=...).
    install(CODE "
        set(CMAKE_INSTALL_FULL_BINDIR \"\${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_BINDIR}\")
        configure_file(\"${CMAKE_CURRENT_SOURCE_DIR}/packaging/cinefy.desktop.in\"
                       \"\$ENV{DESTDIR}\${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_DATADIR}/applications/cinefy.desktop\" @ONLY)
        message(STATUS \"Installing: \$ENV{DESTDIR}\${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_DATADIR}/applications/cinefy.desktop\")
    ")
    install(FILES packaging/cinefy.svg DESTINATION ${CMAKE_INSTALL_DATADIR}/icons/hicolor/scalable/apps)
else()
    qt_generate_deploy_qml_app_script(TARGET cinefy OUTPUT_SCRIPT deploy_script)
    install(SCRIPT ${deploy_script})
endif()
