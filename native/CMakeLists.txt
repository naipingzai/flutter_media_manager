######################################################################
# 文件坐标: native/CMakeLists.txt
# 作用:     C++ 原生库的 CMake 构建配置
# 说明:     构建 SQLite3 静态库和 flutter_media_manager 动态共享库
######################################################################

# --------------------------------------------------------------------
# 第 1 行: 声明 CMake 最低版本要求
# 使用 3.10 确保支持现代 CMake 特性（如 target_* 命令）
cmake_minimum_required(VERSION 3.10)

# --------------------------------------------------------------------
# 第 2 行: 定义项目名称并启用 C 和 C++ 语言支持
# 项目名 flutter_media_manager 会用于生成共享库文件名
project(flutter_media_manager C CXX)

# --------------------------------------------------------------------
# 第 4 行: 设置 C++ 标准为 C++17
# 使用 C++17 支持现代特性（std::filesystem、结构化绑定等）
set(CMAKE_CXX_STANDARD 17)

# --------------------------------------------------------------------
# 第 5 行: 强制要求编译器支持 C++17
# 如果编译器不支持，构建过程会报错而不是回退到旧标准
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# --------------------------------------------------------------------
# 第 7 行: 注释说明 SQLite3 单文件合并方式
# 将 sqlite3.c 直接编译为静态库，方便链接到主共享库

# --------------------------------------------------------------------
# 第 8 行: 定义静态库目标 sqlite3
# 源文件: third_party/sqlite3.c (SQLite3 单文件合并)
add_library(sqlite3 STATIC third_party/sqlite3.c)

# --------------------------------------------------------------------
# 第 9 行: 公开 sqlite3 头文件搜索路径
# third_party 目录同时包含 sqlite3.h，让其他目标能 include
target_include_directories(sqlite3 PUBLIC third_party)

# --------------------------------------------------------------------
# 第 10 行: 定义私有编译宏
# SQLITE_THREADSAFE=1 启用 SQLite3 多线程安全模式
target_compile_definitions(sqlite3 PRIVATE SQLITE_THREADSAFE=1)

# --------------------------------------------------------------------
# 第 11 行: 设置 sqlite3 编译优化选项
# -O2 开启优化，-fPIC 生成位置无关代码（静态库需要用于共享库）
target_compile_options(sqlite3 PRIVATE -O2 -fPIC)

# --------------------------------------------------------------------
# 第 13 行: 注释说明主库源文件列表

# --------------------------------------------------------------------
# 第 14 行: 定义变量 SOURCES 存储主共享库的源文件
set(SOURCES
    # 第 15 行: 数据库核心实现
    src/db/database.cpp
    # 第 16 行: Dart FFI C ABI 导出层
    src/ffi_bridge.cpp
)

# --------------------------------------------------------------------
# 第 19 行: 注释说明该共享库供 Dart FFI 动态加载

# --------------------------------------------------------------------
# 第 20 行: 创建共享库目标 flutter_media_manager
# 生成 libflutter_media_manager.so (Linux/Android)
add_library(flutter_media_manager SHARED ${SOURCES})

# --------------------------------------------------------------------
# 第 21 行: 设置主库的私有头文件搜索路径
# - src 目录包含 database.h
# - third_party 目录包含 sqlite3.h
target_include_directories(flutter_media_manager PRIVATE src ${CMAKE_CURRENT_SOURCE_DIR}/third_party)

# --------------------------------------------------------------------
# 第 22 行: 将 sqlite3 静态库链接到主共享库
# PRIVATE 表示依赖不传递
target_link_libraries(flutter_media_manager PRIVATE sqlite3)

# --------------------------------------------------------------------
# 第 23 行: 设置主库的优化选项
# -O2 优化，-fPIC 确保位置无关代码
target_compile_options(flutter_media_manager PRIVATE -O2 -fPIC)

# --------------------------------------------------------------------
# 第 25 行: 条件判断：非 Apple 且非 Android 平台
# 桌面 Linux 需要显式链接 pthread、dl 和数学库 m
if(NOT APPLE AND NOT ANDROID)
    # 第 26 行: 链接 pthread 线程库、dl 动态加载库、m 数学库
    target_link_libraries(flutter_media_manager PRIVATE pthread dl m)
endif()

# --------------------------------------------------------------------
# 第 28 行: 条件判断：Android 平台
# Android NDK 已经内置 pthread，但需要显式链接 log 库
if(ANDROID)
    # 第 29 行: 链接 Android 日志库，用于原生层打印 logcat
    target_link_libraries(flutter_media_manager PRIVATE log)
endif()
