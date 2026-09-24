set(SRC
    main.cpp
)

add_executable(nitroshare-cli ${SRC})

set_target_properties(nitroshare-cli PROPERTIES
    CXX_STANDARD 17
)

target_include_directories(nitroshare-cli PUBLIC
    "${CMAKE_CURRENT_BINARY_DIR}"
)

target_link_libraries(nitroshare-cli nitroshare Qt${QT_VERSION_MAJOR}::Core)

install(TARGETS nitroshare-cli
    DESTINATION "${INSTALL_BIN_PATH}"
)

if(APPLE)
    include(DeployQt)
    macdeployqt(nitroshare-cli)
endif()
