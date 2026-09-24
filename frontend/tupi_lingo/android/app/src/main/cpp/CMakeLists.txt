cmake_minimum_required(VERSION 3.10.2)
project(tupi_security VERSION 1.0.0 LANGUAGES CXX)

add_library(tupi_security SHARED
    tupi_security.cpp
)

target_include_directories(tupi_security PRIVATE .)
