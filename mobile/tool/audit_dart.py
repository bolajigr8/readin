#!/usr/bin/env python3
"""Static audit for the Flutter project (no Dart SDK needed).
Checks: import resolution · package deps in pubspec · symbols used but not imported
 · `show`/`hide` clauses · constructor named/required args at call sites · assets.
Usage: python3 audit_dart.py <project root>"""
import os, re, sys, glob

# Windows consoles default to cp1252, which cannot print the ✗ mark.
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

root = sys.argv[1] if len(sys.argv) > 1 else '.'
PKG = 'readin_flutter'
problems = []
def bad(f, msg): problems.append(f"{os.path.relpath(f, root)}: {msg}")

files = [os.path.normpath(f) for f in glob.glob(root + '/lib/**/*.dart', recursive=True) + glob.glob(root + '/test/**/*.dart', recursive=True) + glob.glob(root + '/tool/**/*.dart', recursive=True)]

def strip(src):
    """remove comments and string contents (keep quotes) so tokens are code only."""
    out = []; i = 0; n = len(src)
    while i < n:
        c = src[i]
        if src.startswith('//', i):
            j = src.find('\n', i); j = n if j < 0 else j; i = j; continue
        if src.startswith('/*', i):
            j = src.find('*/', i); i = n if j < 0 else j + 2; continue
        if c in '\'"':
            q = c; triple = src.startswith(q * 3, i)
            if src.startswith('r' + q, i - 1) : pass
            end = q * 3 if triple else q
            j = i + (3 if triple else 1)
            while j < n:
                if src[j] == '\\' : j += 2; continue
                if src.startswith(end, j): break
                j += 1
            out.append(q + q); i = j + len(end); continue
        out.append(c); i += 1
    return ''.join(out)

raw = {f: open(f, encoding='utf-8').read() for f in files}
code = {f: strip(raw[f]) for f in files}

# ── imports
imp_re = re.compile(r"""^\s*(import|export)\s+['"]([^'"]+)['"]([^;]*);""", re.M)
def resolve(f, target):
    if target.startswith('dart:'): return 'dart'
    if target.startswith('package:'):
        pkg, _, rest = target[8:].partition('/')
        if pkg == PKG: return os.path.normpath(os.path.join(root, 'lib', rest))
        return 'pkg:' + pkg
    return os.path.normpath(os.path.join(os.path.dirname(f), target))

pubspec = open(os.path.join(root, 'pubspec.yaml'), encoding='utf-8').read()
deps = set(re.findall(r'^  ([a-z_0-9]+):', pubspec, re.M))
sdk_ok = {'flutter', 'flutter_test', 'flutter_localizations'}

imports = {}
for f in files:
    lst = []
    for kind, tgt, tail in imp_re.findall(raw[f]):
        r = resolve(f, tgt)
        show = hide = None
        m = re.search(r'\bshow\s+([\w\s,]+)', tail)
        if m: show = {x.strip() for x in m.group(1).split(',') if x.strip()}
        m = re.search(r'\bhide\s+([\w\s,]+)', tail)
        if m: hide = {x.strip() for x in m.group(1).split(',') if x.strip()}
        if r == 'dart': pass
        elif r.startswith('pkg:'):
            if r[4:] not in deps and r[4:] not in sdk_ok: bad(f, f"imports package '{r[4:]}' which is not in pubspec.yaml")
        elif not os.path.exists(r): bad(f, f"import not found: {tgt}")
        lst.append((kind, tgt, r, show, hide))
    imports[f] = lst

# ── top-level symbols per project file
sym_re = re.compile(r'^(?:abstract\s+|sealed\s+|final\s+|base\s+|interface\s+|mixin\s+)*(?:class|enum|mixin|typedef|extension\s+type)\s+(\w+)|^(?:const|final|var)\s+(?:[\w<>?,\s]+?\s)?(\w+)\s*=|^(?:Future<[^>]*>|Future|void|bool|int|double|String|[A-Z]\w*(?:<[^>]*>)?\??)\s+(\w+)\s*(?:<[^>]*>)?\s*\(', re.M)
defs = {}
for f in files:
    s = set()
    for m in sym_re.finditer(code[f]):
        for g in m.groups():
            if g and not g.startswith('_'): s.add(g)
    # Dart 3 record typedef / extension
    for m in re.finditer(r'^extension\s+(\w+)\s+on', code[f], re.M): s.add(m.group(1))
    defs[f] = s

owners = {}
for f, s in defs.items():
    for x in s: owners.setdefault(x, set()).add(f)

def exported(f, seen=None):
    """symbols visible when importing f (its own + `export`ed files)."""
    seen = seen or set()
    if f in seen: return set()
    seen.add(f)
    out = set(defs.get(f, ()))
    for kind, tgt, r, show, hide in imports.get(f, ()):
        if kind == 'export' and r in defs:
            ex = exported(r, seen)
            if show: ex &= show
            if hide: ex -= hide
            out |= ex
    return out

tok = re.compile(r'(?<![\w.$])([A-Za-z_]\w*)')
for f in files:
    used = set(tok.findall(code[f]))
    own = defs[f]
    # names declared locally (any scope) reduce false positives
    local_decl = set(re.findall(r'\b(?:final|var|const|late|int|double|bool|String|Future|dynamic)\s+(?:<[^>]*>\s*)?(\w+)\s*[=;,)]', code[f]))
    local_decl |= set(re.findall(r'\b(\w+)\s*(?:,|\))\s*(?:=>|\{)', code[f]))
    visible = set()
    for kind, tgt, r, show, hide in imports[f]:
        if kind != 'import' or r not in defs: continue
        ex = exported(r)
        if show: 
            miss = [u for u in used if u in ex and u not in show]
            # symbols used but hidden by `show` list
            for u in miss:
                if u not in own and u not in visible:
                    pass
            ex = ex & show
        if hide: ex = ex - hide
        visible |= ex
    for u in sorted(used):
        if u in own or u in visible or u in local_decl: continue
        o = owners.get(u)
        if not o: continue
        # used symbol is defined in project file(s) but not visible here
        if len(o) == 1 and list(o)[0] != f:
            # was it hidden by a `show` list?
            g = list(o)[0]
            hidden_by_show = any(r == g and show and u not in show and u in exported(g) for _, _, r, show, _ in imports[f])
            # is it only a common word (method/field) rather than a type/provider?
            if re.match(r'^[A-Z]', u) or u.endswith('Provider') or re.match(r'^(show|open|read|format|label|title|time|habit|status|day|date|current|best|month|total|progress|merge|apply|evaluate|kind|extension|mime|storage)\w*$', u) is None and False:
                bad(f, f"uses '{u}' (defined in {os.path.relpath(g, root)}) but {'the import has a `show` list without it' if hidden_by_show else 'does not import it'}")
            elif hidden_by_show:
                bad(f, f"uses '{u}' (defined in {os.path.relpath(g, root)}) but the import's `show` list does not include it")
        # lowerCamel top-level functions/providers: only flag providers & show*/open* helpers
        elif len(o) == 1 and list(o)[0] == f: pass

# lower-case helper functions & providers (single owner) not imported
for f in files:
    used = set(tok.findall(code[f]))
    visible = set(defs[f])
    for kind, tgt, r, show, hide in imports[f]:
        if kind == 'import' and r in defs:
            ex = exported(r)
            if show: ex &= show
            if hide: ex -= hide
            visible |= ex
    for u in used:
        if u in visible: continue
        o = owners.get(u)
        if o and len(o) == 1 and not re.match(r'^[A-Z]', u) and (u.endswith('Provider') or u.startswith(('show', 'open', 'format', 'label', 'merge', 'status', 'effective', 'evaluate'))):
            g = list(o)[0]
            if g != f and not re.search(r'\b(?:final|var|void|bool|int|String|Future\S*)\s+' + re.escape(u) + r'\b', code[f]) and not re.search(r'[.]\s*' + re.escape(u) + r'\b', code[f]) :
                bad(f, f"uses '{u}' (defined in {os.path.relpath(g, root)}) without importing it")

# ── constructor argument check
ctor = {}
class_re = re.compile(r'(?:^|\n)\s*(?:abstract\s+|final\s+|base\s+|sealed\s+)*class\s+(\w+)\b[^{;]*\{', re.M)
def balanced(s, i, open_c='(', close_c=')'):
    d = 0; j = i
    while j < len(s):
        if s[j] == open_c: d += 1
        elif s[j] == close_c:
            d -= 1
            if d == 0: return j
        j += 1
    return -1
def split_top(s, angle=False):
    parts = []; d = 0; cur = ''
    opens = '([{<' if angle else '([{'; closes = ')]}>' if angle else ')]}'
    prev = ''
    for c in s:
        if c in opens and not (c == '<' and prev in '<'): d += 1
        elif c in closes and not (c == '>' and prev == '='): d -= 1
        prev = c
        if c == ',' and d == 0: parts.append(cur); cur = ''
        else: cur += c
    if cur.strip(): parts.append(cur)
    return parts
for f in files:
    s = code[f]
    for m in class_re.finditer(s):
        name = m.group(1)
        # find default constructor:  [const] Name(
        cm = re.search(r'\b(?:const\s+)?' + re.escape(name) + r'\s*\(', s[m.end():m.end() + 6000])
        if not cm: continue
        start = m.end() + cm.end() - 1
        end = balanced(s, start)
        if end < 0: continue
        inner = s[start + 1:end]
        b = inner.find('{')
        named = set(); req = set(); positional = 0
        if b >= 0 and balanced(inner, b, '{', '}') > b:
            pos_part = inner[:b]; named_part = inner[b + 1:balanced(inner, b, '{', '}')]
            positional = len([p for p in split_top(pos_part, True) if p.strip()])
            for p in split_top(named_part, True):
                p = p.strip()
                if not p: continue
                p2 = re.split(r'(?<![=!<>])=(?![=>])', p, maxsplit=1)[0]
                words = re.findall(r'\w+', p2)
                if words:
                    nm = words[-1]; named.add(nm)
                    if p.lstrip().startswith('required'): req.add(nm)
        else:
            positional = len([p for p in split_top(inner, True) if p.strip()])
        ctor.setdefault(name, []).append((f, named, req, positional, b >= 0))

call_re = re.compile(r'(?<![\w.$])(?:const\s+|new\s+)?(_?[A-Z]\w*)\s*\(')
for f in files:
    s = code[f]
    for m in call_re.finditer(s):
        name = m.group(1)
        cands = [c for c in ctor.get(name, []) if (not name.startswith('_')) or c[0] == f]
        if len(cands) != 1: continue
        # skip declarations: "class Name(" / factory / constructor definitions inside the class itself
        before = s[max(0, m.start() - 40):m.start()]
        if re.search(r'(?:class|extends|implements|with|factory|=>)\s*$', before) and 'class' in before[-12:]: continue
        cf, named, req, positional, has_named = cands[0]
        o = m.end() - 1
        e = balanced(s, o)
        if e < 0: continue
        nxt = s[e + 1:e + 40].lstrip()[:1]
        if nxt in ('{', ';', ':') and cf == f: continue   # the constructor declaration itself
        args = split_top(s[o + 1:e])
        given = set(); pos = 0
        for a in args:
            a = a.strip()
            if not a: continue
            nm = re.match(r'(\w+)\s*:(?!:)', a)
            if nm and not a.startswith(('?', '(')): given.add(nm.group(1))
            else: pos += 1
        if not has_named and positional == 0: continue
        for g in given:
            if g not in named:
                bad(f, f"{name}(...) has no parameter named '{g}'")
        for r in req:
            if r not in given:
                bad(f, f"{name}(...) is missing required parameter '{r}'")


# ── unused / duplicate imports (what `flutter analyze` reports as warnings)
interp = lambda src: set(re.findall(r'[A-Za-z_]\w*', ' '.join(re.findall(r'\$\{([^{}]*)\}', src) + re.findall(r'\$([A-Za-z_]\w*)', src))))
for f in files:
    used = set(tok.findall(code[f])) | interp(raw[f])
    seen = {}
    for kind, tgt, r, show, hide in imports[f]:
        if kind != 'import': continue
        key = (tgt, tuple(sorted(show or ())), tuple(sorted(hide or ())))
        if key in seen: bad(f, f"duplicate import: {tgt}")
        seen[key] = True
        if r in defs:
            ex = exported(r)
            if show: ex = ex & show
            if hide: ex = ex - hide
            has_ext = bool(re.search(r'^extension\s', code.get(r, ''), re.M))  # used as context.something
            if ex and not (ex & used) and not has_ext and not tgt.endswith('ionicons.dart'):
                bad(f, f"unused import: {tgt}")

# ── assets
asset_dirs = re.findall(r'^\s+- (assets/[^\s]+)', pubspec, re.M)
for d in asset_dirs:
    if not os.path.exists(os.path.join(root, d)): bad(os.path.join(root, 'pubspec.yaml'), f"asset path missing: {d}")
for f in [x for x in files if not x.startswith('tool')]:
    for m in re.finditer(r"['\"](assets/[\w./-]+)['\"]", raw[f]):
        p = os.path.join(root, m.group(1))
        if not os.path.exists(p): bad(f, f"asset not found: {m.group(1)}")

# ── Ionicons names
shim = open(os.path.join(root, 'lib/constants/ionicons.dart'), encoding='utf-8').read()
have = set(re.findall(r'static const IconData (\w+) =', shim))
for f in files:
    if f.replace(os.sep, '/').endswith('constants/ionicons.dart'): continue  # Windows paths use backslashes
    for n in set(re.findall(r'Ionicons\.([a-z_0-9]+)', code[f])):
        if n not in have: bad(f, f"Ionicons.{n} missing from the icon file")

print(f"audited {len(files)} dart files")
for p in sorted(set(problems)): print('✗', p)
print(f"{len(set(problems))} problem(s)")
sys.exit(1 if problems else 0)
