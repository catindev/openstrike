#include "assets/VirtualFileSystem.h"

#include <algorithm>
#include <cctype>
#include <system_error>
#include <unordered_set>

namespace osk {
namespace {

std::filesystem::path normalizeExistingDirectory(const std::filesystem::path& input, std::string* errorMessage) {
    std::error_code ec;
    std::filesystem::path absolute = input.is_absolute() ? input : std::filesystem::absolute(input, ec);
    if (ec) {
        if (errorMessage != nullptr) {
            *errorMessage = "cannot resolve absolute path: " + input.string();
        }
        return {};
    }

    std::filesystem::path canonical = std::filesystem::weakly_canonical(absolute, ec);
    if (ec) {
        if (errorMessage != nullptr) {
            *errorMessage = "cannot canonicalize path: " + absolute.string();
        }
        return {};
    }

    if (!std::filesystem::exists(canonical, ec) || ec) {
        if (errorMessage != nullptr) {
            *errorMessage = "path does not exist: " + canonical.string();
        }
        return {};
    }

    if (!std::filesystem::is_directory(canonical, ec) || ec) {
        if (errorMessage != nullptr) {
            *errorMessage = "path is not a directory: " + canonical.string();
        }
        return {};
    }

    std::filesystem::directory_iterator probe(canonical, ec);
    (void)probe;
    if (ec) {
        if (errorMessage != nullptr) {
            *errorMessage = "path is not readable: " + canonical.string();
        }
        return {};
    }

    return canonical;
}

std::string lowerString(std::string_view value) {
    std::string result(value);
    std::transform(result.begin(), result.end(), result.begin(), [](unsigned char c) {
        return static_cast<char>(std::tolower(c));
    });
    return result;
}

std::string lowerExtension(std::string_view extension) {
    std::string result = lowerString(extension);

    if (!result.empty() && result.front() != '.') {
        result.insert(result.begin(), '.');
    }

    return result;
}

std::string virtualPathFor(const std::filesystem::path& root, const std::filesystem::path& file) {
    std::error_code ec;
    auto relative = std::filesystem::relative(file, root, ec);
    if (ec) {
        relative = file.filename();
    }

    return relative.generic_string();
}

std::string canonicalFileKey(const std::filesystem::path& file) {
    std::error_code ec;
    std::filesystem::path canonical = std::filesystem::weakly_canonical(file, ec);
    if (ec) {
        ec.clear();
        canonical = std::filesystem::absolute(file, ec);
    }

    if (ec) {
        canonical = file;
    }

    return canonical.generic_string();
}

std::string virtualFileKey(std::string_view virtualPath) {
    // Legacy game resource lookups are effectively case-insensitive on the
    // platforms we target, and macOS default filesystems are commonly
    // case-insensitive. Keep virtual resource shadowing case-insensitive too.
    return lowerString(virtualPath);
}

} // namespace

bool VirtualFileSystem::mountReadOnlyDirectory(
    const std::filesystem::path& path,
    std::string label,
    bool userProvided,
    std::string* errorMessage) {
    std::filesystem::path canonical = normalizeExistingDirectory(path, errorMessage);
    if (canonical.empty()) {
        return false;
    }

    const auto alreadyMounted = std::any_of(
        mountedRoots_.begin(),
        mountedRoots_.end(),
        [&](const MountedRoot& root) {
            return root.canonicalPath == canonical;
        });

    if (alreadyMounted) {
        return true;
    }

    mountedRoots_.push_back(MountedRoot{
        .canonicalPath = canonical,
        .label = std::move(label),
        .userProvided = userProvided,
    });

    return true;
}

std::size_t VirtualFileSystem::mountCount() const {
    return mountedRoots_.size();
}

std::size_t VirtualFileSystem::userMountCount() const {
    return static_cast<std::size_t>(std::count_if(
        mountedRoots_.begin(),
        mountedRoots_.end(),
        [](const MountedRoot& root) {
            return root.userProvided;
        }));
}

const std::vector<MountedRoot>& VirtualFileSystem::mounts() const {
    return mountedRoots_;
}

std::vector<ResourceFile> VirtualFileSystem::findByExtension(std::string_view extension) const {
    return findByExtensions({lowerExtension(extension)});
}

std::vector<ResourceFile> VirtualFileSystem::findByExtensions(const std::vector<std::string>& extensions) const {
    std::unordered_set<std::string> wanted;
    wanted.reserve(extensions.size());

    for (const std::string& extension : extensions) {
        wanted.insert(lowerExtension(extension));
    }

    std::vector<ResourceFile> result;
    std::unordered_set<std::string> seenCanonicalFiles;
    std::unordered_set<std::string> seenVirtualFiles;

    for (std::size_t mountIndex = 0; mountIndex < mountedRoots_.size(); ++mountIndex) {
        const MountedRoot& root = mountedRoots_[mountIndex];

        std::error_code ec;
        std::filesystem::recursive_directory_iterator it(
            root.canonicalPath,
            std::filesystem::directory_options::skip_permission_denied,
            ec);

        const std::filesystem::recursive_directory_iterator end;
        for (; !ec && it != end; it.increment(ec)) {
            if (ec) {
                break;
            }

            if (!it->is_regular_file(ec) || ec) {
                ec.clear();
                continue;
            }

            const std::string ext = lowerExtension(it->path().extension().string());
            if (!wanted.contains(ext)) {
                continue;
            }

            // The same physical file can be visible through multiple mounted roots,
            // for example when both a mod directory and its parent game directory are
            // configured. Keep the first match so mount order defines precedence.
            if (!seenCanonicalFiles.insert(canonicalFileKey(it->path())).second) {
                continue;
            }

            const std::string virtualPath = virtualPathFor(root.canonicalPath, it->path());

            // Different physical files can also have the same virtual path across
            // mounted roots, for example cstrike/cached.wad and valve/cached.wad
            // both appear as cached.wad when their directories are mounted directly.
            // This mirrors mod overlay semantics: earlier mounts shadow later mounts.
            if (!seenVirtualFiles.insert(virtualFileKey(virtualPath)).second) {
                continue;
            }

            result.push_back(ResourceFile{
                .absolutePath = it->path(),
                .virtualPath = virtualPath,
                .extension = ext,
                .mountIndex = mountIndex,
            });
        }
    }

    std::sort(result.begin(), result.end(), [](const ResourceFile& a, const ResourceFile& b) {
        if (a.extension != b.extension) {
            return a.extension < b.extension;
        }
        return a.virtualPath < b.virtualPath;
    });

    return result;
}

} // namespace osk
