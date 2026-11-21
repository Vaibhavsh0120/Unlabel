(() => {
  'use strict';
  const params = new URLSearchParams(location.hash.slice(1));
  const query = new URLSearchParams(location.search);
  history.replaceState(null, '', '/account-confirmation.html');
  const status = document.getElementById('status');
  if (params.has('error') || query.has('error')) {
    status.textContent = 'This confirmation link is invalid or expired. Return to Unlabel and request a new email.';
  } else if (['signup', 'email_change'].includes(params.get('type'))) {
    status.textContent = 'Your email link has been confirmed. Return to Unlabel and sign in.';
  }
  // Confirmation credentials never activate a scanner or enter browser storage.
})();
