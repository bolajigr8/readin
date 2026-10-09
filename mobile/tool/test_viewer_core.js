// Run:  node tool/test_viewer_core.js
const assert = require('assert');
const core = require('../assets/reader/viewer_core.js');
let n = 0;
const t = (name, fn) => { fn(); n++; console.log('ok -', name); };

t('colIndex', () => {
  assert.strictEqual(core.colIndex('A1'), 0);
  assert.strictEqual(core.colIndex('Z9'), 25);
  assert.strictEqual(core.colIndex('AA10'), 26);
  assert.strictEqual(core.colIndex('AB2'), 27);
  assert.strictEqual(core.colIndex(''), 0);
});

t('naturalCompare orders pages naturally', () => {
  const a = ['p10.jpg', 'p2.jpg', 'p1.jpg', 'P3.jpg'];
  a.sort(core.naturalCompare);
  assert.deepStrictEqual(a, ['p1.jpg', 'p2.jpg', 'P3.jpg', 'p10.jpg']);
});

t('parseCsv basics, quotes, escapes, CRLF', () => {
  const r = core.parseCsv('a,b,c\r\n1,"x, y",3\r\n"he said ""hi""",,\r\n');
  assert.deepStrictEqual(r.rows, [['a', 'b', 'c'], ['1', 'x, y', '3'], ['he said "hi"', '', '']]);
  assert.strictEqual(r.truncated, false);
});

t('parseCsv detects ; and tab, strips BOM, keeps multi-line fields', () => {
  assert.deepStrictEqual(core.parseCsv('\uFEFFa;b\n1;2').rows, [['a', 'b'], ['1', '2']]);
  assert.deepStrictEqual(core.parseCsv('a\tb\n1\t2').rows, [['a', 'b'], ['1', '2']]);
  assert.deepStrictEqual(core.parseCsv('a,b\n"line1\nline2",x').rows, [['a', 'b'], ['line1\nline2', 'x']]);
});

t('parseCsv truncates huge files', () => {
  const big = Array.from({ length: 50 }, (_, i) => i + ',x').join('\n');
  const r = core.parseCsv(big, 10);
  assert.strictEqual(r.rows.length, 10);
  assert.strictEqual(r.truncated, true);
});

t('markdown: headings, emphasis, links, code', () => {
  const h = core.markdownToHtml('# Title\n\nHello **bold** and *it* and `x < y` [site](https://a.com).');
  assert.ok(h.includes('<h1>Title</h1>'));
  assert.ok(h.includes('<strong>bold</strong>'));
  assert.ok(h.includes('<em>it</em>'));
  assert.ok(h.includes('<code>x &lt; y</code>'));
  assert.ok(h.includes('<a href="https://a.com">site</a>'));
});

t('markdown: lists, quote, rule, fenced code', () => {
  const h = core.markdownToHtml('- a\n- b\n\n1. one\n2. two\n\n> quoted\n\n---\n\n```js\nlet a = "<b>";\n```');
  assert.ok(h.includes('<ul>\n<li>a</li>\n<li>b</li>\n</ul>'));
  assert.ok(h.includes('<ol>\n<li>one</li>\n<li>two</li>\n</ol>'));
  assert.ok(h.includes('<blockquote>quoted</blockquote>'));
  assert.ok(h.includes('<hr>'));
  assert.ok(h.includes('<pre><code>let a = &quot;&lt;b&gt;&quot;;</code></pre>'));
});

t('markdown is XSS safe', () => {
  const h = core.markdownToHtml('<script>alert(1)</script> [x](javascript:alert(1)) ![i](http://e/x.png)');
  assert.ok(!h.includes('<script'));
  assert.ok(!/href="javascript/i.test(h));
  assert.ok(!h.includes('<img'));
});

t('textToHtml keeps paragraphs and escapes', () => {
  const h = core.textToHtml('Hello <b>\nworld\n\nSecond');
  assert.strictEqual(h, '<p>Hello &lt;b&gt;<br>world</p>\n<p>Second</p>');
});

console.log(`\n${n} tests passed`);
