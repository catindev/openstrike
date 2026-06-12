#pragma once

#include "assets/VirtualFileSystem.h"

#include <ostream>
#include <vector>

namespace osk {

struct ResourceIndex {
    std::vector<ResourceFile> maps;
    std::vector<ResourceFile> wads;
    std::vector<ResourceFile> models;
    std::vector<ResourceFile> sprites;
    std::vector<ResourceFile> sounds;

    [[nodiscard]] std::size_t totalFiles() const;
};

ResourceIndex buildResourceIndex(const VirtualFileSystem& vfs);
void printResourceIndex(std::ostream& out, const ResourceIndex& index, bool verbose);

} // namespace osk
