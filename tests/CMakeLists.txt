add_executable(OpenStrikeConfigVfsTests
    config_vfs_tests.cpp
)

target_link_libraries(OpenStrikeConfigVfsTests
    PRIVATE
        openstrike_engine
)

target_compile_features(OpenStrikeConfigVfsTests PRIVATE cxx_std_20)

add_test(
    NAME config_vfs
    COMMAND OpenStrikeConfigVfsTests
)
