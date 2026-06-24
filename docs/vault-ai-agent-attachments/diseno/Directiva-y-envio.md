---
titulo: Directiva {{nombre}} y envío del archivo
tipo: diseno
tags: [ai-agent-attachments, directiva, envio]
---

# Directiva `{{nombre}}` y envío

## Sintaxis (canónica)

En el **prompt complementario** del Agente IA (tab "💡 Entrenamiento",
`complementary_prompt`) se escribe la directiva con **dos puntos**:

```
{{archivo_nombre}}
```

- `archivo_nombre` = la **clave** del adjunto definida en el tab "📎 Archivos"
  (columna `name`, ver [[Modelo-de-datos]]).
- **Disparador del autocompletado:** `{{nombre}}` (ver [[Frontend]]).
- Esta es la **única** forma válida; backend (parser) y frontend (autocompletado +
  inserción) la usan idéntica.
- Sigue el estilo de las directivas existentes del módulo Contact Tracking
  (`@agendar_calendar`, `@buscar_predefinidas`, `@buscar_foro`, `@discourse`).

## Regex de parseo (referencia)

```
\{\{\s*([a-zA-Z0-9_-]+)\s*\}\}
```

El `name` se restringe a slug (sin espacios) para que el token termine de forma
inequívoca. Validar ese formato también al crear el adjunto (ver [[Modelo-de-datos]]).

## Dónde se procesa (IMPLEMENTADO)

Punto de intercepción elegido: **`ContactTrackingResponseAnalyzerJob#send_auto_reply`**
(`app/jobs/contact_tracking_response_analyzer_job.rb`) — es el **único** punto por el que
pasan las ~11 respuestas conversacionales del Agente IA.

- `resolve_attachment_directives(tracking, content)` → `[texto_limpio, signed_ids]`.
- El `complementary_prompt` ya llega al LLM como "INSTRUCCIONES ADICIONALES"; se añadió una
  línea "ENVÍO DE ARCHIVOS" al system prompt **solo si** el prompt contiene `{{nombre}}`,
  para que el modelo emita el token **literal**.
- Reutiliza el **blob existente** pasando su `signed_id` a `Messages::MessageBuilder`
  (`process_attachments` trata cada String como signed_id) → **no duplica almacenamiento**.
- Límite por respuesta: `MAX_DIRECTIVE_ATTACHMENTS` (env `AI_AGENT_MAX_ATTACHMENTS`, def. 5).

## Flujo (implementado)

```
1. La IA genera la respuesta usando complementary_prompt (con el token {{nombre}}).
2. send_auto_reply → resolve_attachment_directives detecta {{nombre}} (scan).
3. Resuelve cada `nombre` → AiAgentAttachment del tracking_template (LOWER(name), por agente).
   - no existe → log warning, se omite ese adjunto (no rompe el envío).
4. Quita los tokens del texto y limpia espacios/puntuación.
5. Pasa los signed_ids como `attachments:` a MessageBuilder (blob reutilizado).
6. Si el texto queda vacío pero hay adjuntos → se envía igualmente (solo el archivo).
```

## Limitaciones conocidas

- Si el `complementary_prompt` contiene directivas **kbase** (`@buscar_predefinidas`,
  `@buscar_foro(...)`, `@discourse`), `clean_cp` se vacía y el LLM **no** recibe las
  instrucciones `{{nombre}}` (no emitiría el token). Combinar kbase + adjuntos no está
  soportado todavía.
- Solo aplica a la **respuesta conversacional**; el mensaje proactivo
  (`contact_tracking_job.rb`) aún no procesa `{{nombre}}`.

## Reglas

- **Scope estricto por agente:** `{{nombre}}` solo resuelve archivos del mismo
  `tracking_template`. Nunca cruza agentes/cuentas.
- **Varias directivas** en un mismo mensaje → varios adjuntos (definir límite por canal).
- **Idempotencia/seguridad:** validar `content_type`/tamaño contra el canal destino
  (WhatsApp limita tipos/peso); si no cumple, omitir y registrar.
- **Sin match:** si `archivo_nombre` no existe, no se envía adjunto y el texto se entrega
  limpio.

## Decisiones por confirmar → [[Pendiente]]

- Punto exacto de intercepción (job de envío vs servicio de respuesta).
- Límite de adjuntos por mensaje y validación por canal.
