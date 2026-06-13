#include "assets/loaders/ModelMetadata.h"

#include <exception>
#include <filesystem>
#include <iomanip>
#include <iostream>
#include <string>

namespace fs = std::filesystem;

namespace {

void printUsage(std::ostream& out) {
    out << "OpenStrikeModelDump\n"
        << "\n"
        << "Usage:\n"
        << "  OpenStrikeModelDump <path/to/model.mdl>\n"
        << "\n"
        << "This read-only tool prints legacy model header and table metadata.\n"
        << "It does not extract meshes, decode texture pixels, write assets, or cache user data.\n";
}

void printVec3(const osk::model::Vec3& value) {
    std::cout << value.x << ',' << value.y << ',' << value.z;
}

void printSection(const char* name, const osk::model::CountedSection& section) {
    std::cout << "  " << std::left << std::setw(18) << name
        << std::right << std::setw(8) << section.count
        << std::setw(12) << section.offset << '\n';
}

void printSummary(const fs::path& path, const osk::model::ModelMetadataSummary& summary) {
    const osk::model::ModelHeaderInfo& header = summary.header;

    std::cout << "Model:           " << path.string() << '\n';
    std::cout << "Magic:           " << header.magic << '\n';
    std::cout << "Version:         " << header.version << '\n';
    std::cout << "Name:            " << header.name << '\n';
    std::cout << "Size:            " << header.fileSize << " bytes\n";
    std::cout << "Declared length: " << header.declaredLength << " bytes\n";
    std::cout << "Flags:           " << header.flags << '\n';
    std::cout << "Eye position:    ";
    printVec3(header.eyePosition);
    std::cout << '\n';
    std::cout << "Extents:         min ";
    printVec3(header.min);
    std::cout << " / max ";
    printVec3(header.max);
    std::cout << '\n';
    std::cout << "Bounds:          min ";
    printVec3(header.bbmin);
    std::cout << " / max ";
    printVec3(header.bbmax);
    std::cout << '\n';

    std::cout << "\nHeader sections:\n";
    std::cout << "  " << std::left << std::setw(18) << "Name"
        << std::right << std::setw(8) << "Count" << std::setw(12) << "Offset" << '\n';
    printSection("bones", header.bones);
    printSection("bone controllers", header.boneControllers);
    printSection("hitboxes", header.hitboxes);
    printSection("sequences", header.sequences);
    printSection("sequence groups", header.sequenceGroups);
    printSection("textures", header.textures);
    printSection("body parts", header.bodyParts);
    printSection("attachments", header.attachments);
    printSection("sounds", header.sounds);
    printSection("sound groups", header.soundGroups);
    printSection("transitions", header.transitions);
    std::cout << "  " << std::left << std::setw(18) << "texture data"
        << std::right << std::setw(8) << "-" << std::setw(12) << header.textureDataOffset << '\n';
    std::cout << "  " << std::left << std::setw(18) << "skins"
        << std::right << std::setw(8) << header.skinReferenceCount << std::setw(12) << header.skinOffset
        << "  families=" << header.skinFamilyCount << '\n';

    std::cout << "\nBody parts:\n";
    std::cout << "  " << std::left
        << std::setw(28) << "Name"
        << std::right << std::setw(8) << "Models"
        << std::setw(10) << "Base"
        << std::setw(12) << "Offset" << '\n';
    for (const osk::model::ModelBodyPartInfo& bodyPart : summary.bodyParts) {
        std::cout << "  " << std::left << std::setw(28) << bodyPart.name
            << std::right << std::setw(8) << bodyPart.modelCount
            << std::setw(10) << bodyPart.base
            << std::setw(12) << bodyPart.modelOffset << '\n';
    }

    std::cout << "\nSequences:\n";
    std::cout << "  " << std::left
        << std::setw(34) << "Label"
        << std::right << std::setw(8) << "Frames"
        << std::setw(10) << "FPS"
        << std::setw(10) << "Activity"
        << std::setw(8) << "Events"
        << std::setw(8) << "Group" << '\n';
    for (const osk::model::ModelSequenceInfo& sequence : summary.sequences) {
        std::cout << "  " << std::left << std::setw(34) << sequence.label
            << std::right << std::setw(8) << sequence.frameCount
            << std::setw(10) << sequence.fps
            << std::setw(10) << sequence.activity
            << std::setw(8) << sequence.eventCount
            << std::setw(8) << sequence.sequenceGroup << '\n';
    }

    std::cout << "\nTextures:\n";
    std::cout << "  " << std::left
        << std::setw(34) << "Name"
        << std::right << std::setw(8) << "Width"
        << std::setw(8) << "Height"
        << std::setw(10) << "Flags"
        << std::setw(12) << "DataOff" << '\n';
    for (const osk::model::ModelTextureInfo& texture : summary.textures) {
        std::cout << "  " << std::left << std::setw(34) << texture.name
            << std::right << std::setw(8) << texture.width
            << std::setw(8) << texture.height
            << std::setw(10) << texture.flags
            << std::setw(12) << texture.dataOffset << '\n';
    }

    std::cout << "\nHitboxes:\n";
    std::cout << "  " << std::left
        << std::setw(8) << "Bone"
        << std::setw(8) << "Group"
        << "Bounds\n";
    for (const osk::model::ModelHitboxInfo& hitbox : summary.hitboxes) {
        std::cout << "  " << std::left << std::setw(8) << hitbox.bone
            << std::setw(8) << hitbox.group
            << "min ";
        printVec3(hitbox.bbmin);
        std::cout << " / max ";
        printVec3(hitbox.bbmax);
        std::cout << '\n';
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
        const osk::model::ModelMetadataSummary summary = osk::model::loadModelMetadata(path);
        printSummary(path, summary);
        return summary.warnings.empty() ? 0 : 2;
    } catch (const std::exception& e) {
        std::cerr << "OpenStrikeModelDump error: " << e.what() << '\n';
        return 1;
    }
}
