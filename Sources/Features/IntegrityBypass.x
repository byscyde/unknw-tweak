// Integrity / attestation bypass — the enabler that makes a sideloaded
// (re-signed) Instagram stable, the same thing Regram implements as
// "Block Attestation".
//
// A re-signed app cannot produce a valid Apple App Attest assertion. When
// Instagram asks DCAppAttestService to attest the device identity, the attest
// fails, and Instagram's handling of that failure takes down its networking /
// device-identity layer on a background thread (the uncaught NSException seen in
// distribgw/connectivity). Telling Instagram that App Attest is simply
// unavailable — and failing any attest/assertion call gracefully — makes it skip
// that path entirely, exactly as on a device where App Attest isn't offered.
//
// These are all standard, documented DeviceCheck APIs; we only change what our
// own process is told about its own attestation support.

#import "../UNKNW.h"
#import <dlfcn.h>

static NSError *UNKNWAttestUnavailable(void) {
    // DCErrorFeatureUnsupported == 1 — the same error iOS returns when App
    // Attest is not available, so Instagram follows its normal fallback.
    return [NSError errorWithDomain:@"com.apple.devicecheck.error" code:1 userInfo:nil];
}

%group UNKNWIntegrityBypass

%hook DCAppAttestService

- (BOOL)isSupported {
    return NO;
}

- (void)generateKeyWithCompletionHandler:(void (^)(NSString *keyId, NSError *error))completion {
    if (completion) completion(nil, UNKNWAttestUnavailable());
}

- (void)attestKey:(NSString *)keyId
    clientDataHash:(NSData *)clientDataHash
 completionHandler:(void (^)(NSData *attestationObject, NSError *error))completion {
    if (completion) completion(nil, UNKNWAttestUnavailable());
}

- (void)generateAssertion:(NSString *)keyId
           clientDataHash:(NSData *)clientDataHash
        completionHandler:(void (^)(NSData *assertionObject, NSError *error))completion {
    if (completion) completion(nil, UNKNWAttestUnavailable());
}

%end

%end

void UNKNWInitIntegrityBypass(void) {
    // DeviceCheck is loaded lazily; make sure the class exists before we hook it.
    dlopen("/System/Library/Frameworks/DeviceCheck.framework/DeviceCheck", RTLD_NOW);
    %init(UNKNWIntegrityBypass);
    UNKNWLog(@"integrity/attestation bypass installed");
}
