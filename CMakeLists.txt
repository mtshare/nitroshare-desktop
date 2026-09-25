cmake_minimum_required(VERSION 3.16)

# Must be set before project(); the SwiftUI app requires macOS 14+
set(CMAKE_OSX_DEPLOYMENT_TARGET "14.0" CACHE STRING "Minimum macOS version")

project(nitroshare)

# Point CMake to the custom modules
set(CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

# It would be nice if CMake offered a constant for Linux
if(${CMAKE_SYSTEM_NAME} MATCHES "Linux")
    set(LINUX 1)
endif()

set(PROJECT_NAME "NitroShare")
set(PROJECT_DESCRIPTION "Cross-platform network file transfer application")
set(PROJECT_AUTHOR "Nathan Osman")
set(PROJECT_URL "https://nitroshare.net")

set(PROJECT_VERSION_MAJOR 0)
set(PROJECT_VERSION_MINOR 5)
set(PROJECT_VERSION_PATCH 0)
set(PROJECT_VERSION ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}.${PROJECT_VERSION_PATCH})

# Prefer Qt 6, falling back to Qt 5.15 (the oldest release still supported)
find_package(QT NAMES Qt6 Qt5 REQUIRED COMPONENTS Network)
find_package(Qt${QT_VERSION_MAJOR} REQUIRED COMPONENTS Network)
find_package(Qt${QT_VERSION_MAJOR} OPTIONAL_COMPONENTS Widgets)
message(STATUS "Using Qt ${QT_VERSION}")

# CLI and client are always available, UI is available if Qt Widgets is available
option(BUILD_CLI "Build the NitroShare CLI app" ON)
option(BUILD_NMH "Build native messaging host for Chrome" ON)
option(BUILD_CLIENT "Build the NitroShare client app" ON)
# On macOS the native SwiftUI app replaces the Qt widgets UI by default
if(APPLE)
    option(BUILD_MACOS_APP "Build the native macOS app" ON)
    set(MACOS_BUNDLE_IDENTIFIER "com.NathanOsman.NitroShare" CACHE STRING "Bundle identifier of the macOS app")
endif()
if(Qt${QT_VERSION_MAJOR}Widgets_FOUND)
    if(BUILD_MACOS_APP)
        option(BUILD_UI "Build the NitroShare UI app" OFF)
    else()
        option(BUILD_UI "Build the NitroShare UI app" ON)
    endif()
endif()
if(WIN32)
    option(BUILD_NITROSHELL "Build shell extension for Windows Explorer" ON)
endif()

option(ENABLE_TLS "Enable support for TLS" ON)

# Allow file installation directories to be customized
set(INSTALL_BIN_PATH bin CACHE STRING "Application installation directory")
set(INSTALL_LIB_PATH lib CACHE STRING "Shared library installation directory")
set(INSTALL_INCLUDE_PATH include CACHE STRING "Header installation directory")
set(INSTALL_PLUGIN_PATH "${INSTALL_LIB_PATH}/nitroshare/plugins" CACHE STRING "Plugin installation directory")

set(OUTPUT_PREFIX "${CMAKE_BINARY_DIR}/out")

# Ensure the output prefix supports multiple build configurations
if(CMAKE_CONFIGURATION_TYPES)
    set(OUTPUT_PREFIX "${OUTPUT_PREFIX}/$<CONFIG>")
endif()

# For macOS, the output directories form the app bundle; for all other
# platforms, the output paths mirror the installation paths
if(APPLE)
    set(CONTENTS_DIRECTORY "${OUTPUT_PREFIX}/NitroShare.app/Contents")
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CONTENTS_DIRECTORY}/MacOS")
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${CONTENTS_DIRECTORY}/Frameworks")
    set(PLUGIN_OUTPUT_DIRECTORY "${CONTENTS_DIRECTORY}/PlugIns/nitroshare")
else()
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${OUTPUT_PREFIX}/${INSTALL_BIN_PATH}")
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${OUTPUT_PREFIX}/${INSTALL_LIB_PATH}")
    set(PLUGIN_OUTPUT_DIRECTORY "${OUTPUT_PREFIX}/${INSTALL_PLUGIN_PATH}")
endif()

# Set appropriate compiler flags, etc. (MSVC is already set to W3 and Clang
# issues enough warnings as it is)
if(CMAKE_COMPILER_IS_GNUCXX)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -Wextra")
endif()

# Documentation is disabled by default
option(BUILD_DOC "Build Doxygen documentation" OFF)
if(BUILD_DOC)
    find_package(Doxygen REQUIRED)
    option(DOWNLOAD_TAGFILES "Download tagfiles for documentation" ON)
endif()

# Test suite is always disabled by default
option(BUILD_TESTS "Build test suite" OFF)
if(BUILD_TESTS)
    enable_testing()
    find_package(Qt${QT_VERSION_MAJOR} REQUIRED COMPONENTS Test)
endif()

# Add a dependency with a builtin fallback
function(add_dependency name title version)
    find_package(${name} ${version} QUIET)
    if(${name}_FOUND)
        message(STATUS "Found ${title} ${${name}_VERSION}")
    else()
        message(STATUS "${title} ${version}+ not found - using bundled version")
        set(_old_BUILD_DOC ${BUILD_DOC})
        set(BUILD_DOC OFF)
        add_subdirectory(deps/${name})
        set(BUILD_DOC ${_old_BUILD_DOC})
    endif()
endfunction()

# Attempt to find QHttpEngine on the system; use bundled version if missing
option(BUILD_API "Build local API plugin" ON)
if(BUILD_API)
    add_dependency(qhttpengine QHttpEngine 1.0.0)
endif()

# Attempt to find QMdnsEngine on the system; use bundled version if missing
option(BUILD_MDNS "Build mDNS discovery plugin" ON)
if(BUILD_MDNS)
    add_dependency(qmdnsengine QMdnsEngine 0.1.0)
endif()

# Enable libnotify support if GTK and libnotify are present
if(LINUX)
    find_package(PkgConfig)
    if(PKG_CONFIG_FOUND)
        pkg_check_modules(libnotify gtk+-2.0 libnotify)
    endif()
endif()

# Ensure that binaries are built with the RPATH set correctly
set(CMAKE_MACOSX_RPATH ON)

# On macOS everything is loaded by an executable in Contents/MacOS, so point
# the RPATH at the bundle's Frameworks directory rather than at the absolute
# build path - otherwise a bundle run from elsewhere (e.g. a mounted disk
# image) can load a second copy of the libraries from the build directory
if(APPLE)
    set(CMAKE_BUILD_WITH_INSTALL_RPATH ON)
    set(CMAKE_INSTALL_RPATH "@executable_path/../Frameworks")
endif()

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

# The library and plugins are always built
add_subdirectory(libnitroshare)
add_subdirectory(plugins)

if(BUILD_CLI)
    add_subdirectory(cli)
endif()

if(BUILD_CLIENT)
    add_subdirectory(client)
endif()

if(BUILD_NMH)
    add_subdirectory(nmh)
endif()

if(BUILD_UI)
    add_subdirectory(ui)
endif()

if(WIN32 AND BUILD_NITROSHELL)
    add_subdirectory(shell)
endif()

if(BUILD_MACOS_APP)
    add_subdirectory(macos)
    set(MACOS_BUNDLE_EXECUTABLE NitroShare)
else()
    set(MACOS_BUNDLE_EXECUTABLE nitroshare-ui)
endif()

add_subdirectory(dist)

if(APPLE)
    set(MACOS_CODESIGN_IDENTITY "-" CACHE STRING "Code signing identity (\"-\" for ad-hoc)")

    # Collect every plugin so that macdeployqt fixes their library references
    set(_plugins)
    get_property(_plugin_dirs DIRECTORY plugins PROPERTY SUBDIRECTORIES)
    foreach(_dir ${_plugin_dirs})
        get_property(_dir_targets DIRECTORY "${_dir}" PROPERTY BUILDSYSTEM_TARGETS)
        list(APPEND _plugins ${_dir_targets})
    endforeach()

    include(DeployQt)
    macdeployqt_bundle("${CONTENTS_DIRECTORY}/.." ${_plugins})
    if(BUILD_MACOS_APP)
        add_dependencies(deploy macos-app)
    endif()
endif()
