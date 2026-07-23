---
titulo: Referencia osTicket — norte del módulo de tickets
tipo: referencia
tags: [tickets, osticket, referencia, roadmap]
fecha: 2026-06-22
fuente: https://docs.osticket.com/en/latest/
---

# 🧭 Referencia osTicket

> **Norte del proyecto:** MGCI (nuestro Gestor de Tickets sobre Chatwoot, rama
> `feat/tickets`) se construye **lo más parecido posible a osTicket**. osTicket es
> el modelo funcional de referencia; cuando haya dudas de alcance/UX, mirar cómo lo
> resuelve osTicket.
>
> Doc oficial: <https://docs.osticket.com/en/latest/>
> Análisis de brechas vivo: [[Conciliacion-osTicket-MGCI]]

---

## 1. Estructura completa de la documentación osTicket

Mapa de todo lo que osTicket documenta (sirve para checklist de paridad).

### Getting Started
- Tutorials
- Installation
- Post-Install Setup Guide
- Email Settings
- Email Templates
- POP3/IMAP Settings Guide
- **Email Piping** ← email‑to‑ticket
- Upgrade and Migration

### Guides
- **Alerts Guide**: Autoresponder · Alerts and Notices · Disabling Alerts · Editing Template Messages
- **Data Extraction Guide**: Exporting Ticket Data (CSV) · Dashboard Exports (CSV)
- **Translation Guide**: Translating Editable Text
- **OAuth2 Guide**: Authentication · Authorization · Setting Up The Plugin

### Panels (las 3 superficies clave)
- **Admin Panel**: Dashboard · Settings · Manage · Emails · Agents
- **Agent Panel**: Dashboard · Users · **Tasks** · Tickets · Knowledgebase
- **User Portal** ← la cara al cliente que hoy nos falta
  - Open A Ticket
  - Check Ticket Status
  - Knowledgebase

### Features
- Multifactor Authentication
- **Visibility Permissions**
- Previously Released

### Plugins
- Attachments in S3
- **Help Desk Audit**
- Two Factor Authentication
- Password Management Policies
- Attachments on the Filesystem

### Developer Documentation
- Changelog
- **API** (Authentication · HTTP Access · Wrappers · Resources)
- Database ERDs

---

## 2. Las 3 superficies de osTicket (modelo mental)

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│ USER PORTAL  │     │ AGENT PANEL  │     │ ADMIN PANEL  │
│ (cliente)    │     │ (staff)      │     │ (config)     │
├──────────────┤     ├──────────────┤     ├──────────────┤
│ Open ticket  │     │ Tickets      │     │ Settings     │
│ Check status │     │ Tasks        │     │ Manage       │
│ Knowledgebase│     │ Users        │     │ Emails       │
│              │     │ Knowledgebase│     │ Agents       │
│              │     │ Dashboard    │     │ Dashboard    │
└──────────────┘     └──────────────┘     └──────────────┘
   ↑ MGCI NO tiene      ↑ MGCI cubre casi    ↑ MGCI cubre vía
     esta superficie      todo (+ IA/Kanban)   config por cuenta
```

**Brecha estructural:** MGCI tiene Agent Panel y Admin Panel (y los supera con IA,
Kanban, Journey, métricas ITIL), pero **carece del User Portal** — la superficie del
cliente. Ese es el foco para "parecerse a osTicket". Ver detalle y priorización en
[[Conciliacion-osTicket-MGCI]].

---

## 🔗 Relacionado
- [[Conciliacion-osTicket-MGCI]] — gap-analysis y plan de sprints
- [[00-Indice]] · [[Pendiente]] · [[Historial-de-implementacion]]
</content>
</invoke>
