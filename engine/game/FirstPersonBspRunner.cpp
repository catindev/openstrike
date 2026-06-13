#include "game/FirstPersonBspRunner.h"

#include <iostream>

#if !defined(__APPLE__)

namespace osk::game {

int runFirstPersonBsp(const FirstPersonBspOptions& options) {
    const char* logName = options.logName.empty() ? "OpenStrike" : options.logName.c_str();
    std::cerr << logName << " error: first-person BSP view is currently available only on macOS.\n";
    return 1;
}

} // namespace osk::game

#endif
