#include "assets/loaders/BspGeometry.h"
#include "assets/loaders/BspLight.h"
#include "assets/loaders/BspLoader.h"
#include "assets/loaders/BspMesh.h"

#include <array>
#include <cstdint>
#include <filesystem>
#include <iomanip>
#include <iostream>
#include <string>

namespace fs = std::filesystem;

namespace {

void printUsage(std::ostream& out) {
    out << "OpenStrikeBspDump\n"
        << "\n"
        << "Usage:\n"
        << "  OpenStrikeBspDump <path/to/map.bsp>\n"
        << "\n"
        << "This tool reads a local user-provided BSP file and prints structural metadata.\n"
        << "It does not copy assets, extract assets, or connect to any external service.\n";
}

void printBounds(const osk::bsp::Bounds3& bounds) {
    if (!bounds.valid) {
        std::cout << "  bounds:           unavailable\n";
        return;
    }

    std::cout << "  bounds min:       "
        << bounds.min.x << ", " << bounds.min.y << ", " << bounds.min.z << '\n';
    std::cout << "  bounds max:       "
        << bounds.max.x << ", " << bounds.max.y << ", " << bounds.max.z << '\n';
}

std::string lightStylesText(const std::array<std::uint8_t, 4>& styles) {
    std::string out;
    for (std::size_t i = 0; i < styles.size(); ++i) {
        if (i > 0) {
            out += ",";
        }
        if (styles[i] == 255U) {
            out += "-";
        } else {
            out += std::to_string(static_cast<unsigned int>(styles[i]));
        }
    }
    return out;
}

void printLightSummary(const osk::bsp::BspLightSummary& light) {
    std::cout << "\nLight data / Lightmaps summary:\n";
    std::cout << "  lighting bytes:   " << light.lightingByteCount << '\n';
    std::cout << "  faces:            " << light.faceCount << '\n';
    std::cout << "  lit faces:        " << light.litFaceCount << '\n';
    std::cout << "  valid lightmaps:  " << light.validLightmapCount << '\n';
    std::cout << "  missing lightmaps:" << light.missingLightmapCount << '\n';
    std::cout << "  invalid lightmaps:" << light.invalidLightmapCount << '\n';

    if (light.faces.empty()) {
        return;
    }

    std::cout << "\nLightmaps per face:\n";
    std::cout << "  " << std::left
        << std::setw(8) << "Face"
        << std::setw(12) << "Offset"
        << std::setw(10) << "Size"
        << std::setw(10) << "Samples"
        << std::setw(8) << "Styles"
        << std::setw(14) << "StyleIds"
        << std::setw(10) << "Texture"
        << "Status\n";

    for (const osk::bsp::BspLightFaceInfo& face : light.faces) {
        std::string status = "missing";
        if (face.hasLightingData && face.rangeValid) {
            status = "ok";
        } else if (face.hasLightingData) {
            status = face.geometryValid ? "bad-range" : "bad-geometry";
        }

        std::string offsetText = "-";
        if (face.lightOffset >= 0) {
            offsetText = std::to_string(face.lightOffset);
        }

        std::string sizeText = "-";
        if (face.lightmapWidth > 0 && face.lightmapHeight > 0) {
            sizeText = std::to_string(face.lightmapWidth) + "x" + std::to_string(face.lightmapHeight);
        }

        std::cout << "  " << std::left
            << std::setw(8) << face.faceIndex
            << std::setw(12) << offsetText
            << std::setw(10) << sizeText
            << std::setw(10) << face.sampleCount
            << std::setw(8) << face.activeStyleCount
            << std::setw(14) << lightStylesText(face.styles)
            << std::setw(10) << face.textureIndex
            << status << '\n';
    }
}

void printSummary(
    const fs::path& path,
    const osk::bsp::BspSummary& summary,
    const osk::bsp::BspGeometrySummary& geometry,
    const osk::bsp::BspWorldMesh& mesh,
    const osk::bsp::BspLightSummary& light) {
    std::cout << "BSP file: " << path.string() << '\n';
    std::cout << "Version:  " << summary.version << '\n';
    std::cout << "Size:     " << summary.fileSize << " bytes\n";
    std::cout << '\n';

    std::cout << "Lumps:\n";
    std::cout << "  " << std::left
        << std::setw(14) << "Name"
        << std::right
        << std::setw(12) << "Offset"
        << std::setw(12) << "Length"
        << std::setw(12) << "ElemSize"
        << std::setw(12) << "Count"
        << "  Status\n";

    for (const osk::bsp::LumpInfo& lump : summary.lumps) {
        std::string status = "ok";
        if (!lump.rangeValid) {
            status = "bad-range";
        } else if (!lump.sizeAligned) {
            status = "bad-size";
        }

        std::cout << "  " << std::left
            << std::setw(14) << lump.name
            << std::right
            << std::setw(12) << lump.offset
            << std::setw(12) << lump.length
            << std::setw(12) << lump.elementSize
            << std::setw(12) << lump.elementCount
            << "  " << status << '\n';
    }

    std::cout << '\n';
    std::cout << "Entities:\n";
    std::cout << "  blocks:           " << summary.entityBlockCount << '\n';

    std::cout << "\nTextures:\n";
    std::cout << "  declared:         " << summary.textures.declaredCount << '\n';
    std::cout << "  valid offsets:    " << summary.textures.validOffsetCount << '\n';
    std::cout << "  named:            " << summary.textures.namedTextureCount << '\n';

    std::cout << "\nGeometry:\n";
    std::cout << "  vertices:         " << geometry.vertexCount << '\n';
    std::cout << "  edges:            " << geometry.edgeCount << '\n';
    std::cout << "  surfedges:        " << geometry.surfEdgeCount << '\n';
    std::cout << "  faces:            " << geometry.faceCount << '\n';
    std::cout << "  valid faces:      " << geometry.validFaceCount << '\n';
    std::cout << "  invalid faces:    " << geometry.invalidFaceCount << '\n';
    std::cout << "  degenerate faces: " << geometry.degenerateFaceCount << '\n';
    std::cout << "  polygon vertices: " << geometry.polygonVertexCount << '\n';
    std::cout << "  triangles:        " << geometry.triangleCount << '\n';
    std::cout << "  max face edges:   " << geometry.maxEdgesPerFace << '\n';
    printBounds(geometry.bounds);

    std::cout << "\nWorld mesh:\n";
    std::cout << "  vertices:         " << mesh.vertices.size() << '\n';
    std::cout << "  indices:          " << mesh.indices.size() << '\n';
    std::cout << "  triangles:        " << mesh.triangleCount() << '\n';
    std::cout << "  face ranges:      " << mesh.faces.size() << '\n';
    std::cout << "  skipped faces:    " << mesh.skippedFaceCount << '\n';
    printBounds(mesh.bounds);

    printLightSummary(light);

    if (!summary.warnings.empty() || !geometry.warnings.empty() || !mesh.warnings.empty() || !light.warnings.empty()) {
        std::cout << "\nWarnings:\n";
        for (const std::string& warning : summary.warnings) {
            std::cout << "  - " << warning << '\n';
        }
        for (const std::string& warning : geometry.warnings) {
            std::cout << "  - " << warning << '\n';
        }
        for (const std::string& warning : mesh.warnings) {
            std::cout << "  - " << warning << '\n';
        }
        for (const std::string& warning : light.warnings) {
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
        const osk::bsp::BspSummary summary = osk::bsp::loadBspSummary(path);
        const osk::bsp::BspGeometrySummary geometry = osk::bsp::loadBspGeometrySummary(path);
        const osk::bsp::BspWorldMesh mesh = osk::bsp::loadBspWorldMesh(path);
        const osk::bsp::BspLightSummary light = osk::bsp::loadBspLightSummary(path);
        printSummary(path, summary, geometry, mesh, light);
        return summary.warnings.empty() && geometry.warnings.empty() && mesh.warnings.empty() && light.warnings.empty() ? 0 : 2;
    } catch (const std::exception& e) {
        std::cerr << "OpenStrikeBspDump error: " << e.what() << '\n';
        return 1;
    }
}
