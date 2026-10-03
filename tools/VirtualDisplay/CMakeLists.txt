add_library(AROSVirtualDisplay STATIC src/RfbClient.cpp)
target_compile_features(AROSVirtualDisplay PUBLIC cxx_std_23)
target_include_directories(AROSVirtualDisplay PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/include")
