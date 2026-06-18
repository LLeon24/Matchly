# Couples Match — Phase 1 Setup Steps (Click‑by‑Click)

This guide walks you through the **one‑time Xcode + Apple Developer setup** needed for
Phase 1 of the Couples Match feature: **real Sign in with Apple login** and the
**CloudKit identity** the app uses to know "who is who".

You do **not** need to write any code — the code is already done. These steps just turn on
the *capabilities* (permissions) the code depends on. Follow them **in order**.

> **Container we are using:** `iCloud.com.matchly.Matchly`
> **App bundle id (for reference):** `com.lleonmd.Matchly`
> (The CloudKit container id and the bundle id do **not** have to match — that's normal.)

If you skip these steps the app still launches and works; it will simply show an
**"iCloud required"** state for the couples identity and Apple Sign In will fail with a
"capability not enabled" style error. Nothing crashes.

---

## Before you start

- Open the project in **full Xcode** (not just Command Line Tools).
  Double‑click `Matchly.xcodeproj` (or the `.xcworkspace` if one exists).
- Make sure you are **signed into your Apple Developer account** in Xcode:
  **Xcode ▸ Settings… (⌘,) ▸ Accounts**. If your team isn't listed, click **+** and add it.
- On the test device/simulator, make sure you are **signed into an Apple ID** and
  **iCloud** (Settings ▸ [your name]). Sign in with Apple and CloudKit both require this.

---

## Where to find "Signing & Capabilities"

1. In Xcode's left sidebar (the **Project navigator**, the folder icon), click the
   blue **Matchly** project at the very top.
2. In the editor that opens, under **TARGETS**, click **Matchly** (the app target, the one
   with the app icon — not the "Tests" ones).
3. Click the **Signing & Capabilities** tab along the top of the editor.

This tab is where every step below happens (except the Developer‑portal verification at the
end). To add a capability you click the **`+ Capability`** button in the **top‑left of this
tab** and double‑click the capability in the list that appears.

Also confirm at the top of this tab:
- **Automatically manage signing** is **checked**.
- A **Team** is selected. (Automatic signing regenerates the provisioning profile for you
  whenever you add a capability below.)

---

## Step 1 — Sign in with Apple

This makes the "Continue with Apple" button real.

1. In **Signing & Capabilities**, click **`+ Capability`**.
2. Type **Sign in with Apple** and **double‑click** it.
3. A **"Sign in with Apple"** box now appears in the capabilities list. There is nothing to
   configure inside it. Done.

**What this writes:** the key `com.apple.developer.applesignin` in
`Matchly/Matchly.entitlements` (value `Default`). It is **already present** in the repo, so
if the capability box appears with no warning, you're good. If Xcode shows a red error here,
it usually just needs to regenerate the profile — see *Troubleshooting* at the bottom.

---

## Step 2 — iCloud + CloudKit (the important one)

This gives the app a stable cross‑device identity (the CloudKit user record id) that the
couples feature uses to tell partners apart.

1. Click **`+ Capability`** again.
2. Type **iCloud** and **double‑click** it. An **"iCloud"** box appears.
3. Inside that **iCloud** box, under **Services**, **check the `CloudKit` checkbox.**
   (Leave **Key‑value storage** checked too — the app already uses it for personal data and
   we want both to coexist.)
4. A **Containers** list appears below the services. Click the small **`+`** button under
   **Containers**.
5. In the dialog, choose **"Specify a custom container"** (or the text field) and enter
   **exactly**:

   ```
   iCloud.com.matchly.Matchly
   ```

   Click **OK**. The container appears in the list with a **checkmark** next to it —
   make sure it is **checked**.

   > If `iCloud.com.matchly.Matchly` already exists in the list, just **check it** instead
   > of creating a new one.

**What this writes (verify in `Matchly/Matchly.entitlements`):**
- `com.apple.developer.icloud-container-identifiers` → an array containing
  `iCloud.com.matchly.Matchly`
- `com.apple.developer.icloud-services` → an array containing `CloudKit`

Both of those are **already filled in** in the repo's entitlements file, so after you check
the box and select the container the file should match and show **no diff/warning**. If
Xcode wants to change them, let it — but the values should end up identical to the above.

---

## Step 3 — Background Modes ▸ Remote notifications  *(pre‑enable for a later phase)*

You do **not** need this for Phase 1 to work, but turning it on now means you won't have to
revisit signing later. It is required in a **later phase** so CloudKit can *push* a partner's
edits / share invitations to the other device.

1. Click **`+ Capability`**.
2. Type **Background Modes** and **double‑click** it.
3. In the **Background Modes** box, **check `Remote notifications`**.

**What this writes:** `UIBackgroundModes = [remote-notification]` — this goes into the
app's **Info.plist** (in this project the Info.plist is *generated*, so it shows up as an
`INFOPLIST_KEY_…` build setting rather than a standalone file). It does **not** go in the
entitlements file. Nothing in the Phase 1 code reads this yet — it's purely pre‑enablement.

> **Push entitlement (`aps-environment`) — later phase, not now.** When the later CloudKit
> push/subscription work lands, enabling it will add `aps-environment` to the entitlements
> automatically (Xcode does this when you add the **Push Notifications** capability, or it
> appears as `development` in debug builds once CloudKit subscriptions are wired up). **You
> do not need to add Push Notifications for Phase 1.** No separate APNs key is required for
> CloudKit subscriptions.

---

## Who owns what (so you can verify each step landed in the right place)

| Setting | Lives in | Set by |
| --- | --- | --- |
| `com.apple.developer.applesignin` | `Matchly/Matchly.entitlements` | Step 1 |
| `com.apple.developer.icloud-container-identifiers` (= `iCloud.com.matchly.Matchly`) | `Matchly/Matchly.entitlements` | Step 2 |
| `com.apple.developer.icloud-services` (= `CloudKit`) | `Matchly/Matchly.entitlements` | Step 2 |
| `com.apple.developer.ubiquity-kvstore-identifier` | `Matchly/Matchly.entitlements` | already present (key‑value storage) |
| `UIBackgroundModes` (= `remote-notification`) | **Info.plist** (generated → `INFOPLIST_KEY_…`) | Step 3 (later phase) |
| `aps-environment` | `Matchly/Matchly.entitlements` | **later phase**, auto‑added |
| Capabilities toggled ON for the **App ID** + provisioning profile | **Apple Developer portal** | Automatic signing (Xcode), see Step 4 |

You can open `Matchly/Matchly.entitlements` directly in Xcode (or any text editor) to confirm
the keys above. The expected contents after setup are:

```xml
<key>com.apple.developer.applesignin</key>
<array><string>Default</string></array>
<key>com.apple.developer.icloud-container-identifiers</key>
<array><string>iCloud.com.matchly.Matchly</string></array>
<key>com.apple.developer.icloud-services</key>
<array><string>CloudKit</string></array>
<key>com.apple.developer.ubiquity-kvstore-identifier</key>
<string>$(TeamIdentifierPrefix)$(CFBundleIdentifier)</string>
```

---

## Step 4 — Confirm it in the Apple Developer portal (optional but recommended)

Automatic signing usually does this for you, but to verify:

1. Go to <https://developer.apple.com/account> ▸ **Certificates, Identifiers & Profiles**.
2. Click **Identifiers**, then click your App ID (**`com.lleonmd.Matchly`**).
3. Confirm these capabilities are **checked**:
   - **Sign in with Apple**
   - **iCloud** (and that **CloudKit** is enabled). Click **Edit/Configure** next to iCloud
     and confirm the container **`iCloud.com.matchly.Matchly`** is associated.
   - **Push Notifications** can stay **off** for now (later phase).
4. If you change anything here, go back to Xcode's **Signing & Capabilities** tab; with
   **Automatically manage signing** on, Xcode will regenerate the profile. If it doesn't,
   toggle the checkbox off and on, or **Product ▸ Clean Build Folder (⇧⌘K)**.

---

## How to verify it worked ✅

Run the app on a device or simulator that is **signed into iCloud**, then check:

1. **App launches normally** even before/without the steps — it should never crash. (If
   capabilities aren't set up yet, the couples area shows an "iCloud required / coming soon"
   style state instead of fake data.)
2. **Tap "Continue with Apple"** on the sign‑in screen. The native Apple sheet appears and,
   after you authenticate, you land in the app. (If you instead get an error mentioning the
   capability not being enabled, re‑check **Step 1**.)
3. **Stable identity:** sign out and sign back in with Apple — you stay the **same** account
   (no new random id each time).
4. **CloudKit identity resolved:** with iCloud signed in and **Step 2** done, the app fetches
   your CloudKit user record id in the background. In Xcode's **Console** (View ▸ Debug Area
   ▸ Activate Console) filter by subsystem **`com.matchly`** / category **`AuthManager`** and
   look for a log line like *"Resolved CloudKit user record id"*. If you instead see
   *"CloudKit account not available"* or *"iCloud required"*, the device isn't signed into
   iCloud or **Step 2** isn't complete.
5. **Revocation handling:** if you remove the app's Apple ID access (Settings ▸ [your name] ▸
   Sign in with Apple ▸ Matchly ▸ Stop Using), the **next app launch** signs you out
   automatically.

When all five pass, Phase 1 setup is complete.

---

## Troubleshooting

- **Red signing error after adding a capability:** ensure a **Team** is selected and
  **Automatically manage signing** is checked. Then **Product ▸ Clean Build Folder (⇧⌘K)**
  and rebuild.
- **"Continue with Apple" does nothing / errors:** the device must be signed into an Apple ID,
  and **Step 1** must be done.
- **Couples area says iCloud is required:** the device must be signed into **iCloud**
  (Settings ▸ [your name] ▸ iCloud) and **Step 2** must be complete with the
  `iCloud.com.matchly.Matchly` container checked.
- **Entitlements file shows unexpected changes:** the target values are listed in the table
  above — as long as it ends up containing those keys/values you're fine.
- **Couples link always says "No partner found with that code":**
  1. On the **inviting** phone, open Couples Matching and wait for **"Invite ready for your partner"** (green check). If you see an orange error, tap **Retry Publishing Invite** after confirming iCloud is signed in.
  2. Both phones must use the **same CloudKit environment**: two Xcode debug builds, or two TestFlight/App Store builds. A debug build from Xcode and a TestFlight build **cannot** see each other's invite codes.
  3. **CloudKit schema + security (required for publish/link errors)** — in [CloudKit Dashboard](https://icloud.developer.apple.com/):
     - Container **`iCloud.com.matchly.Matchly`** → **Development** (for Xcode builds).
     - **Schema → Record Types → `CoupleCodeInvite`**: every field must be type **String**:
       `code`, `coupleID`, `inviterRecordName`, `inviterName`, `inviterEmail`, `status`, `createdAt`, `partnerRecordName`, `partnerName`, `partnerEmail`, `linkedAt`.
       Error **12** usually means `createdAt` (or another field) is **Date/Time** instead of **String** — fix the type and Save.
     - **Schema → Security Roles**: `_icloud` → Create + Read + Write on `CoupleCodeInvite`; `_world` → Read.
     - On the phone: **Generate New Code** → **Retry Publishing Invite** → confirm green **Invite ready**.
  4. Before TestFlight: **Schema → Deploy Schema Changes…** Development → Production.
- **Partner chat fails to send or load:**
  1. Chat uses record type **`CoupleMessageThread`** (one record per couple, fetched by ID — **no indexes required**).
  2. In [CloudKit Dashboard](https://icloud.developer.apple.com/) → **`iCloud.com.matchly.Matchly`** → **Development** → **Schema → Record Types → +**:
     - Name: **`CoupleMessageThread`**
     - Fields:
       - `coupleID` — **String**
       - `messagesData` — **Bytes**
       - `updatedAt` — **String**
     - No queryable indexes needed for chat to work.
  3. **Schema → Security Roles → `_icloud`**: Create, Read, Write on **`CoupleMessageThread`**.
  4. For TestFlight: **Deploy Schema Changes…** Development → Production.
  5. You can ignore the older **`CoupleMessage`** record type (one-record-per-message design); it is no longer used.
  6. Both partners must use the same CloudKit environment (both Xcode debug or both TestFlight).

---

## What's intentionally NOT in Phase 1

These come in later phases and are **not** required now:
- Sharing the couples list across two accounts (CKShare / `UICloudSharingController`).
- The paired (both‑sided) rank list.
- CloudKit push subscriptions (this is why Background Modes in **Step 3** is pre‑enable‑only).
- Email/phone sign‑in (hidden for v1 — Apple Sign In only).
