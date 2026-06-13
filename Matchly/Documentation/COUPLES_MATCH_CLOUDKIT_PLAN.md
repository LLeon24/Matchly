# Couples Matching — CloudKit Sharing (CKShare) + Real Auth Implementation Plan

**Status:** Planning. No Swift code has been changed by this document.
**Goal:** Turn Matchly's Couples Matching prototype into a real feature where two people link accounts and build a JOINT, NRMP-style rank list (each rank = a PAIR, one program per partner, either side can be "No Match"), backed by CloudKit sharing and a stable identity. No backend server.

---

## 0. Current state (what we're replacing)

- **Linking is faked.** `LinkPartnerView.linkPartner()` and `createCouple()` in `CouplesMatchingView.swift` set `user2ID = UUID().uuidString` and `user2Name = "Partner"`. Nothing ever reaches a second device.
- **Search/invites are mocked.** `UserSearchView` / `InviteManagementView` operate on local `dataManager.preferences.sentInvites/receivedInvites`; a `CoupleInvite` never leaves the device.
- **Deep link is dead.** `Couple.generateInviteLink` produces `matchly://couple/invite/{code}` but there's no URL scheme registered and no `onOpenURL`/scene handler. `MatchlyApp.swift` is a bare `WindowGroup { SplashView() }`.
- **Paired list is single-sided.** `CouplesRankListView.user2Programs` is hardcoded `[]`, so partner programs can never be selected.
- **Persistence is private.** `CloudSyncManager` uses `NSUbiquitousKeyValueStore` (KVS) + `UserDefaults`, scoped to a single iCloud account. No CloudKit container, no `CKShare`.
- **Auth is a local stub.** `AuthManager.signInWithEmail` mints a fresh `UUID()` on every call (unstable IDs); Apple Sign In is real but the identity token/nonce is unverified and credential state is never re-checked on launch.

**Data model is already adequate and is NOT changing in shape:** `Couple`, `CoupleInvite`, `CouplesRankPair` (`user1ProgramID`, `user2ProgramID`, `user1NoMatch`, `user2NoMatch`, `notes`, `rank`), `CouplesPreferences` (`geographicPriority`, `distanceTolerance`, `mustMatchTogether`). `Program` carries `name`, `hospital`, `city`, `state`, `address`; coordinates are derived on demand via `GeocodingHelper.coordinate(for:city:state:)` (Program does NOT persist lat/long).

---

## 1. Identity & Auth

**Recommendation: Sign in with Apple for login + CloudKit user record ID as the stable internal identity.** Stop minting UUIDs entirely for the user.

### Why
- Email/password (the current stub, and the Firebase TODOs) requires a server to store credentials, look up "who is user X", and route invites. We are explicitly avoiding running a backend.
- CloudKit already gives us a per-iCloud-account stable identity (`CKContainer.default().fetchUserRecordID`) and a built-in sharing/permission system. Sign in with Apple gives a stable `user` string per Apple ID + the App Store login UX users expect.
- These two compose cleanly: Apple ID is the *login*; the CloudKit user record ID is the *identity used to own/share records and attribute edits*.

### Concrete changes (P1)
- **Stop generating UUIDs for users.** In `AuthManager`, the `User.id` for the Apple path is already `appleIDCredential.user` (good). Remove the `UUID().uuidString` fallbacks in `signInWithEmail`/`signUpWithEmail`/`signInWithPhone` or gate those providers off for v1. Apple becomes the only "real" provider.
- **Verify the Apple credential properly:**
  - Generate a cryptographic `nonce` (SHA256) before the request, set `request.nonce`, and on completion verify `identityToken`/`authorizationCode` are present (full server-side verification is unnecessary without a backend, but at minimum confirm the token exists and the nonce round-trips).
  - On **every launch**, call `ASAuthorizationAppleIDProvider().getCredentialState(forUserID:)`. If it returns `.revoked` or `.notFound`, sign the user out and clear the cached `User`. Today `checkAuthState()` blindly trusts `UserDefaults`.
- **Resolve and cache the CloudKit identity:**
  - On sign-in and launch, call `CKContainer.default().accountStatus` (must be `.available`) and `fetchUserRecordID()`. Persist the resulting `CKRecord.ID.recordName` as the canonical owner id.
  - Surface a clear "Sign in to iCloud" state when `accountStatus != .available` (reuse the messaging style already in `CloudSyncManager.checkCloudStatus()`).
- **What to persist (locally, in `UserDefaults`/Keychain):**
  - Apple `user` id (stable login id) → Keychain preferred.
  - `displayName`/`email` (Apple only returns these on first authorization — keep the existing "preserve on subsequent sign-in" logic).
  - CloudKit user record name (the identity used in shares).
  - Auth provider = `.apple`.
- **Couple identity:** `Couple.user1ID`/`user2ID` should store the **CloudKit user record name**, not app UUIDs, so both devices agree on who is who.

> Email/password note: keep the `signInWithEmail` API surface if desired, but mark it unsupported for couples (couples requires iCloud). A future email/password path would require a backend (Firebase/own server) and is out of scope.

---

## 2. EXACT Xcode / Developer-Account steps the USER must do

These cannot be done from code/CLI and must be done in Xcode + the Apple Developer portal, in order:

1. **Sign in with Apple capability** (already partially present in `Matchly.entitlements` as `com.apple.developer.applesignin = [Default]`):
   - In Xcode: *Target → Signing & Capabilities → + Capability → Sign in with Apple*. Confirm it's enabled for the App ID in the Developer portal (Certificates, Identifiers & Profiles → your App ID → Sign in with Apple).
2. **iCloud + CloudKit:**
   - *Signing & Capabilities → + Capability → iCloud*. Check **CloudKit**.
   - Under Containers, **create/select a container**, e.g. `iCloud.com.matchly.Matchly` (must match the App ID's iCloud entitlement). Keep KVS checkbox enabled for now (migration coexistence — see §7).
   - This populates `com.apple.developer.icloud-container-identifiers` (currently an empty `<array/>`) and `com.apple.developer.icloud-services` (add `CloudKit`) in `Matchly.entitlements`.
3. **Background Modes → Remote notifications:**
   - *+ Capability → Background Modes → check "Remote notifications".* Required so CloudKit `CKSubscription` push notifications (record/zone/database changes and share-accept notifications) can wake the app and refresh the shared rank list.
   - This adds `UIBackgroundModes = [remote-notification]` to **Info.plist** (not the entitlements file).
4. **Push entitlement / APNs:** Enabling CloudKit push adds `aps-environment` to the entitlements automatically (`development` in debug). No separate APNs key is needed for CloudKit subscriptions.
5. **CloudKit Dashboard:** After first run that defines record types, promote the schema from Development to Production before any TestFlight/App Store build. (You can also pre-create record types in the CloudKit Dashboard.)

### Entitlements file vs Developer portal — who owns what
- **`Matchly/Matchly.entitlements` (in repo, edited by Xcode):** `com.apple.developer.applesignin`, `com.apple.developer.icloud-container-identifiers` (the container id), `com.apple.developer.icloud-services = [CloudKit]`, `com.apple.developer.ubiquity-kvstore-identifier` (already present), `aps-environment`.
- **Info.plist:** `UIBackgroundModes` (remote-notification); URL scheme registration only if we keep `matchly://` (we recommend not — see §6).
- **Developer portal (App ID):** the capabilities must be toggled ON for the App ID (Sign in with Apple, iCloud/CloudKit + the container, Push Notifications), and the provisioning profile regenerated. Xcode "Automatically manage signing" handles profile regeneration once the App ID capabilities exist.

---

## 3. CloudKit data model + sharing

### Database & zone strategy
- Use the **private database** with a **custom record zone per couple** (e.g. zone named `couple-<coupleID>`), created by the inviter. `CKShare` requires a custom zone (you cannot share records in the default zone).
- The **inviter owns** the zone + share; the partner accesses it via the accepted share in their **shared database**. CloudKit handles the cross-account permission — no server needed.

### Record types (minimal)
- `CoupleRecord` (the share root):
  - `coupleID` (String), `user1RecordName`, `user2RecordName` (set on accept), `user1Name`, `user2Name`, `status`, `createdAt`, `linkedAt`.
  - `couplesPreferences` (encoded `CouplesPreferences` blob — small).
- `RankPairRecord` (one per `CouplesRankPair`):
  - `coupleID` (ref to CoupleRecord), `rank`, `user1ProgramID`, `user2ProgramID`, `user1NoMatch`, `user2NoMatch`, `notes`.
- `SharedProgramRecord` (one per program each partner is willing to rank — see §4):
  - `ownerRecordName` (which partner contributed it), `programID` (the local `Program.id`, used to map `user1ProgramID`/`user2ProgramID`), and a **MINIMAL** subset of `Program`:
    - `name`, `hospital`, `city`, `state`, plus optional `address`, and `latitude`/`longitude` (precomputed via `GeocodingHelper` at publish time so the partner can sort by distance without re-geocoding).
  - **Explicitly NOT shared:** `notes`, `voiceMemoURL`, `questionnaire`, `programQuality`/`cultureFit`/`logistics`/`careerAlignment`/`redFlags` scores, `finalScore`, contact info. Couples sharing only needs identity + location of each candidate program.

### Invite/accept → CKShare (replacing the fake code/search/invite stubs)
- **Delete the mock flow's data effects:** the random `coupleCode`, `generateInviteLink`, `UserSearchView` lookups, and local `CoupleInvite` arrays are replaced by a real `CKShare`.
- **Create couple (inviter):**
  1. Create `couple-<id>` zone, save `CoupleRecord` as the share root.
  2. Create `CKShare(rootRecord: coupleRecord)`, set `publicPermission = .none`, `share[CKShare.SystemFieldKey.title] = "Matchly Couples List"`, participant `permission = .readWrite`.
  3. Save share + root via `CKModifyRecordsOperation`.
  4. Present **`UICloudSharingController`** (wrapped in a `UIViewControllerRepresentable`) so the inviter sends the invite via Messages/Mail/etc. CloudKit generates the share URL — we do not invent one.
- **Accept (partner):** taps the system share link → iOS delivers it to the app via the scene delegate (see §3.1). On accept, set `user2RecordName`/`user2Name` on the `CoupleRecord`, flip `status` to `.linked`. The existing `Couple.isLinked` (`user2ID != nil && user2Name != nil`) then drives the UI exactly as today.

The "I Have a Partner Code" / code-entry / invite-link-paste UI in `LinkPartnerView` becomes either (a) removed, or (b) repurposed as a fallback that opens the CKShare URL. Recommended: replace with a single "Invite Partner" (share sheet) button + a system-handled accept.

### 3.1 Accepting a share under the SwiftUI App lifecycle (explicit plumbing)

SwiftUI's `App` lifecycle does **not** deliver `userDidAcceptCloudKitShareWith` to a SwiftUI modifier — it must go through a `UIWindowSceneDelegate`. Wire it up:

1. **Add a `UIApplicationDelegateAdaptor`** in `MatchlyApp.swift`:
   ```swift
   @main
   struct MatchlyApp: App {
       @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
       var body: some Scene { WindowGroup { SplashView()... } }
   }
   ```
2. **`AppDelegate`** implements `application(_:configurationForConnecting:options:)` returning a `UISceneConfiguration` whose `delegateClass = SceneDelegate.self`.
3. **`SceneDelegate: UIResponder, UIWindowSceneDelegate`** implements:
   - `windowScene(_:userDidAcceptCloudKitShareWith metadata:)` — call `CKContainer.default().accept(metadata)` (via `CKAcceptSharesOperation`), then fetch the shared `CoupleRecord` and hydrate `dataManager.preferences.couple`.
   - `scene(_:willConnectTo:options:)` — handle the cold-launch case where the share metadata arrives in `connectionOptions.cloudKitShareMetadata`.
4. **`CKSharingSupported = true`** must be added to **Info.plist**, otherwise iOS won't route share URLs to the app.
5. Bridge the accepted couple into the existing `@EnvironmentObject DataManager` (e.g. via a shared `CouplesCloudManager` singleton + Combine publisher the views observe).

> This delegate plumbing is the single most important piece of "lifecycle" work and is the reason `matchly://` deep linking is not sufficient on its own.

---

## 4. Paired rank list (both-sided)

The bug today is `user2Programs = []`. Fix:

- Each partner **publishes their rankable programs** as `SharedProgramRecord`s into the couple's shared zone (minimal fields per §3). Source = `dataManager.getRankedPrograms()` (the same set feeding `user1Programs`).
- `CouplesRankListView.user2Programs` becomes: *the `SharedProgramRecord`s in the shared zone whose `ownerRecordName == partner's record name`*, mapped into lightweight `Program` values for the picker. (We can decode them into real `Program` structs with empty sub-objects, since the picker only reads `program.hospital`/`program.name`/`id`.)
- Now `AddCouplesRankPairView`'s "Partner's Program" picker is populated, so a `CouplesRankPair` can reference both `user1ProgramID` (your program) and `user2ProgramID` (their program). The list is identical for both partners because both read the same shared `RankPairRecord`s.
- **Symmetry:** "your" vs "partner" is resolved per-device by comparing the local CloudKit user record name to `user1RecordName`/`user2RecordName` on `CoupleRecord`. Device A sees its programs as user1; Device B sees the same records but maps roles inversely so each side sees themselves as "You".

### Edit sync + source of truth
- **CloudKit is the source of truth** for couple-shared data (`CoupleRecord`, `RankPairRecord`, `SharedProgramRecord`). Local `dataManager.preferences.couplesRankPairs` becomes a cache hydrated from CloudKit.
- Edits (`addPair`/`updatePair`/`movePairs`/`deletePairs`) write to CloudKit via `CKModifyRecordsOperation`; success updates the local cache. Use `recordChangeTag` for optimistic concurrency; on conflict, refetch and reapply (last-writer-wins is acceptable for v1, with a refetch-on-conflict).
- **Live updates:** create a `CKDatabaseSubscription`/`CKRecordZoneSubscription` on the shared zone so the partner's edits push to the other device (requires the Background Modes work in §2). On push (or on `scenePhase == .active`), run `CKFetchRecordZoneChangesOperation` with a stored `serverChangeToken` and merge.
- Reordering: `rank` is the ordering field; writing reordered ranks syncs naturally.

---

## 5. Geographic pairing (v1)

Leverage existing `GeocodingHelper.coordinate(for:city:state:)` (returns `CLLocationCoordinate2D`; falls back to city→state→US center).

- At publish time, compute and store `latitude`/`longitude` on each `SharedProgramRecord` so distance math needs no async geocoding on the consuming device.
- **Suggestion/sort helper** (pure function, easy to unit test): given your ranked programs + partner's shared programs + `CouplesPreferences`, produce candidate pairs scored by distance:
  - Distance = `CLLocation.distance(from:)` in miles between the two programs' coordinates.
  - Honor `distanceTolerance`: pairs beyond the tolerance are de-prioritized or filtered.
  - Honor `geographicPriority` (`sameCity`/`sameState`/`sameRegion`/`balanced`/`flexible`) as the sort weighting.
  - Honor `mustMatchTogether`: when `true`, do not auto-suggest "No Match" splits; when `false`, allow suggested pairs that leave one side "No Match".
- v1 scope: **suggest + sort** candidate pairs in `AddCouplesRankPairView` / a "Suggestions" section; do not auto-build the whole list (see §9 default). This reuses the existing `generateCouplesRankList()` hook in `DataManager`, upgraded to be geography-aware.

---

## 6. Deep link: CKShare URL vs custom `matchly://`

**Recommendation: rely on CKShare's own share URLs; drop the custom `matchly://couple/invite/{code}` scheme.**

Why:
- CKShare URLs are issued and validated by CloudKit, carry the cryptographic share metadata, and are delivered straight to `userDidAcceptCloudKitShareWith` (§3.1) with the recipient already authenticated against the right iCloud account. The custom scheme carries only a 6-char code that maps to nothing real (no server to resolve it) — it's the heart of why the current flow is fake.
- Using `matchly://` would require us to build the very backend we're trying to avoid (to resolve a code → a couple → a participant).
- Keep `Couple.generateInviteLink`/`parseInviteLink` only as dead-but-harmless code or delete the UI that surfaces them; do **not** register the URL scheme. The "Share invite link" `ShareLink(item: inviteLink)` in `CouplesMatchingView` is replaced by the `UICloudSharingController` share sheet.

---

## 7. Migration: KVS → CloudKit (coexistence, no data loss)

- **Keep `NSUbiquitousKeyValueStore` for personal data** (programs, `UserPreferences`) in v1. KVS is fine for single-account private data and is already wired in `CloudSyncManager`. Do **not** rip it out.
- **Add CloudKit only for the couples-shared subset** (`CoupleRecord`/`RankPairRecord`/`SharedProgramRecord`). This is additive and avoids a risky wholesale migration.
- **One-time migration of existing local couple data:** on first launch after the update, if `dataManager.preferences.couple` exists locally (faked or real) but no CloudKit couple zone exists, treat the local couple as "unlinked draft": keep the user1 side, discard the bogus `user2ID = UUID()`/`"Partner"` values, and prompt to re-invite via CKShare. Existing `couplesRankPairs` with only `user1ProgramID` set are preserved as drafts.
- **Do not depend on the separately-landed Codable-hardening change.** The resilient `init(from:)` decoders in `Couple.swift`/`CoupleInvite.swift` are nice-to-have but this plan must read/write CloudKit fields explicitly; treat decoding defensively on our own.
- Provide a small `CouplesCloudManager` (sibling to `CloudSyncManager`) that owns container/zone/share/subscription logic, so KVS sync and CloudKit sharing stay decoupled.

---

## 8. Phased rollout (reviewable PRs)

Each phase is independently reviewable. Note: **none of this can be build-verified in the current environment (Command Line Tools only — no full Xcode/simulator)**, and full testing requires **two real iCloud accounts on two devices** (CloudKit sharing cannot be exercised in a single-account simulator reliably).

- **P1 — Auth/identity + capabilities** (smallest, no CloudKit data yet):
  - Apple Sign In nonce + token presence check; `getCredentialState` on launch; remove UUID minting; resolve & cache CloudKit user record id; account-status gating.
  - User performs the Xcode/portal capability steps (§2).
  - Verifiable: app builds, Apple sign-in yields a stable id, launch revalidates credential state.
- **P2 — CloudKit data layer + migration**:
  - `CouplesCloudManager`, record types, custom zone, read/write of `CoupleRecord`/`RankPairRecord`/`SharedProgramRecord`, zone-change fetch + subscription. KVS coexistence + local-couple migration (§7).
  - Verifiable (single account): records save/fetch in own private DB.
- **P3 — CKShare invite/accept replacing stubs**:
  - `UICloudSharingController` invite; `AppDelegate`/`SceneDelegate` + `CKSharingSupported`; accept → link couple. Remove code/search/invite-link UI effects.
  - Requires two accounts to fully verify.
- **P4 — Paired rank list + geographic suggestions**:
  - Populate `user2Programs` from shared records; both-sided pair selection; edit sync; geography-aware `generateCouplesRankList()` honoring `distanceTolerance`/`mustMatchTogether`/`geographicPriority`.
  - Requires two accounts to verify end-to-end.

---

## 9. Proposed defaults for open behavior questions

To keep momentum, proceed with these defaults unless the user objects:

- **Pair-building mode: ASSISTED (default).** Manual add/edit stays; add a geography-ranked "Suggestions" section the user accepts into the list. Not fully auto (auto-building a whole couples list is high-risk and second-guesses the user). Manual remains always available.
- **"No Match" UI: keep the existing per-side toggle** in `AddCouplesRankPairView` (`user1NoMatch`/`user2NoMatch`), and have suggestions only propose "No Match" when `mustMatchTogether == false`.
- **Data sharing: MINIMAL (default).** Share only program identity + location (`name`, `hospital`, `city`, `state`, `address`, coords). Never share notes, voice memos, questionnaire scores, or `finalScore`.
- **Couple cardinality:** exactly 2 participants; share `publicPermission = .none`, single read-write participant. One active couple per user at a time (mirrors current single `preferences.couple`).
- **Container id:** `iCloud.com.matchly.Matchly` unless the user already has a preferred container.
- **Conflict policy:** last-writer-wins with refetch-on-conflict for v1.

---

## Decisions still needed from the user

1. **CloudKit container identifier** — use `iCloud.com.matchly.Matchly`, or an existing/preferred container name?
2. **Drop email/password + other social providers for v1?** (Plan assumes Apple/iCloud only; couples requires iCloud. Confirm OK to gate non-Apple providers off.)
3. **Pair-building level** — confirm ASSISTED (suggest + accept) vs requiring fully manual, or wanting full auto-generation.
4. **Apple developer access** — confirm you (the user) will perform the Xcode capability + Developer-portal steps in §2, and that you have **two iCloud accounts/devices** available for testing P3–P4.
