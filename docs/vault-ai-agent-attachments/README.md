# Bóveda de conocimiento — AI Agent Attachments (Adjuntos de Agentes IA)

Notas atómicas (Markdown + wikilinks `[[ ]]`) del módulo **AI Agent Attachments**:
permite **adjuntar archivos a un Agente IA** (`tracking_template`) y que el agente los
**envíe en la conversación** cuando el prompt complementario invoca la directiva
**`{{nombre}}`**. Reutiliza el almacenamiento de archivos nativo de Chatwoot
(ActiveStorage). Empieza por **[[00-Indice]]**.

```
vault-ai-agent-attachments/
├── 00-Indice.md            ← mapa de contenido (MOC), empieza aquí
├── diseno/                 ← qué es, modelo de datos, frontend (tab Archivos), directiva y envío, API
└── implementacion/         ← archivos reales, estado y pendientes
```

> Rama `feat/ai_agent_attachments` (derivada de `develop`). El módulo está **por
> construir**: esta bóveda nace como **diseño/plan** y se irá llenando con el estado
> real a medida que se implemente.

## Relación con otras bóvedas

- **Contact Tracking** (`vault-contact-tracking`): este módulo **extiende** el Agente IA
  (`tracking_template`) de ese módulo. La directiva `{{nombre}}` sigue el mismo
  patrón que `@agendar_calendar` / `@buscar_predefinidas` del prompt complementario.

## Convención (heredada de Contact Tracking)

- Tablas/columnas/enums y **código en inglés**; **UI en español** (i18n `es`/`en`).
- **Migraciones siempre al final.** **Commit solo cuando se pida.**
- Marcador en el código: `# proyecto@ai_agent_attachments`.
