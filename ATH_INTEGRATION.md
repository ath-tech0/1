# FF Cache Manager + ATH License — integration

## What changed

Activation now prefers the ATH Cloudflare Worker (`ath-license-bot-vip`).

| Flow | Behavior |
|------|----------|
| Key starts with `ATH-` | Always uses `/api/license/mobile-verify` |
| ATH base URL + HMAC secret configured | All keys go through ATH |
| ATH not configured + non-ATH key | Falls back to the old `/license/activate` server (if URL is re-encoded) |

On successful ATH verify the client:

1. HMAC-signs the request (`X-ATH-Timestamp`, `X-ATH-Nonce`, `X-ATH-Signature`)
2. Binds `device_id` to the existing `ZXInstallID()`
3. Stores a synthetic session (`ath_` / `athr_` tokens) so the rest of the UI keeps working
4. Unlocks local features: BODY, DRAG, NECK, CHEST, MAGIC, HOLOGRAM_GUN, SKIN_HOLO, MOD_SKINS, ESP

New source files:

- `FFATHLicense.h` / `FFATHLicense.m` — client
- `FFATHConfig.h` — base URL + HMAC secret defaults

Build scripts (`build_clean.ps1`, `build_local.ps1`) compile and link `FFATHLicense.m`.

## Deploy ATH Worker first

```powershell
cd ath-license
npm install
npx wrangler login
npx wrangler d1 migrations apply ath_license_db --remote
npx wrangler secret put TELEGRAM_BOT_TOKEN
npx wrangler secret put OWNER_TELEGRAM_ID
npx wrangler secret put API_HMAC_SECRET
npx wrangler secret put TELEGRAM_WEBHOOK_SECRET
npm run deploy
```

Copy the Worker URL (e.g. `https://ath-license-bot-vip.xxx.workers.dev`).

## Wire the app

Edit `FFATHConfig.h` (private builds only):

```objc
#define FFATH_DEFAULT_BASE_URL @"https://YOUR_WORKER.workers.dev"
#define FFATH_DEFAULT_HMAC_SECRET @"the-exact-API_HMAC_SECRET-you-set"
```

Or at launch (before any activation UI):

```objc
FFATHSetBaseURL(@"https://YOUR_WORKER.workers.dev");
FFATHSetHMACSecret(@"your-hmac-secret");
```

**Do not push real secrets to a public GitHub repo.** Use a private repo or inject via CI secrets that rewrite `FFATHConfig.h` before compile.

## Generate keys

Talk to the Telegram bot (owner account): bulk / single key generation. Keys look like `ATH-123-456-789-012`.

Device limit 1 → first successful verify binds that device. Other devices get `device_mismatch`.

## Build IPA (Windows, existing pipeline)

Same as before. Requirements unchanged: iPhoneOS14.5.sdk, llvm-mingw clang, Filza donor IPA, Python + pillow + lief.

```powershell
$env:FF_SDK = "C:\path\to\iPhoneOS14.5.sdk"
$env:FF_CLANG = "C:\path\to\llvm-mingw\bin\clang.exe"
powershell -ExecutionPolicy Bypass -File .\build_clean.ps1
```

Output: `dist\clean\FFCacheManager-CLEAN.ipa`

## GitHub Actions

See `.github/workflows/build-ipa.yml`.

Full signed IPA still needs:

- Windows runner (or self-hosted) with the SDK + clang cached
- Filza donor IPA as a secret artifact
- Optional: macOS runner + Apple cert for App Store / ad-hoc signing after the clang build

The workflow packages sources, runs static checks, and documents the Windows build step. It does not invent an SDK that is not present.

## Verify after install

1. Install IPA (ESign / TrollStore / jailbreak signer).
2. Open app → license screen.
3. Paste an `ATH-...` key from the bot.
4. Status should flip to `LICENSE ACTIVE ✓`.
5. Features that ship locally become available.

If you see `ATH base URL not configured` or `ATH HMAC secret not configured`, `FFATHConfig.h` was not filled.

## Files that must stay private

- Real `API_HMAC_SECRET`
- Real Worker URL if you treat it as sensitive
- Signing certs / provisioning profiles
- Filza donor IPA (if licensed)
