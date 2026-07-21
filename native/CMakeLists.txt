cmake_minimum_required(VERSION 3.10)
project(flutter_media_manager_native C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(NATIVE_DIR ${CMAKE_CURRENT_SOURCE_DIR})

add_library(sqlite3 STATIC ${NATIVE_DIR}/third_party/sqlite3.c)
target_include_directories(sqlite3 PUBLIC ${NATIVE_DIR}/third_party)
target_compile_definitions(sqlite3 PRIVATE SQLITE_THREADSAFE=1)
target_compile_options(sqlite3 PRIVATE -O2 -fPIC)

set(SOURCES
    ${NATIVE_DIR}/src/db/database.cpp
    ${NATIVE_DIR}/src/ffi_bridge.cpp
)

add_library(flutter_media_manager_native SHARED ${SOURCES})
target_include_directories(flutter_media_manager_native PRIVATE ${NATIVE_DIR}/src ${NATIVE_DIR}/third_party)
target_link_libraries(flutter_media_manager_native PRIVATE sqlite3)
target_compile_options(flutter_media_manager_native PRIVATE -O2 -fPIC)

if(NOT APPLE AND NOT ANDROID)
    target_link_libraries(flutter_media_manager_native PRIVATE pthread dl m)
endif()

if(ANDROID)
    target_link_libraries(flutter_media_manager_native PRIVATE log)
endif()
