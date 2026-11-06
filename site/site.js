// Turns the download buttons on when /release.json says a release exists.
// Edit release.json for each release (Play link, APK link, version, size, SHA-256) — no code change needed.
(function () {
  var play = document.getElementById('play-btn');
  var apk = document.getElementById('apk-btn');
  var note = document.getElementById('release-note');
  if (!play || !apk || !note || !window.fetch) return;

  fetch('/release.json', { cache: 'no-store' })
    .then(function (r) { return r.ok ? r.json() : null; })
    .then(function (rel) {
      if (!rel) return;
      var parts = [];
      if (rel.playUrl) {
        play.href = rel.playUrl;
        play.textContent = 'Get it on Google Play';
        play.removeAttribute('aria-disabled');
        play.rel = 'noopener';
      }
      if (rel.apk && rel.apk.url) {
        apk.href = rel.apk.url;
        apk.textContent = 'Download for Android' + (rel.apk.version ? ' (v' + rel.apk.version + ')' : '');
        apk.removeAttribute('aria-disabled');
        if (rel.apk.sizeMb) parts.push(rel.apk.sizeMb + ' MB');
        if (rel.apk.date) parts.push('released ' + rel.apk.date);
      }
      if (rel.playUrl || (rel.apk && rel.apk.url)) {
        note.textContent = parts.length ? 'Direct download: ' + parts.join(' · ') : '';
        if (rel.apk && rel.apk.sha256) {
          var s = document.createElement('div');
          s.className = 'mono';
          s.textContent = 'SHA-256: ' + rel.apk.sha256;
          note.appendChild(s);
        }
      }
    })
    .catch(function () { /* keep the "coming soon" buttons */ });
})();
