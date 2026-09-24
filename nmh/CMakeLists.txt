set(SRC
    main.cpp
)

add_executable(nitroshare-nmh WIN32 ${SRC})

set_target_properties(nitroshare-nmh PROPERTIES
    CXX_STANDARD 17
)

target_link_libraries(nitroshare-nmh nitroshare Qt${QT_VERSION_MAJOR}::Core)

install(TARGETS nitroshare-nmh
    DESTINATION "${INSTALL_BIN_PATH}"
)

if(APPLE)
    include(DeployQt)
    macdeployqt(nitroshare-nmh)
endif()
