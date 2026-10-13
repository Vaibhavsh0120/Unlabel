# Unlabel app mark

The unchanged Google G in `google-g.svg` comes from Google's official
`https://fonts.gstatic.com/s/i/productlogos/googleg/v6/24px.svg` and appears only
on Google sign-in controls. It identifies that provider, not Unlabel branding.

The app-only startup wordmark uses bundled Cormorant Garamond at regular weight.
Its unmodified variable font, SIL Open Font License and pinned official Google
Fonts source URLs/SHA-256 hashes are in `fonts/startup-font-source.json`. It does
not require an installed system serif or a runtime font download.

Original large leaf above a rounded Unlabel wordmark, following the supplied
icon direction. The light mark uses white, forest green and a soft green leaf
gradient; the dark mark uses charcoal, mint and an off-white wordmark. Editable
SVGs and 1024px PNG masters live here, separately from the attributed Solar
feature icons. Light is the app's first-use default. Platform masks supply the
outer rounded shape; the source artwork is a full square.

`python scripts/generate_app_icons.py --check` verifies all 42 committed assets
and font/license source files, their hashes and PNG dimensions without external
dependencies. To regenerate deliberately, install Pillow and fontTools in an
authoring environment and run the script without `--check`.
Normal setup/build uses committed assets and does not download an icon tool.

The rounded wordmark uses Nunito at weight 800. The unmodified variable font and
its SIL Open Font License are retained in [fonts](fonts/), acquired from the
[official Google Fonts repository](https://github.com/google/fonts/tree/main/ofl/nunito).
The Android/SVG wordmark is outlined, so displaying the icon never downloads a
font or depends on a platform-installed typeface. Font acquisition is an explicit
authoring step; the generation script uses the checked-in source offline.

- Android: five legacy light/night density pairs; adaptive API26 vector foreground
  includes the gradient leaf and outlined wordmark with a safe-zone inset, plus
  background/night colors; API33 monochrome leaf/wordmark themed layer. Launcher appearance
  follows the OS/launcher, independently of the app's saved appearance choice.
- iOS/iPadOS: universal single-size Any/light and dark appearance assets. The dark
  icon has a transparent background for the system surface. Xcode/device rendering
  remains a separate native build gate; the existing AppIcon asset name is kept.
- Web: light/dark favicons, touch icons and any/maskable 192/512 assets with separate
  manifests. The selected app appearance updates these descriptors. A first visit
  uses light; choosing System follows browser appearance. Installed launchers may
  cache their icon and are not guaranteed to refresh immediately.

Platform references: [Apple asset catalog](https://developer.apple.com/documentation/xcode/configuring-your-app-icon)
and [Android adaptive icons](https://developer.android.com/develop/ui/compose/system/icon_design_adaptive).
