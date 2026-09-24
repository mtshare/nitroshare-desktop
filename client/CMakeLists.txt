set(SRC
    main.cpp
)

add_executable(nitroshare-client ${SRC})

set_target_properties(nitroshare-client PROPERTIES
    CXX_STANDARD 17
    OUTPUT_NAME  nitroshare
)

# macOS file systems are case-insensitive, so "nitroshare" would collide with
# the "NitroShare" app executable in the bundle
if(APPLE)
    set_target_properties(nitroshare-client PROPERTIES OUTPUT_NAME nitroshare-client)
endif()

target_link_libraries(nitroshare-client nitroshare Qt${QT_VERSION_MAJOR}::Core)

install(TARGETS nitroshare-client
    DESTINATION "${INSTALL_BIN_PATH}"
)

if(APPLE)
    include(DeployQt)
    macdeployqt(nitroshare-client)
endif()
