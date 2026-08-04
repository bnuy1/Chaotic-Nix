// Live recolor for Spotify: poll colors.css in the app bundle and, when its
// content changes (spicetify -n refresh after a palette switch), re-apply it
// by cache-busting the stylesheet link. No restart, no devtools needed.
//
// On the first poll the link is cache-busted unconditionally: the browser
// often serves a stale cached colors.css at startup, and without this the
// first palette change after launch would be recorded as the baseline and
// never applied.
(function () {
  "use strict";
  var POLL_MS = 800;
  var first = true;
  var last = null;

  function getLink() {
    return document.querySelector('link[href="colors.css"], link[href^="colors.css"]');
  }

  function forceReload() {
    var l = getLink();
    if (l) l.href = "colors.css?t=" + Date.now();
  }

  async function poll() {
    try {
      var r = await fetch("colors.css", { cache: "no-store" });
      var t = await r.text();
      if (first) {
        first = false;
        last = t;
        forceReload();
      } else if (t !== last) {
        last = t;
        forceReload();
      }
    } catch (e) { /* page still loading */ }
    setTimeout(poll, POLL_MS);
  }

  setTimeout(poll, 1500);
})();
