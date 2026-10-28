// Minimal CydiaSubstrate shim for jailed (sideloaded) injection.
//
// UNKNW's logos %hook directives compile down to a single substrate entry
// point, MSHookMessageEx, which swaps an Objective-C method implementation in
// the current process. On a non-jailbroken device there is no system-wide
// Substrate, so this self-contained dylib provides that symbol (and the two
// common image/symbol helpers) using only the public Objective-C runtime and
// dyld. It performs no code injection of its own — it is loaded into the app by
// the injected load command and simply offers the hooking primitive in-process.
//
// Built as CydiaSubstrate.framework/CydiaSubstrate with install name
// @rpath/CydiaSubstrate.framework/CydiaSubstrate so the injected UNKNW.dylib
// resolves it from the app's Frameworks directory.

#import <objc/runtime.h>
#import <dlfcn.h>

#define EXPORT __attribute__((visibility("default")))

// Replace the implementation of `sel` on `cls` with `replacement`, returning the
// previous implementation in `*result` so %orig keeps working. Mirrors the
// classic MobileSubstrate semantics for Objective-C methods.
EXPORT void MSHookMessageEx(Class cls, SEL sel, IMP replacement, IMP *result) {
    if (!cls || !sel) {
        if (result) *result = NULL;
        return;
    }
    Method method = class_getInstanceMethod(cls, sel);
    if (!method) {
        if (result) *result = NULL;
        return;
    }
    const char *types = method_getTypeEncoding(method);
    IMP previous = method_getImplementation(method);

    // If the method is inherited, add it to this class so %orig reaches the
    // original (super) implementation; otherwise swap in place.
    if (class_addMethod(cls, sel, replacement, types)) {
        if (result) *result = previous;
    } else {
        IMP swapped = method_setImplementation(method, replacement);
        if (result) *result = swapped ? swapped : previous;
    }
}

// Return a handle for an already-loaded image (Substrate-compatible).
EXPORT void *MSGetImageByName(const char *name) {
    return dlopen(name, RTLD_NOLOAD | RTLD_LAZY);
}

// Resolve a symbol; accepts the leading-underscore form Substrate callers use.
EXPORT void *MSFindSymbol(void *image, const char *name) {
    if (!name) return NULL;
    const char *stripped = (name[0] == '_') ? name + 1 : name;
    return dlsym(image ? image : RTLD_DEFAULT, stripped);
}
