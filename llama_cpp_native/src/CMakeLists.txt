cmake_minimum_required(VERSION 3.22.1)

project(llama_cpp_dart_wrapper)

# Enable KleidiAI ARM-optimized kernels for faster inference on Snapdragon devices
# KleidiAI provides 2-3x speedup via dotprod/i8mm/SME microkernels
# The SDK auto-downloads via FetchContent during CMake configure
if(CMAKE_ANDROID_ARCH_ABI STREQUAL "arm64-v8a")
    set(GGML_CPU_KLEIDIAI ON CACHE BOOL "Enable KleidiAI ARM kernels" FORCE)
endif()

# Add llama.cpp (builds llama, ggml, and applies build flags)
add_subdirectory(llama.cpp)

# 3. Define your wrapper library (mtmd)
if (ANDROID)
    find_library(log-lib log)

    file(GLOB MTMD_MODEL_SOURCES
        "llama.cpp/tools/mtmd/models/*.cpp"
    )

    add_library(mtmd SHARED
        llama.cpp/tools/mtmd/mtmd.cpp
        llama.cpp/tools/mtmd/mtmd-audio.cpp
        llama.cpp/tools/mtmd/clip.cpp
        llama.cpp/tools/mtmd/mtmd-helper.cpp
        ${MTMD_MODEL_SOURCES}
    )

    # Include directories
    target_include_directories(mtmd PUBLIC
        "${CMAKE_CURRENT_SOURCE_DIR}/llama.cpp/include"
        "${CMAKE_CURRENT_SOURCE_DIR}/llama.cpp/ggml/include"
        "${CMAKE_CURRENT_SOURCE_DIR}/llama.cpp/common"
        "${CMAKE_CURRENT_SOURCE_DIR}/llama.cpp/tools/mtmd"
        "${CMAKE_CURRENT_SOURCE_DIR}"
    )

    # Link libraries
    target_link_libraries(mtmd 
        PUBLIC 
            llama 
            ggml
            ${log-lib}
    )

    find_package(Threads REQUIRED)
    target_link_libraries(mtmd PRIVATE Threads::Threads)
endif()