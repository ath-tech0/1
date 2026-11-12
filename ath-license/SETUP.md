# ATH License Bot — hardened setup

This is for an authorized app/service license system only. It does not control exploits, injection, third-party app containers, or arbitrary shell commands.

## Deploy

```powershell
npm install
npx wrangler login
npx wrangler d1 migrations apply ath_license_db --remote
npx wrangler secret put TELEGRAM_BOT_TOKEN
npx wrangler secret put OWNER_TELEGRAM_ID
npx wrangler secret put API_HMAC_SECRET
npx wrangler secret put TELEGRAM_WEBHOOK_SECRET
npm run deploy
```

Use a long random value for `API_HMAC_SECRET` and `TELEGRAM_WEBHOOK_SECRET`. Do not put secrets in source, `wrangler.toml`, Git, or chat.

## Webhook

If the Worker URL is `https://YOUR_WORKER.workers.dev` and your webhook secret is `YOUR_WEBHOOK_SECRET`, set it locally:

```powershell
$token = Read-Host "Paste bot token"
$secret = Read-Host "Paste webhook secret"
curl.exe -X POST "https://api.telegram.org/bot$token/setWebhook" -d "url=https://YOUR_WORKER.workers.dev/telegram/webhook/$secret" -d "secret_token=$secret"
```

## Bot behavior

- Bulk generation is capped at 100 keys per request.
- Bulk keys are returned as a `.txt` document.
- A 1-device key binds to the first valid `device_id` used at `/api/license/verify`.
- A different device receives `device_mismatch`.
- Reset and revoke require `/confirm ID` within two minutes.
- Resellers can only access keys created by themselves or descendants.
- `/api/license/verify` requires HMAC headers, a fresh timestamp, a unique nonce, and rejects replayed requests.
- Telegram webhook requests require the configured secret-token header.

## API request signing

Sign this exact UTF-8 string with HMAC-SHA256 using `API_HMAC_SECRET`:

```text
<unix_timestamp>\n<random_nonce>\n<raw_json_body>
```

Send:

```text
X-ATH-Timestamp
X-ATH-Nonce
X-ATH-Signature
```

Example JSON body:

```json
{"key":"ATH-123-456-789-012","device_id":"your-app-install-id"}
```

The response contains `X-ATH-Response-Signature`, which signs the exact JSON response body. Keep the API secret only in your authorized server; never ship it in a public mobile client.
