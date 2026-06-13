#include "assets/loaders/ModelMetadata.h"

#include <cctype>
#include <cstddef>
#include <cstring>
#include <fstream>
#include <limits>
#include <string>
#include <utility>
#include <vector>

namespace osk::model {
namespace {

constexpr std::size_t HeaderSize = 244;
constexpr std::size_t ModelNameBytes = 64;
constexpr std::size_t BodyPartSize = 76;
constexpr std::size_t SequenceSize = 176;
constexpr std::size_t TextureSize = 80;
constexpr std::size_t HitboxSize = 32;
constexpr std::int32_t SupportedStudioVersion = 10;

std::uint8_t byteAt(std::span<const std::byte> bytes, std::size_t offset) {
    return std::to_integer<std::uint8_t>(bytes[offset]);
}

std::uint32_t readU32LE(std::span<const std::byte> bytes, std::size_t offset) {
    return static_cast<std::uint32_t>(byteAt(bytes, offset))
        | (static_cast<std::uint32_t>(byteAt(bytes, offset + 1)) << 8U)
        | (static_cast<std::uint32_t>(byteAt(bytes, offset + 2)) << 16U)
        | (static_cast<std::uint32_t>(byteAt(bytes, offset + 3)) << 24U);
}

std::int32_t readI32LE(std::span<const std::byte> bytes, std::size_t offset) {
    return static_cast<std::int32_t>(readU32LE(bytes, offset));
}

float readF32LE(std::span<const std::byte> bytes, std::size_t offset) {
    const std::uint32_t raw = readU32LE(bytes, offset);
    float value = 0.0F;
    static_assert(sizeof(value) == sizeof(raw));
    std::memcpy(&value, &raw, sizeof(value));
    return value;
}

Vec3 readVec3(std::span<const std::byte> bytes, std::size_t offset) {
    return {
        readF32LE(bytes, offset),
        readF32LE(bytes, offset + 4),
        readF32LE(bytes, offset + 8),
    };
}

std::string readFixedString(std::span<const std::byte> bytes, std::size_t offset, std::size_t maxLength) {
    std::string value;
    value.reserve(maxLength);
    for (std::size_t i = 0; i < maxLength; ++i) {
        const std::uint8_t c = byteAt(bytes, offset + i);
        if (c == 0) {
            break;
        }
        value.push_back(std::isprint(c) != 0 ? static_cast<char>(c) : '?');
    }
    return value;
}

std::string readMagic(std::span<const std::byte> bytes) {
    return readFixedString(bytes, 0, 4);
}

bool magicEquals(std::span<const std::byte> bytes, const char* magic) {
    for (std::size_t i = 0; i < 4; ++i) {
        if (byteAt(bytes, i) != static_cast<std::uint8_t>(magic[i])) {
            return false;
        }
    }
    return true;
}

void requireNonNegative(std::int32_t value, const std::string& fieldName) {
    if (value < 0) {
        throw ModelMetadataFormatError("model has a negative " + fieldName);
    }
}

void requireTableRange(
    std::span<const std::byte> bytes,
    const CountedSection& section,
    std::size_t stride,
    const std::string& sectionName) {
    requireNonNegative(section.count, sectionName + " count");
    if (section.count == 0) {
        return;
    }
    if (section.offset < 0) {
        throw ModelMetadataFormatError("model " + sectionName + " table has a negative offset");
    }

    const auto offset = static_cast<std::size_t>(section.offset);
    if (offset < HeaderSize) {
        throw ModelMetadataFormatError("model " + sectionName + " table overlaps the header");
    }
    if (offset > bytes.size()) {
        throw ModelMetadataFormatError("model " + sectionName + " table offset is outside the file");
    }

    const auto count = static_cast<std::size_t>(section.count);
    if (count > (bytes.size() - offset) / stride) {
        throw ModelMetadataFormatError("model " + sectionName + " table is truncated");
    }
}

void warnIfNegativeOffset(std::vector<std::string>& warnings, std::int32_t offset, const std::string& fieldName) {
    if (offset < 0) {
        warnings.emplace_back(fieldName + " is negative");
    }
}

void warnIfNegativeCount(std::vector<std::string>& warnings, std::int32_t count, const std::string& fieldName) {
    if (count < 0) {
        warnings.emplace_back(fieldName + " is negative");
    }
}

ModelHeaderInfo readHeader(std::span<const std::byte> bytes) {
    ModelHeaderInfo header;
    header.magic = readMagic(bytes);
    header.version = readI32LE(bytes, 4);
    header.name = readFixedString(bytes, 8, ModelNameBytes);
    header.declaredLength = readI32LE(bytes, 72);
    header.fileSize = bytes.size();
    header.eyePosition = readVec3(bytes, 76);
    header.min = readVec3(bytes, 88);
    header.max = readVec3(bytes, 100);
    header.bbmin = readVec3(bytes, 112);
    header.bbmax = readVec3(bytes, 124);
    header.flags = readI32LE(bytes, 136);

    header.bones = {readI32LE(bytes, 140), readI32LE(bytes, 144)};
    header.boneControllers = {readI32LE(bytes, 148), readI32LE(bytes, 152)};
    header.hitboxes = {readI32LE(bytes, 156), readI32LE(bytes, 160)};
    header.sequences = {readI32LE(bytes, 164), readI32LE(bytes, 168)};
    header.sequenceGroups = {readI32LE(bytes, 172), readI32LE(bytes, 176)};
    header.textures = {readI32LE(bytes, 180), readI32LE(bytes, 184)};
    header.textureDataOffset = readI32LE(bytes, 188);
    header.skinReferenceCount = readI32LE(bytes, 192);
    header.skinFamilyCount = readI32LE(bytes, 196);
    header.skinOffset = readI32LE(bytes, 200);
    header.bodyParts = {readI32LE(bytes, 204), readI32LE(bytes, 208)};
    header.attachments = {readI32LE(bytes, 212), readI32LE(bytes, 216)};
    header.sounds = {readI32LE(bytes, 220), readI32LE(bytes, 224)};
    header.soundGroups = {readI32LE(bytes, 228), readI32LE(bytes, 232)};
    header.transitions = {readI32LE(bytes, 236), readI32LE(bytes, 240)};

    return header;
}

ModelBodyPartInfo readBodyPart(std::span<const std::byte> bytes, std::size_t offset) {
    return {
        readFixedString(bytes, offset, ModelNameBytes),
        readI32LE(bytes, offset + 64),
        readI32LE(bytes, offset + 68),
        readI32LE(bytes, offset + 72),
    };
}

ModelSequenceInfo readSequence(std::span<const std::byte> bytes, std::size_t offset) {
    ModelSequenceInfo sequence;
    sequence.label = readFixedString(bytes, offset, 32);
    sequence.fps = readF32LE(bytes, offset + 32);
    sequence.flags = readI32LE(bytes, offset + 36);
    sequence.activity = readI32LE(bytes, offset + 40);
    sequence.activityWeight = readI32LE(bytes, offset + 44);
    sequence.eventCount = readI32LE(bytes, offset + 48);
    sequence.eventOffset = readI32LE(bytes, offset + 52);
    sequence.frameCount = readI32LE(bytes, offset + 56);
    sequence.pivotCount = readI32LE(bytes, offset + 60);
    sequence.pivotOffset = readI32LE(bytes, offset + 64);
    sequence.motionType = readI32LE(bytes, offset + 68);
    sequence.motionBone = readI32LE(bytes, offset + 72);
    sequence.linearMovement = readVec3(bytes, offset + 76);
    sequence.bbmin = readVec3(bytes, offset + 96);
    sequence.bbmax = readVec3(bytes, offset + 108);
    sequence.blendCount = readI32LE(bytes, offset + 120);
    sequence.animOffset = readI32LE(bytes, offset + 124);
    sequence.sequenceGroup = readI32LE(bytes, offset + 156);
    sequence.entryNode = readI32LE(bytes, offset + 160);
    sequence.exitNode = readI32LE(bytes, offset + 164);
    sequence.nodeFlags = readI32LE(bytes, offset + 168);
    sequence.nextSequence = readI32LE(bytes, offset + 172);
    return sequence;
}

ModelTextureInfo readTexture(std::span<const std::byte> bytes, std::size_t offset) {
    return {
        readFixedString(bytes, offset, ModelNameBytes),
        readI32LE(bytes, offset + 64),
        readI32LE(bytes, offset + 68),
        readI32LE(bytes, offset + 72),
        readI32LE(bytes, offset + 76),
    };
}

ModelHitboxInfo readHitbox(std::span<const std::byte> bytes, std::size_t offset) {
    return {
        readI32LE(bytes, offset),
        readI32LE(bytes, offset + 4),
        readVec3(bytes, offset + 8),
        readVec3(bytes, offset + 20),
    };
}

template <typename T, typename Reader>
std::vector<T> readTable(std::span<const std::byte> bytes, const CountedSection& section, std::size_t stride, Reader reader) {
    std::vector<T> values;
    values.reserve(static_cast<std::size_t>(section.count));
    const auto begin = static_cast<std::size_t>(section.offset);
    for (std::int32_t i = 0; i < section.count; ++i) {
        values.push_back(reader(bytes, begin + static_cast<std::size_t>(i) * stride));
    }
    return values;
}

void validateSummary(const ModelMetadataSummary& summary) {
    for (const ModelBodyPartInfo& bodyPart : summary.bodyParts) {
        requireNonNegative(bodyPart.modelCount, "body part model count");
        requireNonNegative(bodyPart.base, "body part base");
    }
    for (const ModelSequenceInfo& sequence : summary.sequences) {
        requireNonNegative(sequence.eventCount, "sequence event count");
        requireNonNegative(sequence.frameCount, "sequence frame count");
        requireNonNegative(sequence.pivotCount, "sequence pivot count");
        requireNonNegative(sequence.blendCount, "sequence blend count");
    }
    for (const ModelTextureInfo& texture : summary.textures) {
        requireNonNegative(texture.width, "texture width");
        requireNonNegative(texture.height, "texture height");
    }
}

} // namespace

ModelMetadataFormatError::ModelMetadataFormatError(const std::string& message)
    : std::runtime_error(message) {}

ModelMetadataSummary parseModelMetadata(std::span<const std::byte> bytes) {
    if (bytes.size() < HeaderSize) {
        throw ModelMetadataFormatError("file is too small to contain a model header");
    }
    if (!magicEquals(bytes, "IDST")) {
        throw ModelMetadataFormatError("unsupported model magic: " + readMagic(bytes));
    }

    ModelMetadataSummary summary;
    summary.header = readHeader(bytes);
    if (summary.header.version != SupportedStudioVersion) {
        throw ModelMetadataFormatError("unsupported model version: " + std::to_string(summary.header.version));
    }

    if (summary.header.declaredLength < static_cast<std::int32_t>(HeaderSize)) {
        summary.warnings.emplace_back("declared model length is smaller than the header");
    } else if (static_cast<std::size_t>(summary.header.declaredLength) != bytes.size()) {
        summary.warnings.emplace_back("declared model length does not match the file size");
    }
    warnIfNegativeOffset(summary.warnings, summary.header.textureDataOffset, "texture data offset");
    warnIfNegativeCount(summary.warnings, summary.header.skinReferenceCount, "skin reference count");
    warnIfNegativeCount(summary.warnings, summary.header.skinFamilyCount, "skin family count");
    warnIfNegativeOffset(summary.warnings, summary.header.skinOffset, "skin offset");

    requireTableRange(bytes, summary.header.bodyParts, BodyPartSize, "body part");
    requireTableRange(bytes, summary.header.sequences, SequenceSize, "sequence");
    requireTableRange(bytes, summary.header.textures, TextureSize, "texture");
    requireTableRange(bytes, summary.header.hitboxes, HitboxSize, "hitbox");

    summary.bodyParts = readTable<ModelBodyPartInfo>(bytes, summary.header.bodyParts, BodyPartSize, readBodyPart);
    summary.sequences = readTable<ModelSequenceInfo>(bytes, summary.header.sequences, SequenceSize, readSequence);
    summary.textures = readTable<ModelTextureInfo>(bytes, summary.header.textures, TextureSize, readTexture);
    summary.hitboxes = readTable<ModelHitboxInfo>(bytes, summary.header.hitboxes, HitboxSize, readHitbox);

    validateSummary(summary);
    return summary;
}

std::vector<std::byte> loadModelMetadataBytes(const std::filesystem::path& path) {
    std::ifstream file(path, std::ios::binary);
    if (!file) {
        throw ModelMetadataFormatError("failed to open model file: " + path.string());
    }

    std::vector<std::byte> bytes;
    file.seekg(0, std::ios::end);
    const std::streamoff size = file.tellg();
    if (size < 0) {
        throw ModelMetadataFormatError("failed to determine model file size: " + path.string());
    }

    bytes.resize(static_cast<std::size_t>(size));
    file.seekg(0, std::ios::beg);

    if (!bytes.empty()) {
        file.read(reinterpret_cast<char*>(bytes.data()), static_cast<std::streamsize>(bytes.size()));
        if (!file) {
            throw ModelMetadataFormatError("failed to read model file: " + path.string());
        }
    }

    return bytes;
}

ModelMetadataSummary loadModelMetadata(const std::filesystem::path& path) {
    std::vector<std::byte> bytes = loadModelMetadataBytes(path);
    return parseModelMetadata(std::span<const std::byte>(bytes.data(), bytes.size()));
}

} // namespace osk::model
