/* Pugmark marketing — tiny progressive enhancements. Works without this file. */
(function () {
  'use strict';

  var toast = document.getElementById('toast');
  var toastTimer = 0;
  function say(msg) {
    if (!toast) return;
    toast.textContent = msg;
    toast.classList.add('is-on');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(function () { toast.classList.remove('is-on'); }, 2800);
  }

  // Store buttons are placeholders until the apps ship; don't jump to top on "#".
  document.querySelectorAll('[data-store]').forEach(function (a) {
    a.addEventListener('click', function (e) {
      e.preventDefault();
      var store = a.getAttribute('data-store') === 'ios' ? 'the App Store' : 'Google Play';
      say('Not in ' + store + ' yet. Soon — your first run opens the bag.');
    });
  });

  // Serial lookup: trim before submitting (the form works natively without JS).
  var form = document.getElementById('lookup-form');
  var q = document.getElementById('q');
  if (form && q) {
    form.addEventListener('submit', function (e) {
      var v = q.value.trim();
      if (!v) { e.preventDefault(); q.focus(); return; }
      e.preventDefault();
      window.location.href = 'verify.html?q=' + encodeURIComponent(v);
    });
  }
})();
