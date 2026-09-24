set(SRC
    qsimplehttpclient.cpp
    qsocketpair.cpp
)

add_library(common STATIC ${SRC})
set_target_properties(common PROPERTIES
    CXX_STANDARD 17
    CXX_STANDARD_REQUIRED ON
)
target_link_libraries(common Qt${QT_VERSION_MAJOR}::Network qhttpengine)
