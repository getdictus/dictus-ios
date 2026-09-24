// DictusKeyboard/HostArbiterActivation.m
#import "HostArbiterActivation.h"
#import <objc/runtime.h>

/// ## Why this is Objective-C, and why it runs before `main`
///
/// The arbiter that knows which app the keyboard is serving is switched off until
/// `+[_UIKeyboardArbiterClient enabled]` answers YES. Installing that swizzle from
/// `viewWillAppear` worked once on a device and then stopped working entirely: four
/// dictations across three host apps, `known=0` every time — the arbiter answered nothing
/// all session, while the host pid read perfectly. The same signature appeared on a
/// simulator that had been answering earlier the same day.
///
/// The surviving explanation is that UIKit decides whether the arbiter client exists
/// **once, early in the process**, and a swizzle installed at the first keyboard
/// appearance is simply late. The day it worked, the timing happened to be favourable.
/// `viewDidLoad` would be earlier but is still a view controller callback, and by then
/// UIKit has done a great deal of setting up.
///
/// A load-time constructor is the earliest point code in this binary can run. There is no
/// earlier one available to an app extension.
///
/// ## What that costs, stated plainly
///
/// **This code runs before everything else in the extension, including Swift's own
/// initialisation.** A crash here is a keyboard that never appears, on every launch, with
/// no UI to report it — the worst failure mode this product has. It is written to be
/// incapable of that:
///
/// - every step is nil-checked, and any nil is a clean return;
/// - it resolves the class by name, so nothing private is linked;
/// - it allocates one block and touches no Foundation object beyond a string constant;
/// - it cannot recurse, cannot block, and does no I/O — **do not add logging here**, the
///   logger is not initialised yet. Swift reads `loadTimeOutcome` later and logs it then.
///
/// The swizzle itself is the same one the probe validated on device. Its cost is written
/// up in `HostAppResolver.swift`: replacing a private UIKit class method's implementation
/// for the life of the process is active, not passive, and if Apple changes `+enabled` the
/// failure is not a nil. Both hops being guarded is what bounds that.

/// The class, by name. Only the underscored spelling exists — measured 85/85 on device —
/// but the un-underscored one is what the original analysis used, so both are tried.
static NSString *const kArbiterClassNameUnderscored = @"_UIKeyboardArbiterClient";
static NSString *const kArbiterClassNamePlain = @"UIKeyboardArbiterClient";
static NSString *const kEnabledSelectorName = @"enabled";

/// Whether the swizzle is in place. Only success is remembered: a failed attempt must be
/// retried later, because a class that is not loaded at constructor time may be loaded by
/// the time the keyboard first appears.
static BOOL gSwizzleInstalled = NO;

/// What the constructor produced, read back by Swift once the logger exists.
static NSString *gLoadTimeOutcome = @"not-attempted";

static Class DictusResolveArbiterClass(void) {
    Class cls = NSClassFromString(kArbiterClassNameUnderscored);
    if (cls == Nil) {
        cls = NSClassFromString(kArbiterClassNamePlain);
    }
    return cls;
}

static NSString *DictusInstallArbiterSwizzle(void) {
    if (gSwizzleInstalled) {
        return @"already";
    }

    Class cls = DictusResolveArbiterClass();
    if (cls == Nil) {
        return @"no-class";
    }

    // `class_getClassMethod` and not `class_getInstanceMethod`: `+enabled` is a class
    // method, so the implementation to replace lives on the metaclass.
    Method method = class_getClassMethod(cls, NSSelectorFromString(kEnabledSelectorName));
    if (method == NULL) {
        return @"no-method";
    }

    // A class method's block receives the class object and no _cmd.
    IMP replacement = imp_implementationWithBlock(^BOOL(id _self) {
        return YES;
    });
    method_setImplementation(method, replacement);
    gSwizzleInstalled = YES;
    return @"installed";
}

/// Runs when this binary is loaded, before `main`. See the header comment above.
__attribute__((constructor))
static void DictusActivateArbiterAtLoad(void) {
    gLoadTimeOutcome = DictusInstallArbiterSwizzle();
}

@implementation DictusHostArbiterActivation

+ (NSString *)activate {
    return DictusInstallArbiterSwizzle();
}

+ (NSString *)loadTimeOutcome {
    return gLoadTimeOutcome;
}

+ (BOOL)isInstalled {
    return gSwizzleInstalled;
}

@end
