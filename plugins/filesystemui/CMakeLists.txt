configure_file(filesystemui.json.in "${CMAKE_CURRENT_BINARY_DIR}/filesystemui.json")

set(SRC
    acceptfilesdialog.h
    acceptfilesdialog.cpp
    filesystemuiplugin.h
    filesystemuiplugin.cpp
    senddirectoryuiaction.h
    senddirectoryuiaction.cpp
    sendfilesuiaction.h
    sendfilesuiaction.cpp
    senditemsuiaction.h
    senditemsuiaction.cpp
)

add_library(filesystemui MODULE ${SRC})

set_target_properties(filesystemui PROPERTIES
    CXX_STANDARD             17
    VERSION                  ${VERSION}
    SOVERSION                ${VERSION_MAJOR}
    RUNTIME_OUTPUT_DIRECTORY "${PLUGIN_OUTPUT_DIRECTORY}"
    LIBRARY_OUTPUT_DIRECTORY "${PLUGIN_OUTPUT_DIRECTORY}"
)

target_include_directories(filesystemui PUBLIC "${CMAKE_CURRENT_BINARY_DIR}")
target_link_libraries(filesystemui Qt${QT_VERSION_MAJOR}::Widgets nitroshare)

install(TARGETS filesystemui
    DESTINATION "${INSTALL_PLUGIN_PATH}"
)
