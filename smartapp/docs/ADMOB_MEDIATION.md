# AdMob Mediation — Smartapp

This app uses [AdMob Mediation](https://developers.google.com/admob/flutter/mediation) with three bidding/waterfall partners:

| Partner | Flutter package | Docs |
|--------|-----------------|------|
| Meta Audience Network (bidding) | `gma_mediation_meta` | [Integrate Meta](https://developers.google.com/admob/flutter/mediation/meta) |
| Liftoff Monetize | `gma_mediation_liftoffmonetize` | [Integrate Liftoff](https://developers.google.com/admob/flutter/mediation/liftoff-monetize) |
| Mintegral | `gma_mediation_mintegral` | [Integrate Mintegral](https://developers.google.com/admob/flutter/mediation/mintegral) |

SDK integration in this repo is complete. **Mediation only serves partner ads after you configure each network in AdMob and on the partner dashboards.**

---

## Ad formats in this app

| Format | Where used | Config key (`.env`) |
|--------|------------|---------------------|
| **Banner** | Home / top banner (`AdController`, `PremiumAwareBannerAd`) | `ADMOB_*_BANNER_ID` |
| **MREC (300×250)** | Streaming tab (`StreamingMrecAd`) | `ADMOB_*_MREC_ID` |
| **Interstitial** | After TV connection (`AdController`) | `ADMOB_*_INTERSTITIAL_ID` |
| **Rewarded** | Wallpaper unlock, media cast | `ADMOB_*_REWARDED_ID` |
| **App open** | Cold start + return from background (`AppOpenAdService`) | `ADMOB_*_APP_OPEN_ID` |

Native ads are **not** used in the Flutter UI today. You can still add Meta/Mintegral/Liftoff native placements in AdMob for future use.

---

## AdMob app & ad unit IDs

Publisher ID: `pub-3605518487927639`

### Android

| Item | ID |
|------|-----|
| App ID | `ca-app-pub-3605518487927639~9868448476` |
| Banner | `ca-app-pub-3605518487927639/9209972929` |
| Interstitial | `ca-app-pub-3605518487927639/5270727918` |
| Rewarded | `ca-app-pub-3605518487927639/7238415706` |
| MREC | `ca-app-pub-3605518487927639/2257551761` |
| App open | `ca-app-pub-3605518487927639/4595940497` |

Package: `com.FutureDialLabs.tv.remote.universal.control`

### iOS

| Item | ID |
|------|-----|
| App ID | `ca-app-pub-3605518487927639~7530935451` |
| Banner | `ca-app-pub-3605518487927639/1803221192` |
| Interstitial | `ca-app-pub-3605518487927639/1125309209` |
| Rewarded | `ca-app-pub-3605518487927639/6804266435` |
| MREC | `ca-app-pub-3605518487927639/3591690443` |
| App open | `ca-app-pub-3605518487927639/8293352784` |

IDs are loaded from `.env` via `lib/config/admob_config.dart`. Set `ADMOB_TEST_MODE=true` to use Google test ad units.

---

## AdMob mediation checklist (per ad unit)

For **each** production ad unit above (banner, interstitial, rewarded, MREC, app open), on **both** Android and iOS:

- [ ] Open **AdMob → Mediation → Mediation groups** (or ad unit → mediation)
- [ ] Add ad sources:
  - [ ] **Meta Audience Network (Bidding)**
  - [ ] **Liftoff Monetize (Bidding)** — and/or Waterfall if you use it
  - [ ] **Mintegral (Bidding)** — and/or Waterfall if you use it
- [ ] Enter partner credentials from their dashboards (Placement ID, App ID, etc.)
- [ ] Save and wait for status **Ready** (can take up to an hour)

### Ad format notes for partners

| Format | Meta | Liftoff | Mintegral |
|--------|------|---------|-----------|
| Banner | Medium rectangle / 50–250 height; no adaptive | Banner or MREC placement | Standard banner sizes |
| Interstitial | Supported | Interstitial + skippable for app-open style | Interstitial |
| Rewarded | Supported | Rewarded (+ contact Liftoff for rewarded interstitial) | Rewarded |
| App open | — | Use **Interstitial** placement, skippable **Yes**, In-App Bidding on | App open supported |
| MREC | Use banner placement | **MREC** placement | Banner |

**Banner refresh:** Disable auto-refresh on third-party network UIs for banner/MREC units used in AdMob mediation (AdMob controls refresh).

---

## Partner dashboard checklist

### Meta Audience Network (bidding only)

- [ ] [Business Manager](https://business.facebook.com/) — create property for this app (Android + iOS)
- [ ] Mediation platform: **Google AdMob**
- [ ] Create placements per format; copy **Placement ID** into AdMob Meta mapping
- [ ] [app-ads.txt](https://developers.facebook.com/docs/audience-network/optimization/best-practices/authorized-sellers-app-ads) on your developer website
- [ ] Test mode off before release
- [ ] **Testing:** Facebook app installed + logged in on device; [test guide](https://developers.facebook.com/docs/audience-network/guides/test)

### Liftoff Monetize

- [ ] [Dashboard](https://publisher.vungle.com/) — add application (Android + iOS); note **App ID**
- [ ] Create **new** placements for mediation (not only “default”); enable **In-App Bidding** where required
- [ ] Copy **Reference ID** per placement into AdMob
- [ ] Waterfall only: **Reporting API Key** in AdMob
- [ ] Append Liftoff lines to [app-ads.txt](https://support.vungle.com/hc/en-us/articles/360047771052)
- [ ] Placement test mode: **Show test ads only** while testing

### Mintegral

- [ ] [Mintegral](https://www.mintegral.com/) — APP Key, App ID (Android/iOS)
- [ ] **Placements & Units** — per format; bidding: **Header Bidding**
- [ ] Placement ID + Ad Unit ID into AdMob
- [ ] Waterfall only: **Skey** + **Secret** (Reporting API)
- [ ] [app-ads.txt](https://www.mintegral.com/en/app-ads-txt/)
- [ ] Native (if ever used): format **Native (Custom Rendering)**

---

## Privacy & compliance (AdMob UI)

- [ ] **GDPR** — [European regulations](https://support.google.com/admob/answer/10114039): add **Meta**, **Liftoff**, **Mobvista/Mintegral**
- [ ] **US state laws** — same partners in US state regulations list
- [ ] Use **UMP SDK** if you show a consent form (recommended for EEA)
- [ ] iOS: `NSUserTrackingUsageDescription` is set in `ios/Runner/Info.plist`
- [ ] Propagate consent to Meta per [their GDPR guidance](https://developers.facebook.com/docs/audience-network/guides/gdpr)
- [ ] Liftoff CCPA (optional API): `GmaMediationLiftoffmonetize.setCCPAStatus()` — see [Liftoff doc](https://developers.google.com/admob/flutter/mediation/liftoff-monetize)

---

## Code integration (already in repo)

| File | Purpose |
|------|---------|
| `pubspec.yaml` | `google_mobile_ads ^8.0.0` + three `gma_mediation_*` packages |
| `lib/services/ad_mediation.dart` | Links mediation plugins in release builds |
| `lib/services/mobile_ads_service.dart` | `MobileAds.initialize()` + adapter status logs |
| `android/build.gradle.kts` | Mintegral Maven repository |
| `ios/Runner/Info.plist` | SKAdNetwork IDs (Google, Meta, Liftoff, Mintegral) |

Initialization runs from `main.dart` → `_initializeMobileAds()` after first frame.

### Debug logs

```
[ADS] Mediation adapter com.google.ads.mediation.meta...: ...
[ADS] banner served by mediation adapter: ...
```

Use **AdMob Ad Inspector** → **Verify adapter integrations** and **single ad source testing** per network.

---

## Testing checklist

- [ ] Register test devices in AdMob
- [ ] `ADMOB_TEST_MODE=false` when testing real mediation (or `true` for Google-only test units)
- [ ] Partner test modes enabled only during QA
- [ ] Confirm adapter **Ready** in startup logs
- [ ] Ad Inspector: test **Meta (Bidding)**, **Liftoff**, **Mintegral** one at a time
- [ ] Disable all test modes before store release

---

## Troubleshooting

| Issue | What to check |
|-------|----------------|
| Partner never wins auction | AdMob mediation mapping, placement IDs, bidding enabled on partner side |
| Meta loads fail (101) | Missing Placement ID in AdMob |
| Android build: Mintegral 403 | `dl-maven-android.mintegral.com` repo in `android/build.gradle.kts` |
| iOS pod errors | `cd ios && LANG=en_US.UTF-8 pod install --repo-update` |
| No fill from partner | New placements, test mode, GDPR partner list, app-ads.txt |

Official guides: [Mediation overview](https://developers.google.com/admob/flutter/mediation) · [Troubleshoot ads](https://developers.google.com/admob/flutter/troubleshoot-ad-load-errors)
