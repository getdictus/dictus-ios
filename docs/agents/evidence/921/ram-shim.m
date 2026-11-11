// Test harness for the #921 captures only. Not part of any target.
//
// A simulator reports the Mac's RAM (24 GB here, docs/agents/simulator.md §1), so
// `DeviceCapabilities.current()` never reads 4 GB and the recommendation's 4 GB branch
// never runs. Injected with SIMCTL_CHILD_DYLD_INSERT_LIBRARIES, this library replaces
// -[NSProcessInfo physicalMemory] with a fixed 3.8 GB, which `readPhysicalMemoryGB()`
// rounds up to 4, the marketed tier of an iPhone 12 or 13.
//
// Build:
//   clang -dynamiclib -fobjc-arc -target arm64-apple-ios17.0-simulator \
//     -isysroot "$(xcrun --sdk iphonesimulator --show-sdk-path)" \
//     -framework Foundation ram-shim.m -o ram-shim.dylib
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static unsigned long long fakePhysicalMemory(id self, SEL _cmd) {
    return 4080218931ULL; // 3.8 GiB
}

__attribute__((constructor)) static void installRamShim(void) {
    Class cls = object_getClass([NSProcessInfo processInfo]);
    for (Class c = cls; c != Nil; c = class_getSuperclass(c)) {
        Method m = class_getInstanceMethod(c, @selector(physicalMemory));
        if (m) { method_setImplementation(m, (IMP)fakePhysicalMemory); }
    }
}
