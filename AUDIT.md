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

## 8. CI-/Styling-Politur (Phase 2) — Implementiert

**Leitidee:** Der „gebastelt"-Eindruck kam nicht von schlechten Farben (das Blau ist tatsächlich CI-konform — automatiks.io nutzt selbst Tailwind-Blue `#3b82f6` als Primary), sondern von **fehlenden Vertrauenssignalen** und einem **schwachen Identitäts-Akzent**. Die Politur stärkt beides, ohne die funktionale Logik anzufassen.

### Änderungen auf einen Blick

| # | Bereich | Änderung | Severity-Ref |
|---|---|---|---|
| 1 | R14-Bugfix | `Uebertragung` → `Übertragung` (Zeile 677) | L1 |
| 2 | CSP-Header | Content-Security-Policy + Permissions-Policy im Dockerfile | H1, L6 |
| 3 | Hero-Identität | Gold-Pill „SICHERER ZUGANGSLINK" als Eyebrow (automatiks.io „Goldmurmel"-Akzent, #e8c267) | Trust |
| 4 | Hero-Sub | „Verschlüsselt & nach Abruf automatisch gelöscht" — Klartext über der Karte | Trust |
| 5 | Logo | 26px → 30px, dezenter Hover-State | Trust |
| 6 | Trust-Pills | EU-Hosting / Self-hosted / DSGVO-konform unter dem Submit-Button | Trust |
| 7 | Security-Badge | Eigene Box mit Border & Trust-Background statt nackter Text | Trust |
| 8 | Success-Icon | Subtiler grüner Glow-Ring | Polish |
| 9 | Error-Views | Eigenes Icon + freundlicherer Titel („Link nicht mehr gültig") + Mail-CTA | UX |
| 10 | Footer | Divider + „BEREITGESTELLT VON AUTOMATIKS.IO"-Eyebrow | Trust |
| 11 | Card-Shadow | Subtiler Inner-Highlight + Drop-Shadow für Tiefe | Polish |
| 12 | Mobile | Responsive Tweaks für Pills, Header-Padding, Card-Margin | UX |

**Wichtig:** Keine Änderung an `WEBHOOK_SECRET`, `loadConfig`, Submit-Logik, PwPush-Integration. Auch keine Änderung der `n8n.automatiksio.cloud`-Endpoints. Reine Frontend-Politur (R31).

### Self-Review (/qa-web quick analog)

- ✅ Form-View rendert mit Mock-Config sauber (Desktop 1280×900 + Mobile 390×844 geprüft)
- ✅ Invalid-View rendert mit neuem Icon + Mail-CTA
- ✅ Trust-Pills brechen auf Mobile sauber um
- ✅ Hero-Pill nicht zu dominant (5px×10px, dezent gold)
- ✅ Footer-Hierarchie liest sich klar: Brand → Company → Contact
- ✅ Logo + Hero zusammen <100px Header-Höhe (Mobile-tauglich)
- ✅ Keine R14-Verletzungen im neuen Code (geprüft)
- ✅ CSP whitelistet exakt die nötigen Origins (Google Fonts, n8n, PwPush, automatiks.io für Logo)
- ⚠ CSP nutzt `'unsafe-inline'` für Scripts & Styles — inline `<script>` und `<style>` Tags in der HTML zwingen das aktuell. Echter Fix wäre Nonces oder Auslagerung in externe Files (Quick-Win Q-CSP-2 für nächsten Lauf).
- ⚠ Echter Live-Render mit valider n8n-Config (statt Mock) konnte nicht getestet werden (R31, kein Touch der Config-API). Mock matched aber das beobachtete Response-Schema.

### Bewusst NICHT verändert (Out-of-Scope)

- `WEBHOOK_SECRET` Konstante — siehe AUDIT 3.2, Roadmap Q1 (Server-Side-Fix nötig)
- Form-Submit-Logik
- `loadConfig`-Funktion
- PwPush-Parameter (`expire_after_views`, `retrieval_step`)
- Routes-Konfiguration in n8n
- Logo-Asset auf `automatiks.io` — bleibt extern, Phase B Whitelabel-Roadmap bringt Per-Tenant-Logo

---

## 9. Vorher/Nachher (Phase 2 Output)

Lokales Rendering der `index.html`, gleicher Mock-Datensatz (Microsoft-365-Route). Live-Site `share.automatiks.io` wurde nicht angetastet.

### Form-View Desktop (1280×900)

| Vorher | Nachher |
|---|---|
| `screenshots/before-form-desktop.png` | `screenshots/after-form-desktop.png` |

**Sichtbare Verbesserungen:**
- Gold-Pill „SICHERER ZUGANGSLINK" als Identitäts-Akzent über der Karte (vorher: nur Logo)
- Security-Badge als eigene Box mit Border statt nackter Zeile
- Trust-Pills (EU-Hosting / Self-hosted / DSGVO-konform) unter dem Submit-Button
- Footer mit Divider + Eyebrow „BEREITGESTELLT VON AUTOMATIKS.IO"
- Card mit subtiler Inner-Highlight für Tiefe

### Invalid-View Desktop (1280×900)

| Vorher | Nachher |
|---|---|
| `screenshots/before-invalid-desktop.png` | `screenshots/after-invalid-desktop.png` |

**Sichtbare Verbesserungen:**
- Eigenes Info-Icon im Kreis (vorher: nur Text)
- Titel präziser: „Link nicht mehr gültig" statt „Ungültiger Link"
- Direkte CTA „info@automatiks.io kontaktieren" als Mail-Link
- Gleiche Trust-Architektur (Hero-Pill + Footer-Brand) auch auf Error-Views

### Form-View Mobile (390×844)

| Nachher |
|---|
| `screenshots/after-form-mobile.png` |

Pills brechen auf zwei Reihen um, Card-Padding angepasst, Hero kompakt. Keine horizontale Scroll-Bar.

---

## Anhang

- Code-Stand: Commit `d6fe6fb` (Add per-field help block with clickable links)
- n8n-Workflow-Referenz: `OkR9x386p2EwrcQu` — nicht inspiziert (R31)
- PwPush-Instanz: `pwpush.automatiks.io` (EU, self-hosted) — nicht inspiziert
- Live-URL: `https://share.automatiks.io`
