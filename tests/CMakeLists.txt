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

add_executable(openstrike_bsp_light_tests
    test_bsp_light.cpp
)

target_link_libraries(openstrike_bsp_light_tests
    PRIVATE
        openstrike_engine
)

target_compile_features(openstrike_bsp_light_tests PRIVATE cxx_std_20)

add_test(
    NAME openstrike_bsp_light_tests
    COMMAND openstrike_bsp_light_tests
)

add_executable(openstrike_bsp_collision_tests
    test_bsp_collision.cpp
)

target_link_libraries(openstrike_bsp_collision_tests
    PRIVATE
        openstrike_engine
)

target_compile_features(openstrike_bsp_collision_tests PRIVATE cxx_std_20)

add_test(
    NAME openstrike_bsp_collision_tests
    COMMAND openstrike_bsp_collision_tests
)

add_executable(openstrike_player_movement_tests
    test_player_movement.cpp
)

target_link_libraries(openstrike_player_movement_tests
    PRIVATE
        openstrike_engine
)

target_compile_features(openstrike_player_movement_tests PRIVATE cxx_std_20)

add_test(
    NAME openstrike_player_movement_tests
    COMMAND openstrike_player_movement_tests
)

add_executable(openstrike_model_metadata_tests
    test_model_metadata.cpp
)

target_link_libraries(openstrike_model_metadata_tests
    PRIVATE
        openstrike_engine
)

target_compile_features(openstrike_model_metadata_tests PRIVATE cxx_std_20)

add_test(
    NAME openstrike_model_metadata_tests
    COMMAND openstrike_model_metadata_tests
)

add_executable(openstrike_sprite_metadata_tests
    test_sprite_metadata.cpp
)

target_link_libraries(openstrike_sprite_metadata_tests
    PRIVATE
        openstrike_engine
)

target_compile_features(openstrike_sprite_metadata_tests PRIVATE cxx_std_20)

add_test(
    NAME openstrike_sprite_metadata_tests
    COMMAND openstrike_sprite_metadata_tests
)
