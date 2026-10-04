add_library(VISROSVirtualDisplay STATIC src/RfbClient.cpp)
target_compile_features(VISROSVirtualDisplay PUBLIC cxx_std_23)
target_include_directories(VISROSVirtualDisplay PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/include")
