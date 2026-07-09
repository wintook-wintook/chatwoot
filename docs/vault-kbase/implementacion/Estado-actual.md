# Estado actual

Módulo **implementado**. La integración **Google Docs/Sheets** se desarrolló en
`feat/kbase_google_docs` y está **mergeada a `develop`** (merge `f9e33faa`, 2026-06-26).

## Hecho — base del módulo

- Frontend `knowledgeSources/` completo (4 tabs) — ver [[Arquitectura]].
- Backend: controller, jobs de sync, servicios de respuesta y routing.
- Pipeline de embeddings con pgvector — ver [[Flujo-de-vectorizacion]].
- Datos de muestra: 7 CannedResponses de IA en cuenta 2.

## Hecho — Google Docs/Sheets (ver [[Integracion-Google-Docs]])

- **Google Doc** `{{doc:nombre}}`: texto → chunks + embeddings, pgvector scoped por fuente.
  Solo Docs **nativos** (un `.docx` subido no se puede exportar → ver [[Pendiente]]).
- **Google Sheet FAQ** `{{hoja:nombre}}`: fila → chunk embebido.
- **Google Sheet Datos** `{{hoja:nombre}}`: filas en tabla `google_sheet_rows` (sin embeddings)
  + `SheetQueryService` (el LLM traduce la pregunta, **Ruby calcula exacto**). Soporta
  multi-operación, valores categóricos, grupos OR (`filter_groups`), operador `in`,
  **fechas relativas** (mes pasado / próximo mes) y **cobranza** (columna de pago por verbo).
- **Modo en vivo** (solo Datos): refresca la copia local por `modifiedTime` + TTL, con
  **toggle "Consultar en vivo" + frecuencia** en el modal de la fuente.
- **Gating por la feature `google_calendar`** (super admin, por cuenta): si está OFF, no se
  crean fuentes Google, las existentes se muestran deshabilitadas, las directivas
  `{{doc:}}`/`{{hoja:}}` no operan y el catálogo de directivas las oculta (junto a
  `@agendar_calendar`). Reutiliza el OAuth de Google Calendar.

## Pendiente

Ver [[Pendiente]] (lo principal: soporte de `.docx` subidos a Drive).
