# Whitelabel-Roadmap — AIO Secure-Share für Agency OS

**Stand:** 2026-06-13
**Status:** Design-Doc, KEIN Bau in diesem Lauf.
**Autor:** Claude (autonom, überwacht durch CK)

---

## Zielbild

AIO Secure-Share wird vom monolithischen, auf `automatiks.io` gebrandeten Tool zu einem **mandantenfähigen Whitelabel-Produkt** für den Agency-OS-Stack. Eine Partner-Agentur (z.B. RegioNext, CKDS oder ein OEM-Lizenznehmer) kann mit eigener Domain, eigenem Logo, eigenen Farben und eigenem Footer arbeiten, ohne dass automatiks.io für den Endkunden sichtbar wird.

**Nicht-Ziel:** Reverse-Multitenant SaaS mit Self-Service-Onboarding. Wir bauen B2B-Whitelabel für eine überschaubare Zahl von Partnern (sagen wir < 50 Tenants), die manuell provisioniert werden — schlanker und schneller als ein vollwertiger SaaS.

---

## Quick-Wins (vor Phase A — diese Woche realisierbar)

| ID | Item | Aufwand | Impact |
|---|---|---|---|
| Q1 | Webhook-Secret aus Frontend entfernen, durch `validate`-Antwort-Token ersetzen | M (n8n+FE) | CRITICAL Fix |
| Q2 | CSP-Header in Dockerfile ergänzen | S | HIGH Fix |
| Q3 | R14-Bugfix Zeile 677 (`Uebertragung` → `Übertragung`) | S | Hygiene |
| Q4 | README mit API-Doku + Skill-Beispiel im Repo | S | HIGH Fix |
| Q5 | `key` aus URL nach erfolgreichem `validate` per `replaceState` entfernen | S | MEDIUM Fix |

**Empfehlung:** Q1+Q2+Q3 sofort. Q4+Q5 vor erstem Partner-Pitch.

---

## Phase A — Tenant-Modell in n8n-Config-API (Fundament, ~2-4 PT)

**Ziel:** Saubere Mandanten-Trennung server-side, ohne dass das Frontend etwas davon merkt.

### Was

1. Config-API um `tenant_id` erweitern: Jeder Key gehört einem Tenant. `validate`-Antwort enthält `tenant_id`.
2. n8n-Datenmodell (vermutlich Airtable oder DB): Tabelle `tenants` mit Spalten `id`, `name`, `primary_domain`, `created_at`, `status`.
3. Routes und Keys werden pro Tenant gescoped — Key-Kollisionen tenantfrei nur per (tenant, key) eindeutig.
4. Migration: bestehende Keys (z.B. CALO.SOL) bekommen `tenant_id = "automatiks-default"`.

### Abhängigkeiten
Keine. Kann komplett in n8n + Datastore ausgerollt werden, ohne FE-Änderung.

### Risiken
- Migration bestehender Keys ohne Downtime — kann mit Default-Tenant abgefedert werden.
- n8n-Workflow `OkR9x386p2EwrcQu` muss erweitert werden — saubere Versionierung in n8n-API nötig.

### Aufwand
**Grob 2-4 Personentage** (n8n-Workflow + Datenmodell + Migration + Test).

---

## Phase B — Branding-Config pro Agentur (~3-5 PT)

**Ziel:** Frontend wird themable per Server-Antwort.

### Was

1. `validate`-Antwort erweitern um `branding`-Block:
   ```json
   {
     "valid": true,
     "tenant_id": "regionext",
     "branding": {
       "logo_url": "https://share.regionext.de/logo.svg",
       "logo_height": 26,
       "primary_color": "#0d3b66",
       "accent_color": "#f4a261",
       "background": "#0a0a0a",
       "text": "#f0f0f0",
       "company_name": "RegioNext GmbH",
       "footer_html": "RegioNext GmbH<br>...<br>info@regionext.de",
       "support_email": "info@regionext.de",
       "title_suffix": "RegioNext"
     },
     "route": {...},
     "key_note": "..."
   }
   ```
2. Frontend setzt CSS-Variablen dynamisch aus `branding` (das Token-Schema in `:root` ist schon vorbereitet — minimaler Refactor).
3. Footer, Logo, Title werden aus `branding` befüllt. Default-Fallback bleibt automatiks.io.
4. Tenant-Admin-Tool (n8n-Form oder Airtable-View) zum Pflegen der Branding-Configs.

### Abhängigkeiten
Phase A muss live sein.

### Risiken
- XSS via `footer_html` — Server-side Allowlist auf erlaubte Tags (`<br>`, `<a>`, `<strong>`) oder Markdown statt HTML.
- Logo-URL extern — für kritische Tenants ggf. R2/CDN-Hosting durch automatiks.io anbieten.
- Branding-Tokens sollten Pflicht-Felder validieren (z.B. valide Hex-Farben), sonst kaputtes Layout.

### Aufwand
**Grob 3-5 PT.** Frontend-Refactor ist minimal dank existierender CSS-Token-Struktur. Hauptarbeit: Branding-Editor + Validierung + Test mit 2-3 Pilot-Tenants.

---

## Phase C — Custom Domains (~3-7 PT, abhängig von Coolify-Setup)

**Ziel:** Jeder Tenant kann eigene Subdomain nutzen (z.B. `share.regionext.de` statt `share.automatiks.io`).

### Was

1. Wildcard-Domain-Strategie:
   - Option 1: Jeder Tenant CNAMEd auf `share.automatiks.io`, Coolify händelt SSL via Wildcard-Cert. **Einfacher.**
   - Option 2: Tenant CNAMEd auf einen separaten Coolify-Eintrag, eigenes Cert pro Domain. **Sauberer für OEM.**
2. Frontend liest `window.location.hostname` und sendet diesen als `host`-Hint an Config-API.
3. Config-API resolvet `host` → `tenant_id` (Tabelle `tenant_domains`).
4. Bei unbekannter Domain: Fallback auf default automatiks-Tenant.

### Abhängigkeiten
Phase A+B müssen live sein.

### Risiken
- DNS-Setup bei Tenant — wir liefern eine kurze Anleitung (CNAME) und supporten beim Onboarding.
- Coolify-SSL muss Wildcard können ODER Option 2 mit Per-Domain-Cert-Automation (Letsencrypt).
- Cookie/LocalStorage-Scope, falls später Auth dazukommt — pro Subdomain isoliert, ist eher Vorteil.

### Aufwand
**3-7 PT.** Spreizung kommt vom Coolify-Setup — Option 1 ist 3 PT, Option 2 eher 5-7 PT mit Cert-Automation.

---

## Phase D — Agent-Endpoint für programmatische Nutzung (~4-6 PT)

**Ziel:** Saubere API, mit der ein Agent (Claude, n8n-Agent, externer Service) Share-Links erzeugen und Submission-Antworten lesen kann.

### Was

1. **POST `/api/share/create`** — erzeugt neuen Key + Route. Body: `{ tenant_id, route_template, ttl_minutes, key_note }`. Antwort: `{ key, url, expires_at }`.
2. **POST `/api/share/list`** — listet Keys eines Tenants mit Status (pending/submitted/expired). Body: `{ tenant_id, since? }`. Antwort: `{ keys: [...] }`.
3. **GET `/api/share/{key}/status`** — Status + Submission-Antwort (PwPush-URL nur für berechtigten Agent), `valid`/`submitted`/`expired`.
4. **Auth:** OAuth2-Style Bearer-Token pro Tenant, kurzlebig + refresh. Alternativ: Service-Account-API-Key, pro Tenant rotierbar.
5. **Idempotenz:** `Idempotency-Key` Header auf `/create`, mind. 24h Deduplication.
6. **Rate-Limit:** N Requests/Minute pro Tenant, sauber dokumentiert (429 + `Retry-After`).
7. **OpenAPI 3.1 Spec** im Repo. MCP-kompatibel ausliefern (siehe Skill `printing-press` als Inspiration).

### Abhängigkeiten
Phase A muss live sein (Tenant-Modell). Phase B+C sind nicht zwingend — Agent-Endpoint kann mit automatiks.io-Domain starten.

### Risiken
- API-Surface wächst — saubere Versionierung (`/api/v1/...`) ab Start.
- Token-Rotation und Revocation — Process für Partner dokumentieren.
- Audit-Log für Agent-Calls (wer hat wann was erzeugt) — wichtig für Compliance.

### Aufwand
**4-6 PT** für v1. OpenAPI + 4 Endpoints + Auth + Rate-Limit + grundlegender Audit-Log.

---

## Top-3 Empfehlung für nächste 2 Wochen

1. **Q1 + Q2 + Q3 sofort** (Critical-Fixes + CI-Politur). 1-2 PT.
2. **Phase A starten** (Tenant-Modell in n8n). Damit ist das Fundament für alles weitere gelegt. 2-4 PT.
3. **Phase B im Anschluss** (Branding-Tokens) — sobald A live, ist B die kleinste Investition mit größtem Whitelabel-Aha-Effekt für Pilot-Partner. 3-5 PT.

**Phase C+D danach**, abhängig vom ersten Partner-Use-Case. Wenn der erste Partner mit `share.automatiks.io` + eigenem Branding ok ist, kann C verschoben werden. Wenn Agency-OS-Bots sofort Share-Links erzeugen sollen, ist D vor C.

---

## Was dieser Plan **nicht** löst

- Persistente Speicherung der eingereichten Credentials über PwPush hinaus. Soll auch so bleiben — PwPush ist der Pufferspeicher, der Tenant nimmt die Daten aus dem 1Password/Bitwarden/etc. seines Mandanten auf.
- SSO/SAML für Tenant-Admins. Wenn relevant: separater Track, nicht hier.
- Mehrsprachigkeit (i18n) — aktuell Deutsch only. Englisch-Variante als Phase B+ möglich, dann über `branding.locale`.
- 100%-Self-Service-Onboarding für Tenants. Manuelle Provisionierung ist für den projektierten Mandanten-Range angemessen.

---

## Offene Fragen an CK

- Soll Phase A im n8n-Workflow `OkR9x386p2EwrcQu` selbst geschehen oder als neuer Workflow geforked?
- Wie viele Tenants sind in 6-12 Monaten realistisch (relevant für DB vs. Airtable-Entscheidung in Phase A)?
- Gibt es einen geplanten Partner, dessen Use-Case Phase B+C+D priorisiert (Agency-OS-Demo)?
