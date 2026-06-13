#include "assets/loaders/SpriteMetadata.h"

#include <exception>
#include <filesystem>
#include <iomanip>
#include <iostream>
#include <string>

namespace fs = std::filesystem;

namespace {

void printUsage(std::ostream& out) {
    out << "OpenStrikeSpriteDump\n"
        << "\n"
        << "Usage:\n"
        << "  OpenStrikeSpriteDump <path/to/sprite.spr>\n"
        << "\n"
        << "This read-only tool prints legacy sprite header, palette, and frame metadata.\n"
        << "It does not decode pixels, extract frames, write assets, or cache user data.\n";
}

void printSummary(const fs::path& path, const osk::sprite::SpriteMetadataSummary& summary) {
    const osk::sprite::SpriteHeaderInfo& header = summary.header;
    const osk::sprite::SpritePaletteInfo& palette = summary.palette;

    std::cout << "Sprite:          " << path.string() << '\n';
    std::cout << "Magic:           " << header.magic << '\n';
    std::cout << "Version:         " << header.version << '\n';
    std::cout << "Size:            " << header.fileSize << " bytes\n";
    std::cout << "Type:            " << header.type << " (" << osk::sprite::spriteTypeName(header.type) << ")\n";
    std::cout << "Texture format:  " << header.textureFormat << " ("
        << osk::sprite::spriteTextureFormatName(header.textureFormat) << ")\n";
    std::cout << "Max dimensions:  " << header.maxWidth << " x " << header.maxHeight << '\n';
    std::cout << "Frames:          " << header.frameCount << " logical / " << summary.frames.size() << " physical\n";
    std::cout << "Groups:          " << summary.groups.size() << '\n';
    std::cout << "Bounding radius: " << header.boundingRadius << '\n';
    std::cout << "Beam length:     " << header.beamLength << '\n';
    std::cout << "Sync type:       " << header.syncType << " (" << osk::sprite::spriteSyncTypeName(header.syncType) << ")\n";
    std::cout << "Palette:         " << palette.colorCount << " colors at " << palette.dataOffset
        << " (" << palette.dataSize << " bytes)\n";

    if (!summary.groups.empty()) {
        std::cout << "\nGroups:\n";
        std::cout << "  " << std::right
            << std::setw(8) << "Frame"
            << std::setw(12) << "Subframes" << '\n';
        for (const osk::sprite::SpriteGroupInfo& group : summary.groups) {
            std::cout << "  " << std::right
                << std::setw(8) << group.frameIndex
                << std::setw(12) << group.subframeCount << '\n';
        }
    }

    std::cout << "\nFrames:\n";
    std::cout << "  " << std::right
        << std::setw(8) << "Frame"
        << std::setw(8) << "Sub"
        << std::setw(9) << "Grouped"
        << std::setw(10) << "Interval"
        << std::setw(10) << "OriginX"
        << std::setw(10) << "OriginY"
        << std::setw(8) << "Width"
        << std::setw(8) << "Height"
        << std::setw(12) << "PixelsAt"
        << std::setw(12) << "PixelBytes" << '\n';
    for (const osk::sprite::SpriteFrameInfo& frame : summary.frames) {
        std::cout << "  " << std::right
            << std::setw(8) << frame.frameIndex
            << std::setw(8) << frame.subframeIndex
            << std::setw(9) << (frame.grouped ? "yes" : "no")
            << std::setw(10) << frame.interval
            << std::setw(10) << frame.originX
            << std::setw(10) << frame.originY
            << std::setw(8) << frame.width
            << std::setw(8) << frame.height
            << std::setw(12) << frame.pixelDataOffset
            << std::setw(12) << frame.pixelDataSize << '\n';
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
        const osk::sprite::SpriteMetadataSummary summary = osk::sprite::loadSpriteMetadata(path);
        printSummary(path, summary);
        return summary.warnings.empty() ? 0 : 2;
    } catch (const std::exception& e) {
        std::cerr << "OpenStrikeSpriteDump error: " << e.what() << '\n';
        return 1;
    }
}
