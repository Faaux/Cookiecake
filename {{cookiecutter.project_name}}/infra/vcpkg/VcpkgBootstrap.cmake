function(_vcpkg_bootstrap)
  include(FetchContent)

  if(WIN32)
    set(VCPKG vcpkg.exe)
  elseif(LINUX)
    if(EXISTS "/etc/alpine-release")
      set(VCPKG vcpkg-musl)
    else()
      set(VCPKG vcpkg-glibc)
    endif()
  elseif(APPLE)
    set(VCPKG vcpkg-macos)
  else()
    message(FATAL_ERROR "Cannot bootstrap vcpkg: Unsupported platform")
  endif()

  FetchContent_Declare(vcpkg
    URL https://github.com/microsoft/vcpkg-tool/releases/latest/download/${VCPKG}
    SOURCE_DIR ${vcpkg_root}
    DOWNLOAD_NO_EXTRACT TRUE
  )

  FetchContent_MakeAvailable(vcpkg)
  set(VCPKG ${vcpkg_SOURCE_DIR}/${VCPKG})

  file(CHMOD ${VCPKG} PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE)
  set(ENV{VCPKG_ROOT} ${vcpkg_SOURCE_DIR})
  execute_process(COMMAND ${VCPKG} bootstrap-standalone)

  if(NOT WIN32)
    file(RENAME ${VCPKG} ${vcpkg_SOURCE_DIR}/vcpkg)
  endif()
endfunction()

macro(vcpkg_configure)  
    if(DEFINED CACHE{_VCPKG_ROOT})
        set(vcpkg_root $CACHE{_VCPKG_ROOT})
    else()
        set(vcpkg_root "${CMAKE_SOURCE_DIR}/.vcpkg")
    endif()

    if(NOT EXISTS ${vcpkg_root})
        message(STATUS "Setup vcpkg")
        _vcpkg_bootstrap(${vcpkg_root})
    else()
        message(STATUS "Found vcpkg in: ${vcpkg_root}")
        #_vcpkg_upgrade(${vcpkg_root} ${arg_REPO} ${arg_REF})
    endif()

    set(_VCPKG_ROOT
        "${vcpkg_root}"
        CACHE INTERNAL "vcpkg root")

    set(_VCPKG_TOOLCHAIN_FILE
        "${vcpkg_root}/scripts/buildsystems/vcpkg.cmake"
        CACHE INTERNAL "vcpkg toolchain file")

    message(STATUS "vcpkg_toolchain_file:$CACHE{_VCPKG_TOOLCHAIN_FILE}")
    include("$CACHE{_VCPKG_TOOLCHAIN_FILE}")

    unset(vcpkg_root)
    unset(_VCPKG_ROOT)
    unset(_VCPKG_TOOLCHAIN_FILE)
endmacro()

