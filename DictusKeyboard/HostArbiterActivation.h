// DictusKeyboard/HostArbiterActivation.h
// Switches the private keyboard arbiter on, as early in the process as code can run.
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Installs the `+[_UIKeyboardArbiterClient enabled]` swizzle and reports what happened.
///
/// **This runs at load time**, from a `__attribute__((constructor))` in the .m — before
/// `main`, before any view controller exists, before Swift has initialised anything. That
/// is deliberate and it is the point of the file: see the .m for why `viewWillAppear` and
/// even `viewDidLoad` are too late.
///
/// Safe to call again. The swizzle is installed at most once; a *failed* attempt is not
/// remembered, so a later call retries — a class that was not yet loaded at constructor
/// time can be loaded by the time the keyboard appears.
@interface DictusHostArbiterActivation : NSObject

/// Installs the swizzle if it is not already installed, and returns the outcome:
/// `installed`, `already`, `no-class` or `no-method`.
+ (NSString *)activate;

/// What the load-time constructor produced, without attempting anything now.
/// `not-attempted` if the constructor never ran, which should be impossible.
+ (NSString *)loadTimeOutcome;

/// Whether the swizzle is currently installed.
+ (BOOL)isInstalled;

@end

NS_ASSUME_NONNULL_END
