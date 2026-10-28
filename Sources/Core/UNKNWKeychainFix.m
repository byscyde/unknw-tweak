#import "UNKNWKeychainFix.h"
#import "../UNKNW.h"
#import "../vendor/fishhook.h"
#import <Security/Security.h>

static OSStatus (*orig_SecItemAdd)(CFDictionaryRef, CFTypeRef *);
static OSStatus (*orig_SecItemCopyMatching)(CFDictionaryRef, CFTypeRef *);
static OSStatus (*orig_SecItemUpdate)(CFDictionaryRef, CFDictionaryRef);
static OSStatus (*orig_SecItemDelete)(CFDictionaryRef);

// Copy of `query` without kSecAttrAccessGroup (caller releases). Returns NULL
// unchanged so the originals still handle a NULL argument themselves.
static CFDictionaryRef UNKNWStripAccessGroup(CFDictionaryRef query) {
    if (!query) return NULL;
    CFMutableDictionaryRef mutable = CFDictionaryCreateMutableCopy(NULL, 0, query);
    CFDictionaryRemoveValue(mutable, kSecAttrAccessGroup);
    return mutable;
}

static OSStatus UNKNWSecItemAdd(CFDictionaryRef attributes, CFTypeRef *result) {
    CFDictionaryRef stripped = UNKNWStripAccessGroup(attributes);
    OSStatus status = orig_SecItemAdd(stripped ?: attributes, result);
    if (stripped) CFRelease(stripped);
    return status;
}

static OSStatus UNKNWSecItemCopyMatching(CFDictionaryRef query, CFTypeRef *result) {
    CFDictionaryRef stripped = UNKNWStripAccessGroup(query);
    OSStatus status = orig_SecItemCopyMatching(stripped ?: query, result);
    if (stripped) CFRelease(stripped);
    return status;
}

static OSStatus UNKNWSecItemUpdate(CFDictionaryRef query, CFDictionaryRef attributesToUpdate) {
    CFDictionaryRef q = UNKNWStripAccessGroup(query);
    CFDictionaryRef a = UNKNWStripAccessGroup(attributesToUpdate);
    OSStatus status = orig_SecItemUpdate(q ?: query, a ?: attributesToUpdate);
    if (q) CFRelease(q);
    if (a) CFRelease(a);
    return status;
}

static OSStatus UNKNWSecItemDelete(CFDictionaryRef query) {
    CFDictionaryRef stripped = UNKNWStripAccessGroup(query);
    OSStatus status = orig_SecItemDelete(stripped ?: query);
    if (stripped) CFRelease(stripped);
    return status;
}

void UNKNWInstallKeychainFix(void) {
    static BOOL installed = NO;
    if (installed) return;
    installed = YES;
    rebind_symbols((struct rebinding[]){
        {"SecItemAdd",          (void *)UNKNWSecItemAdd,          (void **)&orig_SecItemAdd},
        {"SecItemCopyMatching", (void *)UNKNWSecItemCopyMatching, (void **)&orig_SecItemCopyMatching},
        {"SecItemUpdate",       (void *)UNKNWSecItemUpdate,       (void **)&orig_SecItemUpdate},
        {"SecItemDelete",       (void *)UNKNWSecItemDelete,       (void **)&orig_SecItemDelete},
    }, 4);
    UNKNWLog(@"keychain login fix installed");
}
