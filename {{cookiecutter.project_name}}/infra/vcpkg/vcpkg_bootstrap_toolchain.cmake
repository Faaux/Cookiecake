include_guard(GLOBAL)

cmake_minimum_required(VERSION 3.25)

get_property(IN_TRY_COMPILE GLOBAL PROPERTY IN_TRY_COMPILE)

if(IN_TRY_COMPILE)
  return()
endif()

unset(IN_TRY_COMPILE)

include(${CMAKE_CURRENT_LIST_DIR}/VcpkgBootstrap.cmake)

set(VCPKG_VERBOSE ON CACHE BOOL "Vcpkg VCPKG_VERBOSE")

vcpkg_configure()
