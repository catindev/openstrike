find_package(Python3 COMPONENTS Interpreter)

if (Python3_Interpreter_FOUND)
    add_custom_target(asset_audit
        COMMAND ${Python3_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/asset_audit.py ${CMAKE_SOURCE_DIR}
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        COMMENT "Scanning repository for suspicious proprietary legacy resource files"
        VERBATIM
    )
endif()
