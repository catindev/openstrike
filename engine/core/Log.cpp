#include "core/Log.h"

#include <iostream>

namespace osk {
namespace {

const char* prefix(LogLevel level) {
    switch (level) {
        case LogLevel::Info:
            return "[info] ";
        case LogLevel::Warning:
            return "[warn] ";
        case LogLevel::Error:
            return "[error] ";
    }

    return "[log] ";
}

} // namespace

void Log::write(LogLevel level, std::string_view message) {
    std::ostream& stream = level == LogLevel::Error ? std::cerr : std::cout;
    stream << prefix(level) << message << '\n';
}

void Log::info(std::string_view message) {
    write(LogLevel::Info, message);
}

void Log::warning(std::string_view message) {
    write(LogLevel::Warning, message);
}

void Log::error(std::string_view message) {
    write(LogLevel::Error, message);
}

} // namespace osk
