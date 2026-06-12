#pragma once

#include <filesystem>
#include <optional>
#include <string>
#include <string_view>
#include <vector>

namespace osk {

struct MountedRoot {
    std::filesystem::path canonicalPath;
    std::string label;
    bool userProvided = true;
};

struct ResourceFile {
    std::filesystem::path absolutePath;
    std::string virtualPath;
    std::string extension;
    std::size_t mountIndex = 0;
};

class VirtualFileSystem {
public:
    bool mountReadOnlyDirectory(
        const std::filesystem::path& path,
        std::string label,
        bool userProvided,
        std::string* errorMessage = nullptr);

    [[nodiscard]] std::size_t mountCount() const;
    [[nodiscard]] std::size_t userMountCount() const;
    [[nodiscard]] const std::vector<MountedRoot>& mounts() const;

    [[nodiscard]] std::vector<ResourceFile> findByExtension(std::string_view extension) const;
    [[nodiscard]] std::vector<ResourceFile> findByExtensions(const std::vector<std::string>& extensions) const;

private:
    std::vector<MountedRoot> mountedRoots_;
};

} // namespace osk
