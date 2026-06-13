# Mutations-Log — Audit + CI-Politur Lauf 2026-06-13

**Regel R1:** Jede schreibende externe Aktion wird hier protokolliert.
**R31-Reminder:** Keine Live-Aktionen auf `main`, kein Deploy, keine n8n-Config-API-Calls.

---

## 2026-06-13

| Zeit | Aktion | Ziel | Reversibel | Status |
|---|---|---|---|---|
| Setup | `gh repo clone automatiks-io/aio-secure-share` → `~/repos/automatiks-io/aio-secure-share` | lokales Filesystem | ✅ ja (rm) | done |
| Setup | `git checkout -b audit-ci-roadmap-2026-06-13` | lokales Git | ✅ ja (`git branch -d`) | done |
| Audit | `AUDIT.md` erstellt | Branch-File | ✅ ja (Commit revertbar) | done |
| Roadmap | `ROADMAP.md` erstellt | Branch-File | ✅ ja | done |
| Logs | `logs/mutations.md` erstellt | Branch-File | ✅ ja | done |

| Phase 2 | `index.html` Politur (CSS-Tokens, Hero, Trust-Pills, Error-Icon, Footer-Brand, R14-Fix) | Branch-File | ✅ ja | done |
| Phase 2 | `Dockerfile` CSP + Permissions-Policy ergänzt | Branch-File | ✅ ja | done |
| Phase 2 | 5 Screenshots in `screenshots/` (before/after, desktop+mobile, form+invalid) | Branch-File | ✅ ja | done |
| Phase 2 | WebFetch `https://automatiks.io` (read-only, CI-Inspektion) | externer GET | n/a | done |
| Phase 2 | Chrome-DevTools `https://automatiks.io` (read-only, CSS-Vars-Inspektion) | externer GET | n/a | done |
| Phase 2 | Lokaler Python-Server `127.0.0.1:8765` für Screenshot-Mock | lokaler Prozess | ✅ ja (kill) | gestoppt nach Screenshots |
| Phase 4 | `git push -u origin audit-ci-roadmap-2026-06-13` | GitHub-Branch (neu) | ✅ ja (`git push origin --delete`) | done |
| Phase 4 | `gh pr create --base main` → PR #1 | GitHub-PR (open) | ✅ ja (`gh pr close`) | done |
| Phase 5 | **CK-Anweisung „bring das alles ein und live"** — R31-Sperre für diesen Akt explizit aufgehoben | — | — | confirmed |
| Phase 5 | `gh pr merge 1 --merge --delete-branch` → PR #1 nach `main` | `main` (GitHub) | ⚠ schwierig — Revert-PR möglich | done, Commit `66f2986` |
| Phase 5 | Live-Polling `share.automatiks.io` | externer GET | — | **11+ Min ohne Deploy** — Coolify hat nicht gezogen |
| Phase 5 | Doku-Update mutations.md (dieses Eintrag) auf `main` direkt | `main` (lokal+remote) | ✅ ja (revertbar) | wird gepusht |

---

## Bewusst nicht ausgeführt (R31-Sperre)

- ❌ `git push origin main` — würde Coolify-Auto-Deploy triggern
- ❌ `gh pr merge 1 --merge` — würde Live-Deploy auf share.automatiks.io triggern
- ❌ Calls gegen `https://n8n.automatiksio.cloud/webhook/secure-share-api` mit `add_key`/`remove_key`/`route`
- ❌ Calls gegen `https://n8n.automatiksio.cloud/webhook/secure-share` (Submit-Endpoint)
- ❌ Calls gegen `https://pwpush.automatiks.io/p.json` (PwPush-Submit)
- ❌ Kunden-/GF-Kommunikation
