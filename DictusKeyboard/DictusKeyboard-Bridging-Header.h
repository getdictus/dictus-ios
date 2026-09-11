// DictusKeyboard-Bridging-Header.h
// Bridges ObjC++ types to Swift for the DictusKeyboard target.
#import "AOSPTrieBridge.h"
#import "TextProxyIdentity.h"
#import "HostArbiterActivation.h"
// #23 candidate B probe. `proc_pidpath` is exported by libSystem on iOS but its header,
// <libproc.h>, ships only in the macOS SDK — so the prototype is declared here rather
// than imported. Declaring it is what makes the call reachable from Swift at all; whether
// the sandbox then allows it for another process is the thing being measured, and the
// probe logs the errno either way.
#import <sys/param.h>
int proc_pidpath(int pid, void *buffer, uint32_t buffersize);
