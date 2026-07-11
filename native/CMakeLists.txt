cmake_minimum_required(VERSION 3.10)
project(advance_media_kb C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# SQLite3 amalgamation
add_library(sqlite3 STATIC third_party/sqlite3.c)
target_include_directories(sqlite3 PUBLIC third_party)
target_compile_definitions(sqlite3 PRIVATE SQLITE_THREADSAFE=1)
target_compile_options(sqlite3 PRIVATE -O2 -fPIC)

# Source files
set(SOURCES
    src/db/database.cpp
    src/ffi_bridge.cpp
)

# Shared library for Dart FFI
add_library(advance_media_kb SHARED ${SOURCES})
target_include_directories(advance_media_kb PRIVATE src ${CMAKE_CURRENT_SOURCE_DIR}/third_party)
target_link_libraries(advance_media_kb PRIVATE sqlite3)
target_compile_options(advance_media_kb PRIVATE -O2 -fPIC)

if(NOT APPLE)
    target_link_libraries(advance_media_kb PRIVATE pthread dl m)
endif()
