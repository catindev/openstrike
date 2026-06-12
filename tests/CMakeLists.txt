add_executable(openstrike_config_vfs_tests
    test_config_vfs.cpp
)

target_link_libraries(openstrike_config_vfs_tests
    PRIVATE
        openstrike_engine
)

target_compile_features(openstrike_config_vfs_tests PRIVATE cxx_std_20)

add_test(
    NAME openstrike_config_vfs_tests
    COMMAND openstrike_config_vfs_tests
)

add_executable(openstrike_texture_package_tests
    test_texture_package.cpp
)

target_link_libraries(openstrike_texture_package_tests
    PRIVATE
        openstrike_engine
)

target_compile_features(openstrike_texture_package_tests PRIVATE cxx_std_20)

add_test(
    NAME openstrike_texture_package_tests
    COMMAND openstrike_texture_package_tests
)
