

add_library(woland SHARED IMPORTED GLOBAL)
#set_property(TARGET woland PROPERTY IMPORTED_NO_SONAME 1)
#set_target_properties(woland PROPERTIES IMPORTED_LOCATION ${CMAKE_CURRENT_SOURCE_DIR}/../../${ANDROID_ABI}/libwoland.so)
set_target_properties(woland PROPERTIES IMPORTED_LOCATION ${CMAKE_CURRENT_SOURCE_DIR}/src/main/jniLibs/${ANDROID_ABI}/libwoland.so)
#include_directories(${CMAKE_CURRENT_SOURCE_DIR}../../lib/mobile/jniLibs/${CMAKE_ANDROID_ARCH_ABI}/)
 