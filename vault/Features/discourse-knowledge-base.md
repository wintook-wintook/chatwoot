# Integración Discourse como base de conocimiento

**Fecha:** 2026-05-08

## Objetivo

Permitir que el bot de seguimientos (`ContactTrackingResponseAnalyzerJob`) consulte el foro
Discourse como base de conocimiento cuando el cliente hace una pregunta que lo requiere, usando el
`complementary_prompt` del tracking como system prompt del bot consultor.

**Why:** el prompt "CONSULTOR JUNIOR" del usuario ya incluía la instrucción `@discourse`, pero el
sistema no tenía mecanismo para ejecutar esa intención — GPT simplemente escribiría `@discourse
[query]` como texto literal al cliente.

**How to apply:** si se reporta que el bot envía texto `@discourse ...` al cliente, significa que
`TRACKING_DETECT_INTENT` sigue en `false` o que el `RouterService` no está clasificando
correctamente.

## Archivos modificados

### 1. `app/services/knowledge_base_response_service.rb`
- `initialize(message)` → `initialize(message, tracking: nil)` — acepta tracking opcional.
- `build_messages`: si se pasa un tracking con `complementary_prompt`, lo usa como system prompt en
  vez del genérico.
- El contexto del foro se inyecta como `"\n\nContenido relevante del foro:\n#{context}"` al final
  del system prompt (en ambas ramas).

Por qué: cuando el router detecta `:discourse` en un tracking con prompt "CONSULTOR JUNIOR", el
servicio debe usar ese prompt y no el genérico, o el bot pierde su personalidad y sus instrucciones
de comportamiento.

### 2. `app/jobs/contact_tracking_response_analyzer_job.rb`
- Ruta `:discourse` (línea ~96): `KnowledgeBaseResponseService.new(message)` →
  `KnowledgeBaseResponseService.new(message, tracking: tracking)`.
- Fallback discourse (línea ~110): mismo cambio.

### 3. `app/services/contact_trackings/router_service.rb` *(nuevo en ese momento)*

Clasifica la intención del mensaje del cliente usando GPT-4o-mini con un prompt de clasificación
estructurado (`response_format` JSON). Retorna una ruta simbólica:

- `:rejected` — cliente rechaza el seguimiento
- `:interested` — cliente muestra interés
- `:reschedule` — cliente quiere cambiar fecha (incluye parsing de fecha/hora en `reschedule_data`)
- `:discourse` — duda técnica/funcional → va a `KnowledgeBaseResponseService`
- `:botseller` — mensaje para el bot de ventas
- `:tracking` — conversación normal (default)

Activación: solo se usa cuando `TRACKING_DETECT_INTENT=true`. Con `false` (default) el job retorna
siempre `:tracking` sin llamar a este servicio.

Seguridad: si clasifica `:discourse` pero `kbase_available?` es false → downgrade a `:tracking`.
Mismo para `:botseller`.

## Configuración necesaria para activar el sistema completo

**Variables de entorno:**
```
TRACKING_DETECT_INTENT=true   # activa el RouterService
```

**Integración Discourse por inbox:** Chatwoot → Settings → Integrations → Discourse → agregar hook
para el inbox correspondiente (URL del foro, API Key, Username default `system`).

**Plugin en Discourse:** el foro debe tener instalado **`discourse-ai`** porque
`KnowledgeBaseResponseService` usa el endpoint de búsqueda semántica:
```
GET /discourse-ai/embeddings/semantic-search.json?q=<query>
```

**Prompt del tracking:** el `complementary_prompt` de la plantilla debe incluir `@discourse` para
que `kbase_available?` lo detecte (`tracking.complementary_prompt.to_s.include?('@discourse')`).

## Flujo completo activado

```
Cliente: "no puedo guardar la cotización"
  ↓
RouterService → GPT clasifica → :discourse (confianza: 0.9)
  ↓
kbase_available? → true (hook configurado + '@discourse' en prompt)
  ↓
KnowledgeBaseResponseService.perform(tracking: tracking)
  ├── search_discourse("no puedo guardar la cotización")
  │     → discourse-ai semantic search → 3 posts relevantes
  ├── ask_openai(pregunta, contexto_foro, historial, system: complementary_prompt)
  │     → GPT genera respuesta usando el prompt CONSULTOR JUNIOR
  └── reply(respuesta) → enviada al cliente en la conversación
```

## Relacionado
- [[bot-seguimientos-openai]]
- [[bug-dia-semana-equivocado]]
