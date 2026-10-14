# Superseded development note — planned frontend 0.8.1+13

**Historical status: unshipped working scope, superseded by
[frontend 0.9.0+13](FRONTEND_V0_9_0_REVIEW.md).** The earlier hold was lifted by the
user's 13 October completion/push instruction. This note records the intermediate
reset repair, not a separately published release. The preceding source push `59e9411` correctly
used frontend 0.8.0+12 and backend 0.12.1; its
[frontend review](FRONTEND_V0_8_0_REVIEW.md) and
[backend review](BACKEND_V0_12_1_REVIEW.md) keep their own evidence. Backend runtime
and wire contracts are unchanged by this frontend bugfix. Canonical versions remain
the component manifests; this review does not duplicate runtime defaults.

## Changed reset flow

Firebase rejected saving the custom action URL through both Admin API and Console.
The repair uses its supported hosted reset flow instead of requiring that setting.

1. The app sends a reset request through the Firebase SDK with
   `ActionCodeSettings(handleCodeInApp: false, url:
   'https://unlabel-india.vercel.app/#/account-signin')`.
2. The app displays a neutral link-sent confirmation. It does not disclose whether
   the account exists or claim that a password has changed.
3. Firebase's same-project `/__/auth/action` page validates the code, accepts the
   new password and shows success under the project's configured password policy.
4. Firebase's Continue action opens the fixed authorized Unlabel web sign-in URL.
   The app recognizes only its strict sign-in return route; it receives no reset
   code and does not automatically sign the user in.

The public legacy bridge forwards supported account actions to Firebase's reserved
handler with the fixed return destination. It no longer redirects reset codes into
an app-owned password form. This local bridge change still requires its normal
verification and eventual deployment; no deployment is authorized in this scope.
No custom email template, mail service, database or billing/card is needed.
[Account/profile contract](../architecture/ACCOUNT_PROFILE.md).

## App UI and asset boundaries

The app retains sign-in, signup, forgot-password and neutral link-sent states.
Remove the custom new-password/success states and their now-unused runtime artwork.
Keep the actual filled Unlabel BrandLeaf and centered leaf/Unlabel wordmark,
Profile-origin phone X and one viewport without horizontal or vertical page
scrolling. Further auth visual polish is deferred. Single-screen layout and
reference acceptance need current rendered evidence; source changes alone do not
establish an exact match.

Google/password linking, account isolation, private thumbnail/gender settings,
guest workflows and the existing account library contract retain their preceding
scope. New-password signup/linking keeps the app policy; the Firebase-hosted reset
page owns its own validation.

The local Vercel build script also reduces successful Flutter test output to its
final summary line. A failing command still prints full diagnostics and exits
nonzero. Earlier quoted negative-case test names were verified as `stdout`, not
failed deployment events; this change does not relabel a real error as success.

## Verification boundaries

New SDK request-settings, return-route, bridge and responsive auth tests are
pending until their current results are recorded. A synthetic generated-link check
can verify handler/Continue URL configuration without sending an email; it cannot
prove inbox delivery. Real reset-email delivery, Google consent, exact-source
hosted/native behavior and physical LiveContainer acceptance remain separate gates.
No final release or hosted success is claimed for this held local source.

The configuration follows Firebase's official
[email-action state documentation](https://firebase.google.com/docs/auth/web/passing-state-in-email-actions),
checked through Context7 for this change.
