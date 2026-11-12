// lang: ObjC, file: FFATHLicense.h, target: iOS 15+, ATH license client
// Connects Free Fire Cache Manager activation to ath-license-bot /api/license/mobile-verify

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Base URL of the deployed Cloudflare Worker (no trailing slash).
/// Example: https://ath-license-bot.YOUR_SUBDOMAIN.workers.dev
FOUNDATION_EXPORT NSString *FFATHBaseURL(void);

/// Set after you deploy the worker. Leave empty and the client reports misconfiguration.
FOUNDATION_EXPORT void FFATHSetBaseURL(NSString *url);

/// HMAC secret matching the Worker secret API_HMAC_SECRET.
/// Obfuscated at rest; never commit the real value in a public repo.
FOUNDATION_EXPORT NSString *FFATHHMACSecret(void);
FOUNDATION_EXPORT void FFATHSetHMACSecret(NSString *secret);

/// Device id used for binding (maps to ZXInstallID / installation_id).
FOUNDATION_EXPORT NSString *FFATHDeviceID(void);

/// POST /api/license/mobile-verify with HMAC headers.
/// On success: completion(responseDict, nil). responseDict is shaped for applySessionResponse.
/// On failure: completion(nil, NSError).
FOUNDATION_EXPORT void FFATHVerifyLicense(NSString *licenseKey,
                                          void (^completion)(NSDictionary * _Nullable response,
                                                             NSError * _Nullable error));

/// True if the last successful verify is still within soft cache window.
FOUNDATION_EXPORT BOOL FFATHHasCachedValidLicense(void);

/// Persist / clear local ATH session markers (keychain + defaults).
FOUNDATION_EXPORT void FFATHPersistSuccess(NSString *licenseKey, NSDictionary *serverResult);
FOUNDATION_EXPORT void FFATHClear(void);

/// Build the synthetic session payload the rest of main.m expects after activate.
FOUNDATION_EXPORT NSDictionary *FFATHSyntheticSessionResponse(NSString *licenseKey,
                                                              NSDictionary *serverResult);

NS_ASSUME_NONNULL_END
