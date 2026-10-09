# Unlabel interface contract

9 October Insights references are implemented in frontend v0.7.0+11: one featured
daily article, three distinct illustrated cards, topic filters, full articles and
device-local saved insights. Desktop retains the sidebar/top bar and a saved/
quick-topic rail; phones place saved insights below the feed. Today's four picks
are shared with Home and refresh by local calendar date. Both Home carousels use
manual swipe, selectable dots and keyboard/screen-reader adjustment, without
autoplay. Every article owns its artwork; no generic bowl repeats across facts.
All eight food preferences and twelve allergen reminders use different matching
symbols in their editors and selected summaries. Large text stacks the layout.
The [v0.7 review](docs/planning/FRONTEND_V0_7_0_REVIEW.md) records local checks and
the independent publication gate. The reference composition takes precedence
over tool heuristics that would remove its requested topic filters. The existing
Flutter framework, forest/mint palette and control icons remain the contract.

The latest 8 October references define desktop Home and mobile/PC single-product
results. Published frontend v0.6.0+7 implements this direction; screenshot
comparison was reviewed at 390/1440/1728 px, and its READY deployment passed
54 hosted checks. Exact identities belong to the release reviews. Frontend
v0.6.1+8 is now published/READY with 55 hosted checks and refines the shorter-window sidebar and insight artwork, and rebuilds
separate Profile editors with eight food preferences, twelve allergen reminders,
selected counts/chips and pinned actions. The mobile pill follows hold or direct
horizontal drag, previews a destination and selects only on release.
Published/READY frontend v0.6.2+9 corrects Profile summaries: display saved selections only,
first two labels followed by `+N` for the remaining count. Empty selections have
no chips. Each heading/chip opens its separate complete editor; saved data is
never truncated. Retain the existing card, colors and responsive wrapping.
Frontend v0.6.3+10 replaces the opaque desktop insight banner with a fresh
transparent bowl-and-leaf composition. The art uses contain fit, complete
silhouettes and inner padding on the card's own light/dark surface. Keep live
copy in its separate slot; preserve compact phone art and enlarged-text stacking.
This supersedes the earlier manual-entry UI direction while preserving the
existing mobile Home / Scan / Compare / Saved order and Profile shortcut.

Desktop uses a 240 px sidebar with Home, Scan, Compare, Saved, History and Insights,
a search/Profile top bar, a wide pale mint scan banner, four shortcuts, insight
banner, actual recent scans or an illustrated empty state, and source footer.
Fresh desktop artwork leaves quiet space behind live headings/buttons. The sidebar
uses the newly supplied pale mint watercolor three-leaf branch and slender stem,
with the reference footer text; the older dark glossy bouquet is unsuitable there.

Single-product results preserve the supplied identity/image, mint summary,
findings, front claims, nutrition, ingredient insights, declarations and sources
hierarchy. Phone cards stack; desktop gives ingredients/sources a supporting
column. Reference scores, health labels and sample facts remain illustrative.
Use available-fact counts and qualified findings instead of inventing 85/100.
Real product images come from sourced descriptors or the current front photo;
the new result botanical decoration is never package evidence.

8 October steering: Profile, app loading and mobile/desktop Welcome use the four
new supplied references. Keep the existing four-tab navbar design/order and
Profile shortcut; only reduce its bottom gap and refine the held active indicator
so its green selection surface tracks the finger while tab icons stay in place.
Cancel returns to the active tab; motion preferences are respected. Do not copy the
five-tab screenshot navbar or add a redundant Profile settings button. The
botanical loading screen is app-only; the website has no branded loading screen.
Welcome uses live copy/actions and a generated package/leaf illustration, with
stacked phone and two-column desktop compositions. Profile uses the actual
guest/account identity, real counts and device-local preferences. See the
[next releases plan](docs/planning/FRONTEND_BACKEND_NEXT_VERSIONS.md).

The user's five supplied mobile references are the visual source of truth.
Use white/off-white surfaces, forest-green headings/actions, mint icon backgrounds,
rounded cards, generous spacing and restrained leaf shapes. Text and status must
remain readable in dark mode and at 2x text scaling. No fixed text-card heights.

The 7 October refinements override the original oversized artwork brief: keep
complete illustrations inside their reserved space, use a shorter 64 px normal
header, and compact proportional shortcut cards with vertically centered copy.
Cards may grow for enlarged text. The Home banner uses separate light/charcoal
botanical backgrounds beneath live copy; contain the package rather than crop it.
The bottom bar floats over scrolling content, has rounded corners and a shared
green selection indicator that can be held and slid, committing on release.
Today's Insight has a smaller heading gap and manually swiped label-reading
tips with distinct decorative artwork. There is no autoplay, arrow or pause
control; keyboard and accessibility adjustment also work. Navigation and
confirmed saves have supported-platform haptics. The later 7 October instruction
authorized docs, push and publication at that historical checkpoint. The later
8 October instruction authorizes pushing after completing review and docs.

Scan uses a centered compact title with back/gallery controls and a fixed,
non-scrolling viewport. Its camera area takes the remaining height above three
modes and capture/review/gallery actions. Opening Scan requests camera access;
the rear feed is preferred, audio is disabled, and leaving/backgrounding stops
the session. Captures remain in session memory. Missing camera or denied access
retains retry and gallery. Local v0.6 reads barcode/front/back captures
automatically, with optional backend transfer consent and conservative local
fallback; it removes the Enter package label route. Known barcode reports open
directly; unknown products request the missing/clearer photo. Actual normalized
regions and barcode anchors are highlighted after capture, and the action becomes
View results when useful facts are ready. Unverified reading and optional one-tap
fact acceptance are distinct; there is no mandatory typing. v0.4.0 starts preview without awaiting
interrupted Android gallery recovery and protects newer actions from late photos.
Product search replaces the header with a long input and updates actual results
while typing. Product names and images open sourced reports. Reports/comparison
follow reference card hierarchy without inventing scores or health verdicts.
v0.4.0 keeps original source/table choices in the paired comparison cards and
explains amounts, unknowns and original references separately. Matched ingredient
details retain bilingual functions, reviewed URLs/dates and limited coverage.

Preserve Flutter 3.47.4 and its real Material 3 components: Scaffold, Navigator,
Card, FilledButton, TextFormField, DropdownButtonFormField, CheckboxListTile,
NavigationBar, dialogs and SnackBar. Keep labeled keyboard/focus semantics.
Use bundled Solar linear SVG feature icons, obtained through Better Design;
Material's built-in control icons remain native control affordances. No icon CDN.

Better Design project `3f652ccd-b56e-4b8d-b691-ca62cacd3a51` was consulted for
reference reading, forms, search, accessibility and review. Its generated React
registry/blue palette do not match this Flutter workspace or the user's green
references. Installing that React registry would change the chosen framework.
Use the Flutter theme as the implementation contract and the user's palette as
precedence. This is an explicit framework adaptation, not a React installation.

Primary Home action is Start Scan. Photographing and reading an unknown package
is a dedicated task; mandatory corrected-label entry has been removed.
Saved/history are secondary navigation, showing real local records or useful
empty states. Never seed convincing fake products, scores, claims or users.
Historical facts keep dates/source and must not become current package proof.
Missing allergen information cannot indicate safety. Every action must work.

Review: source rules and text comprehension through Better Design, Flutter
overflow/text/semantics tests, and rendered web views at 390/1440/1728 in light
and dark modes. Flutter canvas has no DOM card geometry: record that limitation
if DOM inspection can measure only the host surface; do not invent measurements.
