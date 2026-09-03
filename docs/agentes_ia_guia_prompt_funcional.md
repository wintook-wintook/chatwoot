# Guía — Cómo se escribe un prompt funcional para un Agente IA

**Del texto del Entrenamiento a la ejecución: qué lee el código, qué lee el modelo y qué se ejecuta**

| | |
|---|---|
| **Aplica a** | Agentes IA de Seguimientos (`tracking_templates.complementary_prompt`) |
| **Versión de prompt de referencia** | v6.x — *Agente Coordinador Multi-Intención* |
| **Código analizado** | rama `fix/test_agentes_ia` · commit `7a7ff21a` |
| **Fecha** | 03/09/2026 |

---

## 1. La idea que hay que tener clara antes de escribir una línea

El Entrenamiento **no es un documento que el modelo interpreta**. Es un texto que
atraviesan dos lectores distintos, y cada uno se lleva una parte:

1. **Ruby (el parser)** busca *patrones exactos* — `@ruta(...)`, `@buscar_predefinidas(GESTION)`,
   `{{hoja:Precios}}`. Lo que coincide se convierte en una llamada real: una consulta a
   pgvector, un GET a Discourse, un alta de ticket. Lo que no coincide **no existe**: no
   falla, no avisa, simplemente es prosa.
2. **El modelo (OpenAI)** recibe la prosa **ya limpia de esos patrones**, más el resultado
   que Ruby recuperó, más la rama que el sistema ya decidió.

De ahí la regla que gobierna todo lo demás:

> **Una instrucción solo se ejecuta si coincide con un patrón del catálogo.
> Una instrucción que solo suena bien es decoración.**

El caso documentado de esto es `@evaluar_evidencia(fail=closed)` en el prompt V1.6: cuatro
apariciones, cero coincidencias en el repositorio, cero efecto — y con él caían el gate de
suficiencia y los estados de evidencia completos
(ver `docs/agente_coordinador_kontrolya_analisis.md` §6.1).

---

## 2. Anatomía del Entrenamiento: dónde termina cada línea

<svg viewBox="0 0 860 470" width="100%" style="max-width:860px;height:auto" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="El Entrenamiento se parte en líneas @ruta parseables, prosa para el modelo y directivas sueltas que blanquean el prompt">
  <defs>
    <marker id="g1" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
      <path d="M 0 0 L 10 5 L 0 10 z" fill="#94a3b8"/>
    </marker>
    <marker id="g1r" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
      <path d="M 0 0 L 10 5 L 0 10 z" fill="#ef4444"/>
    </marker>
  </defs>
  <rect x="24" y="34" width="440" height="412" rx="10" fill="#ffffff" stroke="#94a3b8" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="13px" font-weight="700" fill="#0f172a" x="42" y="60">Entrenamiento del Agente IA</text>
  <text font-family="ui-monospace, SFMono-Regular, Menlo, monospace" font-size="10.5px" fill="#64748b" x="42" y="76">tracking_templates.complementary_prompt</text>
  <line x1="42" y1="86" x2="446" y2="86" stroke="#e2e8f0"/>
  <rect x="42" y="98" width="404" height="112" rx="8" fill="#eef2ff" stroke="#6366f1" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11px" font-weight="700" fill="#475569" letter-spacing=".03em" x="56" y="118">1 · LÍNEAS @ruta — configuración parseable</text>
  <text font-family="ui-monospace, SFMono-Regular, Menlo, monospace" font-size="10px" fill="#0f172a" x="56" y="140">@ruta(soporte #soporte1: fallas, errores): @discourse</text>
  <text font-family="ui-monospace, SFMono-Regular, Menlo, monospace" font-size="10px" fill="#0f172a" x="56" y="158">     -&gt; @crear_ticket(tipo=Soporte)</text>
  <text font-family="ui-monospace, SFMono-Regular, Menlo, monospace" font-size="10px" fill="#0f172a" x="56" y="176">@ruta(comercial #comercial1: precios): @buscar_predefinidas</text>
  <text font-family="ui-monospace, SFMono-Regular, Menlo, monospace" font-size="10px" fill="#0f172a" x="56" y="194">@ruta_por_defecto: comercial</text>
  <rect x="42" y="222" width="404" height="120" rx="8" fill="#f8fafc" stroke="#cbd5e1" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11px" font-weight="700" fill="#475569" letter-spacing=".03em" x="56" y="242">2 · PROSA — lo único que llega al modelo</text>
  <text font-family="ui-monospace, SFMono-Regular, Menlo, monospace" font-size="10px" fill="#94a3b8" x="56" y="264">[ROL] Eres el coordinador de atención de…</text>
  <text font-family="ui-monospace, SFMono-Regular, Menlo, monospace" font-size="10px" fill="#94a3b8" x="56" y="282">[ALCANCE POR RAMA] SOPORTE: … COMERCIAL: …</text>
  <text font-family="ui-monospace, SFMono-Regular, Menlo, monospace" font-size="10px" fill="#94a3b8" x="56" y="300">[ETIQUETAS] Cierra SIEMPRE con la etiqueta…</text>
  <text font-family="ui-monospace, SFMono-Regular, Menlo, monospace" font-size="10px" fill="#94a3b8" x="56" y="318">[ESTILO] WhatsApp, 1–2 párrafos, sin listas…</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10px" fill="#64748b" x="56" y="334">Se le entrega ya sin las líneas @ruta ni las directivas</text>
  <rect x="42" y="354" width="404" height="76" rx="8" fill="#fef2f2" stroke="#ef4444" stroke-width="1.5" stroke-dasharray="5 3"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11px" font-weight="700" fill="#b91c1c" letter-spacing=".03em" x="56" y="374">3 · DIRECTIVA SUELTA EN LA PROSA — la trampa</text>
  <text font-family="ui-monospace, SFMono-Regular, Menlo, monospace" font-size="10px" fill="#0f172a" x="56" y="394">Si consultan algo técnico usá @discourse.</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10px" fill="#64748b" x="56" y="414">Fuera de una línea @ruta, una directiva de búsqueda</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10px" fill="#64748b" x="56" y="426">borra el prompt entero en el camino conversacional.</text>
  <path d="M450,140 L486,96" stroke="#94a3b8" stroke-width="1.5" fill="none" marker-end="url(#g1)"/>
  <path d="M450,158 L486,176" stroke="#94a3b8" stroke-width="1.5" fill="none" marker-end="url(#g1)"/>
  <path d="M450,180 L486,256" stroke="#94a3b8" stroke-width="1.5" fill="none" marker-end="url(#g1)"/>
  <path d="M450,290 L486,336" stroke="#94a3b8" stroke-width="1.5" fill="none" marker-end="url(#g1)"/>
  <path d="M450,392 L486,412" stroke="#ef4444" stroke-width="1.5" fill="none" marker-end="url(#g1r)"/>
  <rect x="490" y="64" width="346" height="64" rx="8" fill="#ffffff" stroke="#6366f1" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="12px" font-weight="700" fill="#0f172a" x="506" y="86">RouteMap.parse</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10.5px" fill="#64748b" x="506" y="104">Ramas, etiqueta #tag, fuente y escalamiento.</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10.5px" fill="#64748b" x="506" y="119">Sin estas líneas, el motor opera como siempre.</text>
  <rect x="490" y="144" width="346" height="64" rx="8" fill="#ffffff" stroke="#6366f1" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="12px" font-weight="700" fill="#0f172a" x="506" y="166">BranchClassifierService</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10.5px" fill="#64748b" x="506" y="184">Ve SOLO los nombres y las descripciones.</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10.5px" fill="#64748b" x="506" y="199">Una llamada corta al LLM → una rama.</text>
  <rect x="490" y="224" width="346" height="64" rx="8" fill="#ffffff" stroke="#22c55e" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="12px" font-weight="700" fill="#0f172a" x="506" y="246">KnowledgeBase::Directives.detect</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10.5px" fill="#64748b" x="506" y="264">Recibe la directiva de UNA rama.</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10.5px" fill="#64748b" x="506" y="279">Ejecuta la búsqueda antes de llamar al modelo.</text>
  <rect x="490" y="304" width="346" height="64" rx="8" fill="#ffffff" stroke="#f59e0b" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="12px" font-weight="700" fill="#0f172a" x="506" y="326">System prompt del modelo</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10.5px" fill="#64748b" x="506" y="344">Prosa + objetivo + RAMA YA DECIDIDA.</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10.5px" fill="#64748b" x="506" y="359">Aquí mandan tono, reglas y etiquetas.</text>
  <rect x="490" y="384" width="346" height="56" rx="8" fill="#fef2f2" stroke="#ef4444" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="12px" font-weight="700" fill="#b91c1c" x="506" y="406">clean_cp = &#39;&#39;</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10.5px" fill="#64748b" x="506" y="424">job:545 — el conversacional descarta TODO el prompt</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10.5px" fill="#64748b" x="506" y="437">si ve una directiva de búsqueda fuera de @ruta.</text>
</svg>

**Cómo leer el diagrama.** El mismo texto se reparte en cuatro consumidores. Las líneas
`@ruta` alimentan al parser y al clasificador y **nunca llegan al modelo**
(`RouteMap.strip`, `route_map.rb:58`). La prosa llega al modelo **después** de que
`agent_system_prompt` (`knowledge_base_response_service.rb:618`) le quite las líneas de ruta
y las directivas sueltas de búsqueda. Y la zona 3 es el error clásico: una directiva escrita
en medio de la prosa, fuera de una línea `@ruta`, hace que el camino conversacional tire el
Entrenamiento completo a la basura (`job:545`).

---

## 3. Catálogo de directivas — el contrato exacto

Solo esto se ejecuta. El patrón es literal: se respetan paréntesis, dos puntos y llaves.

| Directiva | Patrón real en el código | Quién la ejecuta | Cuándo se evalúa |
|---|---|---|---|
| `{{consulta:nombre}}` · `{{consulta:conexion/nombre(args)}}` | `ExternalDb::ConsultaDirectiveRenderer::DIRECTIVE` | consulta al ERP, sin IA | 1º del catálogo de fuentes |
| `@buscar_predefinidas` | `/@buscar_predefinidas\b(?:\s*\(([^)]*)\))?/i` | pgvector sobre Respuestas predefinidas | 2º |
| `@buscar_predefinidas(GRUPO)` | mismo patrón, grupo capturado | idem, solo nombres que empiezan con `GRUPO` | 2º |
| `@buscar_predefinidas(!GRUPO)` | mismo patrón, `!` = negación | idem, todas MENOS esas | 2º |
| `@buscar_articulo` | `/@buscar_art[ií]culo\b/i` | pgvector sobre Centro de Ayuda | 3º |
| `@buscar_foro(nombre)` | `/@buscar_foro\(([^)]+)\)/i` — **los paréntesis son obligatorios** | Discourse vía KnowledgeSource | 4º |
| `{{doc:nombre}}` | `/\{\{doc:([^}]+)\}\}/i` | Google Doc (exige feature `google_calendar`) | 5º |
| `{{hoja:nombre}}` | `/\{\{hoja:([^}]+)\}\}/i` | Google Sheet — FAQ o modo Datos | 6º |
| `@discourse` | `/@discourse\b/i` | Discourse AI del hook del inbox | 7º |
| `@crear_ticket(...)` | `Cases::TicketCreatorService::DIRECTIVE_RE` | alta de ticket con IA de intake | fuera del catálogo de fuentes |
| `@estado_ticket` | comparación literal de cadena | consulta del caso del contacto | antes que todo lo anterior |
| `@agendar_calendar` | `/@agendar_calendar\b/i` | agenda de citas de Google Calendar | tras los tickets |
| `{{nombre}}` | `/\{\{\s*([a-zA-Z0-9_-]+)\s*\}\}/` | adjunta un archivo del Agente IA | **al enviar**, sobre lo que escribió el modelo |
| `@ruta(...)` · `@ruta_por_defecto:` | `RouteMap::LINE_RE` / `DEFAULT_RE` | mapa de ramas | antes que nada |

Parámetros admitidos hoy:

| Forma | Efecto |
|---|---|
| `@crear_ticket(tipo=Soporte, prioridad=alta)` | fija tipo y prioridad del caso |
| `@crear_ticket(fallback=true)` | invierte el orden: primero contesta la KBase, el ticket es último recurso |
| `@buscar_predefinidas(GESTION)` | corpus estrecho + **umbral 0.45** en vez de 0.20 |
| `@buscar_predefinidas(!GESTION)` | corpus general menos ese grupo, **umbral 0.20** |
| `@ruta(nombre #etiqueta: descripción): fuente -> escalamiento` | rama completa |
| `@ruta(nombre: ...): -` | rama declarada **sin fuente** → contesta el conversacional |

---

## 4. El recorrido de un turno: quién contesta primero

<svg viewBox="0 0 860 726" width="100%" style="max-width:860px;height:auto" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Orden de decisión de un turno, desde el mensaje entrante hasta el envío de la respuesta">
  <defs>
    <marker id="g2" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
      <path d="M 0 0 L 10 5 L 0 10 z" fill="#94a3b8"/>
    </marker>
  </defs>
  <rect x="230" y="14" width="400" height="44" rx="10" fill="#eef2ff" stroke="#6366f1" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="12.5px" font-weight="700" fill="#0f172a" x="430" y="34" text-anchor="middle">Mensaje entrante del cliente</text>
  <text font-family="ui-monospace, SFMono-Regular, Menlo, monospace" font-size="9.5px" fill="#64748b" x="430" y="50" text-anchor="middle">message.rb:138 after_create_commit → job</text>
  <line x1="430" y1="58" x2="430" y2="74" stroke="#94a3b8" stroke-width="1.5" marker-end="url(#g2)"/>
  <rect x="230" y="76" width="400" height="42" rx="10" fill="#f8fafc" stroke="#cbd5e1" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11.5px" fill="#0f172a" x="430" y="94" text-anchor="middle" style="font-weight:600">Gates de entrada — job:47</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10px" fill="#64748b" x="430" y="110" text-anchor="middle">¿entrante? · ¿tiene contenido o adjunto? · ¿el bot no contestó ya?</text>
  <line x1="430" y1="118" x2="430" y2="134" stroke="#94a3b8" stroke-width="1.5" marker-end="url(#g2)"/>
  <rect x="150" y="136" width="560" height="128" rx="10" fill="#ffffff" stroke="#94a3b8" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11.5px" font-weight="700" fill="#1e293b" x="170" y="158">process_message_for_tracking — job:82</text>
  <rect x="170" y="168" width="520" height="26" rx="6" fill="#f8fafc" stroke="#e2e8f0"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10.5px" fill="#334155" x="184" y="185">[1] keyword_actions — coincidencia exacta, sin IA. Si pega, corta aquí.</text>
  <rect x="170" y="198" width="520" height="26" rx="6" fill="#f8fafc" stroke="#e2e8f0"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10.5px" fill="#334155" x="184" y="215">[2] PENDING_SLOT / PENDING_EMAIL — hay una cita a medio confirmar.</text>
  <rect x="170" y="228" width="520" height="26" rx="6" fill="#fffbeb" stroke="#fcd34d"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10.5px" fill="#334155" x="184" y="245">[3] RouterService — apagado por TRACKING_DETECT_INTENT=false → ruta :tracking.</text>
  <line x1="430" y1="264" x2="430" y2="280" stroke="#94a3b8" stroke-width="1.5" marker-end="url(#g2)"/>
  <rect x="150" y="282" width="560" height="290" rx="10" fill="#ffffff" stroke="#6366f1" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11.5px" font-weight="700" fill="#1e293b" x="170" y="304">try_kbase_then_conversational — job:175 · el PRIMERO que resuelve, gana</text>
  <rect x="170" y="314" width="520" height="26" rx="6" fill="#f8fafc" stroke="#e2e8f0"/>
  <text font-family="ui-monospace, SFMono-Regular, Menlo, monospace" font-size="10px" fill="#0f172a" x="184" y="331">a) cita ya clasificada</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10px" fill="#64748b" x="330" y="331">el calendario gana sobre la base de conocimiento</text>
  <rect x="170" y="344" width="520" height="26" rx="6" fill="#f8fafc" stroke="#e2e8f0"/>
  <text font-family="ui-monospace, SFMono-Regular, Menlo, monospace" font-size="10px" fill="#0f172a" x="184" y="361">b) @estado_ticket</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10px" fill="#64748b" x="330" y="361">consultar un caso nunca abre uno nuevo</text>
  <rect x="170" y="374" width="520" height="26" rx="6" fill="#f8fafc" stroke="#e2e8f0"/>
  <text font-family="ui-monospace, SFMono-Regular, Menlo, monospace" font-size="10px" fill="#0f172a" x="184" y="391">c) @crear_ticket</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10px" fill="#64748b" x="330" y="391">salvo fallback=true, que lo manda al final</text>
  <rect x="170" y="404" width="520" height="26" rx="6" fill="#f8fafc" stroke="#e2e8f0"/>
  <text font-family="ui-monospace, SFMono-Regular, Menlo, monospace" font-size="10px" fill="#0f172a" x="184" y="421">d) @agendar_calendar</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10px" fill="#64748b" x="330" y="421">solo si el cliente habla realmente de una cita</text>
  <rect x="170" y="434" width="520" height="42" rx="6" fill="#ecfdf5" stroke="#22c55e"/>
  <text font-family="ui-monospace, SFMono-Regular, Menlo, monospace" font-size="10px" fill="#0f172a" x="184" y="451">e) branch_for → KBase</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10px" fill="#64748b" x="330" y="451">clasifica la rama UNA vez y busca en SU fuente</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10px" fill="#64748b" x="184" y="468">si la rama no tiene fuente, o la búsqueda no trae nada, sigue de largo</text>
  <rect x="170" y="480" width="520" height="26" rx="6" fill="#f8fafc" stroke="#e2e8f0"/>
  <text font-family="ui-monospace, SFMono-Regular, Menlo, monospace" font-size="10px" fill="#0f172a" x="184" y="497">f) @crear_ticket(fallback)</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10px" fill="#64748b" x="330" y="497">último recurso: la fuente no resolvió el turno</text>
  <rect x="170" y="510" width="520" height="42" rx="6" fill="#fffbeb" stroke="#f59e0b"/>
  <text font-family="ui-monospace, SFMono-Regular, Menlo, monospace" font-size="10px" fill="#0f172a" x="184" y="527">g) conversacional</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10px" fill="#64748b" x="330" y="527">responde con la prosa del prompt — o sin ella</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10px" fill="#b91c1c" x="184" y="544">si hay una directiva de búsqueda suelta en la prosa, el prompt se blanquea (job:545)</text>
  <line x1="430" y1="572" x2="430" y2="588" stroke="#94a3b8" stroke-width="1.5" marker-end="url(#g2)"/>
  <rect x="150" y="590" width="560" height="120" rx="10" fill="#ffffff" stroke="#22c55e" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11.5px" font-weight="700" fill="#1e293b" x="170" y="612">Post-proceso del texto que devolvió el modelo</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10.5px" fill="#334155" x="170" y="634">· with_branch_tag — repone la #etiqueta de la rama solo si el modelo la olvidó</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10.5px" fill="#334155" x="170" y="654">· firma de la fuente al pie (_Respuestas predefinidas_) o link 📚 del foro</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10.5px" fill="#334155" x="170" y="674">· resolve_attachment_directives — {{nombre}} se convierte en archivo adjunto</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10.5px" fill="#334155" x="170" y="694">· MessageBuilder envía y marca sentiment_auto_reply</text>
</svg>

**Cómo leer el diagrama.** Es una cascada de guardias, no un árbol de decisión: el primer
paso que resuelve el turno **corta** y los de abajo no se ejecutan. Por eso el orden manda
más que cualquier instrucción del prompt — si `@crear_ticket` está sin `fallback=true`, la
base de conocimiento no llega a hablar nunca. La caja verde de abajo importa igual: hay
cosas que el prompt pide y que **no las hace el modelo**, las hace Ruby después.

---

## 5. El "function calling" de este motor

No se usa el *tool calling* nativo de OpenAI. El contrato es texto y JSON, y la ejecución
ocurre en tres momentos distintos:

<svg viewBox="0 0 860 430" width="100%" style="max-width:860px;height:auto" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Tres mecanismos de ejecución: directivas antes de llamar al modelo, JSON del modelo despachado por Ruby, y directivas escritas por el modelo ejecutadas al enviar">
  <rect x="20" y="40" width="266" height="300" rx="10" fill="#ffffff" stroke="#6366f1" stroke-width="1.5"/>
  <rect x="20" y="40" width="266" height="34" rx="10" fill="#eef2ff" stroke="#6366f1" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11.5px" font-weight="700" fill="#0f172a" x="153" y="62" text-anchor="middle">A · ANTES de llamar al modelo</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10.5px" fill="#64748b" x="36" y="94">Ruby lee la directiva del prompt y</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10.5px" fill="#64748b" x="36" y="109">ejecuta la búsqueda por su cuenta.</text>
  <text font-family="ui-monospace, SFMono-Regular, Menlo, monospace" font-size="10px" fill="#0f172a" x="36" y="134">{{consulta:saldo}}  → SQL al ERP</text>
  <text font-family="ui-monospace, SFMono-Regular, Menlo, monospace" font-size="10px" fill="#0f172a" x="36" y="152">@buscar_predefinidas → pgvector</text>
  <text font-family="ui-monospace, SFMono-Regular, Menlo, monospace" font-size="10px" fill="#0f172a" x="36" y="170">@buscar_foro(X)     → Discourse</text>
  <text font-family="ui-monospace, SFMono-Regular, Menlo, monospace" font-size="10px" fill="#0f172a" x="36" y="188">{{hoja:Precios}}    → Sheets</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10.5px" fill="#64748b" x="36" y="214">El resultado entra al prompt como</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10.5px" fill="#64748b" x="36" y="229">«Información relevante».</text>
  <rect x="36" y="244" width="234" height="82" rx="8" fill="#f8fafc" stroke="#cbd5e1"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10.5px" font-weight="700" fill="#334155" x="50" y="264">Consecuencia para el prompt</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10px" fill="#64748b" x="50" y="282">El modelo NO decide si buscar.</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10px" fill="#64748b" x="50" y="298">Pedirle «consultá la base» no hace</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10px" fill="#64748b" x="50" y="314">nada: ya se buscó, o no se buscó.</text>
  <rect x="297" y="40" width="266" height="300" rx="10" fill="#ffffff" stroke="#22c55e" stroke-width="1.5"/>
  <rect x="297" y="40" width="266" height="34" rx="10" fill="#ecfdf5" stroke="#22c55e" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11.5px" font-weight="700" fill="#0f172a" x="430" y="62" text-anchor="middle">B · DURANTE — JSON → despacho</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10.5px" fill="#64748b" x="313" y="94">El modelo responde JSON estricto</text>
  <text font-family="ui-monospace, SFMono-Regular, Menlo, monospace" font-size="10px" fill="#64748b" x="313" y="109">response_format: json_object</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10.5px" fill="#64748b" x="313" y="124">y Ruby lo convierte en una acción.</text>
  <text font-family="ui-monospace, SFMono-Regular, Menlo, monospace" font-size="10px" fill="#0f172a" x="313" y="150">{&quot;rama&quot;: &quot;soporte&quot;}</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="9.5px" fill="#64748b" x="313" y="164">BranchClassifier → elige la fuente</text>
  <text font-family="ui-monospace, SFMono-Regular, Menlo, monospace" font-size="10px" fill="#0f172a" x="313" y="186">{&quot;intent&quot;, &quot;appointment_action&quot;,</text>
  <text font-family="ui-monospace, SFMono-Regular, Menlo, monospace" font-size="10px" fill="#0f172a" x="313" y="200">&quot;reschedule_data&quot;}</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="9.5px" fill="#64748b" x="313" y="214">RouterService → agenda / cancela</text>
  <text font-family="ui-monospace, SFMono-Regular, Menlo, monospace" font-size="10px" fill="#0f172a" x="313" y="236">{filtros, columnas, operación}</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="9.5px" fill="#64748b" x="313" y="250">SheetQuery → Ruby calcula exacto</text>
  <rect x="313" y="262" width="234" height="64" rx="8" fill="#f8fafc" stroke="#cbd5e1"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10.5px" font-weight="700" fill="#334155" x="327" y="282">Consecuencia para el prompt</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10px" fill="#64748b" x="327" y="300">Estos clasificadores NO leen tu</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10px" fill="#64748b" x="327" y="316">prosa: leen las descripciones @ruta.</text>
  <rect x="574" y="40" width="266" height="300" rx="10" fill="#ffffff" stroke="#f59e0b" stroke-width="1.5"/>
  <rect x="574" y="40" width="266" height="34" rx="10" fill="#fffbeb" stroke="#f59e0b" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11.5px" font-weight="700" fill="#0f172a" x="707" y="62" text-anchor="middle">C · DESPUÉS — sobre su respuesta</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10.5px" fill="#64748b" x="590" y="94">El modelo ESCRIBE la directiva en</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10.5px" fill="#64748b" x="590" y="109">su texto y Ruby la ejecuta al enviar.</text>
  <text font-family="ui-monospace, SFMono-Regular, Menlo, monospace" font-size="10px" fill="#0f172a" x="590" y="134">{{catalogo}}</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="9.5px" fill="#64748b" x="590" y="148">→ se borra del texto y se adjunta</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="9.5px" fill="#64748b" x="590" y="162">el archivo real (máx. 5)</text>
  <text font-family="ui-monospace, SFMono-Regular, Menlo, monospace" font-size="10px" fill="#0f172a" x="590" y="186">#gestion</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="9.5px" fill="#64748b" x="590" y="200">→ queda en el mensaje y dispara</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="9.5px" fill="#64748b" x="590" y="214">las automatizaciones de la cuenta</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="9.5px" fill="#64748b" x="590" y="236">Si falta, la repone with_branch_tag</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="9.5px" fill="#64748b" x="590" y="250">con la etiqueta declarada en @ruta</text>
  <rect x="590" y="262" width="234" height="64" rx="8" fill="#fef2f2" stroke="#fecaca"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10.5px" font-weight="700" fill="#b91c1c" x="604" y="282">Límite real</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10px" fill="#64748b" x="604" y="300">{{nombre}} solo se resuelve en el</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10px" fill="#64748b" x="604" y="316">camino conversacional, no en KBase.</text>
  <rect x="20" y="356" width="820" height="58" rx="10" fill="#f8fafc" stroke="#cbd5e1" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="11px" font-weight="700" fill="#0f172a" x="38" y="378">Por qué esto cambia cómo se escribe el prompt</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10.5px" fill="#64748b" x="38" y="398">No hay un esquema de herramientas que valide nada. Una directiva mal escrita no produce error: deja de existir, y el turno</text>
  <text font-family="ui-sans-serif, system-ui, 'Segoe UI', Roboto, sans-serif" font-size="10.5px" fill="#64748b" x="38" y="410">sigue por otro camino sin avisar. El patrón exacto ES el contrato.</text>
</svg>

**Cómo leer el diagrama.** Tres columnas, tres momentos.

- **A — antes.** Cuando el turno entra, Ruby ya sabe qué fuente consultar porque la leyó del
  prompt. Busca, arma el contexto y recién entonces llama al modelo. El modelo **redacta**;
  no decide si buscar ni dónde. Escribirle «si no sabés, consultá el foro» no tiene efecto:
  la decisión se tomó antes de que él existiera en el turno.
- **B — durante.** Es lo más parecido a *function calling*: se le pide al modelo un JSON
  cerrado y Ruby lo despacha con un `case`. Son llamadas aparte, cortas, con
  `response_format: json_object`, y **no ven la prosa del Entrenamiento** — el clasificador
  de rama solo ve `nombre: descripción` de cada línea `@ruta`. Por eso esas descripciones
  son configuración crítica, no comentarios.
- **C — después.** El único punto donde algo que el modelo *escribe* dispara una acción:
  `{{nombre}}` se convierte en un archivo adjunto real, y la `#etiqueta` sobrevive en el
  mensaje para que las automatizaciones de la cuenta la vean. Con un matiz medido: el modelo
  omitía la etiqueta en 4 de cada 5 respuestas que no resuelven nada, así que
  `with_branch_tag` la repone — pero solo si el modelo no puso ninguna.

---

## 6. Las reglas para que un prompt funcione

### 6.1 Estructura

| # | Regla | Por qué |
|---|---|---|
| 1 | **Toda directiva va dentro de una línea `@ruta`**, nunca en la prosa | `RouteMap.strip` limpia esas líneas; una directiva suelta blanquea el prompt en el camino conversacional (`job:545`) |
| 2 | Las líneas `@ruta` van juntas, al principio, una por renglón | `LINE_RE` es *line-anchored*: exige `@ruta(` al inicio de la línea |
| 3 | Nombre de rama: `[a-z0-9_-]+`, sin espacios ni acentos | el resto del patrón no coincide y la rama se pierde en silencio |
| 4 | La descripción de la rama se escribe **para el clasificador, no para el humano** | es literalmente lo único que ve `BranchClassifierService` |
| 5 | Las secciones de la prosa se nombran con **las mismas palabras** de la descripción | el motor le dice al modelo «RAMA YA DECIDIDA: comercial_info — precios, planes»; con esas palabras empareja la sección |
| 6 | Declará `@ruta_por_defecto` | si el clasificador no reconoce nada y no hay default, el turno se va sin ruteo |

### 6.2 Fuentes

| # | Regla | Por qué |
|---|---|---|
| 7 | **Una fuente por rama.** Sin `@ruta`, solo una directiva del prompt entero se ejecuta | `detect` es una cadena `if/elsif` — gana la primera del catálogo, y `@buscar_predefinidas` está casi al principio |
| 8 | `@buscar_foro` **siempre con paréntesis** y con el nombre exacto del KnowledgeSource | sin paréntesis el patrón no coincide y la directiva es prosa inerte |
| 9 | Usá `@buscar_predefinidas(GRUPO)` cuando dos ramas comparten el corpus | el grupo es un **prefijo del nombre** de la respuesta predefinida, y sube el umbral de 0.20 a 0.45 |
| 10 | El grupo negado `(!GRUPO)` conserva el umbral 0.20 | es el corpus general con un recorte, no un corpus estrecho |
| 11 | Rama sin fuente: guion (`-`, `–`, `—`) | así el turno cae al conversacional a propósito, en vez de buscar donde no debe |
| 12 | `{{doc:}}` y `{{hoja:}}` exigen la feature `google_calendar` en la cuenta | si no está, la directiva no opera y el turno sigue de largo |

### 6.3 Escalamiento y etiquetas

| # | Regla | Por qué |
|---|---|---|
| 13 | El escalamiento se declara por rama con `-> @crear_ticket(...)` | **si alguna rama declara flecha, la directiva global deja de regir** y una rama sin flecha no abre ticket |
| 14 | Con fuente + escalamiento, poné `@crear_ticket(fallback=true)` o la flecha | sin eso, el ticket se evalúa **antes** que la búsqueda y la fuente nunca contesta |
| 15 | Declará la `#etiqueta` en la línea `@ruta` **y** pedila en la prosa | la línea es la red de seguridad; la prosa es lo que hace que el modelo elija bien el grado |
| 16 | En soporte, declará en `@ruta` el **grado más conservador** | la etiqueta de la línea solo se usa cuando el modelo no puso ninguna, y el motor solo conoce la rama |
| 17 | La etiqueta debe ser `#[a-z0-9_]{3,}` | es el patrón que reconoce `with_branch_tag`, y lo que filtran las automatizaciones |

### 6.4 Lo que el modelo puede y no puede

| # | Regla | Por qué |
|---|---|---|
| 18 | No inventes directivas ni «modos» | lo que no está en el catálogo es texto muerto — el caso `@evaluar_evidencia` |
| 19 | No le pidas al modelo que decida la rama | ya se decidió; `branch_scope_rule` le prohíbe reclasificar, y contradecirlo produce respuestas mezcladas |
| 20 | No le pidas que cite fuentes ni links | el pie de fuente y el link 📚 los pone Ruby; los que escribe el modelo se borran (`strip_echoed_sources`) |
| 21 | Pedí respuestas **cortas** | el tope de salida es 250 tokens en el conversacional y 800 en KBase: una respuesta larga se corta a media frase |
| 22 | Escribí la regla de fidelidad a la fuente igual en todas las ramas | la recuperación es por parecido: puede traer un tema vecino, y sin esa regla el modelo lo adapta y suena convincente |
| 23 | `{{nombre}}` (adjuntos) solo en ramas **sin fuente** | el camino KBase envía por `send_reply`, que no resuelve adjuntos: la directiva se vería literal en el chat |

### 6.5 Los números con los que trabaja el motor

| Parámetro | Valor | Dónde |
|---|---|---|
| Umbral de similitud general | 0.20 | `DEFAULTS` — `knowledge_base_response_service.rb:18` |
| Umbral de grupo positivo | 0.45 | `GROUP_SIMILARITY_THRESHOLD` — `:38` |
| Fragmentos recuperados | 3 | `max_results` |
| Tamaño por fragmento / contexto total | 2 000 / 6 000 caracteres | `MAX_ITEM_CHARS` / `max_context_chars` |
| Historial que ve el modelo | 6 turnos (`kb_history`) | `MAX_HISTORY` |
| Contexto reciente para clasificar la rama | 4 mensajes, 600 caracteres | `BranchClassifierService` |
| Tokens de salida | 800 KBase · 600 foro · 250 conversacional · 60 clasificador | `EngineConfig::MAX_TOKENS` |
| Modelo | el del hook `tracking_bot` **del inbox** | `EngineConfig.model_for` |

> El modelo **no se elige en el prompt**: se elige en la integración del inbox. Y está
> medido que `gpt-4o-mini` no cumple prompts con reglas encadenadas; `gpt-4o` sí.

---

## 7. Plantilla de un prompt funcional

Copiar, renombrar ramas y reemplazar las descripciones. Todo lo demás ya está en el contrato.

```text
@ruta(soporte #soporte1: fallas, errores, algo que ya usa y dejó de funcionar, integraciones): @discourse -> @crear_ticket(tipo=Soporte, prioridad=alta)
@ruta(comercial_info #comercial1: precios, planes, licencias, qué incluye, comparativas): @buscar_predefinidas(!GESTION)
@ruta(comercial_gestion #gestion: pide que hagamos un trámite, alta, cambio o baja): @buscar_predefinidas(GESTION) -> @crear_ticket(tipo=Comercial)
@ruta(administrativo #admin: facturas, RFC, datos fiscales, pagos, comprobantes): - -> @crear_ticket(tipo=Administrativo)
@ruta_por_defecto: comercial_info

[ROL]
Sos el coordinador de atención de <EMPRESA>. Atendés por WhatsApp/Telegram a clientes
que ya usan el producto y a interesados. Hablás como una persona del equipo.

[ALCANCE POR RAMA]
SOPORTE — fallas, errores, algo que dejó de funcionar. Explicás el procedimiento con los
nombres de menús y permisos tal como figuran en la documentación. No diagnosticás causas
que la fuente no diga.
COMERCIAL INFORMACIÓN — precios, planes, licencias, qué incluye. Das la cifra o el dato
directo. No pedís datos del cliente para contestar una consulta de información.
COMERCIAL GESTIÓN — pide que hagamos un trámite. Recolectás los datos indispensables,
uno o dos por mensaje, y confirmás lo que quedó registrado.
ADMINISTRATIVO — facturas, RFC, pagos. No tenés fuente: tomás el pedido con sus datos y
avisás que lo pasás al área correspondiente.

[FIDELIDAD]
La información que recibís se recuperó por parecido, así que puede tratar de un tema
vecino. Nunca la adaptes para que encaje. Si no cubre exactamente lo que preguntaron,
decilo, contá qué sí cubre y ofrecé pasarlo con un asesor.

[ETIQUETAS]
Cerrá SIEMPRE el mensaje con una sola etiqueta, en la última línea, aunque el mensaje solo
pida una aclaración o esté reuniendo datos:
#soporte1 consulta resuelta con documentación · #soporte2 requiere revisión de un técnico
#comercial1 información entregada · #gestion trámite en curso · #admin derivado a administración

[ESTILO]
Máximo dos párrafos cortos. Sin listas numeradas salvo que sean pasos. Sin emojis salvo
uno al saludar. No digas que sos un bot, ni que consultaste una base de datos, ni cites
links: el sistema agrega la fuente al pie.

[PROHIBIDO]
Inventar precios, plazos, procedimientos o números de caso. Prometer tiempos de respuesta.
Reclasificar el tema: la rama del turno ya viene decidida.
```

Qué hace cada parte, contra el código:

| Parte | La lee | Efecto real |
|---|---|---|
| Líneas `@ruta` | `RouteMap` + `BranchClassifier` + `Directives` | ramas, fuente por rama, etiqueta, escalamiento |
| `[ROL]`, `[ESTILO]`, `[PROHIBIDO]` | el modelo | tono y límites de redacción |
| `[ALCANCE POR RAMA]` | el modelo, **filtrado** por `branch_scope_rule` | de todas las secciones aplica solo la de la rama del turno |
| `[FIDELIDAD]` | el modelo | contrapesa el riesgo del umbral 0.20 |
| `[ETIQUETAS]` | el modelo, con red en `with_branch_tag` | dispara las automatizaciones de la cuenta |

---

## 8. Checklist antes de guardar el Entrenamiento

- [ ] Cada línea `@ruta` arranca en la primera columna y cierra el paréntesis del nombre.
- [ ] Ninguna directiva (`@buscar_*`, `@discourse`, `{{doc:}}`, `{{hoja:}}`) aparece fuera de una línea `@ruta`.
- [ ] Hay `@ruta_por_defecto` y apunta a una rama declarada.
- [ ] Cada rama con fuente: esa fuente existe, está activa y tiene contenido cargado.
- [ ] `@buscar_foro` lleva paréntesis y el nombre exacto del KnowledgeSource.
- [ ] Si se usan grupos: los nombres de las respuestas predefinidas empiezan con el prefijo, tal cual.
- [ ] Cada rama que deba abrir caso tiene su `-> @crear_ticket(...)`; las que no, no la tienen.
- [ ] Cada rama tiene `#etiqueta` en la línea, y la prosa explica cuándo usar cada una.
- [ ] Las secciones de la prosa usan las palabras de las descripciones de las ramas.
- [ ] El inbox tiene elegido el modelo correcto en la integración `tracking_bot`.

---

## 9. Síntoma → causa

| Lo que se ve | Causa en el código |
|---|---|
| «Contesta con documentación de otro tema» | umbral 0.20 sobre el corpus completo: lo más cercano siempre existe. Separar en grupo → 0.45 |
| «Todo lo contesta con Respuestas predefinidas, hasta soporte» | no hay líneas `@ruta`: gana la precedencia del catálogo y `@buscar_predefinidas` está segunda |
| «El prompt no tiene ningún efecto en las respuestas» | directiva de búsqueda suelta en la prosa → `clean_cp = ''` (`job:545`) |
| «No pone la etiqueta y la automatización no corre» | la rama no declara `#etiqueta` y el modelo la omitió — pasa sobre todo en turnos que no resuelven |
| «El foro nunca contesta» | `@buscar_foro` sin paréntesis, o el nombre del KnowledgeSource no coincide |
| «Abre ticket antes de intentar contestar» | falta `fallback=true` o falta la flecha `->` en esa rama |
| «Una rama abre tickets que no debería» | otra rama declara flecha: con una sola que la declare, la directiva global se ignora por completo |
| «El archivo `{{catalogo}}` sale como texto» | esa rama respondió por KBase, que no resuelve adjuntos |
| «Elige mal la rama» | el clasificador solo ve nombre + descripción + 4 mensajes: descripciones ambiguas o solapadas |
| «Un audio no dispara la base de conocimiento» | KBase exige `message.content` presente; el adjunto solo alimenta al conversacional |
| «Cambié el modelo y sigue igual» | el modelo sale del hook `tracking_bot` del inbox, no del prompt |
| «La respuesta se corta» | tope de 250 tokens en el conversacional |

---

## 10. Cómo verificar sin adivinar

Los logs dicen exactamente qué rama y qué fuente se usaron:

| Línea de log | Qué confirma |
|---|---|
| `[BranchClassifier] 🧭 Rama: comercial_info` | el clasificador reconoció la rama |
| `[BranchClassifier] ⚠️ Sin rama reconocida (...) → por defecto: X` | las descripciones no separan bien |
| `[KBase] 🧭 Rama 'X' → {:mode=>...}` | qué fuente quedó elegida para el turno |
| `[KBase] 🗂️ Grupo exigido: GESTION` | el filtro de grupo entró en la consulta |
| `[KBase] ✅ 3 resultado(s) en canned_response` | hubo recuperación por encima del umbral |
| `[KBase] ⚠️ Sin resultados en ...` | pasó del umbral hacia abajo → seguirá al conversacional |
| `[KBase] 🏷️ Sin etiqueta → se repone la de la rama` | el modelo la omitió y actuó la red |
| `[TrackingBot] 🎫 Ticket via @crear_ticket (outcome: ...)` | el escalamiento se ejecutó |
| `[TrackingBot] 📎 {{x}} no encontrado en Agente IA #N` | el nombre del adjunto no coincide |

---

## 11. Referencias de código

| Archivo | Puntos clave |
|---|---|
| `app/models/message.rb` | `:138` `after_create_commit` → encola el job |
| `app/jobs/contact_tracking_response_analyzer_job.rb` | `:42` `ATTACHMENT_DIRECTIVE` · `:82` flujo por tracking · `:175` cascada de guardias · `:266` `branch_for` · `:459` `kbase_available?` · `:545` blanqueo del prompt · `:1753` resolución de adjuntos |
| `app/services/knowledge_base/directives.rb` | `:29` `CANNED_RE` · `:33` `detect` (precedencia) · `:69` `available?` |
| `app/services/contact_trackings/route_map.rb` | `:28` `LINE_RE` · `:29` `DEFAULT_RE` · `:33` `ARROW_RE` · `:58` `strip` |
| `app/services/contact_trackings/branch_classifier_service.rb` | `:27` `classify` · `:84` prompt del clasificador |
| `app/services/knowledge_base_response_service.rb` | `:38` umbral de grupo · `:167` `detect_directive` · `:244` `grouped_items` · `:386` prompt de redacción · `:618` `agent_system_prompt` · `:649` `branch_scope_rule` · `:740` `with_branch_tag` |
| `app/services/cases/ticket_creator_service.rb` | `:28` `DIRECTIVE_RE` · `:53` `fallback?` |
| `app/services/contact_trackings/engine_config.rb` | modelo por inbox y topes de tokens |
| `docs/agentes_ia_ruteo_por_rama_plan.md` | plan y gramática de `@ruta` |
| `docs/agente_coordinador_kontrolya_analisis.md` | análisis del prompt V1.6 y sus directivas inertes |
