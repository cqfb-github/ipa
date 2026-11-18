# StreamVault

An ad-free stream player and offline video/audio archiver for iOS (optimized for sideloading on iPhone 16 Pro via Signulous).

## Features
- **Direct Stream Extraction:** Extract direct audio and video streams (including 1080p/4K) without ads or tracking.
- **Offline Archiving:** Download full streams directly into the app sandbox.
- **Chewie/AVPlayer Integration:** Multi-speed playback (0.5x - 2.0x), full-screen landscape, and scrubbing controls.
- **Export & AirDrop:** Native iOS share sheet integration to send downloaded `.mp4` and `.m4a` files to Files, Mac via AirDrop, or other media players (VLC, Infuse).

## How to Build the .IPA from Windows PC

You don't need a Mac or Xcode installed locally. GitHub Actions will build it on a cloud macOS runner.

### Step 1: Create a GitHub Repository
1. Go to [github.com/new](https://github.com/new) and create a new repository (e.g. `stream-vault`).
2. You can set it to **Private** or **Public**.

### Step 2: Upload Project Files to GitHub
You can use GitHub's web interface or Git CLI/GitHub Desktop to upload the contents of this folder (`C:\Users\cb123\.gemini\antigravity\scratch\stream_vault`):
- `pubspec.yaml`
- `lib/main.dart`
- `ios/Runner/Info.plist`
- `.github/workflows/build_ipa.yml`

*Tip: If uploading via GitHub web, you can create the file `.github/workflows/build_ipa.yml` using the "Add file" -> "Create new file" button.*

### Step 3: Trigger the Build
1. In your GitHub repository, click the **Actions** tab.
2. Select **"Build Unsigned IPA for Signulous"** from the left sidebar.
3. Click **Run workflow** -> **Run workflow**.
4. The macOS runner will compile the Flutter app, bundle `Runner.app` into an unsigned `StreamVault.ipa`, and attach it to the run. (Takes ~4-6 minutes).

### Step 4: Sign & Install via Signulous
1. Click on the completed run in the Actions tab.
2. Under **Artifacts** at the bottom, download `StreamVault-Unsigned-IPA.zip`.
3. Extract the `.zip` to get `StreamVault.ipa`.
4. Go to **[Signulous.com](https://www.signulous.com)** > **Dashboard** > **Upload App**.
5. Select `StreamVault.ipa` and click **Sign App**.
6. Follow the on-screen link to install it directly onto your iPhone 16 Pro!
