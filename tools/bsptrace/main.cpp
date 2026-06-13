#include "assets/loaders/BspCollision.h"

#include <cstdlib>
#include <exception>
#include <filesystem>
#include <iostream>
#include <string>

namespace fs = std::filesystem;

namespace {

void printUsage(std::ostream& out) {
    out << "OpenStrikeBspTrace\n"
        << "\n"
        << "Usage:\n"
        << "  OpenStrikeBspTrace <path/to/map.bsp> --start x y z --end x y z [--model n] [--hull n]\n"
        << "\n"
        << "This read-only tool traces a point through BSP collision clipnodes.\n"
        << "It does not modify, extract, cache, or copy user-provided assets.\n";
}

bool parseFloat(const std::string& value, float& out) {
    char* end = nullptr;
    out = std::strtof(value.c_str(), &end);
    return end != value.c_str() && end != nullptr && *end == '\0';
}

bool parseSize(const std::string& value, std::size_t& out) {
    char* end = nullptr;
    const unsigned long parsed = std::strtoul(value.c_str(), &end, 10);
    if (end == value.c_str() || end == nullptr || *end != '\0') {
        return false;
    }
    out = static_cast<std::size_t>(parsed);
    return true;
}

bool parseVec3(int argc, char** argv, int& index, osk::bsp::Vec3& out) {
    if (index + 3 >= argc) {
        return false;
    }
    return parseFloat(argv[++index], out.x)
        && parseFloat(argv[++index], out.y)
        && parseFloat(argv[++index], out.z);
}

struct Args {
    fs::path path;
    osk::bsp::BspTraceInput trace;
    bool hasStart = false;
    bool hasEnd = false;
};

bool parseArgs(int argc, char** argv, Args& args) {
    if (argc == 2) {
        const std::string arg = argv[1];
        if (arg == "--help" || arg == "-h") {
            printUsage(std::cout);
            return false;
        }
    }

    for (int i = 1; i < argc; ++i) {
        const std::string arg = argv[i];
        if (arg == "--start") {
            if (!parseVec3(argc, argv, i, args.trace.start)) {
                std::cerr << "OpenStrikeBspTrace error: --start requires three numeric values\n";
                return false;
            }
            args.hasStart = true;
            continue;
        }
        if (arg == "--end") {
            if (!parseVec3(argc, argv, i, args.trace.end)) {
                std::cerr << "OpenStrikeBspTrace error: --end requires three numeric values\n";
                return false;
            }
            args.hasEnd = true;
            continue;
        }
        if (arg == "--model") {
            if (i + 1 >= argc || !parseSize(argv[++i], args.trace.modelIndex)) {
                std::cerr << "OpenStrikeBspTrace error: --model requires an integer\n";
                return false;
            }
            continue;
        }
        if (arg == "--hull") {
            if (i + 1 >= argc || !parseSize(argv[++i], args.trace.hullIndex)) {
                std::cerr << "OpenStrikeBspTrace error: --hull requires an integer\n";
                return false;
            }
            continue;
        }
        if (!args.path.empty()) {
            std::cerr << "OpenStrikeBspTrace error: unexpected argument: " << arg << '\n';
            return false;
        }
        args.path = arg;
    }

    if (args.path.empty() || !args.hasStart || !args.hasEnd) {
        printUsage(std::cerr);
        return false;
    }

    return true;
}

void printVec3(const char* label, osk::bsp::Vec3 value) {
    std::cout << label << value.x << ", " << value.y << ", " << value.z << '\n';
}

} // namespace

int main(int argc, char** argv) {
    Args args;
    if (!parseArgs(argc, argv, args)) {
        return argc == 2 && (std::string(argv[1]) == "--help" || std::string(argv[1]) == "-h") ? 0 : 1;
    }

    try {
        const osk::bsp::BspCollisionData collision = osk::bsp::loadBspCollisionData(args.path);
        const osk::bsp::BspTraceResult result = osk::bsp::tracePoint(collision, args.trace);

        std::cout << "BSP trace: " << args.path.string() << '\n';
        printVec3("  start:       ", args.trace.start);
        printVec3("  end:         ", args.trace.end);
        std::cout << "  model:       " << args.trace.modelIndex << '\n';
        std::cout << "  hull:        " << args.trace.hullIndex << '\n';
        std::cout << "  valid:       " << (result.valid ? "yes" : "no") << '\n';
        std::cout << "  hit:         " << (result.hit ? "yes" : "no") << '\n';
        std::cout << "  fraction:    " << result.fraction << '\n';
        printVec3("  position:    ", result.endPosition);
        std::cout << "  plane index: " << result.planeIndex << '\n';
        printVec3("  normal:      ", result.hitNormal);
        std::cout << "  startSolid:  " << (result.startSolid ? "yes" : "no") << '\n';
        std::cout << "  allSolid:    " << (result.allSolid ? "yes" : "no") << '\n';
        std::cout << "  contents:    " << result.contents << '\n';

        if (!result.warnings.empty()) {
            std::cout << "\nWarnings:\n";
            for (const std::string& warning : result.warnings) {
                std::cout << "  - " << warning << '\n';
            }
        }

        return result.valid && result.warnings.empty() ? 0 : 2;
    } catch (const std::exception& e) {
        std::cerr << "OpenStrikeBspTrace error: " << e.what() << '\n';
        return 1;
    }
}
