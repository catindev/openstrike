add_executable(OpenStrikePlayerMove
    main.cpp
)

target_link_libraries(OpenStrikePlayerMove
    PRIVATE
        openstrike_engine
)

target_compile_features(OpenStrikePlayerMove PRIVATE cxx_std_20)
