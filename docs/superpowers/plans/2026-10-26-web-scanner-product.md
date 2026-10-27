# Web, scanner and product information implementation plan

**Goal:** Complete the supplied scanner/product references and improve web interaction, especially iPhone Safari.

**Architecture:** Extend the current Flutter camera and unified product destination. Keep backend-only NutriGraph separate from immutable catalogue observations, saved reports and account synchronization. Retain the existing themes, app shell, free services and main checkout.

**Spec:** The user-supplied desktop/mobile screenshots and 26 October request supersede the earlier deferred product redesign and scanner garden direction in DESIGN.md.

## Tasks

- [x] Rebuild the product identity, available-facts banner, four evidence cards, six nutrient tiles, declarations, unknowns and sources. Keep all original evidence accessible and scale to narrow/large-text layouts.
- [x] Match the scanner reference with the maintained free mobile_scanner SDK and native/ZXing-C++ WASM backends, duplicate/cancellation/lifecycle guards and manual capture/gallery fallback. The later user chose a free, no-expiry alternative to Dynamsoft.
- [x] Configure NutriGraph in local `.env`, refresh `.env.age`, verify the supplied endpoint, harden provider schema/failure/quota handling and retain session-only expiry. Make all backend sources optional with credential-based keyed defaults and explicit disable overrides.
- [x] Show a toast when a guest selects Sign-in methods. Preserve explicit sign-in actions elsewhere.
- [x] Reduce loading-animation paint/build work and stop it while backgrounded. Retain platform scrolling, reduced motion and zoom accessibility. Fix SDK Safari inline playback and camera-track cleanup.
- [x] Generate a small transparent decorative product botanical, store its prompt/hash, and verify both themes at phone/tablet/desktop sizes. Apply the user's smaller phone typography correction.
- [x] Run focused and full frontend/backend checks, production web build, rendered review and source/secret/contract validation. Record provider/device limits separately and update current docs.
- [ ] Commit and push authorized source on main, then record actual hosted/native publication evidence separately from device acceptance.

## Review focus

Guest and signed-in provider management must remain distinct. Barcode attempts must never overlap or upload undecoded frames. Missing/conflicting nutrition and allergens must not become zero/safe. Vendor facts and keys must not enter client bundles or permanent data. Screens must keep all actions reachable at 320 px/2x text and respect background/reduced-motion settings.

## Decisions

Keep current Flutter design tokens; the references choose the structural direction. Add nutrition basis, source/date, provider status and unknown/conflict details where the screenshots omit them. No new billing, catalogue migration, paid scanner library, or fabricated vendor success. Existing teammate documentation edits are preserved.
