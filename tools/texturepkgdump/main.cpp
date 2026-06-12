#include "assets/loaders/TexturePackage.h"

#include <exception>
#include <filesystem>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <string>

namespace fs = std::filesystem;

namespace {

void printUsage(std::ostream& out) {
    out << "OpenStrikeTexturePkgDump\n"
        << "\n"
        << "Usage:\n"
        << "  OpenStrikeTexturePkgDump <path/to/texture-package.wad>\n"
        << "\n"
        << "This read-only tool prints legacy texture package header and directory metadata.\n"
        << "It does not decode pixels, extract textures, write assets, or cache user data.\n";
}

std::string hexByte(std::uint8_t value) {
    std::ostringstream out;
    out << "0x" << std::hex << std::uppercase << std::setw(2) << std::setfill('0')
        << static_cast<unsigned int>(value);
    return out.str();
}

std::string mipOffsets(const osk::texture::TexturePackageEntry& entry) {
    if (!entry.mipMetadataAvailable) {
        return "-";
    }

    std::ostringstream out;
    for (std::size_t i = 0; i < entry.mipOffsets.size(); ++i) {
        if (i > 0) {
            out << ',';
        }
        out << entry.mipOffsets[i];
    }
    return out.str();
}

void printSummary(const fs::path& path, const osk::texture::TexturePackageSummary& summary) {
    std::cout << "Texture package: " << path.string() << '\n';
    std::cout << "Kind:            " << osk::texture::texturePackageKindName(summary.kind) << '\n';
    std::cout << "Size:            " << summary.fileSize << " bytes\n";
    std::cout << "Directory:       " << summary.directoryOffset << '\n';
    std::cout << "Entries:         " << summary.entries.size()
        << " parsed / " << summary.declaredEntryCount << " declared\n";

    std::cout << "\nEntries:\n";
    std::cout << "  " << std::left
        << std::setw(18) << "Name"
        << std::setw(8) << "Type"
        << std::right
        << std::setw(12) << "Offset"
        << std::setw(12) << "DiskSize"
        << std::setw(12) << "Size"
        << "  " << std::left
        << std::setw(18) << "Texture"
        << std::right
        << std::setw(8) << "Width"
        << std::setw(8) << "Height"
        << "  MipOffsets\n";

    for (const osk::texture::TexturePackageEntry& entry : summary.entries) {
        const std::string textureName = entry.mipMetadataAvailable ? entry.textureName : "-";
        const std::string offsetText = mipOffsets(entry);

        std::cout << "  " << std::left
            << std::setw(18) << entry.name
            << std::setw(8) << hexByte(entry.type)
            << std::right
            << std::setw(12) << entry.dataOffset
            << std::setw(12) << entry.diskSize
            << std::setw(12) << entry.uncompressedSize
            << "  " << std::left
            << std::setw(18) << textureName
            << std::right
            << std::setw(8) << (entry.mipMetadataAvailable ? entry.width : 0)
            << std::setw(8) << (entry.mipMetadataAvailable ? entry.height : 0)
            << "  " << offsetText << '\n';
    }

    if (!summary.warnings.empty()) {
        std::cout << "\nWarnings:\n";
        for (const std::string& warning : summary.warnings) {
            std::cout << "  - " << warning << '\n';
        }
    }
}

} // namespace

int main(int argc, char** argv) {
    if (argc == 2) {
        const std::string arg = argv[1];
        if (arg == "--help" || arg == "-h") {
            printUsage(std::cout);
            return 0;
        }
    }

    if (argc != 2) {
        printUsage(std::cerr);
        return 1;
    }

    try {
        const fs::path path = argv[1];
        const osk::texture::TexturePackageSummary summary = osk::texture::loadTexturePackageSummary(path);
        printSummary(path, summary);
        return summary.warnings.empty() ? 0 : 2;
    } catch (const std::exception& e) {
        std::cerr << "OpenStrikeTexturePkgDump error: " << e.what() << '\n';
        return 1;
    }
}
