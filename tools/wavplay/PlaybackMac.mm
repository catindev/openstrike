#include "Playback.h"

#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

bool playWaveFile(const std::filesystem::path& path, std::string& error) {
    @autoreleasepool {
        const std::string pathText = path.string();
        NSString* nsPath = [NSString stringWithUTF8String:pathText.c_str()];
        if (nsPath == nil) {
            error = "failed to convert WAV path to NSString";
            return false;
        }

        NSURL* url = [NSURL fileURLWithPath:nsPath];
        NSError* nsError = nil;
        AVAudioPlayer* player = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&nsError];
        if (player == nil) {
            NSString* message = [nsError localizedDescription];
            error = message != nil ? [message UTF8String] : "AVAudioPlayer failed to open WAV file";
            return false;
        }

        if (![player prepareToPlay] || ![player play]) {
            error = "AVAudioPlayer failed to start playback";
            [player release];
            return false;
        }

        while ([player isPlaying]) {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                     beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
        }

        [player release];
        return true;
    }
}
