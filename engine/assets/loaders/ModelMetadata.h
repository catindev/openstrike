#pragma once

#include <cstddef>
#include <cstdint>
#include <filesystem>
#include <span>
#include <stdexcept>
#include <string>
#include <vector>

namespace osk::model {

class ModelMetadataFormatError : public std::runtime_error {
public:
    explicit ModelMetadataFormatError(const std::string& message);
};

struct Vec3 {
    float x = 0.0F;
    float y = 0.0F;
    float z = 0.0F;
};

struct CountedSection {
    std::int32_t count = 0;
    std::int32_t offset = 0;
};

struct ModelHeaderInfo {
    std::string magic;
    std::int32_t version = 0;
    std::string name;
    std::int32_t declaredLength = 0;
    std::size_t fileSize = 0;
    Vec3 eyePosition;
    Vec3 min;
    Vec3 max;
    Vec3 bbmin;
    Vec3 bbmax;
    std::int32_t flags = 0;

    CountedSection bones;
    CountedSection boneControllers;
    CountedSection hitboxes;
    CountedSection sequences;
    CountedSection sequenceGroups;
    CountedSection textures;
    std::int32_t textureDataOffset = 0;
    std::int32_t skinReferenceCount = 0;
    std::int32_t skinFamilyCount = 0;
    std::int32_t skinOffset = 0;
    CountedSection bodyParts;
    CountedSection attachments;
    CountedSection sounds;
    CountedSection soundGroups;
    CountedSection transitions;
};

struct ModelBodyPartInfo {
    std::string name;
    std::int32_t modelCount = 0;
    std::int32_t base = 0;
    std::int32_t modelOffset = 0;
};

struct ModelSequenceInfo {
    std::string label;
    float fps = 0.0F;
    std::int32_t flags = 0;
    std::int32_t activity = 0;
    std::int32_t activityWeight = 0;
    std::int32_t eventCount = 0;
    std::int32_t eventOffset = 0;
    std::int32_t frameCount = 0;
    std::int32_t pivotCount = 0;
    std::int32_t pivotOffset = 0;
    std::int32_t motionType = 0;
    std::int32_t motionBone = 0;
    Vec3 linearMovement;
    Vec3 bbmin;
    Vec3 bbmax;
    std::int32_t blendCount = 0;
    std::int32_t animOffset = 0;
    std::int32_t sequenceGroup = 0;
    std::int32_t entryNode = 0;
    std::int32_t exitNode = 0;
    std::int32_t nodeFlags = 0;
    std::int32_t nextSequence = 0;
};

struct ModelTextureInfo {
    std::string name;
    std::int32_t flags = 0;
    std::int32_t width = 0;
    std::int32_t height = 0;
    std::int32_t dataOffset = 0;
};

struct ModelHitboxInfo {
    std::int32_t bone = 0;
    std::int32_t group = 0;
    Vec3 bbmin;
    Vec3 bbmax;
};

struct ModelMetadataSummary {
    ModelHeaderInfo header;
    std::vector<ModelBodyPartInfo> bodyParts;
    std::vector<ModelSequenceInfo> sequences;
    std::vector<ModelTextureInfo> textures;
    std::vector<ModelHitboxInfo> hitboxes;
    std::vector<std::string> warnings;
};

ModelMetadataSummary parseModelMetadata(std::span<const std::byte> bytes);
ModelMetadataSummary loadModelMetadata(const std::filesystem::path& path);
std::vector<std::byte> loadModelMetadataBytes(const std::filesystem::path& path);

} // namespace osk::model
