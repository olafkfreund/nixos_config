// Injects a blinking terminal cursor after the MkDocs Material header brand.
// Paired with the .term-cursor rule + @keyframes term-blink in terminal.css.
//
// MkDocs Material uses instant navigation, so we re-run on every page swap
// via the `document$` subscriber (exposed by Material when the
// `navigation.instant` feature is enabled).

(function () {
  'use strict';

  function injectCursor() {
    document.querySelectorAll('.md-header__topic > .md-ellipsis').forEach(function (el) {
      if (el.querySelector('.term-cursor')) return; // already injected
      var span = document.createElement('span');
      span.className = 'term-cursor';
      span.setAttribute('aria-hidden', 'true');
      el.appendChild(span);
    });
  }

  // Initial pageload.
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', injectCursor);
  } else {
    injectCursor();
  }

  // Material's instant-navigation observable.
  if (typeof window !== 'undefined' && window.document$) {
    window.document$.subscribe(injectCursor);
  }
})();
