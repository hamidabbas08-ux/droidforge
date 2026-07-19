cmake_minimum_required(VERSION 3.22.1)
project(droidforge_runtime LANGUAGES C CXX)

add_library(
    droidforge_runtime
    SHARED
    droidforge_runtime.cpp
)

find_library(log-lib log)

target_compile_features(droidforge_runtime PRIVATE cxx_std_17)
target_compile_options(droidforge_runtime PRIVATE -Wall -Wextra -Werror)
target_link_libraries(droidforge_runtime ${log-lib})
