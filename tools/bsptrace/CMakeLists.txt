add_executable(OpenStrikeBspTrace
    main.cpp
)

target_link_libraries(OpenStrikeBspTrace
    PRIVATE
        openstrike_engine
)

target_compile_features(OpenStrikeBspTrace PRIVATE cxx_std_20)
