cmake_minimum_required(VERSION 3.20)
cmake_policy(SET CMP0091 NEW)  # honour CMAKE_MSVC_RUNTIME_LIBRARY
project(TTimeTSF LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
# The DLL C runtime (/MD), as the Rust static library uses. A text service is loaded
# into other programs and must not mix two runtimes.
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>DLL")

# Expected from the parent build script:
#   TTIME_FFI_LIB   — path to ttime_ffi.lib
#   TTIME_FFI_INCLUDE — path to ttime.h directory
#   TTIME_NATIVE_LIBS — extra system libs the Rust staticlib needs (ws2_32, …)
if(NOT TTIME_FFI_LIB)
  message(FATAL_ERROR "TTIME_FFI_LIB is required (path to ttime_ffi.lib)")
endif()
if(NOT TTIME_FFI_INCLUDE)
  message(FATAL_ERROR "TTIME_FFI_INCLUDE is required (directory containing ttime.h)")
endif()

add_library(TTimeTSF SHARED
  src/DllMain.cpp
  src/ClassFactory.cpp
  src/Register.cpp
  src/Globals.cpp
  src/Guids.cpp
  src/ComposerHost.cpp
  src/TextService.cpp
  src/EditSessions.cpp
  src/DisplayAttribute.cpp
  TTimeTSF.def
)

target_include_directories(TTimeTSF PRIVATE
  ${TTIME_FFI_INCLUDE}
  ${CMAKE_CURRENT_SOURCE_DIR}/src
)

target_compile_definitions(TTimeTSF PRIVATE UNICODE _UNICODE WIN32_LEAN_AND_MEAN NOMINMAX)
target_compile_options(TTimeTSF PRIVATE /utf-8 /W4 /EHsc)

# TTIME_NATIVE_LIBS is a space-separated list of .lib files from the build script
# (ws2_32.lib …). Linker flags such as /defaultlib: are left out there: CMake would
# take them for file names.
separate_arguments(_ttime_native_libs NATIVE_COMMAND "${TTIME_NATIVE_LIBS}")

target_link_libraries(TTimeTSF PRIVATE
  "${TTIME_FFI_LIB}"
  # No msctf.lib: TSF objects come from CoCreateInstance (ole32) and their GUIDs
  # (CLSID_TF_*, GUID_TFCAT_*) from uuid.lib.
  ole32
  oleaut32
  uuid
  user32
  advapi32
  ${_ttime_native_libs}
)

set_target_properties(TTimeTSF PROPERTIES
  OUTPUT_NAME "TTimeTSF"
  RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}"
  LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}"
  ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}"
)
