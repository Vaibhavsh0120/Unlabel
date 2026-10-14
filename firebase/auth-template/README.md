# Firebase password-reset email

Checked against the live `unlabel-india-catalogue` project on **13 October 2026**.
The project remains without billing. Its default Firebase email delivery and
supported hosted reset handler remain active.

## Applied and verified

The password-reset email's **sender display name is now `Unlabel`**. A field-scoped
Identity Toolkit config update returned HTTP 200; a separate GET confirmed it.
The project name is also `Unlabel`. The working Firebase template still uses:

- Subject: `Reset your password for %APP_NAME%`.
- Firebase's default HTML message, including `%LINK%` and the ignore-if-unrequested
  explanation.
- Sender local part `noreply` and the existing Firebase sender domain.
- Action URL: `https://unlabel-india-catalogue.firebaseapp.com/__/auth/action`.

The app requests the fixed continue URL
`https://unlabel-india.vercel.app/#/account-signin` with `handleCodeInApp: false`.
Firebase validates the code and owns new-password entry and completion. Continue
returns to Unlabel's sign-in screen; a reset never claims that the user signed in.

## Provider restriction and prepared design

Firebase rejected a field-scoped custom subject update and a separate HTML body
update with HTTP 400 **`EMAIL_TEMPLATE_UPDATE_NOT_ALLOWED`**. The earlier combined
template update was rejected with the same error. Fresh readback confirmed the
default subject/body and hosted action URL remained in place. This is an observed
project restriction; the response does not establish its cause or a billing fix.

[password-reset.html](password-reset.html) and
[password-reset.proposed.json](password-reset.proposed.json) are an **unapplied
design draft**, ready if Firebase permits template customization later. They use
the existing white, mint and forest palette, a clear reset action, a copyable link
and an explanation for unsolicited requests. They preserve `%APP_NAME%` and
`%LINK%`. The proposed subject is `Reset your Unlabel password`. The draft passed
the Better Design text-comprehension check; actual inbox rendering is unverified.

Changing a provider restriction requires Firebase support or a later explicit
delivery decision. No custom SMTP, paid service, Function, Storage bucket, billing
change or new reset handler was added. The functional reset flow does not depend
on activating this draft.

## Verification boundary

A privileged `accounts:sendOobCode` request used a synthetic nonexistent
`example.invalid` address and **`returnOobLink: true`**, which sends no email.
Firebase returned HTTP 200 without a reset link, consistent with the project's
enabled email-enumeration protection. This checks the configured request is
accepted without revealing account existence; it does **not** prove a valid reset
code, password completion, inbox delivery or native deep linking. No user was
created, read, modified or deleted for this check, and no email was sent.

Live settings and source are separate evidence. The sender update is live;
committing these draft files does not install an email template.

## Official references

- [Firebase account-management email customization](https://support.google.com/firebase/answer/7000714)
- [Identity Toolkit config and email-template fields](https://docs.cloud.google.com/identity-platform/docs/reference/rest/v2/Config#EmailTemplate)
- [Field-scoped project config updates](https://docs.cloud.google.com/identity-platform/docs/reference/rest/v2/projects/updateConfig)
- [No-email link generation with returnOobLink](https://docs.cloud.google.com/identity-platform/docs/reference/rest/v1/accounts/sendOobCode)
- [Flutter password-reset requests](https://firebase.google.com/docs/auth/flutter/manage-users#send_a_password_reset_email)
