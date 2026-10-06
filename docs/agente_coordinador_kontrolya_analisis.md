# Agente IA "Atender a los clientes en Soporte, Comercial y Administrativo"

**Análisis del funcionamiento real y de las directivas en uso**

| | |
|---|---|
| **Plantilla** | `tracking_templates` #4906 — cuenta 2 |
| **Inbox** | #4 · `kontrolyaBots_bot` (Telegram) |
| **Seguimiento activo** | `contact_trackings` #1817 — contacto 15412, estado `pending` |
| **Entrenamiento** | *PROMPT AGENTE COORDINADOR KONTROLYA V1.6 — PRODUCCIÓN* (374 líneas) |
| **Ramas declaradas** | SOPORTE · COMERCIAL · ADMINISTRATIVO |
| **Rama de trabajo** | `fix/test_agentes_ia` |
| **Fecha** | 25/08/2026 |

---

## 1. Para qué sirve este documento

El prompt V1.6 describe un coordinador de tres ramas con router de intenciones, gate de
suficiencia, estados de evidencia y etiquetas operacionales. Este documento contrasta
**lo que el prompt ordena** contra **lo que el motor de seguimientos realmente ejecuta**,
para que las pruebas del agente se interpreten sobre el comportamiento real y no sobre el
comportamiento descrito.

---

## 2. Recorrido real de un mensaje entrante

<svg viewBox="0 0 860 790" width="100%" style="max-width:860px;height:auto" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Diagrama del recorrido de un mensaje entrante por el motor de seguimientos">
  <defs>
    <marker id="ah" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
      <path d="M 0 0 L 10 5 L 0 10 z" fill="#94a3b8"/>
    </marker>
  </defs>
  <rect x="140" y="16" width="580" height="48" rx="10" fill="#eef2ff" stroke="#6366f1" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="13px" font-weight="600" fill="#0f172a" x="430" y="38" text-anchor="middle">Cliente escribe en Telegram</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11px" fill="#64748b" x="430" y="54" text-anchor="middle">inbox 4 · kontrolyaBots_bot</text>
  <line x1="430" y1="64" x2="430" y2="80" stroke="#94a3b8" stroke-width="1.5" marker-end="url(#ah)"/>
  <rect x="140" y="82" width="580" height="54" rx="10" fill="#f8fafc" stroke="#cbd5e1" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="13px" font-weight="600" fill="#0f172a" x="430" y="104" text-anchor="middle">Message#analyze_for_active_trackings</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11px" fill="#64748b" x="430" y="121" text-anchor="middle">message.rb:474 — encola ContactTrackingResponseAnalyzerJob</text>
  <line x1="430" y1="136" x2="430" y2="152" stroke="#94a3b8" stroke-width="1.5" marker-end="url(#ah)"/>
  <rect x="140" y="154" width="580" height="54" rx="10" fill="#f8fafc" stroke="#cbd5e1" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="13px" font-weight="600" fill="#0f172a" x="430" y="176" text-anchor="middle">Gates de entrada · job:47</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11px" fill="#64748b" x="430" y="193" text-anchor="middle">¿entrante? · ¿tiene contenido? · ¿ya respondió el bot?</text>
  <line x1="430" y1="208" x2="430" y2="224" stroke="#94a3b8" stroke-width="1.5" marker-end="url(#ah)"/>
  <rect x="140" y="226" width="580" height="54" rx="10" fill="#f8fafc" stroke="#cbd5e1" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="13px" font-weight="600" fill="#0f172a" x="430" y="248" text-anchor="middle">find_active_trackings</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11px" fill="#64748b" x="430" y="265" text-anchor="middle">encuentra el seguimiento #1817 (plantilla 4906)</text>
  <line x1="430" y1="280" x2="430" y2="296" stroke="#94a3b8" stroke-width="1.5" marker-end="url(#ah)"/>
  <rect x="140" y="298" width="580" height="150" rx="10" fill="#ffffff" stroke="#94a3b8" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="12px" font-weight="700" fill="#1e293b" letter-spacing=".02em" x="160" y="322">process_message_for_tracking · job:83</text>
  <rect x="160" y="332" width="540" height="24" rx="6" fill="#f8fafc" stroke="#e2e8f0"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="12px" font-weight="700" x="172" y="348" fill="#cbd5e1">✗</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11.5px" fill="#334155" x="192" y="348">[1] Keywords — keyword_actions está vacío</text>
  <rect x="160" y="360" width="540" height="24" rx="6" fill="#f8fafc" stroke="#e2e8f0"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="12px" font-weight="700" x="172" y="376" fill="#cbd5e1">✗</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11.5px" fill="#334155" x="192" y="376">[2] PENDING_SLOT / PENDING_EMAIL — sin calendario configurado</text>
  <rect x="160" y="388" width="540" height="24" rx="6" fill="#fef2f2" stroke="#fecaca"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="12px" font-weight="700" x="172" y="404" fill="#ef4444">✗</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11.5px" fill="#334155" x="192" y="404">[3] RouterService — TRACKING_DETECT_INTENT=false (.env:25) → apagado</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11px" fill="#64748b" x="430" y="434" text-anchor="middle" style="font-weight:600;fill:#475569">ruta resultante: :tracking</text>
  <line x1="430" y1="448" x2="430" y2="464" stroke="#94a3b8" stroke-width="1.5" marker-end="url(#ah)"/>
  <rect x="140" y="468" width="580" height="212" rx="10" fill="#ffffff" stroke="#94a3b8" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="12px" font-weight="700" fill="#1e293b" letter-spacing=".02em" x="160" y="492">try_kbase_then_conversational · job:177</text>
  <rect x="160" y="502" width="540" height="24" rx="6" fill="#f8fafc" stroke="#e2e8f0"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="12px" font-weight="700" x="172" y="518" fill="#cbd5e1">✗</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11.5px" fill="#334155" x="192" y="518">a) acción de cita ya clasificada — el router está apagado</text>
  <rect x="160" y="530" width="540" height="24" rx="6" fill="#f8fafc" stroke="#e2e8f0"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="12px" font-weight="700" x="172" y="546" fill="#cbd5e1">✗</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11.5px" fill="#334155" x="192" y="546">b) @estado_ticket — no está en el prompt</text>
  <rect x="160" y="558" width="540" height="24" rx="6" fill="#f8fafc" stroke="#e2e8f0"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="12px" font-weight="700" x="172" y="574" fill="#cbd5e1">✗</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11.5px" fill="#334155" x="192" y="574">c) @crear_ticket — no está en el prompt</text>
  <rect x="160" y="586" width="540" height="24" rx="6" fill="#f8fafc" stroke="#e2e8f0"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="12px" font-weight="700" x="172" y="602" fill="#cbd5e1">✗</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11.5px" fill="#334155" x="192" y="602">d) @agendar_calendar — no está en el prompt</text>
  <rect x="160" y="614" width="540" height="24" rx="6" fill="#ecfdf5" stroke="#22c55e"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="12px" font-weight="700" x="172" y="630" fill="#16a34a">✓</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11.5px" fill="#334155" x="192" y="630">e) kbase_available? → @buscar_predefinidas · 16 respuestas predefinidas</text>
  <rect x="160" y="642" width="540" height="24" rx="6" fill="#fffbeb" stroke="#fcd34d"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="12px" font-weight="700" x="172" y="658" fill="#d97706">↓</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11.5px" fill="#334155" x="192" y="658">f) si la KBase no devuelve resultados → respuesta conversacional (job:441)</text>
  <path d="M430,680 L430,692" stroke="#94a3b8" stroke-width="1.5" fill="none"/>
  <path d="M280,692 L580,692" stroke="#94a3b8" stroke-width="1.5" fill="none"/>
  <line x1="280" y1="692" x2="280" y2="710" stroke="#94a3b8" stroke-width="1.5" marker-end="url(#ah)"/>
  <line x1="580" y1="692" x2="580" y2="710" stroke="#94a3b8" stroke-width="1.5" marker-end="url(#ah)"/>
  <rect x="140" y="712" width="280" height="56" rx="10" fill="#ecfdf5" stroke="#22c55e" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="13px" font-weight="600" fill="#0f172a" x="280" y="734" text-anchor="middle">Respuesta desde pgvector</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11px" fill="#64748b" x="280" y="751" text-anchor="middle">firmada “Respuestas predefinidas”</text>
  <rect x="440" y="712" width="280" height="56" rx="10" fill="#fffbeb" stroke="#f59e0b" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="13px" font-weight="600" fill="#0f172a" x="580" y="734" text-anchor="middle">Respuesta conversacional</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11px" fill="#64748b" x="580" y="751" text-anchor="middle">sin las instrucciones del prompt</text>
</svg>

---

## 3. Precedencia de directivas: solo una gana

`KnowledgeBaseResponseService#detect_directive`
(`app/services/knowledge_base_response_service.rb:76`) es una cadena **if / elsif**.
Se detiene en la primera coincidencia; el resto de las directivas del prompt no se evalúan.

<svg viewBox="0 0 860 470" width="100%" style="max-width:860px;height:auto" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Cadena de precedencia de directivas: buscar_predefinidas gana y discourse queda inalcanzable">
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="12px" font-weight="700" fill="#1e293b" x="40" y="26">detect_directive — orden de evaluación</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11px" fill="#64748b" x="40" y="44">knowledge_base_response_service.rb:76</text>
  <rect x="40" y="60" width="470" height="34" rx="8" fill="#f8fafc" stroke="#e2e8f0"/>
  <circle cx="62" cy="77" r="11" fill="#94a3b8"/><text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="12px" font-weight="700" fill="#ffffff" x="62" y="81" text-anchor="middle">1</text>
  <text font-family="ui-monospace, SFMono-Regular, Menlo, monospace" font-size="12px" x="84" y="76" fill="#0f172a">{{consulta:nombre}}</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11px" fill="#64748b" x="84" y="89">consulta determinista a ERP</text>
  <rect x="40" y="100" width="470" height="34" rx="8" fill="#ecfdf5" stroke="#22c55e" stroke-width="2"/>
  <circle cx="62" cy="117" r="11" fill="#16a34a"/><text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="12px" font-weight="700" fill="#ffffff" x="62" y="121" text-anchor="middle">2</text>
  <text font-family="ui-monospace, SFMono-Regular, Menlo, monospace" font-size="12px" x="84" y="116" fill="#0f172a" style="font-weight:700">@buscar_predefinidas</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11px" fill="#64748b" x="84" y="129" style="fill:#16a34a;font-weight:600">GANA — está en el prompt (línea 226, rama COMERCIAL)</text>
  <rect x="40" y="140" width="470" height="34" rx="8" fill="#f8fafc" stroke="#e2e8f0"/>
  <circle cx="62" cy="157" r="11" fill="#94a3b8"/><text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="12px" font-weight="700" fill="#ffffff" x="62" y="161" text-anchor="middle">3</text>
  <text font-family="ui-monospace, SFMono-Regular, Menlo, monospace" font-size="12px" x="84" y="156" fill="#0f172a">@buscar_articulo</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11px" fill="#64748b" x="84" y="169">Centro de Ayuda (pgvector)</text>
  <rect x="40" y="180" width="470" height="34" rx="8" fill="#f8fafc" stroke="#e2e8f0"/>
  <circle cx="62" cy="197" r="11" fill="#94a3b8"/><text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="12px" font-weight="700" fill="#ffffff" x="62" y="201" text-anchor="middle">4</text>
  <text font-family="ui-monospace, SFMono-Regular, Menlo, monospace" font-size="12px" x="84" y="196" fill="#0f172a">@buscar_foro(nombre)</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11px" fill="#64748b" x="84" y="209">Discourse vía KnowledgeSource — exige paréntesis</text>
  <rect x="40" y="220" width="470" height="34" rx="8" fill="#f8fafc" stroke="#e2e8f0"/>
  <circle cx="62" cy="237" r="11" fill="#94a3b8"/><text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="12px" font-weight="700" fill="#ffffff" x="62" y="241" text-anchor="middle">5</text>
  <text font-family="ui-monospace, SFMono-Regular, Menlo, monospace" font-size="12px" x="84" y="236" fill="#0f172a">{{doc:nombre}}</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11px" fill="#64748b" x="84" y="249">Google Doc</text>
  <rect x="40" y="260" width="470" height="34" rx="8" fill="#f8fafc" stroke="#e2e8f0"/>
  <circle cx="62" cy="277" r="11" fill="#94a3b8"/><text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="12px" font-weight="700" fill="#ffffff" x="62" y="281" text-anchor="middle">6</text>
  <text font-family="ui-monospace, SFMono-Regular, Menlo, monospace" font-size="12px" x="84" y="276" fill="#0f172a">{{hoja:nombre}}</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11px" fill="#64748b" x="84" y="289">Google Sheet (FAQ o Datos)</text>
  <rect x="40" y="300" width="470" height="34" rx="8" fill="#fef2f2" stroke="#ef4444" stroke-width="2" stroke-dasharray="5 3"/>
  <circle cx="62" cy="317" r="11" fill="#ef4444"/><text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="12px" font-weight="700" fill="#ffffff" x="62" y="321" text-anchor="middle">7</text>
  <text font-family="ui-monospace, SFMono-Regular, Menlo, monospace" font-size="12px" x="84" y="316" fill="#0f172a" style="font-weight:700">@discourse</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11px" fill="#64748b" x="84" y="329" style="fill:#ef4444;font-weight:600">INALCANZABLE — el flujo se detuvo en el paso 2</text>
  <path d="M515,117 L560,117" stroke="#16a34a" stroke-width="2" fill="none"/>
  <path d="M515,317 L560,317" stroke="#ef4444" stroke-width="2" stroke-dasharray="4 3" fill="none"/>
  <rect x="565" y="92" width="255" height="86" rx="10" fill="#ecfdf5" stroke="#22c55e" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="12.5px" font-weight="600" fill="#0f172a" x="580" y="114">Lo que se ejecuta siempre</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11px" fill="#64748b" x="580" y="133">Búsqueda pgvector sobre las 16</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11px" fill="#64748b" x="580" y="148">Respuestas Predefinidas de la cuenta,</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11px" fill="#64748b" x="580" y="163">para SOPORTE, COMERCIAL y ADMIN.</text>
  <rect x="565" y="278" width="255" height="86" rx="10" fill="#fef2f2" stroke="#ef4444" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="12.5px" font-weight="600" fill="#0f172a" x="580" y="300">Lo que nunca se ejecuta</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11px" fill="#64748b" x="580" y="319">La rama SOPORTE ordena @discourse</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11px" fill="#64748b" x="580" y="334">(líneas 133 · 135 · 150 · 152) y el hook</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11px" fill="#64748b" x="580" y="349">del inbox 4 está activo, pero no se llega.</text>
  <rect x="40" y="378" width="780" height="70" rx="10" fill="#fffbeb" stroke="#f59e0b" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="12.5px" font-weight="600" fill="#0f172a" x="58" y="400">Consecuencia para las pruebas</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11px" fill="#64748b" x="58" y="420">Cualquier consulta técnica se responde con Respuestas Predefinidas, no con el foro. Si el resultado suena</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11px" fill="#64748b" x="58" y="437">“fuera de tema”, la causa es la precedencia de la cadena, no la calidad del contenido del foro.</text>
</svg>

### Catálogo completo de directivas del motor

| Directiva | Modo | Fuente de datos | Dónde se evalúa |
|---|---|---|---|
| `{{consulta:nombre}}` | ERP determinista | conexión ERP de la cuenta | `ConsultaDirectiveRenderer::DIRECTIVE` |
| `@buscar_predefinidas` | pgvector | Respuestas Predefinidas (16 items) | `detect_search_directive` |
| `@buscar_articulo` | pgvector | Centro de Ayuda (1 item) | `detect_search_directive` |
| `@buscar_foro(nombre)` | Discourse semántico | KnowledgeSource "Foro Kontrolya" | `detect_search_directive` |
| `{{doc:nombre}}` | pgvector | Google Doc | `detect_search_directive` |
| `{{hoja:nombre}}` | pgvector o cálculo exacto | Google Sheet | `detect_search_directive` |
| `@discourse` | Discourse AI del inbox | hook `discourse` del inbox 4 | `detect_search_directive` |
| `@crear_ticket(...)` | creación de ticket | módulo Tickets | `TicketCreatorService::DIRECTIVE_RE` |
| `@estado_ticket` | consulta de ticket | módulo Tickets | `TicketStatusService` |
| `@agendar_calendar` | agenda de citas | Google Calendar | `agendar_calendar_directive?` |
| `{{nombre}}` | envío de archivo | adjuntos del Agente IA | `ATTACHMENT_DIRECTIVE` |

> `@evaluar_evidencia(fail=closed)` **no pertenece a este catálogo**: no existe en el código.

---

## 4. Qué prompt llega realmente al modelo

<svg viewBox="0 0 860 430" width="100%" style="max-width:860px;height:auto" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Diagrama que muestra que el prompt de entrenamiento no llega al modelo en ninguno de los dos caminos">
  <defs>
    <marker id="ah2" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
      <path d="M 0 0 L 10 5 L 0 10 z" fill="#94a3b8"/>
    </marker>
  </defs>
  <rect x="230" y="14" width="400" height="52" rx="10" fill="#eef2ff" stroke="#6366f1" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="13px" font-weight="700" fill="#0f172a" x="430" y="37" text-anchor="middle">complementary_prompt — “Entrenamiento”</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11px" fill="#64748b" x="430" y="55" text-anchor="middle">374 líneas · PROMPT COORDINADOR KONTROLYA V1.6</text>
  <path d="M430,66 L430,84 M215,84 L645,84" stroke="#94a3b8" stroke-width="1.5" fill="none"/>
  <line x1="215" y1="84" x2="215" y2="104" stroke="#94a3b8" stroke-width="1.5" marker-end="url(#ah2)"/>
  <line x1="645" y1="84" x2="645" y2="104" stroke="#94a3b8" stroke-width="1.5" marker-end="url(#ah2)"/>
  <rect x="40" y="106" width="350" height="240" rx="10" fill="#ffffff" stroke="#94a3b8" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="13px" font-weight="700" fill="#0f172a" x="60" y="130">Camino KBase</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11px" fill="#64748b" x="60" y="147">generate_contextual_reply · kb_service:268</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11px" fill="#64748b" x="60" y="173" style="font-weight:600;fill:#475569">El system prompt contiene:</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11.5px" fill="#334155" x="60" y="194">• “Eres un asesor de {nombre de la cuenta}”</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11.5px" fill="#334155" x="60" y="214">• Objetivo del seguimiento</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11.5px" fill="#334155" x="60" y="234">• Los 3 fragmentos más parecidos de la KBase</text>
  <rect x="60" y="252" width="310" height="72" rx="8" fill="#fef2f2" stroke="#fecaca"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11.5px" fill="#334155" x="74" y="274" style="font-weight:700;fill:#b91c1c">El Entrenamiento no se pasa</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11px" fill="#64748b" x="74" y="292">Este camino arma su propio prompt y nunca</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11px" fill="#64748b" x="74" y="308">lee complementary_prompt.</text>
  <rect x="470" y="106" width="350" height="240" rx="10" fill="#ffffff" stroke="#94a3b8" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="13px" font-weight="700" fill="#0f172a" x="490" y="130">Camino conversacional</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11px" fill="#64748b" x="490" y="147">generate_conversational_reply · job:441</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11px" fill="#64748b" x="490" y="173" style="font-weight:600;fill:#475569">El system prompt contiene:</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11.5px" fill="#334155" x="490" y="194">• Cuenta · objetivo · ai_context (“Usuario Final”)</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11.5px" fill="#334155" x="490" y="214">• Estado de la cita y próximo contacto</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11.5px" fill="#94a3b8" x="490" y="234">• INSTRUCCIONES ADICIONALES: (vacío)</text>
  <rect x="490" y="252" width="310" height="72" rx="8" fill="#fef2f2" stroke="#fecaca"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11.5px" fill="#334155" x="504" y="274" style="font-weight:700;fill:#b91c1c">El Entrenamiento se blanquea</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11px" fill="#64748b" x="504" y="292">job:469 — al detectar una directiva de KBase</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11px" fill="#64748b" x="504" y="308">hace clean_cp = '' a propósito.</text>
  <rect x="40" y="358" width="780" height="58" rx="10" fill="#fffbeb" stroke="#f59e0b" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11.5px" fill="#334155" x="58" y="380" style="font-weight:700">Resultado neto</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11px" fill="#64748b" x="58" y="400">Router de ramas, gate de suficiencia, estados de evidencia, etiquetas #soporte1 / #comercial2 / #resuelto, reglas de no-diagnóstico y estilo: sin efecto.</text>
</svg>

---

## 5. Lo que ordena cada rama frente a lo que ocurre

| Rama | El prompt V1.6 ordena | Lo que ejecuta el motor |
|---|---|---|
| **SOPORTE** | `@discourse <consulta>` + `@evaluar_evidencia(fail=closed)` | `@buscar_predefinidas` — el foro nunca se consulta |
| **COMERCIAL** | `@buscar_predefinidas` + `@evaluar_evidencia(fail=closed)` | `@buscar_predefinidas` — única coincidencia real |
| **ADMINISTRATIVO** | Sin fuente; conducir a atención humana | El mismo `@buscar_predefinidas`; no existe una rama "sin fuente" |

---

## 6. Hallazgos

### 6.1 `@evaluar_evidencia(fail=closed)` no existe

Cero coincidencias en todo el repositorio. Las cuatro apariciones en el prompt son texto
inerte. Con ellas caen `EVIDENCIA_AUTORIZADA`, `ESTADO_EVIDENCIA`, `FUENTES_AUTORIZADAS`
y el gate `fail=closed`: no hay nada que distinga EXACTA de PARCIAL, de NO_CONFIRMADA,
de CONTRADICTORIA ni de SIN_EVIDENCIA.

### 6.2 Solo una directiva gana, y gana `@buscar_predefinidas`

Está en la línea 226 (rama COMERCIAL) y por precedencia se lleva **todos** los turnos,
incluidos los de SOPORTE. El hook de Discourse del inbox 4 está habilitado y el
KnowledgeSource "Foro Kontrolya" está activo, pero jamás se alcanzan.

### 6.3 Las 374 líneas del prompt no gobiernan ninguna respuesta

Por el camino KBase el system prompt se arma aparte; por el camino conversacional el
prompt se blanquea de forma deliberada (`job:469`). Como además `keyword_actions` está
vacío, las etiquetas operacionales tampoco disparan acciones: no clasifican, no cierran
ni marcan nada.

### 6.4 `@buscar_foro` sin paréntesis no coincide

En la línea 145 aparece como mención en prosa. El patrón exige `@buscar_foro(nombre)`,
así que ahí es inofensivo — conviene saberlo para no darlo por activo.

### 6.5 El Router de intenciones está apagado

`TRACKING_DETECT_INTENT=false` (`.env:25`). La ruta es siempre `:tracking`, así que las
rutas `rejected`, `interested`, `book_appointment`, `reschedule`, `cancel_appointment`
y `kbase` no se evalúan en este entorno.

---

## 7. Opciones de corrección

Ninguna está aplicada; quedan a decisión antes de tocar código.

| # | Opción | Alcance | Efecto |
|---|---|---|---|
| A | Quitar `@buscar_predefinidas` del prompt y dejar solo `@discourse` | Solo dato (editar la plantilla) | SOPORTE llega al foro; COMERCIAL pierde las predefinidas |
| B | Permitir varias directivas y elegir la fuente según la rama detectada | Código: `detect_directive` + job | Es el comportamiento que el prompt asume; el más costoso |
| C | Separar en dos Agentes IA (uno de Soporte con `@discourse`, otro Comercial/Admin con `@buscar_predefinidas`) | Solo configuración | Resuelve hoy sin tocar el motor; exige enrutar por inbox o etiqueta |
| D | Implementar `@evaluar_evidencia` como gate real sobre los resultados de la KBase | Código: servicio nuevo | Habilita los estados de evidencia del prompt |
| E | Pasar el prompt al camino KBase en lugar de descartarlo | Código: `generate_contextual_reply` | Devuelve el control de estilo y de reglas al Entrenamiento |

**Recomendación**: empezar por **C** para desbloquear las pruebas sin riesgo, y evaluar
**B + E** como el cambio de fondo si se quiere que el prompt V1.6 realmente mande.

---

## 8. Referencias de código

| Archivo | Puntos clave |
|---|---|
| `app/models/message.rb` | `:474` — encolado del job |
| `app/jobs/contact_tracking_response_analyzer_job.rb` | `:47` gates · `:83` flujo por tracking · `:177` KBase/conversacional · `:378` `kbase_available?` · `:441` respuesta conversacional · `:469` blanqueo del prompt |
| `app/services/knowledge_base_response_service.rb` | `:76` `detect_directive` · `:82` cadena de precedencia · `:268` prompt del camino KBase |
| `app/services/contact_trackings/router_service.rb` | `:45` rutas válidas · `:140` `classify` |
| `app/services/cases/ticket_creator_service.rb` | `:28` patrón de `@crear_ticket` |
| `app/services/external_db/consulta_directive_renderer.rb` | `:19` patrón de `{{consulta:}}` |
| `.env` | `:25` `TRACKING_DETECT_INTENT=false` |
