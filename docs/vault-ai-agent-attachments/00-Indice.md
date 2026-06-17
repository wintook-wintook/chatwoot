---
titulo: Índice — AI Agent Attachments (Adjuntos de Agentes IA)
tipo: indice
tags: [ai-agent-attachments, indice, moc]
---

# 📎 AI Agent Attachments — Bóveda de conocimiento

Base de conocimiento del módulo de **adjuntos para Agentes IA** de Wintook/Kontrolya
(rama `feat/ai_agent_attachments`, deriva de `develop`). Cada nota es atómica y enlazada
con `[[wikilinks]]`. Esta bóveda es la versión **navegable** del futuro skill
`@ai_agent_attachments`.

> **⭐ Idea central:** en la UI del **Agente IA** (`tracking_template`) se añade un tab
> **"📎 Archivos"** (después de "📅 Agendas") para subir archivos. Esos archivos se
> **referencian desde el prompt complementario** con la directiva **`@adjunto:nombre`**;
> cuando la IA la dispara, el archivo se **envía en la conversación**. El almacenamiento
> reutiliza **ActiveStorage** (forma nativa de Chatwoot de guardar adjuntos).

> **Convención:** código/columnas/enums en inglés; UI en español (i18n `es`/`en`).
> Migraciones siempre al final. **Sin feature flag.** **Commit solo cuando se pida.**
> Marcador en código: `proyecto@ai_agent_attachments`.

---

## 🧭 Empezar aquí (al retomar)

1. [[Vision-y-convenciones]] — qué es, alcance, capas, relación con el Agente IA
2. [[Modelo-de-datos]] — cómo se almacenan los archivos (ActiveStorage) y su `nombre`
3. [[Directiva-y-envio]] — cómo `@adjunto:nombre` resuelve y envía el archivo
4. [[Estado-actual]] — qué está hecho vs pendiente

---

## 📐 Diseño

- [[Vision-y-convenciones]] — propósito, alcance, capas, convenciones es/en
- [[Modelo-de-datos]] — almacenamiento de archivos del Agente IA + clave `nombre`
- [[Frontend]] — tab "📎 Archivos" en `EditTemplate.vue`, subida y listado
- [[Directiva-y-envio]] — sintaxis `@adjunto:nombre`, parseo y envío en la conversación
- [[API-y-rutas]] — endpoints para subir/listar/borrar adjuntos del Agente IA

## 🛠️ Implementación (estado real)

- [[Archivos-reales]] — mapa exacto de archivos backend/frontend a tocar/crear
- [[Estado-actual]] — qué está hecho y qué falta
- [[Pendiente]] — tareas abiertas y decisiones por confirmar

---

## 🗺️ Mapa del módulo

```
  AGENTE IA (tracking_template)
    └─ tab "📎 Archivos" ──► sube archivo (ActiveStorage) con un `nombre` clave
                                     │
   prompt complementario:  "...@adjunto:catalogo..."
                                     │
   conversación activa ─► IA detecta @adjunto:catalogo
                                     │
        resuelve `catalogo` ─► blob ActiveStorage ─► adjunta al mensaje saliente
                                     │
                         se envía el archivo al contacto
```
