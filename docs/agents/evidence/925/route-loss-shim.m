// Test harness for the #925 simulator check only. Not part of any target.
//
// A simulator has no AirPods and logs no route change, so the branch #925 adds cannot run
// on its own. This library posts, 200 ms after DictusApp launches, the one route change the
// device log shows: reason=unknown(0), a previous route with no input, the session's real
// current route. The keyboard's URL launch starts a new process, so the library is injected
// through the simulator's launchd rather than SIMCTL_CHILD_DYLD_INSERT_LIBRARIES.
//
// Build:
//   clang -dynamiclib -fobjc-arc -target arm64-apple-ios17.0-simulator \
//     -isysroot "$(xcrun --sdk iphonesimulator --show-sdk-path)" \
//     -framework Foundation -framework AVFAudio route-loss-shim.m -o route-loss-shim.dylib
// Use:
//   xcrun simctl spawn <udid> launchctl setenv DYLD_INSERT_LIBRARIES <path>/route-loss-shim.dylib
#import <AVFAudio/AVFAudio.h>

@interface EmptyInputRoute : AVAudioSessionRouteDescription
@end

@implementation EmptyInputRoute
- (NSArray<AVAudioSessionPortDescription *> *)inputs { return @[]; }
- (NSArray<AVAudioSessionPortDescription *> *)outputs { return @[]; }
@end

__attribute__((constructor)) static void installRouteLossShim(void) {
    if (![NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.pivi.dictus"]) { return; }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 200 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter
            postNotificationName:AVAudioSessionRouteChangeNotification
                          object:AVAudioSession.sharedInstance
                        userInfo:@{
                            AVAudioSessionRouteChangeReasonKey: @(AVAudioSessionRouteChangeReasonUnknown),
                            AVAudioSessionRouteChangePreviousRouteKey: [EmptyInputRoute new],
                        }];
    });
}
