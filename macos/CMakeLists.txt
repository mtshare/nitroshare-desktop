# Native macOS frontend (SwiftUI) and Finder Share extension. Both are built
# with the Swift toolchain and placed in the application bundle, next to the
# headless core (nitroshare-cli) that they drive through the local API.

set(swift_build_dir "${CMAKE_BINARY_DIR}/swift")
set(swift_target "${CMAKE_SYSTEM_PROCESSOR}-apple-macos${CMAKE_OSX_DEPLOYMENT_TARGET}")
set(app_executable "${CONTENTS_DIRECTORY}/MacOS/NitroShare")

file(GLOB app_sources CONFIGURE_DEPENDS Sources/NitroShare/*.swift)

add_custom_command(
    OUTPUT "${app_executable}"
    COMMAND swift build
        --configuration release
        --package-path "${CMAKE_CURRENT_SOURCE_DIR}"
        --scratch-path "${swift_build_dir}"
    COMMAND "${CMAKE_COMMAND}" -E copy
        "${swift_build_dir}/release/NitroShare" "${app_executable}"
    DEPENDS ${app_sources} Package.swift
    COMMENT "Building the macOS app..."
    VERBATIM
)

# Share extension (Finder > Share > NitroShare)
set(appex "${CONTENTS_DIRECTORY}/PlugIns/ShareExtension.appex")
set(MACOS_SHARE_EXTENSION "${appex}" PARENT_SCOPE)
set(MACOS_SHARE_EXTENSION_ENTITLEMENTS "${CMAKE_CURRENT_SOURCE_DIR}/ShareExtension/ShareExtension.entitlements" PARENT_SCOPE)

configure_file(ShareExtension/Info.plist.in "${appex}/Contents/Info.plist")

add_custom_command(
    OUTPUT "${appex}/Contents/MacOS/ShareExtension"
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${appex}/Contents/MacOS"
    COMMAND xcrun swiftc
        -O
        -swift-version 5
        -parse-as-library
        -application-extension
        -module-name ShareExtension
        -target "${swift_target}"
        -Xlinker -e -Xlinker _NSExtensionMain
        -o "${appex}/Contents/MacOS/ShareExtension"
        "${CMAKE_CURRENT_SOURCE_DIR}/ShareExtension/ShareViewController.swift"
    DEPENDS ShareExtension/ShareViewController.swift
    COMMENT "Building the Share extension..."
    VERBATIM
)

# Localizations
file(GLOB lprojs LIST_DIRECTORIES true Resources/*.lproj)
foreach(lproj ${lprojs})
    file(COPY "${lproj}" DESTINATION "${CONTENTS_DIRECTORY}/Resources")
endforeach()

add_custom_target(macos-app ALL
    DEPENDS "${app_executable}" "${appex}/Contents/MacOS/ShareExtension"
)
