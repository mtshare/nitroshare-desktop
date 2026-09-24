configure_file(bridge.json.in "${CMAKE_CURRENT_BINARY_DIR}/bridge.json")

set(SRC
    bridgeplugin.h
    bridgeplugin.cpp
    functionaction.h
    functionaction.cpp
)

add_library(bridge MODULE ${SRC})

set_target_properties(bridge PROPERTIES
    CXX_STANDARD             17
    VERSION                  ${VERSION}
    SOVERSION                ${VERSION_MAJOR}
    RUNTIME_OUTPUT_DIRECTORY "${PLUGIN_OUTPUT_DIRECTORY}"
    LIBRARY_OUTPUT_DIRECTORY "${PLUGIN_OUTPUT_DIRECTORY}"
)

target_include_directories(bridge PUBLIC "${CMAKE_CURRENT_BINARY_DIR}")

target_link_libraries(bridge nitroshare Qt${QT_VERSION_MAJOR}::Core)

install(TARGETS bridge
    DESTINATION "${INSTALL_PLUGIN_PATH}"
)
