// lang: ObjC, file: FFATHConfig.h
// Fill these AFTER you deploy ath-license Worker. Do not commit real secrets to a public repo.
// Private builds: set real values here, or call FFATHSetBaseURL / FFATHSetHMACSecret at launch.

#ifndef FFATH_CONFIG_H
#define FFATH_CONFIG_H

// Deployed Worker URL, no trailing slash.
// Example: https://ath-license-bot-vip.your-account.workers.dev
#ifndef FFATH_DEFAULT_BASE_URL
#define FFATH_DEFAULT_BASE_URL @"https://ath-license-bot.example.workers.dev"
#endif

// Must match the Worker secret API_HMAC_SECRET exactly.
// Leave empty in public trees; set for private release builds only.
#ifndef FFATH_DEFAULT_HMAC_SECRET
#define FFATH_DEFAULT_HMAC_SECRET @""
#endif

#endif
