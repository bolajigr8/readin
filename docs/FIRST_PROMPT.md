# How to start Claude Code (copy/paste)

> Status 2026-11-05: setup done and the first session ran. Real layout: `Book-App/{CLAUDE.md,.claude/,project/}`,
> app in `project/mobile` (its `CLAUDE.md` is there now). For new sessions use the "Never lose the conversation"
> section below and `/resume`. The setup steps are kept for reference only.

## One-time setup (5 minutes) — done
1. Extract this pack so that the files land in your real folders:
   `CLAUDE.md` and `.claude/` go into the inner `Book-App/` folder (next to `project/`);
   `project/docs/…`, `project/server/CLAUDE.md`, `project/admin/CLAUDE.md`, `project/mobile/CLAUDE.md` go inside your existing `project/`.
   (If a `CLAUDE.md` already exists in a folder, keep both: merge by hand.)
2. In Git Bash: `cd "C:/Users/MICBOL/Desktop/React-Native/New-Projects/Book-App/Book-App"` (the inner folder) then run `claude`.
3. First time only, inside Claude Code run `/permissions` and check that reading `.env`, `key.properties` and `*.jks` is denied (the pack's `.claude/settings.json` does this).
4. Commit the new docs: `cd project && git add docs server/CLAUDE.md admin/CLAUDE.md && git commit -m "docs: Claude Code context pack"`.

## The first prompt (paste exactly)
```
Read CLAUDE.md, then project/docs/HISTORY.md, DECISIONS.md and ROADMAP.md, and the CLAUDE.md of each
sub-project. Do NOT change any file yet.

1. Tell me in about 15 lines what you understood: what ReadIn is, how the three code bases fit together,
   the decisions already taken, and the order of the roadmap.
2. Run /verify-all and give me the true baseline (what passes, what fails, exact first error lines).
3. Inspect the code for places where the docs are wrong or stale (e.g. file names, env variables,
   package versions) and list them.
4. Propose the detailed plan for stage S0, following the /stage protocol, and wait for my approval.
Ask me questions only for things you cannot find in the code or docs.
```

## Never lose the conversation
* Every time you start work: `cd` into the inner `Book-App` folder, then `claude --continue` (reopens the most recent conversation) or `claude --resume` (pick an older one). Use plain `claude` only for a brand-new topic.
* If a resumed conversation feels forgetful, or after a restart, run `/resume` — it reads `NEXT.md` and the latest session logs and tells you where you stopped.
* The project also saves its own memory in `project/docs/NEXT.md` and `project/docs/sessions/`; Claude Code updates them as it works. Commit them with your code.

## Then, stage by stage
`/stage S0` → approve → tests pass → commit → `/stage S1` … (S1 first needs you to create the keystore — Claude Code will tell you the exact command and what to back up).
Useful: `/verify-all` anytime · `/release-apk 1.0.0` when S1–S3 are done · `/play-audit` before submitting to Play · `/handoff` at the end of every session.
Tips: use plan mode (Shift+Tab) for risky stages (S1, S4, S5, S8); keep one stage per session; if Claude Code asks for a secret, don't paste it in the chat — set it in Render/Vercel/`.env` yourself.
