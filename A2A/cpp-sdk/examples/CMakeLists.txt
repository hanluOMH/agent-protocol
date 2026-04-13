
include_directories(${CMAKE_SOURCE_DIR}/include)

add_executable(helloworld_client helloworld_client.cpp)
set_property(TARGET helloworld_client PROPERTY C_STANDARD 11)
target_link_libraries(helloworld_client PRIVATE a2a_cpp)

add_executable(streaming_client streaming_client.cpp)
set_property(TARGET streaming_client PROPERTY C_STANDARD 11)
target_link_libraries(streaming_client PRIVATE a2a_cpp)

add_executable(helloworld_server helloworld_server.cpp)
set_property(TARGET helloworld_server PROPERTY C_STANDARD 11)
target_link_libraries(helloworld_server PRIVATE a2a_cpp)

add_executable(streaming_server streaming_server.cpp)
set_property(TARGET streaming_server PROPERTY C_STANDARD 11)
target_link_libraries(streaming_server PRIVATE a2a_cpp)

if(APPLE)
    set(A2A_OUTPUT_LIB_RPATH "@executable_path/../lib")
    set_target_properties(
        helloworld_client
        streaming_client
        helloworld_server
        streaming_server
        PROPERTIES
        BUILD_RPATH "${A2A_OUTPUT_LIB_RPATH}"
        INSTALL_RPATH "${A2A_OUTPUT_LIB_RPATH}"
    )
endif()
