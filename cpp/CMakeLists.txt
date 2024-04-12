cmake_minimum_required(VERSION 3.20)
project(multi VERSION 0.1.0 LANGUAGES C CXX)

find_package(TBB REQUIRED)
add_executable(multi multi.cpp)
target_compile_options(multi PRIVATE -pthread)
target_link_libraries(multi TBB::tbb)

