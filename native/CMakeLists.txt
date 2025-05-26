cmake_minimum_required(VERSION 3.10)
project(calc_project)

add_library(calc SHARED calc.cpp)

set_target_properties(calc PROPERTIES
    PUBLIC_HEADER "calc.h"
)

# iOS: .frameworkでビルド
if(APPLE)
    set_target_properties(calc PROPERTIES
        FRAMEWORK TRUE
        PUBLIC_HEADER "calc.h"
        MACOSX_FRAMEWORK_IDENTIFIER com.example.calc
    )
endif()

# Android: .soビルド時のlogライブラリリンク
if(ANDROID)
    find_library(log-lib log)
    target_link_libraries(calc ${log-lib})
endif()
