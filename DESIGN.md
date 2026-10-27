# Unlabel interface contract

26 October product-information scope supersedes the earlier deferred visual
redesign while preserving its evidence contracts and the historical directions
below. [Frontend 0.11.0 review](docs/planning/FRONTEND_V0_11_0_REVIEW.md) records
this source scope separately from final browser, hosted and physical-device proof.
The latest user correction asks for smaller phone text and a denser composition;
the supplied dark desktop/phone product references remain the layout direction.

Product information uses its own Nunito heading/Quicksand body theme, drawn from
the already bundled licensed fonts. At ordinary phone text size, product names
use 21 px, section headings 18 px, secondary headings 14 px, evidence-card titles
12 px and body copy 11–13 px. The compact identity card uses an 80 px contained
product image and 16 px padding. Barcode digits and their copy action sit beside
the short Save action when space permits, retaining 48 px tap targets. Wider
layouts retain larger type and imagery. Text scaling is unchanged: enlarged text
wraps and stacks naturally rather than shrinking to fit these default dimensions.

The product hierarchy is identity, recorded-value summary, evidence overview,
nutrition snapshot, ingredient/allergen declarations, qualified allergen notice,
missing facts and source references. Desktop keeps main/supporting columns;
phones use one scroll surface. Four evidence cards form two phone columns or four
desktop columns at ordinary text size. Six nutrient tiles include total sugars;
missing values remain unknown and conflicts remain conflicts. Every original
nutrient row, table basis, evidence state and source reference remains available
through the full nutrient disclosure. Ingredient functions, claim assessments,
sugar conversion, catalogue receipts and optional live/machine readings remain
reachable without becoming part of the fact-count summary.

The compact phone summary has a 56 px leaf ring, a 26 px count, its evidence tag,
and short qualifications. The generated `product-botanical-v2.webp` decoration
occupies its own layout slot, outside live text; it never represents the package.
The default 390 px report-summary regression check uses the actual bundled fonts
and bounds the summary to 160 px. That widget bound is not pixel-match or device
performance proof. Ingredients and Allergens are real tabs; the first four
missing facts expand to the full list. The source heading is Source references,
with a distinct Declaration source references disclosure for label provenance.
Both light/dark themes, existing navigation callbacks, session-only photos and
local save behavior remain. Final rendered reference acceptance is recorded
separately after the latest sizing pass.

The outlined Solar leaf is prohibited. All leaf icons use the filled Unlabel
brand vector from the wordmark through `BrandLeaf`; the retired outline asset is
removed. Food preference and allergen symbols keep their distinct pictograms.

13 October auth/profile scope includes the preceding maintenance and applies the
latest user references. The current [frontend review](docs/planning/FRONTEND_V0_9_0_REVIEW.md)
and [backend review](docs/planning/BACKEND_V0_13_0_REVIEW.md) record the authorized
completion/push scope; the
[preceding source review](docs/planning/FRONTEND_V0_8_0_REVIEW.md) keeps its own evidence. The desktop Recent scans empty state has a larger complete
package illustration, a spacious live-copy/action row and quiet mint botanicals;
the phone stays compact. Home's desktop daily Insight illustration is larger,
and the three supporting Insights cards stretch to the tallest natural row
height without clipping enlarged text. Remove the floating leaf next to the
Insights heading. History and Saved empty states have distinct report/clock and
bookmark/tray illustrations, with no leaf substitute.

404 recovery keeps the existing desktop sidebar/header and phone header/navbar.
Desktop History and individual Insight readers use that same shell. Brand logos
return Home. Sources follows the supplied desktop/phone reference: an illustrated
introduction and separate source rows with real copy/link/detail actions, keeping
unknowns and the limits of official guidance explicit. Public artwork uses sized
WebP assets and nonblocking preloading; never delay navigation to reveal an image.
No product photos or private records enter the decorative-image warmup.
Later steering reduces the desktop Recent scans card to a 208 px natural minimum
and removes padding below the four dots. History/Sources switch inside the fixed
desktop shell; readers open without whole-shell motion. The 404 pre-app fallback
shows loading, and its first Flutter frame already has the navigation shell.
Logo hover enlarges slightly without a tooltip or layout shift. New section
illustrations have separate purposes; unused artwork is removed from the bundle.
Latest steering centers the History/Saved illustration between the description
and lookup button at every phone width, preserving readable copy and art size.
Home's daily tips now rotate every three seconds, overriding the earlier manual-only
direction. Keep manual swipe/dots/keyboard and a pause control; pause on hover,
focus, touch, scrolling, background, hidden routes and accessibility motion settings.
Source details use a centered desktop window and a styled phone sheet, with a
fixed close action, scrollable explanation, a separate limits panel and website link.

The app retains sign-in, signup, forgot-password and neutral link-sent states.
The latest user references use Nunito headings, Quicksand body copy, a cream/forest
light theme and charcoal/bright-green dark theme. All forms and badge labels are
live Flutter widgets. Desktop login/signup have equal-width rounded cards centered
in the right section, narrowed by the requested 15%; neither the page nor desktop
card scrolls. Both hero headlines share one type scale; signup's first phrase is
one line. Artwork scales to available height and decorative cards retain a gap.
On phones and portrait iPads, artwork and card fill the viewport width. The entire
card moves as one piece over stationary artwork, with no nested scrolling inside
the card and no scrollbar. Swiping back down reveals the artwork. The keyboard
lifts the card and closing it restores its prior position. Enlarged text uses a
compact header with wrapping controls. Landscape iPad uses the desktop layout
when height allows; rotation preserves field controllers and focus.
The generated mascot, sprout and light/dark gardens are separate animated layers;
these are reference reconstructions, not exact extracted originals. Reduced motion,
background lifecycle and hidden routes stop decorative loops. Celebration follows
actual controller success. Artwork badges never describe product evidence.
Signup has one full-name field and no redundant email-option button. Profile-origin
login/signup show a back arrow; Welcome-origin screens do not. Firebase's supported
hosted action page owns reset validation, new-password entry and success, with the
fixed Unlabel sign-in return. See [current review](docs/planning/FRONTEND_V0_9_0_REVIEW.md)
for rendered and test evidence, separate from native/device acceptance.
Google/email linking keeps one
UID/library. The photo editor has explicit crop/save and separate source choices;
optional gender never comes from name/photo inference. Sign-in methods use the
supplied two-provider card composition, last-method protection, explicit changes
and account deletion confirmation. Unset/male uses the approved
male default, female uses its own new default. [Profile/storage contract](docs/architecture/ACCOUNT_PROFILE.md).

Historical 9 October Insights references were implemented in frontend v0.7.0+11: one featured
daily article, three distinct illustrated cards, topic filters, full articles and
device-local saved insights. Desktop retains the sidebar/top bar and a saved/
quick-topic rail; phones place saved insights below the feed. Today's four picks
are shared with Home and refresh by local calendar date. Both Home carousels use
manual swipe, selectable dots and keyboard/screen-reader adjustment. The later
three-second Home rotation requirement above supersedes that manual-only behavior. Every article owns its artwork; no generic bowl repeats across facts.
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
tips with distinct decorative artwork. That historical no-autoplay direction is
superseded by the current three-second rotation/pause requirement above; keyboard
and accessibility adjustment remain available. Navigation and
confirmed saves have supported-platform haptics. The later 7 October instruction
authorized docs, push and publication at that historical checkpoint. The later
8 October instruction authorizes pushing after completing review and docs.

Scan follows the supplied October desktop and mobile references. Desktop keeps
a large camera preview beside the mode selector and capture actions; phone and
portrait iPad stack the large preview above those controls and retain the app
navbar. Mobile Scan also retains the shared Unlabel home/search/Profile header
used by the other app screens; its Scan Label title remains task-specific.
The scanner's own header contains only that title, with no second back arrow,
settings action or instruction paragraph, leaving more height for the preview.
Barcode is the initial mode; the other modes are Front and Back. A
centered phone title, pale garden artwork and the shared forest/mint controls
preserve the selected visual direction. One continuous garden illustration sits
behind the preview, mode selector and capture controls, including the mascot;
the illustration is not repeated below the camera. Normal phone layouts fit a fixed
viewport; short windows and enlarged text permit content scrolling so every
action remains reachable. Opening Scan requests camera access;
the rear feed is preferred, audio is disabled, and leaving/backgrounding stops
the session. Captures remain in session memory. Missing camera or denied access
retains retry and gallery. Local v0.6 reads barcode/front/back captures
automatically, with optional backend transfer consent and conservative local
fallback; it removes the Enter package label route. Known barcode reports open
directly; a decoded unknown barcode opens the same Product info destination with
available live/source readings or a clear next photo action. Actual normalized
regions and barcode anchors are highlighted after capture, and the action becomes
View results when useful facts are ready. The captured image stays visible under
a moving scan line and a Reading label/barcode status while processing. Reduced
motion keeps the status and a stationary line; Stop reading cancels the run.
Preview uses a centered aspect-preserving crop; captures use that same visible
region. Capture review contains the resulting photo without stretching it.
Machine output remains explicitly unverified; compatible back-label facts use
the separately documented automatic contribution policy with no per-record
confirmation dialog. There is no mandatory typing. v0.4.0 starts preview without awaiting
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

Scanner illustration provenance: `frontend/assets/artwork/scanner-garden-v1.png`
is a generated 1536×1024 transparent garden/mascot border, made with the built-in
image generation tool for the user's supplied scanner references. It is decorative
Unlabel artwork and provides no product, nutrition or health evidence. Its SHA-256
is `6b04b3a060bec25551f001fecf40e94628211673889c4c5188cd2f526f220f58`.
Live headings, mode labels, camera framing and controls remain Flutter widgets;
no labels or interactive controls are baked into the artwork.
