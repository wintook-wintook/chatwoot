---
titulo: Directivas en complementary_prompt — Contact Tracking
tipo: implementacion
tags: [contact-tracking, directivas, kbase, prompt]
---

# Directivas en `complementary_prompt` ("Entrenamiento")

El campo `complementary_prompt` (UI: **"Entrenamiento"**) puede llevar **directivas**
que cambian cómo se responde al cliente cuando éste contesta. Se detectan sobre el
texto del `complementary_prompt` del tracking. Ver cómo entra al prompt en
[[Servicios-y-jobs]] y el detalle del system prompt
conversacional en `contact_tracking_response_analyzer_job.rb:251` (`generate_conversational_reply`).

## Las 3 directivas (modos KB)

`KnowledgeBaseResponseService#detect_directive` (`app/services/knowledge_base_response_service.rb:69`):

| Directiva | Modo | Qué hace |
|---|---|---|
| `@buscar_predefinidas` | `:canned_response` | pgvector sobre `knowledge_items` (`source_type: 'canned_response'`) — "Respuestas Predefinidas" |
| `@buscar_foro(nombre_fuente)` | `:knowledge_source` | búsqueda semántica en Discourse vía `KnowledgeSource` |
| `@discourse` | `:discourse_integration` | búsqueda Discourse AI vía la integración del inbox |

> ⭐ **El nombre correcto es `@buscar_predefinidas`** (coincide con la etiqueta de
> producto "Respuestas Predefinidas"). Los datos reales (trackings/plantillas) usan
> esta grafía.

## Dónde se evalúa cada directiva

- `KnowledgeBaseResponseService#detect_directive` (`:69`) → enruta al modo KB.
- `ContactTrackingResponseAnalyzerJob#kbase_available?` (`:205`) → ¿hay KB disponible
  para esa directiva?
- `ContactTrackingResponseAnalyzerJob` (`:274`, `has_kbase_directive`) → si el
  `complementary_prompt` trae una directiva KB, **se blanquea** (`clean_cp = ''`) para
  NO colarla al LLM conversacional (el prompt KB está diseñado para operar con la kbase,
  no como instrucción de charla).

## ⚠️ Bug corregido (2026-06-12)

El código tenía la grafía **incorrecta** `@buscar_predeterminadas` en los 4 sitios
(`knowledge_base_response_service.rb:8,71` y
`contact_tracking_response_analyzer_job.rb:205,274`), mientras que los datos usan
`@buscar_predefinidas`. Efecto:

1. La búsqueda **canned (pgvector) nunca se disparaba** (`detect_directive` devolvía `nil`).
2. La directiva `@buscar_predefinidas` **se colaba literal** al prompt conversacional
   (no se limpiaba en `:274`).

Corregido a `@buscar_predefinidas` en los 4 puntos. Comprobado con `rails runner` sobre
el tracking #21: `detect_directive => {mode: :canned_response}` y `clean_cp => ""`.

> Nota: no requirió migración de datos — los registros ya usaban la grafía correcta
> (6 trackings + 1 plantilla con `@buscar_predefinidas`, 0 con la vieja).
