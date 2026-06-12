#include "assets/ResourceIndex.h"

#include <iomanip>

namespace osk {
namespace {

void printGroup(std::ostream& out, const char* name, const std::vector<ResourceFile>& files, bool verbose) {
    out << "  " << std::left << std::setw(8) << name << files.size() << '\n';

    if (!verbose) {
        return;
    }

    for (const ResourceFile& file : files) {
        out << "    - " << file.virtualPath << '\n';
    }
}

} // namespace

std::size_t ResourceIndex::totalFiles() const {
    return maps.size() + wads.size() + models.size() + sprites.size() + sounds.size();
}

ResourceIndex buildResourceIndex(const VirtualFileSystem& vfs) {
    ResourceIndex index;
    index.maps = vfs.findByExtension(".bsp");
    index.wads = vfs.findByExtension(".wad");
    index.models = vfs.findByExtension(".mdl");
    index.sprites = vfs.findByExtension(".spr");
    index.sounds = vfs.findByExtension(".wav");
    return index;
}

void printResourceIndex(std::ostream& out, const ResourceIndex& index, bool verbose) {
    out << "Resource index:\n";
    printGroup(out, "maps:", index.maps, verbose);
    printGroup(out, "wads:", index.wads, verbose);
    printGroup(out, "models:", index.models, verbose);
    printGroup(out, "sprites:", index.sprites, verbose);
    printGroup(out, "sounds:", index.sounds, verbose);
    out << "  " << std::left << std::setw(8) << "total:" << index.totalFiles() << '\n';
}

} // namespace osk
