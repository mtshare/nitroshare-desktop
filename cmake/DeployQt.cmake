# The MIT License (MIT)
#
# Copyright (c) 2018 Nathan Osman
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

find_package(Qt${QT_VERSION_MAJOR} REQUIRED COMPONENTS Core)

# Retrieve the absolute path to qmake and then use that path to find
# the windeployqt and macdeployqt binaries
get_target_property(_qmake_executable Qt${QT_VERSION_MAJOR}::qmake IMPORTED_LOCATION)
get_filename_component(_qt_bin_dir "${_qmake_executable}" DIRECTORY)

find_program(WINDEPLOYQT_EXECUTABLE windeployqt HINTS "${_qt_bin_dir}")
if(WIN32 AND NOT WINDEPLOYQT_EXECUTABLE)
    message(FATAL_ERROR "windeployqt not found")
endif()

find_program(MACDEPLOYQT_EXECUTABLE macdeployqt HINTS "${_qt_bin_dir}")
if(APPLE AND NOT MACDEPLOYQT_EXECUTABLE)
    message(FATAL_ERROR "macdeployqt not found")
endif()

# Add commands that copy the required Qt files to the same directory as the
# target after being built as well as including them in final installation
function(windeployqt target)

    # Run windeployqt immediately after build
    add_custom_command(TARGET ${target} POST_BUILD
        COMMAND "${CMAKE_COMMAND}" -E
            env PATH="${_qt_bin_dir}" "${WINDEPLOYQT_EXECUTABLE}"
                --verbose 0
                --no-compiler-runtime
                --no-angle
                --no-opengl-sw
                \"$<TARGET_FILE:${target}>\"
        COMMENT "Deploying Qt..."
    )

    # windeployqt doesn't work correctly with the system runtime libraries,
    # so we fall back to one of CMake's own modules for copying them over

    # Doing this with MSVC 2015 requires CMake 3.6+
    if((MSVC_VERSION VERSION_EQUAL 1900 OR MSVC_VERSION VERSION_GREATER 1900)
            AND CMAKE_VERSION VERSION_LESS "3.6")
        message(WARNING "Deploying with MSVC 2015+ requires CMake 3.6+")
    endif()

    set(CMAKE_INSTALL_UCRT_LIBRARIES TRUE)
    include(InstallRequiredSystemLibraries)
    foreach(lib ${CMAKE_INSTALL_SYSTEM_RUNTIME_LIBS})
        get_filename_component(filename "${lib}" NAME)
        add_custom_command(TARGET ${target} POST_BUILD
            COMMAND "${CMAKE_COMMAND}" -E
                copy_if_different "${lib}" \"$<TARGET_FILE_DIR:${target}>\"
            COMMENT "Copying ${filename}..."
        )
    endforeach()
endfunction()

# Record a target whose binary lives in the application bundle; the bundle is
# deployed once by macdeployqt_bundle() after every target has been built
# (running macdeployqt per-target lets parallel runs clobber each other)
function(macdeployqt target)
    set_property(GLOBAL APPEND PROPERTY NITROSHARE_DEPLOY_TARGETS ${target})
endfunction()

# Add a target that copies the required Qt files into the application bundle
# and then signs it (ad-hoc unless MACOS_CODESIGN_IDENTITY is set) - macOS
# only grants local network access to apps with a valid signature
function(macdeployqt_bundle bundle)
    get_property(_targets GLOBAL PROPERTY NITROSHARE_DEPLOY_TARGETS)

    # App extensions must be sandboxed, so re-sign the Share extension with
    # its entitlements and then re-seal the bundle around it
    set(_sign_extension)
    if(MACOS_SHARE_EXTENSION)
        set(_sign_extension
            COMMAND codesign --force --sign "${MACOS_CODESIGN_IDENTITY}"
                --entitlements "${MACOS_SHARE_EXTENSION_ENTITLEMENTS}"
                "${MACOS_SHARE_EXTENSION}"
            COMMAND codesign --force --sign "${MACOS_CODESIGN_IDENTITY}" "${bundle}"
        )
    endif()
    set(_args)
    foreach(_target ${_targets} ${ARGN})
        list(APPEND _args "-executable=$<TARGET_FILE:${_target}>")
    endforeach()

    # Without the Qt widgets UI only the core runs, which needs no GUI plugins
    # (letting macdeployqt pick them pulls in Qt Quick, QML, etc.); copy just
    # the TLS and network information plugins that QtNetwork loads
    set(_copy_plugins)
    if(NOT BUILD_UI AND QT_VERSION_MAJOR EQUAL 6)
        list(APPEND _args -no-plugins)
        set(_qt_plugin_dir "${QT6_INSTALL_PREFIX}/${QT6_INSTALL_PLUGINS}")
        foreach(_plugin
                tls/libqsecuretransportbackend.dylib
                tls/libqcertonlybackend.dylib
                networkinformation/libqapplenetworkinformation.dylib)
            get_filename_component(_plugin_type "${_plugin}" DIRECTORY)
            list(APPEND _copy_plugins
                COMMAND "${CMAKE_COMMAND}" -E make_directory "${bundle}/Contents/PlugIns/${_plugin_type}"
                COMMAND "${CMAKE_COMMAND}" -E copy "${_qt_plugin_dir}/${_plugin}" "${bundle}/Contents/PlugIns/${_plugin_type}"
            )
            list(APPEND _args "-executable=${bundle}/Contents/PlugIns/${_plugin}")
        endforeach()
    endif()

    add_custom_target(deploy ALL
        ${_copy_plugins}
        COMMAND "${MACDEPLOYQT_EXECUTABLE}" "${bundle}" -always-overwrite
            "-libpath=${CMAKE_LIBRARY_OUTPUT_DIRECTORY}" ${_args}
        # macdeployqt resolves the @rpath of plugins relative to PlugIns/ and
        # leaves stray copies of the libraries there
        COMMAND "${CMAKE_COMMAND}" -E rm -rf "${bundle}/Contents/PlugIns/Frameworks"
        COMMAND codesign --force --deep --sign "${MACOS_CODESIGN_IDENTITY}" "${bundle}"
        ${_sign_extension}
        DEPENDS ${_targets} ${ARGN}
        COMMENT "Deploying Qt and signing the application bundle..."
        VERBATIM
    )
endfunction()

mark_as_advanced(WINDEPLOYQT_EXECUTABLE MACDEPLOYQT_EXECUTABLE)
