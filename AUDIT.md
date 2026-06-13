# Serienreife-Audit — AIO Secure-Share

**Stand:** 2026-06-13
**Branch:** `audit-ci-roadmap-2026-06-13`
**Auditor:** Claude (autonom, überwacht durch CK)
**Scope:** Frontend (`index.html`, `Dockerfile`, `robots.txt`) — n8n-Config-API und Live-Keys NICHT geprüft (R31 Leitplanke).

---

## Exec Summary

Das AIO Secure-Share ist funktional produktiv, aber **nicht serienreif** für breitere Verwendung. Drei Befunde stechen heraus:

1. **CRITICAL:** Webhook-Secret (`aio-share-k8x2m9v4`) liegt im Klartext im ausgelieferten HTML. Der Header `X-Auth-Token` ist damit für jeden Besucher der Seite sichtbar und nutzlos als Authentifizierung. Jeder kann den n8n-Webhook direkt aufrufen.
2. **CRITICAL:** Architektur ist **Single-Tenant** — Branding, Footer, Logo, Farben hart kodiert. Mandantenfähigkeit (zweite Agentur mit eigenem Whitelabel) ist ohne Refactor nicht möglich.
3. **HIGH:** Vertrauensindikatoren fehlen: kein Impressums-Backlink im Header, kein „powered by", knapper Sicherheits-Disclaimer, kein Hinweis auf Selbsthosting/EU-Standort obwohl PwPush in EU läuft. Endkunden lesen das nicht als „Enterprise Tool".

Daneben ein UX-Bug: `Uebertragung fehlgeschlagen` (Zeile 677) verletzt R14 (Umlaute) und wirkt unprofessionell.

**Empfehlung:** Phase 2 (CI-Politur) JETZT, Phase A der Roadmap (Tenant-Trennung in n8n) als nächster konkreter Schritt für Whitelabel.

---

## 1. Multi-Tenancy / Mandantenfähigkeit

| Punkt | Status | Severity |
|---|---|---|
| Eine zweite Agentur kann eigenes Branding fahren | ❌ Nein | CRITICAL |
| Routes/Keys sind in n8n getrennt | ⚠ Vermutet (Config-API), nicht geprüft | — |
| Footer/Impressum pro Mandant konfigurierbar | ❌ Hart kodiert auf automatiks.io | HIGH |
| Logo pro Mandant ladbar | ❌ Hart kodiert `https://automatiks.io/logo/...` | HIGH |
| Farben pro Mandant konfigurierbar | ❌ Statisches CSS, keine Tokens | HIGH |

**Befund:** Aus Sicht des Frontends ist das Repo monolithisch auf `automatiks.io` gebrandet. Auch wenn die n8n-Config-API Multi-Tenant-Routes erlaubt, ist das Frontend an einen Mandanten gebunden.

---

## 2. Whitelabel-Fähigkeit

| Punkt | Status | Severity |
|---|---|---|
| Custom-Subdomain pro Agentur (z.B. `share.kunde-x.de`) | ❌ Nein | HIGH |
| Logo per Config-Antwort austauschbar | ❌ Nein | HIGH |
| Farben per Config-Antwort austauschbar | ❌ Nein | HIGH |
| Footer/Impressum austauschbar | ❌ Nein | HIGH |
| Absender-Hinweise austauschbar | ❌ Nein | MEDIUM |

**Befund:** Keine Whitelabel-Mechanik im Frontend. Sähe der ck_EA-Mandant `RegioNext` über `share.regionext.de` nichts von ihm — er sähe automatiks.io.

→ Siehe `ROADMAP.md` Phase B+C für Lösungsvorschlag.

---

## 3. Auth & Sicherheit

### 3.1 Key-Handling

| Punkt | Status | Severity |
|---|---|---|
| Key liegt in URL-Param `?key=...` | ✅ Standard | — |
| Key wird per POST an Config-API validiert | ✅ ok | — |
| Server-side Ablauf-/Einmal-Logik (in n8n) | ⚠ Nicht geprüft (out of scope) | — |
| Key im Browser-History | ⚠ URL-Param wird in Browser-History gespeichert | MEDIUM |
| Key wird mit Webhook mitgesendet (`_key`) | ✅ ok — gehört zur Audit-Spur | — |

### 3.2 Webhook-Auth — KRITISCHER BEFUND

```js
// index.html:472-473
const WEBHOOK_URL = 'https://n8n.automatiksio.cloud/webhook/secure-share';
const WEBHOOK_SECRET = 'aio-share-k8x2m9v4';
```

**Severity:** CRITICAL.
Der Secret wird im Klartext an jeden Browser ausgeliefert. View-Source genügt. `X-Auth-Token` bietet damit **null Schutz** vor direkten Webhook-Calls — ein Angreifer kann ohne Frontend beliebige PwPush-Links + Metadaten an den n8n-Endpoint pushen.

**Folgewirkung:** Spam, Verwirrung beim Mandanten, mutwillige Log-Verschmutzung, ggf. Phishing-Vorbereitung (wenn ein Angreifer einen eigenen PwPush-Link unterschiebt und der Empfänger im n8n-Workflow nicht weiter validiert).

**Lösung (server-side, nicht in diesem Branch):**
- Webhook akzeptiert nur Requests, deren `_key` zuerst gegen die Config-API validiert wurde **und** das Token in der Validierungs-Antwort steht (signed token, kurzlebig).
- Alternativ: Webhook-Endpoint nur für Origin `share.automatiks.io` (origin/referer-Check) + CSP — Origin-Check ist umgehbar, aber raises the bar.
- Beste Lösung: Frontend ruft `validate` auf, bekommt einen einmalig nutzbaren `submit_token` (z.B. HMAC über key+timestamp), schickt den im Submit-Call. n8n prüft das Token.

### 3.3 Ablauf, Einmal-Abruf, Rate-Limit, Logging

| Punkt | Status | Severity |
|---|---|---|
| PwPush `expire_after_days: 2` | ✅ ok | — |
| PwPush `expire_after_views: 3` | ⚠ 3 Views statt 1 — bewusst? Begründung dokumentieren | LOW |
| `retrieval_step: false` | ⚠ Kein 2-Step — bewusst? | LOW |
| Client-side Rate-Limit | ❌ Keiner — beliebig viele Submits | MEDIUM |
| 500-Zeichen-Limit pro Feld | ✅ Vorhanden (Zeilen 621-628) | — |
| Server-side Rate-Limit / Logging | ⚠ Out of scope (n8n) | — |
| Client logged keine Credentials | ✅ ok (kein console.log auf payload) | — |

### 3.4 Frontend-Security-Header (Dockerfile)

| Header | Status |
|---|---|
| `X-Robots-Tag` noindex | ✅ |
| `X-Content-Type-Options nosniff` | ✅ |
| `X-Frame-Options DENY` | ✅ |
| `Referrer-Policy no-referrer` | ✅ |
| `Content-Security-Policy` | ❌ FEHLT | HIGH |
| `Strict-Transport-Security` | ❌ FEHLT (Coolify übernimmt evt.) | MEDIUM |
| `Permissions-Policy` | ❌ FEHLT | LOW |

**Besonders relevant:** Ohne CSP können externe Skripte injiziert werden, falls jemals eine XSS-Lücke entsteht (z.B. via `field-help` `renderHelp`). Aktuell ist `renderHelp` zwar sauber (escaped), aber CSP wäre Defense-in-Depth.

### 3.5 Sonstiges

- `renderHelp()` (Zeilen 515-527): escaped korrekt vor Regex-Replace. Reihenfolge ist sicher — erst HTML-Escape, dann Markdown-Bold, dann URL-Linkify. ✅
- Externe Skripte: Nur Google Fonts (preconnect). Keine externen Tracker. ✅
- AbortController-Timeout 5s für Config-API. ✅
- Keine `console.log` mit Payload-Daten. ✅

---

## 4. Non-Techie-UX

| Punkt | Status | Severity |
|---|---|---|
| Endkunde kann das Formular ausfüllen | ✅ Klar | — |
| Felder haben Hilfetexte (`help`) | ✅ Aus Config | — |
| Hilfetext rendert Links + Bold | ✅ `renderHelp` | — |
| Fehlerbilder freundlich | ✅ 3 Views (Ungültig / Service-Down / Submit-Error) | — |
| Trust-Signale (Verschlüsselungs-Hinweis, EU-Standort) | ⚠ Nur 1 kleiner Hinweis | MEDIUM |
| Share-Link **erstellen** (für den Sender) | ❌ Kein UI — nur Skill/API | HIGH |
| Onboarding-Hinweis: was passiert nach Submit | ✅ Success-View | — |
| R14: Echte Umlaute überall | ❌ Zeile 677 `Uebertragung` | LOW |

**Hauptlücke (HIGH):** Es gibt **kein UI für den Versender**. Wer einen Share-Link erzeugen will, muss entweder Chris fragen oder einen Skill/API-Call wissen. Für Agency-OS-Mitarbeiter ist das eine harte Adoption-Bremse.

→ Empfehlung: Phase B-Vorgriff in Roadmap — Mini-Admin-UI mit Login zum Erzeugen von Keys/Routen, gated hinter Tenant.

---

## 5. Agent-/API-Anbindung

| Punkt | Status | Severity |
|---|---|---|
| Endpoint dokumentiert | ❌ Keine README/API-Doku im Repo | HIGH |
| OpenAPI/Schema | ❌ Nicht vorhanden | MEDIUM |
| Auth-Modell für Agents | ⚠ Aktueller Webhook-Secret unbrauchbar (siehe 3.2) | CRITICAL |
| Idempotenz-Key | ❌ Kein `Idempotency-Key`-Pattern | MEDIUM |
| Antwortformate konsistent | ⚠ Nicht testbar ohne API-Call gegen n8n (R31) | — |
| Skill `secure-share` vorhanden | ⚠ Nicht in ck_EA gefunden (Memory `reference_secure_share_api` nicht auffindbar) | MEDIUM |

**Empfehlung:** README mit Endpoint-Doku + Beispiel-Calls (curl) + JSON-Schemas für `validate`-Antwort + Submit-Payload. Damit kann ein Agent das Tool sauber programmatisch nutzen.

---

## 6. Code-Qualität / Wartbarkeit

| Punkt | Status | Severity |
|---|---|---|
| Single-File-Architektur (HTML+CSS+JS inline) | ⚠ Vertretbar für Static, aber begrenzt | LOW |
| Build-Step | ❌ Keiner | LOW (passt zum Setup) |
| Lint/Format | ❌ Keine Konfiguration | LOW |
| Tests | ❌ Keine | MEDIUM |
| TypeScript | ❌ Plain JS | LOW |
| Error-Boundary für Fetch | ✅ try/catch + 3 Error-Views | — |
| Logo extern (`automatiks.io/logo/...`) | ⚠ Single Point of Failure | LOW |
| Mixed-Style var/const | ⚠ `var currentKey` neben `const formView` | LOW |

**Bemerkenswert:** Der CSS-Token-Block (`:root { --black, --accent, ... }`) ist sauber strukturiert — gute Basis für das Whitelabel-Theming (siehe Roadmap Phase B).

---

## 7. Findings-Liste nach Severity

### CRITICAL (Block für breitere Verwendung)
- **C1** Webhook-Secret im Klartext im Frontend — siehe 3.2
- **C2** Single-Tenant-Architektur, kein Whitelabel — siehe 1+2

### HIGH (Vor Mandantenfähigkeit zwingend)
- **H1** Kein CSP-Header — siehe 3.4
- **H2** Keine API-Doku im Repo — siehe 5
- **H3** Branding (Logo/Farben/Footer) hart kodiert — siehe 1
- **H4** Kein UI für Share-Link-Erstellung — siehe 4

### MEDIUM
- **M1** Key in Browser-History — siehe 3.1 (kann durch `replaceState` reduziert werden)
- **M2** Kein client-side Rate-Limit — siehe 3.3
- **M3** Kein Strict-Transport-Security — siehe 3.4 (ggf. Coolify-Default, prüfen)
- **M4** Kein Idempotency-Key — siehe 5
- **M5** Keine Tests — siehe 6
- **M6** Skill `secure-share` Memory nicht auffindbar — siehe 5

### LOW
- **L1** R14-Verletzung „Uebertragung" Zeile 677 — siehe 4 (wird in Phase 2 gefixt)
- **L2** `expire_after_views: 3` ggf. zu lax — siehe 3.3
- **L3** `retrieval_step: false` — siehe 3.3
- **L4** Mixed var/const — siehe 6
- **L5** Logo extern verlinkt — siehe 6
- **L6** Permissions-Policy fehlt — siehe 3.4

---

## 8. CI-/Styling-Politur (Phase 2)

→ Siehe Sektion 9 nach Implementierung.

## 9. Vorher/Nachher (Phase 2 Output)

*Wird nach Implementation der Politur befüllt.*

---

## Anhang

- Code-Stand: Commit `d6fe6fb` (Add per-field help block with clickable links)
- n8n-Workflow-Referenz: `OkR9x386p2EwrcQu` — nicht inspiziert (R31)
- PwPush-Instanz: `pwpush.automatiks.io` (EU, self-hosted) — nicht inspiziert
- Live-URL: `https://share.automatiks.io`
