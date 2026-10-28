// UNKNWKeychainFix — keep the login session across relaunches on a sideloaded
// (re-signed) install.
//
// Instagram stores its session in a keychain item scoped to Meta's team via
// kSecAttrAccessGroup. After re-signing with the user's certificate, that group
// is unreachable, so the item can't be read back and the app logs out on every
// launch. This rebinds the four SecItem* functions (via fishhook) and removes
// the explicit access group from each query, so items land in — and are read
// from — the app's own default access group, which is stable across launches.
//
// This is original, general code based on how iOS keychain groups work; it does
// not reproduce any other tweak.

#import <Foundation/Foundation.h>

void UNKNWInstallKeychainFix(void);
