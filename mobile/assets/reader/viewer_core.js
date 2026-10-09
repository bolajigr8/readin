/* Pure helpers of the ReadIn document viewer (no DOM) — unit-tested with Node:
 *   node tool/test_viewer_core.js
 */
var ReadInViewerCore = (function () {
  'use strict';

  function escapeHtml(s) {
    return String(s)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }

  /** "AB12" -> 27 (0-based column index of the letters). */
  function colIndex(ref) {
    var m = /^([A-Za-z]+)/.exec(ref || '');
    if (!m) return 0;
    var s = m[1].toUpperCase(), n = 0;
    for (var i = 0; i < s.length; i++) n = n * 26 + (s.charCodeAt(i) - 64);
    return n - 1;
  }

  /** Natural sort ("page2" < "page10") for comic pages. */
  function naturalCompare(a, b) {
    var ra = String(a).toLowerCase().match(/(\d+|\D+)/g) || [];
    var rb = String(b).toLowerCase().match(/(\d+|\D+)/g) || [];
    for (var i = 0; i < Math.min(ra.length, rb.length); i++) {
      var x = ra[i], y = rb[i];
      var nx = /^\d+$/.test(x), ny = /^\d+$/.test(y);
      if (nx && ny) {
        var d = parseInt(x, 10) - parseInt(y, 10);
        if (d !== 0) return d;
      } else if (x !== y) {
        return x < y ? -1 : 1;
      }
    }
    return ra.length - rb.length;
  }

  /** RFC-4180-ish CSV parser (quotes, "" escapes, CRLF, ; or tab delimiters). */
  function parseCsv(text, maxRows) {
    text = String(text).replace(/^\uFEFF/, '');
    var first = text.split(/\r?\n/, 1)[0] || '';
    var delim = ',';
    var best = (first.match(/,/g) || []).length;
    var semi = (first.match(/;/g) || []).length;
    var tab = (first.match(/\t/g) || []).length;
    if (semi > best) { delim = ';'; best = semi; }
    if (tab > best) { delim = '\t'; }

    var rows = [], row = [], field = '', inQ = false;
    maxRows = maxRows || 5000;
    for (var i = 0; i < text.length; i++) {
      var c = text[i];
      if (inQ) {
        if (c === '"') {
          if (text[i + 1] === '"') { field += '"'; i++; } else { inQ = false; }
        } else {
          field += c;
        }
      } else if (c === '"') {
        inQ = true;
      } else if (c === delim) {
        row.push(field); field = '';
      } else if (c === '\n' || c === '\r') {
        if (c === '\r' && text[i + 1] === '\n') i++;
        row.push(field); field = '';
        rows.push(row); row = [];
        if (rows.length >= maxRows) return { rows: rows, truncated: true };
      } else {
        field += c;
      }
    }
    if (field.length || row.length) { row.push(field); rows.push(row); }
    return { rows: rows, truncated: false };
  }

  function inlineMd(s) {
    s = escapeHtml(s);
    var codes = [];
    s = s.replace(/`([^`]+)`/g, function (_, c) { codes.push(c); return '\u0000' + (codes.length - 1) + '\u0000'; });
    s = s.replace(/!\[([^\]]*)\]\(([^)]*)\)/g, function (_, alt) { return '<em>[' + alt + ']</em>'; });
    s = s.replace(/\[([^\]]+)\]\((https?:\/\/[^)\s]+|mailto:[^)\s]+)\)/g, '<a href="$2">$1</a>');
    s = s.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
    s = s.replace(/__([^_]+)__/g, '<strong>$1</strong>');
    s = s.replace(/(^|[^*])\*([^*\s][^*]*)\*/g, '$1<em>$2</em>');
    s = s.replace(/(^|[^_\w])_([^_\s][^_]*)_/g, '$1<em>$2</em>');
    s = s.replace(/~~([^~]+)~~/g, '<del>$1</del>');
    s = s.replace(/\u0000(\d+)\u0000/g, function (_, i) { return '<code>' + codes[+i] + '</code>'; });
    return s;
  }

  /** Small, safe Markdown -> HTML (headings, lists, quotes, code, rules, tables-as-text). */
  function markdownToHtml(src) {
    var lines = String(src).replace(/\r\n?/g, '\n').split('\n');
    var out = [], i = 0, para = [], listType = null;

    function flushPara() {
      if (para.length) { out.push('<p>' + inlineMd(para.join(' ')) + '</p>'); para = []; }
    }
    function closeList() {
      if (listType) { out.push('</' + listType + '>'); listType = null; }
    }

    while (i < lines.length) {
      var line = lines[i];

      var fence = /^```\s*(\w*)\s*$/.exec(line);
      if (fence) {
        flushPara(); closeList();
        var code = [];
        i++;
        while (i < lines.length && !/^```\s*$/.test(lines[i])) { code.push(lines[i]); i++; }
        i++;
        out.push('<pre><code>' + escapeHtml(code.join('\n')) + '</code></pre>');
        continue;
      }

      if (/^\s*$/.test(line)) { flushPara(); closeList(); i++; continue; }

      var h = /^(#{1,6})\s+(.*?)\s*#*\s*$/.exec(line);
      if (h) {
        flushPara(); closeList();
        out.push('<h' + h[1].length + '>' + inlineMd(h[2]) + '</h' + h[1].length + '>');
        i++; continue;
      }

      if (/^\s*([-*_])(\s*\1){2,}\s*$/.test(line)) {
        flushPara(); closeList(); out.push('<hr>'); i++; continue;
      }

      var bq = /^>\s?(.*)$/.exec(line);
      if (bq) {
        flushPara(); closeList();
        var quote = [bq[1]];
        i++;
        while (i < lines.length && /^>\s?/.test(lines[i])) { quote.push(lines[i].replace(/^>\s?/, '')); i++; }
        out.push('<blockquote>' + inlineMd(quote.join(' ')) + '</blockquote>');
        continue;
      }

      var ul = /^\s*[-*+]\s+(.*)$/.exec(line);
      var ol = /^\s*\d+[.)]\s+(.*)$/.exec(line);
      if (ul || ol) {
        flushPara();
        var type = ul ? 'ul' : 'ol';
        if (listType !== type) { closeList(); out.push('<' + type + '>'); listType = type; }
        out.push('<li>' + inlineMd((ul || ol)[1]) + '</li>');
        i++; continue;
      }

      closeList();
      para.push(line.trim());
      i++;
    }
    flushPara(); closeList();
    return out.join('\n');
  }

  /** Plain text -> paragraphs (blank-line separated, single newlines kept). */
  function textToHtml(text) {
    var blocks = String(text).replace(/\r\n?/g, '\n').split(/\n{2,}/);
    var out = [];
    for (var i = 0; i < blocks.length; i++) {
      var b = blocks[i].replace(/^\n+|\n+$/g, '');
      if (!b) continue;
      out.push('<p>' + escapeHtml(b).replace(/\n/g, '<br>') + '</p>');
    }
    return out.join('\n');
  }

  var api = {
    escapeHtml: escapeHtml,
    colIndex: colIndex,
    naturalCompare: naturalCompare,
    parseCsv: parseCsv,
    markdownToHtml: markdownToHtml,
    textToHtml: textToHtml
  };
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  return api;
})();
