cmake_minimum_required(VERSION 3.23)

include_guard(GLOBAL)

set(BUILD_CAKE_DIR ${CMAKE_CURRENT_LIST_DIR})

#[[
Helper that lists all subdirs.

Args:
  result: Variable name where the result is stored
  curdir: Root Directory
]]
macro(_cake_subdir_list result curdir)
  file(
    GLOB children
    RELATIVE ${curdir}
    ${curdir}/*)
  set(dirlist "")
  foreach(child ${children})
    if(IS_DIRECTORY ${curdir}/${child})
      list(APPEND dirlist ${child})
    endif()
  endforeach()
  set(${result} ${dirlist})
endmacro()

#[[
Logs a string as as STATUS message verbose
]]
function(cake_verbose msg)
  message(VERBOSE "${msg}")
endfunction()

#[[
Logs a string as as STATUS message
]]
function(cake_log msg)
  message(STATUS "${msg}")
endfunction()

#[[
Logs a a string as an error and stops configuration
]]
function(cake_error msg)
  message("######################################################")
  message("${msg}")
  message("######################################################")
  message(FATAL_ERROR "Quitting configuration")
endfunction()

#[[
Helper Macro for argument parsing. Produces a variable 'cake_argn' with all commands parsed by
cmake_parse_arguments removed.

Assumes the following variables names passed to cmake_parse_arguments:
  - options
  - oneValueArgs
  - multiValueArgs
]]
macro(_cake_cleanup_args)
  set(cake_argn ${ARGN})
  list(REMOVE_ITEM cake_argn ${options})

  foreach(oneValue ${oneValueArgs})
    if(ARGS_${oneValue})

      list(FIND cake_argn ${oneValue} oneValueIndex)

      list(REMOVE_AT cake_argn ${oneValueIndex}) # The oneValueArg Name
      list(REMOVE_AT cake_argn ${oneValueIndex}) # The actual value
    endif()
  endforeach()

  foreach(multiValue ${multiValueArgs})
    if(ARGS_${multiValue})

      list(FIND cake_argn ${multiValue} multiValueIndex)

      list(REMOVE_AT cake_argn ${multiValueIndex})

      foreach(ignored ${ARGS_${multiValue}})
        list(REMOVE_AT cake_argn ${multiValueIndex})
      endforeach()
    endif()
  endforeach()
endmacro()

#[[
Implementation to add a folder. See 'cake_add_folder' for details

Options:
  RECURSIVE: Should it search recursively

One-Value-Args:
  FOLDER: Folder that should be added
  ROOT: Root path

]]
function(_cake_add_folder_impl)
  set(options RECURSIVE)
  set(oneValueArgs FOLDER ROOT)
  set(multiValueArgs)
  cmake_parse_arguments(ARGS "${options}" "${oneValueArgs}" "${multiValueArgs}"
                        ${ARGN})

  _cake_cleanup_args(${ARGN})

  if(NOT ARGS_FOLDER)
    cake_error("Missing 'FOLDER' argument")
  endif()

  if(NOT ARGS_ROOT)
    cake_error("Missing 'ROOT' argument")
  endif()

  cmake_path(APPEND ARGS_ROOT ${ARGS_FOLDER} OUTPUT_VARIABLE ARGS_FOLDER)

  set(FOLDER_TO_ADD)
  set(LIBS)
  set(FOLDER_TO_CHECK)

  # Find all folders that we need to add
  list(APPEND FOLDER_TO_CHECK "${ARGS_FOLDER}")
  while(FOLDER_TO_CHECK)
    list(POP_FRONT FOLDER_TO_CHECK CURRENT_FOLDER)
    if(EXISTS ${CURRENT_FOLDER}/CMakeLists.txt)
      list(APPEND FOLDER_TO_ADD "${CURRENT_FOLDER}")
      cmake_path(GET CURRENT_FOLDER FILENAME libname)
      set(libname "${_CAKE_NAME}.${libname}")
      if(${libname} IN_LIST LIBS)
        cake_error("Duplicate target found: ${libname}")
      endif()
      list(APPEND LIBS "${libname}")
      cake_verbose("Found ${libname}")
    elseif(ARGS_RECURSIVE)
      _cake_subdir_list(subdirs ${CURRENT_FOLDER})
      foreach(subdir ${subdirs})
        list(APPEND FOLDER_TO_CHECK "${CURRENT_FOLDER}/${subdir}")
      endforeach()
    endif()
  endwhile()

  # Build dependency list from folders to add
  set(UNKNOWN_DEPS)
  foreach(folder ${FOLDER_TO_ADD})
    cmake_path(GET folder FILENAME libname)

    set("DEPS_${libname}")

    # Find all dependency files
    file(
      GLOB_RECURSE DEPENDENCY_FILES CONFIGURE_DEPENDS
      LIST_DIRECTORIES false
      ${folder}/Dependencies.cmake)

    foreach(dep_file ${DEPENDENCY_FILES})
      file(STRINGS "${dep_file}" deps)
      foreach(line ${deps})
        set(whitespace "[ \t\r\n]*")
        string(
          REGEX
            MATCH
            "^${whitespace}cake_dep${whitespace}\\(${whitespace}([a-zA-Z0-9_-]+\\.[a-zA-Z0-9_-]+)"
            match
            "${line}")
        if(match)
          if(${CMAKE_MATCH_1} IN_LIST LIBS)
            list(APPEND "DEPS_${libname}" "${CMAKE_MATCH_1}")
            cake_verbose("Found cake_dep ${CMAKE_MATCH_1}")
          elseif(NOT ${CMAKE_MATCH_1} IN_LIST UNKNOWN_DEPS)
            list(APPEND UNKNOWN_DEPS "${CMAKE_MATCH_1}")
            cake_verbose("Found dep ${CMAKE_MATCH_1}")
          endif()
        endif()
      endforeach()
    endforeach()
  endforeach()

  # Now that we have all deps, start adding folders in the correct order
  while(FOLDER_TO_ADD)
    set(ADDED_TARGETS)

    # Find targets without any other dependencies
    foreach(candidate ${FOLDER_TO_ADD})
      cmake_path(GET candidate FILENAME candidate_libname)

      if(NOT DEPS_${candidate_libname})
        cake_log("Adding target: ${_CAKE_NAME}.${candidate_libname}")
        add_subdirectory(${candidate})
        list(REMOVE_ITEM FOLDER_TO_ADD ${candidate})
        list(APPEND ADDED_TARGETS "${_CAKE_NAME}.${candidate_libname}")
      endif()
    endforeach()

    # Remove added dependencies from dependency lists
    foreach(candidate ${FOLDER_TO_ADD})
      cmake_path(GET candidate FILENAME candidate_libname)
      foreach(added ${ADDED_TARGETS})
        list(REMOVE_ITEM DEPS_${candidate_libname} ${added})
      endforeach()
    endforeach()

    if(NOT ADDED_TARGETS)
      cake_log("Failed to add any new target. Dumping remaining info")
      foreach(folder ${FOLDER_TO_ADD})
        cmake_path(GET folder FILENAME libname)
        cake_log("Remaining non-resolved dependencies for ${folder}:")
        cake_log("    ${DEPS_${libname}}")
      endforeach()
      cake_log("Unknown targets, ignored: ${UNKNOWN_DEPS}")
      cake_error("Failed to figure out dependencies")
    endif()
  endwhile()
endfunction()

#[[
Implementation to add a folder. It searches for CMakeLists.txt files, if found in a folder the folder is added
according to the following conventions:

- CMakeLists.txt uses cake_add_executable or cake_add_library
- The name of the target MUST be equal to the folder name
- If a Dependencies.cmake is found it is
    a) include
    b) Passed to the install config files
- Resolved dependencies via Dependencies.cmake automatically (find_package must match target/folder name)
- If the found folder contains a 'test' folder it is also added
  - We assume that the test/ folder contains a CMakeLists.txt
  - We assume it uses cake_add_test_executable

Options:
  RECURSIVE: Should it search recursively

One-Value-Args:
  FOLDER: Folder that should be added
]]
function(cake_add_folder)
  if(NOT _CAKE_WAS_INIT)
    cake_error("Please call 'cake_init()' first")
  endif()

  set(options RECURSIVE)
  set(oneValueArgs FOLDER)
  set(multiValueArgs)
  cmake_parse_arguments(ARGS "${options}" "${oneValueArgs}" "${multiValueArgs}"
                        ${ARGN})

  if(NOT ARGS_FOLDER)
    cake_error("Missing 'FOLDER' argument")
  endif()

  if(ARGS_RECURSIVE)
    set(ARGS RECURSIVE)
  endif()

  _cake_add_folder_impl(FOLDER ${ARGS_FOLDER} ROOT ${CMAKE_CURRENT_LIST_DIR}
                        ${ARGS})

endfunction()

#[[
If not set, sets "CMAKE_CXX_STANDARD" to 23
Sets CMAKE_CXX_EXTENSIONS to OFF

For more information please see '_cake_init_impl'
]]
macro(cake_init name)
  if(_CAKE_WAS_INIT)
    return()
  endif()

  set(_CAKE_NAME ${name})
  string(TOUPPER ${_CAKE_NAME} _CAKE_NAME_UPPER)

  # For added projects later
  include(${BUILD_CAKE_DIR}/cake-install-library.cmake)
  include(${BUILD_CAKE_DIR}/CompilerWarnings.cmake)
  
  if(${_CAKE_NAME_UPPER}_USE_MODULES)
    set(CMAKE_CXX_SCAN_FOR_MODULES ON)
  endif()

  if(${_CAKE_NAME_UPPER}_USE_CACHE)
    include(${BUILD_CAKE_DIR}/Cache.cmake)
    _cake_enable_cache()
  endif() 

  if(${_CAKE_NAME_UPPER}_BUILD_TESTS)
    enable_testing()
  endif()
  
  include(${BUILD_CAKE_DIR}/BuildTelemetryConfig.cmake)
  configure_build_telemetry()  

  # Dependencies
  list(PREPEND CMAKE_PREFIX_PATH "${CMAKE_BINARY_DIR}")
  set(CMAKE_PREFIX_PATH "${CMAKE_PREFIX_PATH}")

  list(PREPEND CMAKE_MODULE_PATH "${CMAKE_BINARY_DIR}")
  set(CMAKE_MODULE_PATH "${CMAKE_PREFIX_PATH}")

  set(_CAKE_WAS_INIT True)
endmacro()

#[[
Helper called from the add_cake_XXX functions (except for tests).

- Adds tests from test/ folder if it exists
- Install the XXConfig.cmake file to the binary dir (for find_package calls in Dependencies.cmake)
  as well as for installation
- Parses Dependencies.cmake and replaces find_package with find_dependency for installation
- Configures the complete install target for the target
]]
macro(_cake_add_common_parts TARGET_NAME)
  file(
    GLOB_RECURSE PUBLIC_HEADERS CONFIGURE_DEPENDS
    LIST_DIRECTORIES false
    include/*.h include/*.hpp)
  _cake_assign_source_group(${PUBLIC_HEADERS})

  file(
    GLOB_RECURSE SOURCES CONFIGURE_DEPENDS
    LIST_DIRECTORIES false
    src/*.h src/*.hpp src/*.cpp)
  _cake_assign_source_group(${SOURCES})

  file(
    GLOB_RECURSE CXX_SOURCES CONFIGURE_DEPENDS
    LIST_DIRECTORIES false
    src/*.ixx src/*.cppm src/*.cxx)
  _cake_assign_source_group(${CXX_SOURCES})

  if(${_CAKE_NAME_UPPER}_USE_MODULES)
    target_sources(
        ${TARGET_NAME}
        PRIVATE
            ${SOURCES}
        PUBLIC
            FILE_SET CXX_MODULES 
                FILES ${CXX_SOURCES}
            FILE_SET HEADERS
                BASE_DIRS include
                FILES ${PUBLIC_HEADERS}
    )
    set_target_properties(${TARGET_NAME} PROPERTIES CXX_MODULE_STD ON)
  else()
    if(CXX_SOURCES)
      cake_log("Ignoring found module files")
    endif()

    target_sources(
        ${TARGET_NAME}
        PRIVATE
            ${SOURCES}
        PUBLIC
            FILE_SET HEADERS
                BASE_DIRS include
                FILES ${PUBLIC_HEADERS}
    )
  endif()

  if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/Dependencies.cmake")
    include(${CMAKE_CURRENT_SOURCE_DIR}/Dependencies.cmake)
  endif()

  _cake_set_project_warnings(${TARGET_NAME} False "" "" "" "")
endmacro()

#[[
Helper that recreates the folder structure in Visual Studio. Takes a list of files as an argument
]]
function(_cake_assign_source_group)
  foreach(_source IN ITEMS ${ARGN})
    if(IS_ABSOLUTE "${_source}")
      file(RELATIVE_PATH _source_rel "${CMAKE_CURRENT_SOURCE_DIR}" "${_source}")
    else()
      set(_source_rel "${_source}")
    endif()
    get_filename_component(_source_path "${_source_rel}" PATH)
    string(REPLACE "/" "\\" _source_path_msvc "${_source_path}")
    source_group("${_source_path_msvc}" FILES "${_source}")
  endforeach()
endfunction()

#[[
Adds an executable by convention.

Single Argument is interpreted as the targets name

- All .h and .hpp files in include/ and their subdirectories are considered public headers
- All .h, .hpp, .cpp files in src/ are added as private files
- All .ixx, .cppm, .cxx files in src/ are considered module files and also installed

Calls _cake_add_common_parts for additional setup
]]
function(cake_add_executable TARGET_NAME)
  if(NOT _CAKE_WAS_INIT)
    cake_error("Please call 'cake_init()' first")
  endif()

  set(options)
  set(oneValueArgs)
  set(multiValueArgs)
  cmake_parse_arguments(ARGS "${options}" "${oneValueArgs}" "${multiValueArgs}"
                        ${ARGN})

  _cake_cleanup_args(${ARGN})

  cake_log("Adding executable ${TARGET_NAME}")

  string(REPLACE "." ";" name_parts "${TARGET_NAME}")

  # fail if the name doesn't look like foo.bar
  list(LENGTH name_parts name_parts_length)
  if(NOT name_parts_length EQUAL 2)
      message(
          FATAL_ERROR
          "cake_install_library(${name}): expects a name of the form 'cake.<name>', got '${TARGET_NAME}'"
      )
  endif()

  add_executable(${TARGET_NAME} ${cake_argn})

  list(JOIN name_parts "::" TARGET_ALIAS)
  add_executable(${TARGET_ALIAS} ALIAS ${TARGET_NAME})

  _cake_add_common_parts(${TARGET_NAME})
  
endfunction()

#[[
Adds a library by convention.

Single Argument is interpreted as the targets name. An alias of form ${TARGET_NAME}.${TARGET_NAME}
is also added to allow find_package to work correctly.

- All .h and .hpp files in include/ and their subdirectories are considered public headers
- All .h, .hpp, .cpp files in src/ are added as private files
- All .ixx, .cppm, .cxx files in src/ are considered module files

Calls _cake_add_common_parts for additional setup.
Installs all header files properly.
]]
function(cake_add_library TARGET_NAME)
  if(NOT _CAKE_WAS_INIT)
    cake_error("Please call 'cake_init()' first")
  endif()

  set(options)
  set(oneValueArgs)
  set(multiValueArgs)
  cmake_parse_arguments(ARGS "${options}" "${oneValueArgs}" "${multiValueArgs}"
                        ${ARGN})

  _cake_cleanup_args(${ARGN})

  cake_log("Adding library ${TARGET_NAME}")

  string(REPLACE "." ";" name_parts "${TARGET_NAME}")

  # fail if the name doesn't look like foo.bar
  list(LENGTH name_parts name_parts_length)
  if(NOT name_parts_length EQUAL 2)
      message(
          FATAL_ERROR
          "cake_install_library(${name}): expects a name of the form 'cake.<name>', got '${TARGET_NAME}'"
      )
  endif()

  add_library(${TARGET_NAME} ${cake_argn})

  list(JOIN name_parts "::" TARGET_ALIAS)
  add_library(${TARGET_ALIAS} ALIAS ${TARGET_NAME})

  _cake_add_common_parts(${TARGET_NAME})

  if(${_CAKE_NAME_UPPER}_BUILD_TESTS)
    if(EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/test)
      add_subdirectory(test)
    else()
      cake_log("${TARGET_NAME} has no tests")
    endif()
  endif()
endfunction()

#[[
Adds a test executable. Assumes to be called in a CMakeLists.txt in a test/ subfolder of a normal target.

Single Argument is interpreted as the targets name.

- All .h and .hpp files in include/ and their subdirectories are considered public headers
- All .h, .hpp, .cpp files in src/ are added as private files
- All .ixx, .cppm, .cxx files in src/ are considered module files

- Automatically links against the parent folder if it is a library (convention -> folder name == target name)
- Automatically links against GTest
- Automatically adds all tests to CTest
]]
function(cake_add_test_executable TARGET_NAME)
  if(NOT _CAKE_WAS_INIT)
    cake_error("Please call 'cake_init()' first")
  endif()

  set(options)
  set(oneValueArgs)
  set(multiValueArgs)
  cmake_parse_arguments(ARGS "${options}" "${oneValueArgs}" "${multiValueArgs}"
                        ${ARGN})

  _cake_cleanup_args(${ARGN})

  add_executable(${TARGET_NAME} ${cake_argn})

  _cake_add_common_parts(${TARGET_NAME})

  # Auto add GTest
  find_package(GTest CONFIG REQUIRED)
  target_link_libraries(${TARGET_NAME} PRIVATE GTest::gtest GTest::gmock)

  # Auto find tests
  include(GoogleTest)
  gtest_discover_tests(${TARGET_NAME} DISCOVERY_MODE PRE_TEST)

  # Link against parent if parent is lib
  cmake_path(GET CMAKE_CURRENT_SOURCE_DIR PARENT_PATH TARGET_PATH)
  cmake_path(GET TARGET_PATH FILENAME LIB_NAME)

  set(LIB_NAME "${_CAKE_NAME}.${LIB_NAME}")
  get_target_property(type ${LIB_NAME} TYPE)
  if(${type} MATCHES ".*_LIBRARY")
    target_link_libraries(${TARGET_NAME} PRIVATE ${LIB_NAME})
  else()
    cake_error("Executables cannot have tests")
  endif()
endfunction()

function(cake_add_file_copy)
  set(options)
  set(oneValueArgs TARGET SRC DEST)
  set(multiValueArgs)
  cmake_parse_arguments(ARGS "${options}" "${oneValueArgs}" "${multiValueArgs}"
                        ${ARGN})

  add_custom_command(
    OUTPUT ${ARGS_DEST}
    COMMAND ${CMAKE_COMMAND} -E copy_if_different "${ARGS_SRC}" "${ARGS_DEST}"
    DEPENDS ${ARGS_SRC}
    COMMENT "Copying '${ARGS_SRC}' to '${ARGS_DEST}'")

  string(RANDOM UNIQUE_STR)
  set(COPY_TARGET_NAME "${ARGS_TARGET}_COPY_${UNIQUE_STR}")
  add_custom_target(${COPY_TARGET_NAME} ALL DEPENDS ${ARGS_DEST})
  add_dependencies(${ARGS_TARGET} ${COPY_TARGET_NAME})
endfunction()


macro(cake_dep)

endmacro()