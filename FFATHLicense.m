// lang: ObjC, file: FFATHLicense.m, target: iOS 15+, ATH license client
// HMAC-SHA256 request signing for /api/license/mobile-verify
// Detection surface: network to Worker; no kernel/EDR impact.

#import "FFATHLicense.h"
#import "FFATHConfig.h"
#import <CommonCrypto/CommonHMAC.h>
#import <Security/Security.h>
#import <UIKit/UIKit.h>

static NSString *gATHBaseURL = nil;
static NSString *gATHHMACSecret = nil;

static NSString *const kATHKeychainService = @"ff.ath.license";
static NSString *const kATHKeyAccount = @"ath_license_key";
static NSString *const kATHTokenAccount = @"ath_access_token";
static NSString *const kATHDefaultsValidUntil = @"FFATHValidUntil";
static NSString *const kATHDefaultsLastResult = @"FFATHLastResultJSON";

// Soft cache: re-verify after this many seconds of wall time.
static const NSTimeInterval kATHCacheWindow = 6 * 60 * 60;

#pragma mark - helpers

static NSString *FFATHHex(NSData *data) {
    const unsigned char *b = data.bytes;
    NSMutableString *s = [NSMutableString stringWithCapacity:data.length * 2];
    for (NSUInteger i = 0; i < data.length; i++) [s appendFormat:@"%02x", b[i]];
    return s;
}

static NSString *FFATHHMACSHA256(NSString *secret, NSString *message) {
    if (!secret.length || !message.length) return @"";
    const char *key = secret.UTF8String;
    const char *msg = message.UTF8String;
    unsigned char mac[CC_SHA256_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA256, key, strlen(key), msg, strlen(msg), mac);
    return FFATHHex([NSData dataWithBytes:mac length:CC_SHA256_DIGEST_LENGTH]);
}

static NSString *FFATHNonce(void) {
    uint8_t buf[16];
    (void)SecRandomCopyBytes(kSecRandomDefault, sizeof(buf), buf);
    return FFATHHex([NSData dataWithBytes:buf length:sizeof(buf)]);
}

static NSError *FFATHError(NSInteger code, NSString *msg) {
    return [NSError errorWithDomain:@"FFATHLicense"
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: msg ?: @"ATH error"}];
}

static BOOL FFATHKeychainWrite(NSString *account, NSString *value) {
    if (!account.length) return NO;
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: kATHKeychainService,
        (__bridge id)kSecAttrAccount: account
    };
    SecItemDelete((__bridge CFDictionaryRef)query);
    if (!value.length) return YES;
    NSDictionary *add = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: kATHKeychainService,
        (__bridge id)kSecAttrAccount: account,
        (__bridge id)kSecValueData: [value dataUsingEncoding:NSUTF8StringEncoding],
        (__bridge id)kSecAttrAccessible: (__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    };
    return SecItemAdd((__bridge CFDictionaryRef)add, NULL) == errSecSuccess;
}

static NSString *FFATHKeychainRead(NSString *account) {
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: kATHKeychainService,
        (__bridge id)kSecAttrAccount: account,
        (__bridge id)kSecReturnData: @YES,
        (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitOne
    };
    CFTypeRef out = NULL;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)query, &out) != errSecSuccess || !out) return nil;
    NSData *data = (__bridge_transfer NSData *)out;
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

#pragma mark - public config

NSString *FFATHBaseURL(void) {
    if (gATHBaseURL.length) return gATHBaseURL;
    return FFATH_DEFAULT_BASE_URL;
}

void FFATHSetBaseURL(NSString *url) {
    gATHBaseURL = [url stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    while ([gATHBaseURL hasSuffix:@"/"]) {
        gATHBaseURL = [gATHBaseURL substringToIndex:gATHBaseURL.length - 1];
    }
}

NSString *FFATHHMACSecret(void) {
    if (gATHHMACSecret.length) return gATHHMACSecret;
    return FFATH_DEFAULT_HMAC_SECRET;
}

void FFATHSetHMACSecret(NSString *secret) {
    gATHHMACSecret = [secret copy];
}

NSString *FFATHDeviceID(void) {
    // Prefer existing install id if the main binary exports it via user defaults /
    // keychain pattern used by ZXInstallID. Fall back to identifierForVendor.
    NSString *cached = [[NSUserDefaults standardUserDefaults] stringForKey:@"FFInstallID"];
    if (cached.length) return cached;
    NSString *vendor = UIDevice.currentDevice.identifierForVendor.UUIDString;
    if (vendor.length) {
        [[NSUserDefaults standardUserDefaults] setObject:vendor forKey:@"FFInstallID"];
        return vendor;
    }
    return @"unknown-device";
}

#pragma mark - session helpers

void FFATHPersistSuccess(NSString *licenseKey, NSDictionary *serverResult) {
    FFATHKeychainWrite(kATHKeyAccount, licenseKey);
    NSString *token = [NSString stringWithFormat:@"ath_%@", licenseKey];
    FFATHKeychainWrite(kATHTokenAccount, token);
    NSTimeInterval until = [NSDate date].timeIntervalSince1970 + kATHCacheWindow;
    [[NSUserDefaults standardUserDefaults] setDouble:until forKey:kATHDefaultsValidUntil];
    if (serverResult) {
        NSData *json = [NSJSONSerialization dataWithJSONObject:serverResult options:0 error:nil];
        if (json) {
            NSString *s = [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
            [[NSUserDefaults standardUserDefaults] setObject:s forKey:kATHDefaultsLastResult];
        }
    }
}

void FFATHClear(void) {
    FFATHKeychainWrite(kATHKeyAccount, nil);
    FFATHKeychainWrite(kATHTokenAccount, nil);
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kATHDefaultsValidUntil];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kATHDefaultsLastResult];
}

BOOL FFATHHasCachedValidLicense(void) {
    NSTimeInterval until = [[NSUserDefaults standardUserDefaults] doubleForKey:kATHDefaultsValidUntil];
    if (until <= 0) return NO;
    if ([NSDate date].timeIntervalSince1970 > until) return NO;
    return FFATHKeychainRead(kATHTokenAccount).length > 0;
}

NSDictionary *FFATHSyntheticSessionResponse(NSString *licenseKey, NSDictionary *serverResult) {
    NSString *token = [NSString stringWithFormat:@"ath_%@", licenseKey ?: @""];
    NSString *refresh = [NSString stringWithFormat:@"athr_%@", licenseKey ?: @""];
    id expires = serverResult[@"expires_at"];
    NSMutableDictionary *license = [@{
        @"key": licenseKey ?: @"",
        @"status": serverResult[@"status"] ?: @"active",
        @"feature": serverResult[@"feature"] ?: @"premium_access",
        @"device_limit": serverResult[@"device_limit"] ?: @"unlimited",
        @"package": serverResult[@"package"] ?: @"FF Cache Manager"
    } mutableCopy];
    if (expires) license[@"expires_at"] = expires;

    // Unlock every local feature the binary already ships.
    NSDictionary *features = @{
        @"BODY": @YES,
        @"DRAG": @YES,
        @"NECK": @YES,
        @"CHEST": @YES,
        @"MAGIC": @YES,
        @"HOLOGRAM_GUN": @YES,
        @"THREE_D": @YES,
        @"SKIN_HOLO": @YES,
        @"MOD_SKINS": @YES,
        @"ESP": @YES,
        @"body": @YES,
        @"drag": @YES,
        @"neck": @YES,
        @"chest": @YES,
        @"magic": @YES,
        @"hologram_gun": @YES,
        @"three_d": @YES,
        @"skin_holo": @YES,
        @"mod_skins": @YES,
        @"esp": @YES
    };

    return @{
        @"ok": @YES,
        @"valid": @YES,
        @"status": @"active",
        @"message": serverResult[@"message"] ?: @"License active",
        @"session": @{
            @"access_token": token,
            @"refresh_token": refresh,
            @"token_type": @"ath"
        },
        @"license": license,
        @"device": @{
            @"installation_id": FFATHDeviceID(),
            @"bound": @YES
        },
        @"features": features,
        @"ath": serverResult ?: @{}
    };
}

#pragma mark - network

void FFATHVerifyLicense(NSString *licenseKey,
                        void (^completion)(NSDictionary * _Nullable, NSError * _Nullable)) {
    if (!completion) return;

    NSString *trimmed = [licenseKey stringByTrimmingCharactersInSet:
                         NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!trimmed.length) {
        completion(nil, FFATHError(35, @"Enter the ATH license key."));
        return;
    }

    NSString *base = FFATHBaseURL();
    NSString *secret = FFATHHMACSecret();
    if (!base.length || [base containsString:@"example.workers.dev"]) {
        completion(nil, FFATHError(40, @"ATH base URL not configured. Set FFATHSetBaseURL after deploy."));
        return;
    }
    if (!secret.length) {
        completion(nil, FFATHError(41, @"ATH HMAC secret not configured. Set FFATHSetHMACSecret."));
        return;
    }

    NSString *deviceID = FFATHDeviceID();
    NSDictionary *bodyObj = @{
        @"key": trimmed,
        @"device_id": deviceID
    };
    NSError *jsonErr = nil;
    NSData *bodyData = [NSJSONSerialization dataWithJSONObject:bodyObj options:0 error:&jsonErr];
    if (!bodyData || jsonErr) {
        completion(nil, FFATHError(42, @"Failed to encode verify payload."));
        return;
    }
    NSString *bodyStr = [[NSString alloc] initWithData:bodyData encoding:NSUTF8StringEncoding] ?: @"";

    NSString *ts = [NSString stringWithFormat:@"%.0f", floor([NSDate date].timeIntervalSince1970)];
    NSString *nonce = FFATHNonce();
    NSString *toSign = [NSString stringWithFormat:@"%@\n%@\n%@", ts, nonce, bodyStr];
    NSString *sig = FFATHHMACSHA256(secret, toSign);

    NSURL *url = [NSURL URLWithString:[base stringByAppendingString:@"/api/license/mobile-verify"]];
    if (!url) {
        completion(nil, FFATHError(43, @"Invalid ATH base URL."));
        return;
    }

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"POST";
    req.HTTPBody = bodyData;
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [req setValue:ts forHTTPHeaderField:@"X-ATH-Timestamp"];
    [req setValue:nonce forHTTPHeaderField:@"X-ATH-Nonce"];
    [req setValue:sig forHTTPHeaderField:@"X-ATH-Signature"];
    req.timeoutInterval = 25.0;

    NSURLSessionDataTask *task = [[NSURLSession sharedSession]
        dataTaskWithRequest:req
          completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            completion(nil, error);
            return;
        }
        NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
        NSDictionary *json = nil;
        if (data.length) {
            json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        }
        if (![json isKindOfClass:NSDictionary.class]) {
            completion(nil, FFATHError(http.statusCode ?: 50, @"ATH response is not JSON."));
            return;
        }

        BOOL valid = [json[@"valid"] boolValue];
        NSString *status = [json[@"status"] isKindOfClass:NSString.class] ? json[@"status"] : @"";

        if (!valid) {
            NSString *msg = status.length ? status : (json[@"error"] ?: @"License rejected");
            if ([msg isEqualToString:@"device_mismatch"]) {
                msg = @"This key is bound to another device.";
            } else if ([msg isEqualToString:@"device_limit_reached"]) {
                msg = @"Device limit reached for this key.";
            } else if ([msg isEqualToString:@"expired"] || [msg isEqualToString:@"revoked"]) {
                msg = [NSString stringWithFormat:@"License %@", msg];
            }
            completion(nil, FFATHError(http.statusCode ?: 403, msg));
            return;
        }

        FFATHPersistSuccess(trimmed, json);
        NSDictionary *synthetic = FFATHSyntheticSessionResponse(trimmed, json);
        completion(synthetic, nil);
    }];
    [task resume];
}
