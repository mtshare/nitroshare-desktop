# Native macOS frontend (SwiftUI) and Finder Share extension. Both are built
# with the Swift toolchain and placed in the application bundle, next to the
# headless core (nitroshare-cli) that they drive through the local API.

set(swift_build_dir "${CMAKE_BINARY_DIR}/swift")
set(app_executable "${CONTENTS_DIRECTORY}/MacOS/NitroShare")

# Build for each architecture in CMAKE_OSX_ARCHITECTURES (or the host's) and
# merge the results with lipo, e.g. "arm64;x86_64" for a universal app
if(CMAKE_OSX_ARCHITECTURES)
    set(swift_archs ${CMAKE_OSX_ARCHITECTURES})
else()
    set(swift_archs ${CMAKE_SYSTEM_PROCESSOR})
endif()

# Share extension (Finder > Share > NitroShare)
set(appex "${CONTENTS_DIRECTORY}/PlugIns/ShareExtension.appex")
set(appex_executable "${appex}/Contents/MacOS/ShareExtension")
set(MACOS_SHARE_EXTENSION "${appex}" PARENT_SCOPE)
set(MACOS_SHARE_EXTENSION_ENTITLEMENTS "${CMAKE_CURRENT_SOURCE_DIR}/ShareExtension/ShareExtension.entitlements" PARENT_SCOPE)

configure_file(ShareExtension/Info.plist.in "${appex}/Contents/Info.plist")

# SwiftPM builds every architecture in one invocation; its output directory
# depends on the build system in use, so ask it with --show-bin-path
set(swift_build_args
    --configuration release
    --package-path "${CMAKE_CURRENT_SOURCE_DIR}"
    --scratch-path "${swift_build_dir}"
)
foreach(arch ${swift_archs})
    list(APPEND swift_build_args --arch ${arch})
endforeach()
string(REPLACE ";" " " swift_build_args_string "${swift_build_args}")

set(appex_build_commands)
set(appex_slices)
foreach(arch ${swift_archs})
    set(appex_slice "${swift_build_dir}/ShareExtension-${arch}")
    list(APPEND appex_build_commands
        COMMAND xcrun swiftc
            -O
            -swift-version 5
            -parse-as-library
            -application-extension
            -module-name ShareExtension
            -target "${arch}-apple-macos${CMAKE_OSX_DEPLOYMENT_TARGET}"
            -Xlinker -e -Xlinker _NSExtensionMain
            -o "${appex_slice}"
            "${CMAKE_CURRENT_SOURCE_DIR}/ShareExtension/ShareViewController.swift"
    )
    list(APPEND appex_slices "${appex_slice}")
endforeach()

file(GLOB app_sources CONFIGURE_DEPENDS Sources/NitroShare/*.swift)

add_custom_command(
    OUTPUT "${app_executable}"
    COMMAND swift build ${swift_build_args}
    COMMAND sh -c "cp \"$(swift build ${swift_build_args_string} --show-bin-path)/NitroShare\" \"$0\"" "${app_executable}"
    # swift build adds the RPATH of the toolchain on this Mac, which other
    # Macs don't have; the Swift libraries are all loaded from /usr/lib/swift
    COMMAND sh -c "otool -l \"$0\" | awk '/LC_RPATH/ { getline; getline; print $2 }' | grep -v '^/usr/lib/' | grep '^/' | sort -u | while read -r p; do install_name_tool -delete_rpath \"$p\" \"$0\"; done; true" "${app_executable}"
    DEPENDS ${app_sources} Package.swift
    COMMENT "Building the macOS app..."
    VERBATIM
)

add_custom_command(
    OUTPUT "${appex_executable}"
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${appex}/Contents/MacOS"
    ${appex_build_commands}
    COMMAND lipo -create ${appex_slices} -output "${appex_executable}"
    DEPENDS ShareExtension/ShareViewController.swift
    COMMENT "Building the Share extension..."
    VERBATIM
)

# Localizations, copied at build time so that edits to the strings are picked up
file(GLOB_RECURSE localization_files CONFIGURE_DEPENDS Resources/*.lproj/*)
set(localization_outputs)
foreach(file ${localization_files})
    file(RELATIVE_PATH relative "${CMAKE_CURRENT_SOURCE_DIR}/Resources" "${file}")
    set(output "${CONTENTS_DIRECTORY}/Resources/${relative}")
    add_custom_command(
        OUTPUT "${output}"
        COMMAND "${CMAKE_COMMAND}" -E copy "${file}" "${output}"
        DEPENDS "${file}"
        VERBATIM
    )
    list(APPEND localization_outputs "${output}")
endforeach()

add_custom_target(macos-app ALL
    DEPENDS "${app_executable}" "${appex_executable}" ${localization_outputs}
)
