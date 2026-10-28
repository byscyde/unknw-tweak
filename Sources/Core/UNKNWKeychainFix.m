#import "UNKNWKeychainFix.h"
#import "../UNKNW.h"
#import "../vendor/fishhook.h"
#import <Security/Security.h>

static OSStatus (*orig_SecItemAdd)(CFDictionaryRef, CFTypeRef *);
static OSStatus (*orig_SecItemCopyMatching)(CFDictionaryRef, CFTypeRef *);
static OSStatus (*orig_SecItemUpdate)(CFDictionaryRef, CFDictionaryRef);
static OSStatus (*orig_SecItemDelete)(CFDictionaryRef);

// The sideload logout happens because Instagram pins its session items to a
// shared keychain access group tied to Meta's team prefix (e.g.
// "MH9GU9K5PX.shared" / "MH9GU9K5PX.platformFamily"). After Feather re-signs,
// the app no longer holds that group's entitlement, so those reads/writes fail
// with errSecMissingEntitlement and the login never persists. We redirect ONLY
// those team-group queries to the app's own default access group by removing
// the attribute; every other keychain call is left completely untouched, so we
// don't change the semantics of unrelated lookups (which was crashing IG's
// networking layer when a lookup it relied on came back empty).
static BOOL UNKNWIsPinnedTeamGroup(CFDictionaryRef query) {
    if (!query) return NO;
    CFTypeRef ag = CFDictionaryGetValue(query, kSecAttrAccessGroup);
    if (!ag || CFGetTypeID(ag) != CFStringGetTypeID()) return NO;
    NSString *group = (__bridge NSString *)ag;
    // A pinned team group looks like "<10-char team id>.<suffix>". The app's own
    // default group (same shape) is still safe to strip: without the attribute
    // the item simply lands in that same default group.
    if ([group hasSuffix:@".shared"] || [group hasSuffix:@".platformFamily"]) return YES;
    if ([group containsString:@"com.burbn"] || [group containsString:@"com.instagram"]) return YES;
    return NO;
}

// Copy of `query` without kSecAttrAccessGroup, but ONLY when the query pins one
// of Instagram's shared team groups. Returns NULL to mean "unchanged" so the
// originals run on the caller's exact dictionary in every other case.
static CFDictionaryRef UNKNWStripAccessGroup(CFDictionaryRef query) {
    if (!UNKNWIsPinnedTeamGroup(query)) return NULL;
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
