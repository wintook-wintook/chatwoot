# Motor de Agentes IA — Manual del motor y guía de autoría de prompts

**Cómo funciona por dentro, qué directivas existen, cómo se combinan y cómo escribir un
Entrenamiento que el motor ejecute de verdad**

| | |
|---|---|
| **Ámbito** | Motor de Seguimientos · Agentes IA (`tracking_templates`) |
| **Código analizado** | rama `fix/test_agentes_ia` · commit `7a7ff21a` |
| **Entrada del agente** | `tracking_templates.complementary_prompt` — en la UI, **Entrenamiento** |
| **Fecha** | 03/09/2026 |
| **Documento hermano** | `docs/agentes_ia_guia_prompt_funcional.md` — versión corta y operativa |

---

## Índice

| # | Sección | Para qué |
|---|---|---|
| 1 | [El motor en una imagen](#1-el-motor-en-una-imagen) | entender las capas y quién decide qué |
| 2 | [Modelo mental: los dos lectores y los tres momentos](#2-modelo-mental-los-dos-lectores-y-los-tres-momentos) | por qué una instrucción "bonita" no ejecuta nada |
| 3 | [Gramática del Entrenamiento](#3-gramática-del-entrenamiento) | la sintaxis exacta, token por token |
| 4 | [Catálogo de directivas — fichas](#4-catálogo-de-directivas--fichas) | qué hace cada una y qué exige |
| 5 | [Combinatoria: cómo se usan juntas](#5-combinatoria-cómo-se-usan-juntas) | qué convive, qué se anula, en qué orden |
| 6 | [Recuperación semántica en detalle](#6-recuperación-semántica-en-detalle) | umbrales, grupos, por qué trae lo que trae |
| 7 | [Estado entre turnos](#7-estado-entre-turnos) | qué recuerda el motor y dónde lo guarda |
| 8 | [Contrato de autoría: reglas por severidad](#8-contrato-de-autoría-reglas-por-severidad) | qué rompe, qué degrada, qué es cosmético |
| 9 | [Recetas: seis arquetipos de agente](#9-recetas-seis-arquetipos-de-agente) | copiar y adaptar |
| 10 | [Generador de prompts](#10-generador-de-prompts) | el meta-prompt para producir Entrenamientos válidos |
| 11 | [Validación y depuración](#11-validación-y-depuración) | checklist mecánico, logs, síntoma→causa |
| 12 | [Límites conocidos del motor](#12-límites-conocidos-del-motor) | lo que hoy no se puede pedir |
| 13 | [Referencias de código](#13-referencias-de-código) | dónde vive cada cosa |

---

## 1. El motor en una imagen

El motor es una **cascada de guardias** sobre un mensaje entrante. No es un agente que
razona en bucle ni que elige herramientas: es Ruby decidiendo, en un orden fijo, quién
atiende el turno; el modelo entra solo a **clasificar** (JSON corto) y a **redactar**.

<svg viewBox="0 0 880 606" width="100%" style="max-width:880px;height:auto" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Arquitectura por capas del motor de Agentes IA: entrada, orquestación, decisión de rama y fuente, fuentes de datos, composición y salida">
  <defs>
    <marker id="m1" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
      <path d="M 0 0 L 10 5 L 0 10 z" fill="#94a3b8"/>
    </marker>
  </defs>
  <circle cx="42" cy="58" r="14" fill="#e2e8f0"/><text font-family="ui-sans-serif, system-ui, sans-serif" font-size="11" font-weight="700" fill="#475569" x="42" y="62" text-anchor="middle">L0</text>
  <circle cx="42" cy="150" r="14" fill="#e2e8f0"/><text font-family="ui-sans-serif, system-ui, sans-serif" font-size="11" font-weight="700" fill="#475569" x="42" y="154" text-anchor="middle">L1</text>
  <circle cx="42" cy="244" r="14" fill="#e2e8f0"/><text font-family="ui-sans-serif, system-ui, sans-serif" font-size="11" font-weight="700" fill="#475569" x="42" y="248" text-anchor="middle">L2</text>
  <circle cx="42" cy="348" r="14" fill="#e2e8f0"/><text font-family="ui-sans-serif, system-ui, sans-serif" font-size="11" font-weight="700" fill="#475569" x="42" y="352" text-anchor="middle">L3</text>
  <circle cx="42" cy="458" r="14" fill="#e2e8f0"/><text font-family="ui-sans-serif, system-ui, sans-serif" font-size="11" font-weight="700" fill="#475569" x="42" y="462" text-anchor="middle">L4</text>
  <circle cx="42" cy="552" r="14" fill="#e2e8f0"/><text font-family="ui-sans-serif, system-ui, sans-serif" font-size="11" font-weight="700" fill="#475569" x="42" y="556" text-anchor="middle">L5</text>
  <rect x="76" y="28" width="784" height="60" rx="10" fill="#eef2ff" stroke="#6366f1" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="12.5" font-weight="700" fill="#0f172a" x="96" y="50">ENTRADA</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10.5" fill="#475569" x="96" y="68">Mensaje entrante → after_create_commit → ContactTrackingResponseAnalyzerJob</text>
  <text font-family="ui-monospace, Menlo, monospace" font-size="9.5" fill="#64748b" x="96" y="82">message.rb:138 · job:47 — gates: ¿entrante? ¿con contenido? ¿el bot no contestó ya?</text>
  <line x1="468" y1="88" x2="468" y2="106" stroke="#94a3b8" stroke-width="1.5" marker-end="url(#m1)"/>
  <rect x="76" y="108" width="784" height="80" rx="10" fill="#ffffff" stroke="#94a3b8" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="12.5" font-weight="700" fill="#0f172a" x="96" y="130">ORQUESTACIÓN — sin IA, gana quien coincida primero</text>
  <rect x="96" y="140" width="230" height="36" rx="7" fill="#f8fafc" stroke="#e2e8f0"/>
  <text font-family="ui-monospace, Menlo, monospace" font-size="10" fill="#0f172a" x="108" y="156">keyword_actions</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#64748b" x="108" y="169">cancel · pause · objective_met</text>
  <rect x="336" y="140" width="230" height="36" rx="7" fill="#f8fafc" stroke="#e2e8f0"/>
  <text font-family="ui-monospace, Menlo, monospace" font-size="10" fill="#0f172a" x="348" y="156">[PENDING_SLOT] · [PENDING_EMAIL]</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#64748b" x="348" y="169">cita a medio confirmar</text>
  <rect x="576" y="140" width="264" height="36" rx="7" fill="#fffbeb" stroke="#fcd34d"/>
  <text font-family="ui-monospace, Menlo, monospace" font-size="10" fill="#0f172a" x="588" y="156">RouterService</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#64748b" x="588" y="169">apagado hoy (TRACKING_DETECT_INTENT=false)</text>
  <line x1="468" y1="188" x2="468" y2="206" stroke="#94a3b8" stroke-width="1.5" marker-end="url(#m1)"/>
  <rect x="76" y="208" width="784" height="80" rx="10" fill="#ffffff" stroke="#6366f1" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="12.5" font-weight="700" fill="#0f172a" x="96" y="230">DECISIÓN DE RAMA Y FUENTE — lee el Entrenamiento</text>
  <rect x="96" y="240" width="230" height="36" rx="7" fill="#eef2ff" stroke="#c7d2fe"/>
  <text font-family="ui-monospace, Menlo, monospace" font-size="10" fill="#0f172a" x="108" y="256">RouteMap.parse</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#64748b" x="108" y="269">ramas · #etiqueta · fuente · escalamiento</text>
  <rect x="336" y="240" width="230" height="36" rx="7" fill="#eef2ff" stroke="#c7d2fe"/>
  <text font-family="ui-monospace, Menlo, monospace" font-size="10" fill="#0f172a" x="348" y="256">BranchClassifier · LLM</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#64748b" x="348" y="269">1 llamada · JSON {&quot;rama&quot;}</text>
  <rect x="576" y="240" width="264" height="36" rx="7" fill="#ecfdf5" stroke="#bbf7d0"/>
  <text font-family="ui-monospace, Menlo, monospace" font-size="10" fill="#0f172a" x="588" y="256">Directives.detect</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#64748b" x="588" y="269">devuelve UNA fuente para el turno</text>
  <line x1="468" y1="288" x2="468" y2="306" stroke="#94a3b8" stroke-width="1.5" marker-end="url(#m1)"/>
  <rect x="76" y="308" width="784" height="98" rx="10" fill="#ffffff" stroke="#22c55e" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="12.5" font-weight="700" fill="#0f172a" x="96" y="330">FUENTES — Ruby ejecuta la recuperación ANTES de llamar al modelo</text>
  <rect x="96" y="340" width="176" height="26" rx="6" fill="#f8fafc" stroke="#e2e8f0"/><text font-family="ui-monospace, Menlo, monospace" font-size="9.5" fill="#0f172a" x="106" y="357">{{consulta:}} → ERP (SQL)</text>
  <rect x="282" y="340" width="176" height="26" rx="6" fill="#ecfdf5" stroke="#bbf7d0"/><text font-family="ui-monospace, Menlo, monospace" font-size="9.5" fill="#0f172a" x="292" y="357">@buscar_predefinidas</text>
  <rect x="468" y="340" width="176" height="26" rx="6" fill="#f8fafc" stroke="#e2e8f0"/><text font-family="ui-monospace, Menlo, monospace" font-size="9.5" fill="#0f172a" x="478" y="357">@buscar_articulo</text>
  <rect x="654" y="340" width="186" height="26" rx="6" fill="#f8fafc" stroke="#e2e8f0"/><text font-family="ui-monospace, Menlo, monospace" font-size="9.5" fill="#0f172a" x="664" y="357">@buscar_foro(nombre)</text>
  <rect x="96" y="372" width="176" height="26" rx="6" fill="#f8fafc" stroke="#e2e8f0"/><text font-family="ui-monospace, Menlo, monospace" font-size="9.5" fill="#0f172a" x="106" y="389">{{doc:nombre}}</text>
  <rect x="282" y="372" width="176" height="26" rx="6" fill="#f8fafc" stroke="#e2e8f0"/><text font-family="ui-monospace, Menlo, monospace" font-size="9.5" fill="#0f172a" x="292" y="389">{{hoja:nombre}}</text>
  <rect x="468" y="372" width="176" height="26" rx="6" fill="#f8fafc" stroke="#e2e8f0"/><text font-family="ui-monospace, Menlo, monospace" font-size="9.5" fill="#0f172a" x="478" y="389">@discourse (hook)</text>
  <rect x="654" y="372" width="186" height="26" rx="6" fill="#fef2f2" stroke="#fecaca"/><text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#b91c1c" x="664" y="389">sin resultados → sigue la cascada</text>
  <line x1="468" y1="406" x2="468" y2="424" stroke="#94a3b8" stroke-width="1.5" marker-end="url(#m1)"/>
  <rect x="76" y="426" width="784" height="80" rx="10" fill="#ffffff" stroke="#f59e0b" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="12.5" font-weight="700" fill="#0f172a" x="96" y="448">COMPOSICIÓN — aquí, y solo aquí, manda la prosa del Entrenamiento</text>
  <rect x="96" y="458" width="176" height="36" rx="7" fill="#fffbeb" stroke="#fde68a"/><text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#0f172a" x="106" y="474">prosa sin líneas @ruta</text><text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#64748b" x="106" y="487">ni directivas sueltas</text>
  <rect x="282" y="458" width="176" height="36" rx="7" fill="#fffbeb" stroke="#fde68a"/><text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#0f172a" x="292" y="474">objetivo del seguimiento</text><text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#64748b" x="292" y="487">+ perfil del contacto</text>
  <rect x="468" y="458" width="176" height="36" rx="7" fill="#fffbeb" stroke="#fde68a"/><text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#0f172a" x="478" y="474">RAMA YA DECIDIDA</text><text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#64748b" x="478" y="487">prohíbe reclasificar</text>
  <rect x="654" y="458" width="186" height="36" rx="7" fill="#fffbeb" stroke="#fde68a"/><text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#0f172a" x="664" y="474">contexto recuperado + kb_history</text><text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#64748b" x="664" y="487">3 fragmentos · 6 turnos</text>
  <line x1="468" y1="506" x2="468" y2="524" stroke="#94a3b8" stroke-width="1.5" marker-end="url(#m1)"/>
  <rect x="76" y="526" width="784" height="60" rx="10" fill="#ecfdf5" stroke="#22c55e" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="12.5" font-weight="700" fill="#0f172a" x="96" y="548">SALIDA — Ruby retoca lo que escribió el modelo</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10.5" fill="#475569" x="96" y="566">#etiqueta repuesta si falta · firma de la fuente al pie · {{nombre}} → archivo adjunto · links propios borrados</text>
  <text font-family="ui-monospace, Menlo, monospace" font-size="9.5" fill="#64748b" x="96" y="580">MessageBuilder → content_attributes.sentiment_auto_reply = true</text>
</svg>

**Cómo leerlo.** De arriba abajo hay **seis capas** y el Entrenamiento se consume en dos de
ellas: en **L2** como configuración parseable (líneas `@ruta` y directivas) y en **L4** como
prosa para el modelo. En L3 el modelo no participa: la búsqueda ya ocurrió cuando le toca
hablar. En L5 pasa lo contrario: hay acciones que dispara el texto que él escribió.

---

## 2. Modelo mental: los dos lectores y los tres momentos

### 2.1 Dos lectores

| | Ruby (parser) | El modelo (OpenAI) |
|---|---|---|
| **Qué lee** | patrones exactos: `@ruta(...)`, `@buscar_*`, `{{...}}`, `@crear_ticket(...)` | la prosa, ya limpia de esos patrones |
| **Qué hace** | ejecuta: SQL, pgvector, HTTP a Discourse, alta de ticket, adjuntar archivo | clasifica (JSON) y redacta (texto) |
| **Qué ignora** | toda la prosa | todo lo que sea configuración |
| **Si te equivocás** | la directiva **deja de existir**, sin error ni log | el modelo improvisa con lo que le quedó |

### 2.2 Tres momentos de ejecución

<svg viewBox="0 0 880 384" width="100%" style="max-width:880px;height:auto" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Los tres momentos en que el motor ejecuta algo: antes de llamar al modelo, durante mediante JSON, y después sobre el texto que el modelo escribió">
  <defs>
    <marker id="m2" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
      <path d="M 0 0 L 10 5 L 0 10 z" fill="#94a3b8"/>
    </marker>
  </defs>
  <line x1="40" y1="52" x2="840" y2="52" stroke="#cbd5e1" stroke-width="2"/>
  <circle cx="160" cy="52" r="7" fill="#6366f1"/><circle cx="450" cy="52" r="7" fill="#22c55e"/><circle cx="730" cy="52" r="7" fill="#f59e0b"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10" fill="#94a3b8" x="40" y="40">turno entra</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10" fill="#94a3b8" x="800" y="40">se envía</text>
  <rect x="30" y="72" width="260" height="230" rx="10" fill="#ffffff" stroke="#6366f1" stroke-width="1.5"/>
  <rect x="30" y="72" width="260" height="30" rx="10" fill="#eef2ff" stroke="#6366f1" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="11.5" font-weight="700" fill="#0f172a" x="160" y="92" text-anchor="middle">A · ANTES del modelo</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10.5" fill="#475569" x="46" y="124">Ruby lee la directiva del prompt</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10.5" fill="#475569" x="46" y="139">y ejecuta la recuperación.</text>
  <text font-family="ui-monospace, Menlo, monospace" font-size="9.5" fill="#0f172a" x="46" y="162">{{consulta:saldo(rfc=X)}} → SQL</text>
  <text font-family="ui-monospace, Menlo, monospace" font-size="9.5" fill="#0f172a" x="46" y="178">@buscar_predefinidas(G) → pgvector</text>
  <text font-family="ui-monospace, Menlo, monospace" font-size="9.5" fill="#0f172a" x="46" y="194">@buscar_foro(Foro) → Discourse</text>
  <text font-family="ui-monospace, Menlo, monospace" font-size="9.5" fill="#0f172a" x="46" y="210">{{hoja:Precios}} → Sheets</text>
  <rect x="46" y="224" width="228" height="62" rx="7" fill="#f8fafc" stroke="#cbd5e1"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10" font-weight="700" fill="#334155" x="58" y="242">Al escribir el prompt</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#64748b" x="58" y="258">El modelo no elige si buscar.</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#64748b" x="58" y="272">«Si no sabés, consultá el foro»</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#64748b" x="58" y="286">no ejecuta nada.</text>
  <rect x="310" y="72" width="260" height="230" rx="10" fill="#ffffff" stroke="#22c55e" stroke-width="1.5"/>
  <rect x="310" y="72" width="260" height="30" rx="10" fill="#ecfdf5" stroke="#22c55e" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="11.5" font-weight="700" fill="#0f172a" x="440" y="92" text-anchor="middle">B · DURANTE — JSON → despacho</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10.5" fill="#475569" x="326" y="124">Llamadas cortas y aparte, con</text>
  <text font-family="ui-monospace, Menlo, monospace" font-size="9.5" fill="#475569" x="326" y="138">response_format: json_object</text>
  <text font-family="ui-monospace, Menlo, monospace" font-size="9.5" fill="#0f172a" x="326" y="162">{&quot;rama&quot;: &quot;soporte&quot;}</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#64748b" x="326" y="175">BranchClassifier → elige la fuente</text>
  <text font-family="ui-monospace, Menlo, monospace" font-size="9.5" fill="#0f172a" x="326" y="196">{&quot;intent&quot;,&quot;appointment_action&quot;,…}</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#64748b" x="326" y="209">RouterService → agenda / cancela</text>
  <text font-family="ui-monospace, Menlo, monospace" font-size="9.5" fill="#0f172a" x="326" y="230">{op, column, filters}</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#64748b" x="326" y="243">SheetQuery → Ruby calcula exacto</text>
  <rect x="326" y="252" width="228" height="36" rx="7" fill="#f8fafc" stroke="#cbd5e1"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#64748b" x="338" y="268">Estos clasificadores NO ven tu prosa:</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#64748b" x="338" y="282">ven las descripciones de @ruta.</text>
  <rect x="590" y="72" width="260" height="230" rx="10" fill="#ffffff" stroke="#f59e0b" stroke-width="1.5"/>
  <rect x="590" y="72" width="260" height="30" rx="10" fill="#fffbeb" stroke="#f59e0b" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="11.5" font-weight="700" fill="#0f172a" x="720" y="92" text-anchor="middle">C · DESPUÉS — sobre su texto</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10.5" fill="#475569" x="606" y="124">Lo único que el modelo ejecuta</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10.5" fill="#475569" x="606" y="139">es lo que escribe en su respuesta.</text>
  <text font-family="ui-monospace, Menlo, monospace" font-size="9.5" fill="#0f172a" x="606" y="162">{{catalogo}}</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#64748b" x="606" y="175">→ se borra del texto y se adjunta</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#64748b" x="606" y="188">el archivo real (máx. 5)</text>
  <text font-family="ui-monospace, Menlo, monospace" font-size="9.5" fill="#0f172a" x="606" y="210">#gestion</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#64748b" x="606" y="223">→ queda en el mensaje y dispara</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#64748b" x="606" y="236">las automatizaciones de la cuenta</text>
  <rect x="606" y="248" width="228" height="40" rx="7" fill="#fef2f2" stroke="#fecaca"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#b91c1c" x="618" y="264">{{nombre}} NO se resuelve en el</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#b91c1c" x="618" y="278">camino KBase: solo conversacional.</text>
  <rect x="30" y="318" width="820" height="52" rx="10" fill="#f8fafc" stroke="#cbd5e1" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="11" font-weight="700" fill="#0f172a" x="48" y="340">No hay tool calling nativo de OpenAI en ningún punto</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10.5" fill="#64748b" x="48" y="360">El contrato es texto y JSON, y nadie valida un esquema. Una directiva mal escrita no produce error: simplemente no existe.</text>
</svg>

**Cómo leerlo.** La línea de arriba es un turno. En **A** el motor ya trabajó antes de que
el modelo abriera la boca. En **B** el modelo actúa como clasificador con salida cerrada, y
Ruby despacha con un `case`. En **C** el modelo escribe algo que Ruby interpreta y ejecuta
al enviar. Cualquier instrucción del prompt que no caiga en A, B o C **solo cambia la
redacción**.

---

## 3. Gramática del Entrenamiento

### 3.1 Estructura del archivo

```
┌─ ZONA 1 · líneas @ruta ────────── parseable, nunca llega al modelo
│  @ruta(...)  ...  @ruta_por_defecto: ...
├─ ZONA 2 · prosa ───────────────── lo único que el modelo lee
│  [ROL] [ALCANCE POR RAMA] [FIDELIDAD] [ETIQUETAS] [ESTILO] [PROHIBIDO]
└─ ZONA 3 · directivas sueltas ──── ⚠ evitar: blanquean el prompt (job:545)
```

### 3.2 La línea `@ruta` token por token

<svg viewBox="0 0 880 330" width="100%" style="max-width:880px;height:auto" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Diagrama de sintaxis de una línea @ruta con cada token señalado: nombre de rama, etiqueta, descripción, fuente, flecha y escalamiento">
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="12" font-weight="700" fill="#0f172a" x="14" y="28">Anatomía de una línea @ruta</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10.5" fill="#64748b" x="14" y="46">RouteMap::LINE_RE — anclada al inicio de la línea; todo lo que no calce queda como prosa</text>
  <rect x="8" y="62" width="864" height="40" rx="8" fill="#f8fafc" stroke="#cbd5e1"/>
  <text font-family="ui-monospace, Menlo, monospace" font-size="12" fill="#0f172a" x="14" y="88">@ruta(comercial_gestion #gestion: pide un trámite): @buscar_predefinidas(GESTION) -&gt; @crear_ticket(tipo=Comercial)</text>
  <path d="M57,104 L57,112 L172,112 L172,104" fill="none" stroke="#6366f1" stroke-width="1.5"/>
  <path d="M115,112 L115,132" stroke="#6366f1" stroke-width="1.5"/>
  <path d="M187,104 L187,120 L238,120 L238,104" fill="none" stroke="#0ea5e9" stroke-width="1.5"/>
  <path d="M212,120 L212,182" stroke="#0ea5e9" stroke-width="1.5"/>
  <path d="M259,104 L259,126 L360,126 L360,104" fill="none" stroke="#8b5cf6" stroke-width="1.5"/>
  <path d="M310,126 L310,232" stroke="#8b5cf6" stroke-width="1.5"/>
  <path d="M388,104 L388,112 L590,112 L590,104" fill="none" stroke="#22c55e" stroke-width="1.5"/>
  <path d="M489,112 L489,132" stroke="#22c55e" stroke-width="1.5"/>
  <path d="M604,104 L604,120 L616,120 L616,104" fill="none" stroke="#f59e0b" stroke-width="1.5"/>
  <path d="M610,120 L610,182" stroke="#f59e0b" stroke-width="1.5"/>
  <path d="M626,104 L626,126 L828,126 L828,104" fill="none" stroke="#ef4444" stroke-width="1.5"/>
  <path d="M727,126 L727,232" stroke="#ef4444" stroke-width="1.5"/>
  <rect x="40" y="134" width="180" height="44" rx="7" fill="#eef2ff" stroke="#6366f1"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10" font-weight="700" fill="#0f172a" x="52" y="150">nombre de rama</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#475569" x="52" y="163">[a-z0-9_-]+ · sin espacios</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#475569" x="52" y="174">lo referencia @ruta_por_defecto</text>
  <rect x="399" y="134" width="180" height="44" rx="7" fill="#ecfdf5" stroke="#22c55e"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10" font-weight="700" fill="#0f172a" x="411" y="150">fuente de la rama</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#475569" x="411" y="163">una sola · del catálogo §4</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#475569" x="411" y="174">«-» = rama sin fuente</text>
  <rect x="122" y="184" width="180" height="44" rx="7" fill="#f0f9ff" stroke="#0ea5e9"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10" font-weight="700" fill="#0f172a" x="134" y="200">#etiqueta (opcional)</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#475569" x="134" y="213">se repone solo si el modelo</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#475569" x="134" y="224">no puso ninguna</text>
  <rect x="520" y="184" width="180" height="44" rx="7" fill="#fffbeb" stroke="#f59e0b"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10" font-weight="700" fill="#0f172a" x="532" y="200">separador de escalamiento</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#475569" x="532" y="213">admite -&gt; =&gt; →</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#475569" x="532" y="224">todo lo de la derecha es opcional</text>
  <rect x="220" y="234" width="180" height="52" rx="7" fill="#f5f3ff" stroke="#8b5cf6"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10" font-weight="700" fill="#0f172a" x="232" y="250">descripción</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#475569" x="232" y="263">lo ÚNICO que ve el clasificador</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#475569" x="232" y="274">para elegir esta rama; también</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#475569" x="232" y="285">se le nombra al redactor</text>
  <rect x="637" y="234" width="180" height="52" rx="7" fill="#fef2f2" stroke="#ef4444"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10" font-weight="700" fill="#0f172a" x="649" y="250">escalamiento de la rama</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#475569" x="649" y="263">se ejecuta si la fuente no</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#475569" x="649" y="274">resolvió el turno. Si UNA rama</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#475569" x="649" y="285">lo declara, la global se ignora</text>
  <rect x="8" y="296" width="864" height="26" rx="7" fill="#f8fafc" stroke="#e2e8f0"/>
  <text font-family="ui-monospace, Menlo, monospace" font-size="9.5" fill="#64748b" x="20" y="313">@ruta_por_defecto: comercial_gestion   ← rama usada cuando el clasificador no reconoce ninguna</text>
</svg>

### 3.3 Gramática formal

```ebnf
entrenamiento = { linea_ruta } , [ linea_default ] , prosa ;

linea_ruta    = "@ruta(" , nombre , [ " #" , etiqueta ] ,
                [ ":" , descripcion ] , ")" , ":" , cuerpo ;
nombre        = ( letra | digito | "_" | "-" )+ ;          (* sin espacios ni acentos *)
etiqueta      = ( letra_min | digito | "_" )+ ;             (* se emite como #etiqueta *)
descripcion   = ? texto libre hasta el ")" ? ;              (* lo lee el clasificador *)
cuerpo        = fuente , [ flecha , escalamiento ] ;
fuente        = directiva_de_fuente | "-" | "–" | "—" | "" ;
flecha        = "->" | "=>" | "→" ;
escalamiento  = "@crear_ticket" , [ "(" , parametros , ")" ] ;

linea_default = "@ruta_por_defecto:" , nombre ;
```

**Condiciones que impone el parser:**

| Condición | Consecuencia si no se cumple |
|---|---|
| `@ruta(` empieza la línea (solo espacios/tabs antes) | la línea es prosa: la rama no existe |
| El paréntesis del nombre se cierra antes del `):` | no coincide `LINE_RE` |
| Nombres de rama únicos | se conserva la **primera**, las repetidas se descartan (`uniq(&:name)`) |
| `@ruta_por_defecto` apunta a una rama declarada | queda sin default: un turno no clasificado se va sin ruteo |
| Al menos una línea `@ruta` | sin ellas el motor usa el modo clásico: precedencia global del catálogo |

---

## 4. Catálogo de directivas — fichas

Cada ficha lista lo que hace falta para que la directiva **exista** en tiempo de ejecución.

### 4.1 Fuentes de información (una por rama)

#### `{{consulta:nombre}}` — ERP determinista

| | |
|---|---|
| **Formas** | `{{consulta:saldo}}` · `{{consulta:saldo(rfc=ABC)}}` · `{{consulta:saldo(30)}}` · `{{consulta:sae/saldo(rfc=ABC, dias=30)}}` |
| **Qué hace** | ejecuta una consulta predefinida (allowlist) contra la BD del ERP y **sustituye la directiva por el resultado**, en el mismo texto |
| **IA** | ninguna: el texto sale interpolado tal cual |
| **Requiere** | `ExternalDbConnection` activa + `external_db_queries` activa con ese nombre; sin prefijo usa la conexión del `ErpCollectionBot` del inbox |
| **Extras** | el parámetro `rfc` se autocompleta desde `contact.custom_attributes['erp_rfc']` |
| **Precedencia** | **primera de todas**: si el prompt tiene `{{consulta:}}`, ninguna otra fuente corre |
| **Alcance** | interpola y envía **todo el `complementary_prompt`**, no solo la línea de la directiva: el prompt es el mensaje (§9.4) |
| **Falla** | fail-soft: una directiva inválida se reemplaza por vacío; si todo queda vacío, no se envía nada |

#### `@buscar_predefinidas[(GRUPO)]` — Respuestas predefinidas (pgvector)

| | |
|---|---|
| **Formas** | `@buscar_predefinidas` · `@buscar_predefinidas(GESTION)` · `@buscar_predefinidas(!GESTION)` |
| **Qué hace** | busca por similitud sobre las Respuestas Predefinidas de la cuenta y redacta con los 3 mejores fragmentos |
| **Grupo** | prefijo del **short_code** de la respuesta (`title ILIKE 'GESTION%'`); `!` invierte el filtro |
| **Umbral** | 0.20 general · **0.45** con grupo positivo · 0.20 con grupo negado |
| **Requiere** | al menos un `knowledge_item` con `source_type = 'canned_response'` |
| **Firma** | agrega al pie el nombre de la fuente (`_Respuestas predefinidas_`) |

#### `@buscar_articulo` — Centro de Ayuda (pgvector)

| | |
|---|---|
| **Forma** | `@buscar_articulo` (acepta `@buscar_artículo`) |
| **Qué hace** | idéntico al anterior sobre `source_type = 'article'` |
| **Requiere** | artículos vectorizados; los tickets que se publican como artículo entran acá |
| **Sin grupos** | el filtro por grupo hoy solo se aplica a predefinidas |

#### `@buscar_foro(nombre)` — Discourse por KnowledgeSource

| | |
|---|---|
| **Forma** | `@buscar_foro(Foro Kontrolya)` — **los paréntesis son obligatorios** |
| **Qué hace** | *semantic search* de Discourse AI, baja el `raw` de cada post (máx. 3, 2 000 caracteres c/u) y redacta |
| **Requiere** | `KnowledgeSource` activa con ese nombre exacto (`source_type: discourse`) y `url` + `api_key` en su config |
| **Firma** | agrega `📚 Más información: <url>` eligiendo el post con más palabras en común con la pregunta |
| **Ojo** | mencionarla en prosa sin paréntesis no la activa |

#### `@discourse` — Discourse por integración del inbox

| | |
|---|---|
| **Forma** | `@discourse` |
| **Diferencia** | usa el hook `discourse` **del inbox**, no un KnowledgeSource |
| **Requiere** | hook `discourse` habilitado para ese inbox |
| **Cuándo** | cuando el foro se configura por bandeja y no por fuente nombrada |

#### `@soporte_contpaq(nombre)` — Agente de Servicio CONTPAQi (API remota)

| | |
|---|---|
| **Forma** | `@soporte_contpaq(Agente de Servicio CONTPAQi)` — **los paréntesis son obligatorios** |
| **Qué hace** | manda la pregunta a la API de CONTPAQi, que busca en la documentación oficial del fabricante **y redacta la respuesta** |
| **Requiere** | `KnowledgeSource` activa con ese nombre exacto (`source_type: contpaq_support`) y `base_url` + `token_url` + `client_id` + `client_secret` + `scope` en su config |
| **Firma** | agrega `📚 Más información: <url>` con la primera fuente que traiga URL pública |
| **Ojo** | **es la única fuente que no pasa por nuestro modelo.** El `complementary_prompt` del agente —tono, regla de evidencia, no diagnosticar— **no se aplica** en esta rama |

Es la diferencia estructural del catálogo. Todas las demás devuelven *contexto* y el
modelo redacta con las reglas del agente; esta devuelve la **respuesta ya escrita**.
Pasarla por el modelo sería pedirle que reescriba algo ya fiel a la documentación del
fabricante, así que no se hace.

Tres consecuencias de autoría:

- **El tono no se controla desde el Entrenamiento.** Si la respuesta tiene que sonar como
  el resto del agente, esta fuente no es la indicada.
- **No hace falta darle historial.** La memoria del hilo la lleva CONTPAQi: basta con que
  el turno tenga conversación, y el seguimiento («¿y cómo lo cancelo?») lo resuelve solo.
- **Hay tres respuestas que llegan sin fuente y no son error:** cuando pide que se
  especifique de qué producto CONTPAQi se habla, cuando la pregunta está fuera de su
  alcance, y cuando es un saludo. En las tres se entrega el texto sin el enlace.

#### `{{doc:nombre}}` — Google Doc (pgvector)

| | |
|---|---|
| **Forma** | `{{doc:Manual de instalación}}` |
| **Requiere** | feature `google_calendar` en la cuenta + `KnowledgeSource` activa `google_doc` con ese nombre |
| **Alcance** | filtra por `knowledge_source_id`: apunta a **un** documento concreto |

#### `{{hoja:nombre}}` — Google Sheet (dos modos)

| | |
|---|---|
| **Forma** | `{{hoja:Precios 2026}}` |
| **Modo FAQ** | igual que un Doc: pgvector sobre las filas vectorizadas |
| **Modo Datos** | `config['sheet_mode'] == 'data'`: el LLM traduce la pregunta a `{op, column, filters}` y **Ruby calcula** (`sum`, `avg`, `min`, `max`, `count`, `filter`, `list`) |
| **Por qué importa** | en modo Datos los números no se alucinan: el modelo solo redacta el resultado exacto |
| **Modo vivo** | con `config['live']` refresca la foto local cuando la hoja cambió (TTL 60 s por defecto) |

### 4.2 Acciones

#### `@crear_ticket[(parámetros)]`

| | |
|---|---|
| **Formas** | `@crear_ticket` · `@crear_ticket(tipo=Soporte)` · `@crear_ticket(prioridad=alta, tipo=Soporte)` · `@crear_ticket(fallback=true)` |
| **Qué hace** | intake con IA: lee la conversación, arma título, descripción y clasificación, y crea el caso |
| **Anti-duplicado** | si el contacto ya tiene un caso abierto, lo **reusa** y avisa |
| **Gate** | si la conversación no amerita ticket (saludo, charla), no crea nada |
| **Fase de datos** | si faltan campos obligatorios del tipo, los **pide una vez** (máx. 2 turnos) antes de crear |
| **Prioridad** | `prioridad=` gana sobre el score de riesgo, que gana sobre la matriz impacto/urgencia. Alias: baja, media, normal, alta, urgente, crítica |
| **Riesgo** | sube un nivel si el intake detecta churn o si el contacto abrió ≥2 casos en 14 días |
| **`fallback=true`** | mueve el alta **después** de la búsqueda: la fuente contesta primero |
| **Por rama** | como escalamiento (`-> @crear_ticket(...)`) cada rama abre su propio tipo |

#### `@estado_ticket`

| | |
|---|---|
| **Forma** | `@estado_ticket` (coincidencia literal en el prompt) |
| **Dispara si** | el mensaje tiene **un sustantivo de caso** (ticket, folio, reporte, caso…) **y** una señal de consulta (cuál, cómo, estado, mi, avance…) |
| **Qué hace** | responde con hasta 3 casos del contacto, con estado en lenguaje de cliente |
| **Posición** | antes de `@crear_ticket`: preguntar por un caso nunca abre uno nuevo |

#### `@agendar_calendar`

| | |
|---|---|
| **Forma** | `@agendar_calendar` |
| **Requiere** | `calendar_integration_ids` en el Agente IA o en el seguimiento |
| **Qué hace** | clasifica la intención de cita (`query`, `book_new`, `move`, `cancel`) viendo el **estado real** de la cita, ofrece horarios, negocia, pide correo y crea el evento |
| **No es ansioso** | si el cliente no habla de una cita, la acción es `null` y el turno sigue |
| **Zona horaria** | la real de Google Calendar (cacheada 12 h) → la del Agente IA → la del inbox |

#### `{{nombre}}` — adjuntar un archivo

| | |
|---|---|
| **Forma** | el **modelo** escribe `{{catalogo}}` dentro de su respuesta |
| **Qué hace** | se borra del texto y se adjunta el archivo del Agente IA con ese nombre (máx. 5 por mensaje) |
| **Requiere** | archivo cargado en la pestaña Archivos del Agente IA, nombre exacto (sin acentos ni espacios) |
| **Limitación** | solo se resuelve en el camino conversacional; en KBase la llave saldría literal |
| **Cómo activarla** | el motor agrega solo la instrucción de uso si detecta `{{...}}` en el prompt visible |

### 4.3 Fuera del prompt (pero mandan igual)

| Elemento | Dónde se configura | Efecto |
|---|---|---|
| **Objetivo** | campo Objetivo del Agente IA | va al system prompt en los dos caminos |
| **Contexto IA** | `ai_context` | se inyecta en el conversacional (800 caracteres) |
| **Palabras clave** | `keyword_actions` | `cancel` · `pause` · `objective_met`, sin IA y sin responder |
| **Modelo** | hook `tracking_bot` del inbox | `gpt-4o-mini` (default), `gpt-4o`, `gpt-4-turbo`, `gpt-3.5-turbo` |
| **Presentación de horarios** | `slots_presentation` | detailed · simple · by_agent · by_calendar · by_day |

---

## 5. Combinatoria: cómo se usan juntas

### 5.1 La regla que lo explica todo

> **Las fuentes compiten; las acciones se apilan.**
> Solo una fuente corre por turno. En cambio una fuente, un escalamiento, una etiqueta y un
> adjunto conviven sin problema, porque actúan en momentos distintos (§2.2).

<svg viewBox="0 0 880 420" width="100%" style="max-width:880px;height:auto" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Tres formas de combinar directivas: sin rutas solo gana una fuente, con rutas cada rama tiene la suya, y las acciones se apilan en el mismo turno">
  <rect x="20" y="30" width="270" height="290" rx="10" fill="#ffffff" stroke="#ef4444" stroke-width="1.5"/>
  <rect x="20" y="30" width="270" height="30" rx="10" fill="#fef2f2" stroke="#ef4444" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="11.5" font-weight="700" fill="#0f172a" x="155" y="50" text-anchor="middle">Sin @ruta — compiten</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10" fill="#64748b" x="36" y="80">5 fuentes en el prompt, 1 se ejecuta:</text>
  <rect x="36" y="90" width="238" height="26" rx="6" fill="#ecfdf5" stroke="#22c55e"/>
  <text font-family="ui-monospace, Menlo, monospace" font-size="10" fill="#0f172a" x="48" y="107">@buscar_predefinidas ✓ gana</text>
  <rect x="36" y="122" width="238" height="24" rx="6" fill="#f8fafc" stroke="#e2e8f0"/>
  <text font-family="ui-monospace, Menlo, monospace" font-size="10" fill="#94a3b8" x="48" y="138">@buscar_articulo</text>
  <rect x="36" y="152" width="238" height="24" rx="6" fill="#f8fafc" stroke="#e2e8f0"/>
  <text font-family="ui-monospace, Menlo, monospace" font-size="10" fill="#94a3b8" x="48" y="168">@buscar_foro(Foro)</text>
  <rect x="36" y="182" width="238" height="24" rx="6" fill="#f8fafc" stroke="#e2e8f0"/>
  <text font-family="ui-monospace, Menlo, monospace" font-size="10" fill="#94a3b8" x="48" y="198">{{hoja:Precios}}</text>
  <rect x="36" y="212" width="238" height="24" rx="6" fill="#f8fafc" stroke="#e2e8f0"/>
  <text font-family="ui-monospace, Menlo, monospace" font-size="10" fill="#94a3b8" x="48" y="228">@discourse</text>
  <rect x="36" y="248" width="238" height="60" rx="7" fill="#fef2f2" stroke="#fecaca"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#b91c1c" x="48" y="266">La cadena if/elsif se detiene en la</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#b91c1c" x="48" y="279">primera coincidencia. Las otras cuatro</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#b91c1c" x="48" y="292">nunca se evalúan, ni en otro turno.</text>
  <rect x="305" y="30" width="270" height="290" rx="10" fill="#ffffff" stroke="#22c55e" stroke-width="1.5"/>
  <rect x="305" y="30" width="270" height="30" rx="10" fill="#ecfdf5" stroke="#22c55e" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="11.5" font-weight="700" fill="#0f172a" x="440" y="50" text-anchor="middle">Con @ruta — se reparten</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10" fill="#64748b" x="321" y="80">cada rama estrena su propia fuente:</text>
  <rect x="321" y="90" width="238" height="42" rx="6" fill="#f8fafc" stroke="#e2e8f0"/>
  <text font-family="ui-monospace, Menlo, monospace" font-size="9.5" fill="#0f172a" x="333" y="106">soporte</text>
  <text font-family="ui-monospace, Menlo, monospace" font-size="9.5" fill="#16a34a" x="333" y="122">→ @discourse</text>
  <rect x="321" y="138" width="238" height="42" rx="6" fill="#f8fafc" stroke="#e2e8f0"/>
  <text font-family="ui-monospace, Menlo, monospace" font-size="9.5" fill="#0f172a" x="333" y="154">comercial_info</text>
  <text font-family="ui-monospace, Menlo, monospace" font-size="9.5" fill="#16a34a" x="333" y="170">→ @buscar_predefinidas(!GESTION)</text>
  <rect x="321" y="186" width="238" height="42" rx="6" fill="#f8fafc" stroke="#e2e8f0"/>
  <text font-family="ui-monospace, Menlo, monospace" font-size="9.5" fill="#0f172a" x="333" y="202">comercial_gestion</text>
  <text font-family="ui-monospace, Menlo, monospace" font-size="9.5" fill="#16a34a" x="333" y="218">→ @buscar_predefinidas(GESTION)</text>
  <rect x="321" y="234" width="238" height="42" rx="6" fill="#f8fafc" stroke="#e2e8f0"/>
  <text font-family="ui-monospace, Menlo, monospace" font-size="9.5" fill="#0f172a" x="333" y="250">administrativo</text>
  <text font-family="ui-monospace, Menlo, monospace" font-size="9.5" fill="#94a3b8" x="333" y="266">→ «-» sin fuente: conversacional</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#64748b" x="321" y="296">El clasificador elige UNA rama por turno.</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#64748b" x="321" y="310">Nunca se prueban dos fuentes seguidas.</text>
  <rect x="590" y="30" width="270" height="290" rx="10" fill="#ffffff" stroke="#6366f1" stroke-width="1.5"/>
  <rect x="590" y="30" width="270" height="30" rx="10" fill="#eef2ff" stroke="#6366f1" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="11.5" font-weight="700" fill="#0f172a" x="725" y="50" text-anchor="middle">Apilar en un mismo turno</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10" fill="#64748b" x="606" y="80">conviven porque actúan en momentos</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10" fill="#64748b" x="606" y="93">distintos del turno:</text>
  <rect x="606" y="102" width="238" height="34" rx="6" fill="#ecfdf5" stroke="#bbf7d0"/>
  <text font-family="ui-monospace, Menlo, monospace" font-size="9.5" fill="#0f172a" x="618" y="117">@buscar_predefinidas(GESTION)</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#64748b" x="618" y="130">A · antes — recupera y redacta</text>
  <rect x="606" y="142" width="238" height="34" rx="6" fill="#fef2f2" stroke="#fecaca"/>
  <text font-family="ui-monospace, Menlo, monospace" font-size="9.5" fill="#0f172a" x="618" y="157">-&gt; @crear_ticket(tipo=Comercial)</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#64748b" x="618" y="170">solo si la fuente no resolvió</text>
  <rect x="606" y="182" width="238" height="34" rx="6" fill="#f0f9ff" stroke="#bae6fd"/>
  <text font-family="ui-monospace, Menlo, monospace" font-size="9.5" fill="#0f172a" x="618" y="197">#gestion</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#64748b" x="618" y="210">C · después — dispara automatización</text>
  <rect x="606" y="222" width="238" height="34" rx="6" fill="#fffbeb" stroke="#fde68a"/>
  <text font-family="ui-monospace, Menlo, monospace" font-size="9.5" fill="#0f172a" x="618" y="237">{{catalogo}}</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#64748b" x="618" y="250">C · después — adjunta el archivo</text>
  <rect x="606" y="262" width="238" height="46" rx="7" fill="#f8fafc" stroke="#cbd5e1"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#64748b" x="618" y="280">Y en paralelo, siempre disponibles:</text>
  <text font-family="ui-monospace, Menlo, monospace" font-size="9.5" fill="#0f172a" x="618" y="296">@estado_ticket · @agendar_calendar</text>
  <rect x="20" y="336" width="840" height="66" rx="10" fill="#f8fafc" stroke="#cbd5e1" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="11" font-weight="700" fill="#0f172a" x="38" y="358">Combinación recomendada por defecto</text>
  <text font-family="ui-monospace, Menlo, monospace" font-size="10" fill="#0f172a" x="38" y="378">@ruta(rama #etiqueta: cuándo aplica): &lt;una fuente&gt; -&gt; @crear_ticket(tipo=…)   +   @estado_ticket y @agendar_calendar en la prosa</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10" fill="#64748b" x="38" y="394">Una fuente por rama, un escalamiento por rama, una etiqueta por rama. Las acciones transversales se declaran una sola vez.</text>
</svg>

### 5.2 Matriz de convivencia

| Combinación | Resultado | Por qué |
|---|---|---|
| dos fuentes en la **misma** rama | ✗ gana la primera del catálogo | `detect` es `if/elsif` |
| dos fuentes en **ramas distintas** | ✓ correcto | cada turno resuelve una rama |
| `{{consulta:}}` + cualquier otra fuente | ✗ el ERP se lleva todos los turnos | está primero en `detect` |
| `{{consulta:}}` + líneas `@ruta` o prosa | ✗✗ el cliente recibe el Entrenamiento completo | `perform_erp_query` envía el prompt entero interpolado |
| fuente + `-> @crear_ticket` | ✓ patrón principal | el ticket corre solo si la fuente no resolvió |
| fuente + `@crear_ticket` global **sin** `fallback=true` | ⚠ el ticket se lleva el turno antes de buscar | el orden de la cascada |
| flecha en una rama + `@crear_ticket` global | ⚠ la global se ignora **por completo** | `branch_escalations?` cambia el régimen |
| `@estado_ticket` + `@crear_ticket` | ✓ recomendado | consultar va antes que crear |
| `@agendar_calendar` + fuente | ✓ | la agenda corre antes que la búsqueda |
| `@agendar_calendar` + `@crear_ticket` | ✓ | al completarse el ticket ofrece horarios en el mismo turno |
| `@soporte_contpaq` + regla de tono en la prosa | ⚠ la regla no se aplica en esa rama | la redacción es de CONTPAQi, no nuestra |
| `@soporte_contpaq` en la misma rama que otra fuente | ✗ gana la otra | va **última** en el catálogo, para no alterar agentes ya configurados |
| `{{nombre}}` + rama con fuente | ✗ sale como texto literal | KBase no resuelve adjuntos |
| `{{nombre}}` + rama sin fuente | ✓ | el conversacional sí los resuelve |
| directiva de búsqueda suelta en la prosa | ✗✗ blanquea el prompt entero | `job:545` |
| `#etiqueta` en `@ruta` + regla de etiquetas en la prosa | ✓ recomendado | la prosa elige el grado, la línea es la red |

### 5.3 Precedencia efectiva de un turno

<svg viewBox="0 0 880 470" width="100%" style="max-width:880px;height:auto" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Cascada de guardias de un turno: once pasos en orden, cada uno puede responder y cortar la cascada">
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="12" font-weight="700" fill="#0f172a" x="20" y="24">Orden real de evaluación — el primero que resuelve, corta</text>
  <rect x="20" y="36" width="560" height="30" rx="7" fill="#f1f5f9" stroke="#cbd5e1"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10.5" fill="#0f172a" x="34" y="55"><tspan font-weight="700">1</tspan>  keyword_actions — coincidencia exacta, sin IA, sin respuesta</text>
  <rect x="20" y="70" width="560" height="30" rx="7" fill="#f1f5f9" stroke="#cbd5e1"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10.5" fill="#0f172a" x="34" y="89"><tspan font-weight="700">2</tspan>  [PENDING_SLOT] — el cliente está eligiendo horario</text>
  <rect x="20" y="104" width="560" height="30" rx="7" fill="#f1f5f9" stroke="#cbd5e1"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10.5" fill="#0f172a" x="34" y="123"><tspan font-weight="700">3</tspan>  [PENDING_EMAIL] — falta el correo para la invitación</text>
  <rect x="20" y="138" width="560" height="30" rx="7" fill="#fffbeb" stroke="#fcd34d"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10.5" fill="#0f172a" x="34" y="157"><tspan font-weight="700">4</tspan>  RouterService — hoy apagado: la ruta es siempre :tracking</text>
  <rect x="20" y="172" width="560" height="30" rx="7" fill="#f1f5f9" stroke="#cbd5e1"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10.5" fill="#0f172a" x="34" y="191"><tspan font-weight="700">5</tspan>  acción de cita ya clasificada — el calendario gana sobre la búsqueda</text>
  <rect x="20" y="206" width="560" height="30" rx="7" fill="#f1f5f9" stroke="#cbd5e1"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10.5" fill="#0f172a" x="34" y="225"><tspan font-weight="700">6</tspan>  @estado_ticket — consultar un caso nunca abre uno nuevo</text>
  <rect x="20" y="240" width="560" height="30" rx="7" fill="#fef2f2" stroke="#fecaca"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10.5" fill="#0f172a" x="34" y="259"><tspan font-weight="700">7</tspan>  @crear_ticket — salvo fallback=true o escalamiento por rama</text>
  <rect x="20" y="274" width="560" height="30" rx="7" fill="#f1f5f9" stroke="#cbd5e1"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10.5" fill="#0f172a" x="34" y="293"><tspan font-weight="700">8</tspan>  @agendar_calendar — solo si el mensaje habla de una cita</text>
  <rect x="20" y="308" width="560" height="30" rx="7" fill="#ecfdf5" stroke="#22c55e"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10.5" fill="#0f172a" x="34" y="327"><tspan font-weight="700">9</tspan>  KBase — clasifica la rama y busca en SU fuente</text>
  <rect x="20" y="342" width="560" height="30" rx="7" fill="#fef2f2" stroke="#fecaca"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10.5" fill="#0f172a" x="34" y="361"><tspan font-weight="700">10</tspan>  @crear_ticket(fallback=true) o el escalamiento de la rama</text>
  <rect x="20" y="376" width="560" height="30" rx="7" fill="#fffbeb" stroke="#f59e0b"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10.5" fill="#0f172a" x="34" y="395"><tspan font-weight="700">11</tspan>  conversacional — responde siempre, con la prosa o sin ella</text>
  <path d="M596,44 L610,44 L610,398 L596,398" fill="none" stroke="#94a3b8" stroke-width="1.5"/>
  <rect x="626" y="150" width="234" height="150" rx="10" fill="#ffffff" stroke="#94a3b8" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="11.5" font-weight="700" fill="#0f172a" x="644" y="174">Consecuencias de escribir</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10" fill="#475569" x="644" y="196">· Poner @crear_ticket sin fallback</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10" fill="#475569" x="644" y="210">  deja la fuente sin uso.</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10" fill="#475569" x="644" y="230">· La KBase es el ÚLTIMO recurso</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10" fill="#475569" x="644" y="244">  antes de conversar: agenda y</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10" fill="#475569" x="644" y="258">  tickets siempre le ganan.</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10" fill="#475569" x="644" y="278">· El paso 11 nunca falla: si nada</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10" fill="#475569" x="644" y="292">  resolvió, el modelo improvisa.</text>
</svg>

---

## 6. Recuperación semántica en detalle

Todo lo que no sea ERP ni hoja en modo Datos pasa por el mismo pipeline. Entenderlo es lo
que separa "el agente contesta raro" de "el corpus está mal repartido".

<svg viewBox="0 0 880 494" width="100%" style="max-width:880px;height:auto" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Pipeline de recuperación semántica: de la pregunta a la respuesta redactada, con doble consulta, umbral y armado de contexto">
  <defs>
    <marker id="m3" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
      <path d="M 0 0 L 10 5 L 0 10 z" fill="#94a3b8"/>
    </marker>
  </defs>
  <rect x="250" y="16" width="330" height="40" rx="9" fill="#eef2ff" stroke="#6366f1" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="11.5" font-weight="700" fill="#0f172a" x="415" y="41" text-anchor="middle">Pregunta del cliente (texto del turno)</text>
  <line x1="415" y1="56" x2="415" y2="72" stroke="#94a3b8" stroke-width="1.5" marker-end="url(#m3)"/>
  <rect x="250" y="74" width="330" height="44" rx="9" fill="#fffbeb" stroke="#f59e0b" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="11" font-weight="700" fill="#0f172a" x="415" y="94" text-anchor="middle">¿Es un turno corto o de continuación?</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#64748b" x="415" y="110" text-anchor="middle">≤ 8 palabras · empieza con y/pero/entonces · lleva «eso», «lo mismo»</text>
  <path d="M250,96 L200,96" stroke="#94a3b8" stroke-width="1.5" marker-end="url(#m3)"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" font-weight="700" fill="#475569" x="222" y="90" text-anchor="middle">no</text>
  <rect x="20" y="76" width="176" height="40" rx="8" fill="#f8fafc" stroke="#cbd5e1"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10" fill="#0f172a" x="108" y="94" text-anchor="middle">1 consulta</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#64748b" x="108" y="108" text-anchor="middle">la pregunta tal cual</text>
  <path d="M580,96 L634,96" stroke="#94a3b8" stroke-width="1.5" marker-end="url(#m3)"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" font-weight="700" fill="#475569" x="608" y="90" text-anchor="middle">sí</text>
  <rect x="638" y="70" width="222" height="52" rx="8" fill="#f8fafc" stroke="#cbd5e1"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10" fill="#0f172a" x="749" y="88" text-anchor="middle">2 consultas</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#64748b" x="749" y="102" text-anchor="middle">la pregunta + la pregunta precedida</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#64748b" x="749" y="114" text-anchor="middle">del tema de los 2 mensajes previos</text>
  <line x1="415" y1="118" x2="415" y2="136" stroke="#94a3b8" stroke-width="1.5" marker-end="url(#m3)"/>
  <rect x="250" y="138" width="330" height="40" rx="9" fill="#ffffff" stroke="#94a3b8" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="11" fill="#0f172a" x="415" y="156" text-anchor="middle">Embeddings — text-embedding-3-small (1536)</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#64748b" x="415" y="170" text-anchor="middle">si la API falla y ninguna consulta se pudo embeber, el turno sigue de largo</text>
  <line x1="415" y1="178" x2="415" y2="196" stroke="#94a3b8" stroke-width="1.5" marker-end="url(#m3)"/>
  <rect x="250" y="198" width="330" height="56" rx="9" fill="#ecfdf5" stroke="#22c55e" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="11" font-weight="700" fill="#0f172a" x="415" y="218" text-anchor="middle">pgvector — vecinos por coseno</text>
  <text font-family="ui-monospace, Menlo, monospace" font-size="9" fill="#475569" x="415" y="233" text-anchor="middle">trae limit×3 y filtra distancia ≤ (1 − umbral)</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#64748b" x="415" y="247" text-anchor="middle">el scope ya viene filtrado por tipo, grupo o fuente</text>
  <rect x="612" y="190" width="248" height="72" rx="8" fill="#f8fafc" stroke="#cbd5e1"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10" font-weight="700" fill="#0f172a" x="626" y="208">Umbral: la decisión de diseño</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#64748b" x="626" y="224">0.20 corpus general — permisivo:</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#64748b" x="626" y="236">algo flojo es mejor que nada.</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#64748b" x="626" y="250">0.45 con grupo — estricto: «no hay</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#64748b" x="626" y="262">instrucción para esto» es útil.</text>
  <line x1="415" y1="254" x2="415" y2="272" stroke="#94a3b8" stroke-width="1.5" marker-end="url(#m3)"/>
  <rect x="250" y="274" width="330" height="44" rx="9" fill="#ffffff" stroke="#94a3b8" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="11" fill="#0f172a" x="415" y="292" text-anchor="middle">Entrelazado + deduplicado → 3 fragmentos</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#64748b" x="415" y="308" text-anchor="middle">alternando las dos consultas, para que ninguna se coma el cupo</text>
  <rect x="20" y="266" width="212" height="60" rx="8" fill="#fef2f2" stroke="#fecaca"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="10" font-weight="700" fill="#b91c1c" x="34" y="284">Si quedan 0 fragmentos</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#64748b" x="34" y="300">la fuente no responde y el turno</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#64748b" x="34" y="312">baja al escalamiento o al</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#64748b" x="34" y="324">conversacional. No se reintenta.</text>
  <line x1="415" y1="318" x2="415" y2="336" stroke="#94a3b8" stroke-width="1.5" marker-end="url(#m3)"/>
  <rect x="250" y="338" width="330" height="44" rx="9" fill="#ffffff" stroke="#94a3b8" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="11" fill="#0f172a" x="415" y="356" text-anchor="middle">Contexto: 2 000 caracteres por fragmento, 6 000 en total</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#64748b" x="415" y="372" text-anchor="middle">numerados «1. título / contenido» — el modelo ve el título de cada uno</text>
  <line x1="415" y1="382" x2="415" y2="400" stroke="#94a3b8" stroke-width="1.5" marker-end="url(#m3)"/>
  <rect x="180" y="402" width="470" height="56" rx="9" fill="#fffbeb" stroke="#f59e0b" stroke-width="1.5"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="11" font-weight="700" fill="#0f172a" x="415" y="422" text-anchor="middle">Redacción — una sola llamada</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#64748b" x="415" y="437" text-anchor="middle">system: prosa del prompt + objetivo + RAMA YA DECIDIDA · historial: 6 turnos</text>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9" fill="#64748b" x="415" y="450" text-anchor="middle">user: pregunta + fragmentos + regla dura de fidelidad a la fuente</text>
  <rect x="180" y="466" width="470" height="24" rx="7" fill="#ecfdf5" stroke="#22c55e"/>
  <text font-family="ui-sans-serif, system-ui, sans-serif" font-size="9.5" fill="#0f172a" x="415" y="482" text-anchor="middle">→ texto + #etiqueta repuesta si falta + firma de la fuente al pie</text>
</svg>

**Cómo leerlo.** El punto crítico está en el centro: **el umbral decide si el agente
contesta con documentación vecina o dice que no sabe**. Con 0.20 sobre un corpus amplio,
"lo más parecido" casi siempre existe, y por eso la regla de fidelidad en la prosa no es
opcional. Con un grupo (0.45) el corpus es estrecho y a propósito: ahí *no encontrar nada*
es un resultado correcto.

### 6.1 Cómo se indexa cada fuente

| Fuente | `title` del ítem | `content` |
|---|---|---|
| Respuesta predefinida | el **short_code** | `short_code: contenido` |
| Artículo | título del artículo | cuerpo troceado |
| Google Doc / Sheet FAQ | encabezado o fila | contenido troceado |
| Discourse | título del hilo | `raw` del post (bajado en vivo) |
| CONTPAQi | — | **no se indexa**: la búsqueda y la redacción ocurren del otro lado |

Por eso el grupo de `@buscar_predefinidas(GESTION)` se cumple **renombrando** las
respuestas: `GESTION - alta de usuario`, `GESTION - datos fiscales`. No hay columna nueva
ni pantalla nueva; el prefijo del nombre **es** el grupo.

### 6.2 Cuándo conviene cada estrategia

| Situación | Qué usar |
|---|---|
| Un solo tema, corpus chico | `@buscar_predefinidas` sin grupo |
| Dos ramas que comparten el corpus | `(GRUPO)` en una y `(!GRUPO)` en la otra |
| Instrucciones de trámite que no deben mezclarse con precios | grupo positivo (umbral 0.45) |
| Documentación técnica extensa y viva | `@discourse` o `@buscar_foro(...)` |
| Dudas de productos CONTPAQi (Nóminas, Bancos, Comercial) | `@soporte_contpaq(...)` — documentación del fabricante, mantenida por él |
| Tablas con números que deben cuadrar | `{{hoja:}}` en modo Datos |
| Datos del cliente en el ERP | `{{consulta:}}` (determinista, sin IA) |

---

## 7. Estado entre turnos

El motor no tiene memoria de agente: tiene **cuatro** lugares donde guarda estado.

| Estado | Dónde vive | Para qué | Cuándo se limpia |
|---|---|---|---|
| `kb_history` | `conversation.additional_attributes` | los últimos 6 pares pregunta/respuesta de la KBase | nunca (rota a 6) |
| `[PENDING_SLOT]` | `tracking.ai_context` | horarios ofrecidos, esperando elección | al elegir, negociar o fallar |
| `[PENDING_EMAIL]` | `tracking.ai_context` | slot elegido, esperando correo | al recibir el correo o "sin correo" |
| intake de ticket | Redis (`case_intake_pending::<conv>`, TTL 1 h) | campos que faltan para crear el caso | al completar o tras 2 insistencias |

Consecuencias para quien escribe el prompt:

- El modelo **no ve toda la conversación**: ve 6 turnos de KBase, o el historial del
  seguimiento en el conversacional. Instrucciones del tipo "recordá lo que dijo al inicio"
  no se cumplen si quedó fuera de esa ventana.
- Mientras hay un estado pendiente de cita, **la cascada ni siquiera llega a la KBase**:
  esos turnos los atiende el flujo de agenda.
- El bot no responde dos veces al mismo mensaje: si ya hay una respuesta automática
  posterior, el turno se descarta (`already_replied_by_bot?`).

---

## 8. Contrato de autoría: reglas por severidad

### 8.1 Bloqueantes — si fallan, la funcionalidad no existe

| # | Regla | Qué pasa si no |
|---|---|---|
| B1 | Las líneas `@ruta` empiezan la línea y cierran bien los paréntesis | la rama no existe; el motor cae al modo clásico |
| B2 | Ninguna directiva de búsqueda fuera de una línea `@ruta` | el conversacional descarta el Entrenamiento completo |
| B3 | `@buscar_foro` siempre con paréntesis y nombre exacto | la directiva es texto muerto |
| B4 | Solo directivas del catálogo (§4) | lo inventado no ejecuta nada, en silencio |
| B3b | `@soporte_contpaq` siempre con paréntesis y nombre exacto | la directiva es texto muerto |
| B5 | Una sola fuente por rama | gana la primera del catálogo, no la que quisiste |
| B6 | La fuente existe, está activa y tiene contenido | la rama nunca responde con fuente |
| B7 | `@ruta_por_defecto` apunta a una rama declarada | los turnos ambiguos se quedan sin ruteo |

### 8.2 Degradan — funciona, pero mal

| # | Regla | Síntoma si falla |
|---|---|---|
| D1 | Descripciones de rama disjuntas y en términos del cliente | el clasificador manda el turno a la rama equivocada |
| D2 | Las secciones de la prosa usan las palabras de las descripciones | el modelo aplica la sección de otra rama |
| D3 | `#etiqueta` declarada en cada `@ruta` | turnos sin etiqueta → automatizaciones que no corren |
| D4 | Regla de fidelidad a la fuente escrita explícitamente | respuestas adaptadas que suenan bien y no son |
| D4b | No prometer un tono propio en una rama `@soporte_contpaq` | la respuesta llega con la voz de CONTPAQi y desentona con el resto |
| D5 | Escalamiento por rama en vez de `@crear_ticket` global | tickets abiertos donde no correspondía |
| D6 | `fallback=true` cuando hay fuente y ticket global | el ticket se lleva el turno antes de buscar |
| D7 | Pedir respuestas de 2 párrafos como máximo | respuestas cortadas por el tope de tokens |
| D8 | Modelo `gpt-4o` para prompts con reglas encadenadas | `gpt-4o-mini` incumple las reglas del prompt |

### 8.3 Cosméticas — mejoran, no rompen

| # | Regla |
|---|---|
| C1 | No pedirle al modelo que cite links: el motor los agrega y borra los suyos |
| C2 | No pedirle que se identifique como bot ni que mencione la base de conocimiento |
| C3 | Evitar listas numeradas salvo para pasos: el canal es mensajería |
| C4 | Un solo emoji, y solo al saludar |
| C5 | `@agendar_calendar` y `@estado_ticket` van en su propia línea al final: no blanquean el prompt, pero en ramas con fuente se cuelan literales en el system prompt del modelo |

---

## 9. Recetas: seis arquetipos de agente

### 9.1 Informativo simple (una fuente, sin tickets)

```text
@ruta(info #info1: precios, planes, horarios, qué incluye el servicio): @buscar_predefinidas
@ruta_por_defecto: info

[ROL] Sos asesor de <EMPRESA> y respondés consultas por WhatsApp.
[FIDELIDAD] Si la información recuperada no cubre exactamente lo que preguntaron, decilo y
ofrecé pasarlo con un asesor. Nunca adaptes un procedimiento de otro tema.
[ETIQUETAS] Cerrá siempre con #info1 en la última línea.
[ESTILO] Dos párrafos como máximo, tono natural, sin listas.
```

### 9.2 Soporte con foro y escalamiento a ticket

```text
@ruta(soporte #soporte1: fallas, errores, algo que dejó de funcionar, configuración): @discourse -> @crear_ticket(tipo=Soporte, prioridad=alta)
@ruta_por_defecto: soporte

[ROL] Sos el primer nivel de soporte de <EMPRESA>.
[ALCANCE] Explicás el procedimiento con los nombres de menús, permisos y campos tal como
figuran en la documentación. No diagnosticás causas que la fuente no mencione.
[ETIQUETAS] #soporte1 si la documentación resolvió · #soporte2 si hace falta un técnico.
[FIDELIDAD] Si el contenido recuperado trata un tema vecino, decilo en vez de forzarlo.
```

> El escalamiento corre **solo si el foro no resolvió el turno**: esa es la diferencia entre
> declararlo con `->` y poner `@crear_ticket` suelto.

### 9.3 Coordinador multi-rama (el caso v6.x)

```text
@ruta(soporte #soporte1: fallas, errores, algo que ya usa y dejó de funcionar): @discourse -> @crear_ticket(tipo=Soporte, prioridad=alta)
@ruta(comercial_info #comercial1: precios, licencias, planes, qué incluye): @buscar_predefinidas(!GESTION)
@ruta(comercial_gestion #gestion: pide que hagamos un trámite, alta, cambio o baja): @buscar_predefinidas(GESTION) -> @crear_ticket(tipo=Comercial)
@ruta(administrativo #admin: facturas, RFC, datos fiscales, pagos): - -> @crear_ticket(tipo=Administrativo)
@ruta_por_defecto: comercial_info

[ROL] Sos el coordinador de atención de <EMPRESA>.
[ALCANCE POR RAMA]
SOPORTE — fallas y errores: explicás el procedimiento documentado, sin inventar causas.
COMERCIAL INFORMACIÓN — precios y licencias: das la cifra directa, sin pedir datos.
COMERCIAL GESTIÓN — trámites: recolectás los datos indispensables, uno o dos por mensaje.
ADMINISTRATIVO — facturación: tomás el pedido y avisás que lo pasás al área.
[FIDELIDAD] …
[ETIQUETAS] #soporte1 · #soporte2 · #comercial1 · #gestion · #admin — siempre una, al final.
[PROHIBIDO] Reclasificar el tema: la rama del turno ya viene decidida.
```

**Por qué así:** las cuatro ramas comparten el mismo corpus de predefinidas, y el grupo
`GESTION` evita que una consulta de precios recupere el guion de un trámite (medido: la
gestión correcta da 0.650 de similitud y las ajenas 0.333, 0.287 y 0.081).

### 9.4 Bot cobrador (ERP, determinista) — **sin `@ruta`**

`{{consulta:}}` no se comporta como las demás fuentes: **no recupera para que el modelo
redacte, sino que envía el Entrenamiento entero con las directivas ya sustituidas**. El
prompt ES el mensaje. Por eso este arquetipo se escribe sin líneas `@ruta` y sin prosa de
instrucciones — todo lo que escribas lo va a leer el cliente.

```text
Hola, te recordamos que tu saldo pendiente con nosotros es de $ {{consulta:saldo_cliente}}.
Tus facturas vencidas son:
{{consulta:facturas_vencidas}}

Si ya realizaste el pago, ignorá este mensaje. Cualquier duda, respondé por acá.
```

| Detalle | Cómo funciona |
|---|---|
| Parámetros | `{{consulta:saldo_cliente(rfc=ABC123)}}` · posicional: `{{consulta:saldo_cliente(ABC123)}}` |
| `rfc` automático | si la consulta lo pide y no vino, se toma de `contact.custom_attributes['erp_rfc']` |
| Conexión | `{{consulta:sae/saldo_cliente}}` fuerza una conexión; sin prefijo usa la del bot ERP del inbox |
| Formato | 1 valor → el valor solo; varias filas → una línea `• valor · valor` por fila; montos a 2 decimales, fechas dd/mm/aaaa |
| Si falla | la directiva se reemplaza por vacío; si todo el texto queda vacío, no se envía nada |

> ⚠ **Nunca mezcles `{{consulta:}}` con líneas `@ruta` ni con prosa de instrucciones**: el
> motor manda el `complementary_prompt` completo al cliente, líneas de configuración
> incluidas.

### 9.5 Agente de agenda

```text
@ruta(agenda #agenda: quiere una cita, reunión, llamada o demo): - -> @crear_ticket(tipo=Comercial)
@ruta_por_defecto: agenda

@agendar_calendar
@estado_ticket

[ROL] Coordinás citas de demostración.
[ESTILO] Ofrecé los horarios tal como te los pasa el sistema, sin inventar disponibilidad
ni prometer horarios fuera de los ofrecidos.
```

> `@agendar_calendar` y `@estado_ticket` **no son fuentes de búsqueda**: pueden ir sueltos
> sin blanquear el prompt. Las que blanquean son `@buscar_*` y `@discourse`.

### 9.6 Intake de datos (formulario conversacional)

```text
@ruta(alta_servicio #alta: quiere contratar o dar de alta un servicio): - -> @crear_ticket(tipo=Alta, prioridad=media)
@ruta_por_defecto: alta_servicio

[ROL] Tomás los datos para dar de alta un servicio.
[ALCANCE] Pedí como máximo dos datos por mensaje y confirmá lo que ya quedó registrado.
[ETIQUETAS] Cerrá con #alta aunque el mensaje solo esté pidiendo un dato.
```

---

## 10. Generador de prompts

Este bloque es el "motor que genera prompts": se le pasa a un LLM junto con los datos del
negocio y devuelve un Entrenamiento **válido para este motor**, no un prompt genérico.

````text
Vas a escribir el "Entrenamiento" de un Agente IA para el motor de Seguimientos de
Chatwoot/Wintook. NO es un prompt libre: parte del texto lo parsea Ruby con expresiones
regulares y solo se ejecuta lo que coincide exactamente.

=== CONTRATO DEL MOTOR ===
1. El texto tiene dos zonas. Primero las líneas de configuración @ruta (las lee el parser,
   nunca el modelo). Después la prosa (la lee el modelo, ya sin esas líneas).
2. Sintaxis exacta de una línea de ruta:
   @ruta(<nombre> #<etiqueta>: <descripción>): <fuente> -> <escalamiento>
   · nombre: [a-z0-9_-]+, sin espacios ni acentos.
   · #etiqueta: opcional, [a-z0-9_]+, es la que dispara automatizaciones.
   · descripción: es LO ÚNICO que ve el clasificador para elegir la rama.
   · fuente: UNA sola del catálogo, o "-" si la rama no consulta nada.
   · -> escalamiento: opcional, solo @crear_ticket(...). Se ejecuta si la fuente no resolvió.
   Y una línea final: @ruta_por_defecto: <nombre de una rama declarada>
3. Catálogo de fuentes (elegir UNA por rama):
   @buscar_predefinidas | @buscar_predefinidas(GRUPO) | @buscar_predefinidas(!GRUPO)
   @buscar_articulo | @buscar_foro(<nombre exacto de la fuente>) | @discourse
   {{doc:<nombre>}} | {{hoja:<nombre>}} | {{consulta:<nombre>(param=valor)}}
4. Acciones que van sueltas en la prosa si se necesitan: @agendar_calendar, @estado_ticket.
   El adjunto {{nombre_archivo}} solo funciona en ramas SIN fuente.
5. PROHIBIDO ABSOLUTO: inventar directivas nuevas, poner @buscar_* o @discourse fuera de
   una línea @ruta (borra el prompt entero), o poner dos fuentes en la misma rama.

=== DATOS DEL NEGOCIO ===
Empresa: <...>
Canal: <WhatsApp | Telegram | ...>
Temas que llegan y cómo los nombra el cliente: <...>
Fuentes disponibles y su nombre exacto: <...>
Tipos de ticket disponibles: <...>
Etiquetas que usan las automatizaciones: <...>
Tono deseado: <...>

=== QUÉ DEBÉS PRODUCIR ===
A. Las líneas @ruta, una por tema, con descripciones DISJUNTAS y escritas con las palabras
   que usa el cliente (no con jerga interna).
B. La prosa, con estas secciones y nada más:
   [ROL] · [ALCANCE POR RAMA] · [FIDELIDAD] · [ETIQUETAS] · [ESTILO] · [PROHIBIDO]
   - [ALCANCE POR RAMA]: una sección por rama, nombrada con las MISMAS palabras de su
     descripción, porque el motor le dice al modelo "RAMA YA DECIDIDA: <nombre> — <descripción>".
   - [FIDELIDAD]: la información se recupera por similitud y puede ser de un tema vecino;
     el agente debe decirlo en vez de adaptarla.
   - [ETIQUETAS]: cerrar SIEMPRE con una etiqueta, incluso en turnos que solo piden un dato.
   - [ESTILO]: máximo dos párrafos; sin decir que es un bot; sin citar links (los agrega el
     sistema); sin listas salvo pasos.
   - [PROHIBIDO]: inventar precios, plazos o folios; reclasificar el tema.

=== AUTOVERIFICACIÓN ANTES DE ENTREGAR ===
Revisá y corregí si algo falla:
[ ] Cada línea @ruta empieza en columna 1 y cierra sus paréntesis.
[ ] Ninguna @buscar_* ni @discourse aparece fuera de una línea @ruta.
[ ] Cada rama tiene como máximo UNA fuente.
[ ] @ruta_por_defecto apunta a una rama que existe.
[ ] Cada rama tiene #etiqueta y la prosa explica cuándo usar cada una.
[ ] Las descripciones no se solapan entre ramas.
[ ] Las secciones de [ALCANCE POR RAMA] coinciden con las descripciones.
[ ] No hay ninguna directiva que no esté en el catálogo.

Entregá SOLO el Entrenamiento final, sin explicaciones.
````

Y para revisar un prompt existente en vez de crear uno, se usa el mismo bloque cambiando la
última instrucción por: *"Auditá el Entrenamiento que sigue contra el contrato y devolvé una
tabla de hallazgos (línea, problema, corrección) y luego la versión corregida."*

---

## 11. Validación y depuración

### 11.1 Checklist mecánico

- [ ] `grep -c '^@ruta('` devuelve el número de ramas esperado.
- [ ] `grep -n '@buscar_\|@discourse'` no muestra líneas fuera de `@ruta(`.
- [ ] Cada nombre de `@buscar_foro(...)`, `{{doc:...}}` y `{{hoja:...}}` existe **igual** en Base de Conocimiento.
- [ ] Los grupos usados tienen respuestas predefinidas cuyo nombre empieza con ese prefijo.
- [ ] `@ruta_por_defecto` coincide con una rama declarada.
- [ ] Cada rama que debe abrir caso tiene su `->`, y ninguna otra lo tiene por accidente.
- [ ] El inbox tiene el modelo correcto en la integración `tracking_bot`.

### 11.2 Qué mirar en los logs

| Línea | Confirma |
|---|---|
| `[BranchClassifier] 🧭 Rama: X` | la rama elegida para el turno |
| `[BranchClassifier] ⚠️ Sin rama reconocida (...) → por defecto: X` | descripciones ambiguas |
| `[KBase] 🧭 Rama 'X' → {:mode=>...}` | la fuente que quedó activa |
| `[KBase] 🗂️ Grupo exigido/excluido: G` | el filtro de grupo entró en la consulta |
| `[KBase] 🧵 Turno corto → segunda búsqueda con contexto` | se heredó el tema anterior |
| `[KBase] ✅ n resultado(s)` / `⚠️ Sin resultados` | si el umbral dejó pasar algo |
| `[KBase] 🏷️ Sin etiqueta → se repone la de la rama` | el modelo omitió la etiqueta |
| `[TrackingBot] 🎫 Ticket via @crear_ticket (outcome: ...)` | el escalamiento se ejecutó |
| `[TrackingBot] 📎 {{x}} no encontrado` | el nombre del adjunto no coincide |
| `[KBase] ⏭️ Sin directiva kbase → skip` | la rama no tenía fuente, o no se detectó ninguna |

### 11.3 Síntoma → causa

| Lo que se ve | Causa |
|---|---|
| Contesta con documentación de otro tema | umbral 0.20 sobre corpus amplio → separar en grupo (0.45) |
| Todo lo contesta con predefinidas | no hay líneas `@ruta`: gana la precedencia del catálogo |
| El prompt no tiene ningún efecto | directiva de búsqueda suelta en la prosa → `clean_cp = ''` |
| Falta la etiqueta y la automatización no corre | rama sin `#etiqueta` y modelo que la omitió |
| El foro nunca contesta | `@buscar_foro` sin paréntesis o nombre que no coincide |
| Abre ticket antes de intentar contestar | falta `fallback=true` o falta el `->` en esa rama |
| Una rama abre tickets que no debería | otra rama declara `->`: la directiva global queda ignorada |
| `{{catalogo}}` sale como texto | esa rama respondió por KBase, que no resuelve adjuntos |
| Elige mal la rama | descripciones solapadas: el clasificador solo ve nombre, descripción y 4 mensajes |
| Un audio no dispara la KBase | la KBase exige `message.content`; el adjunto solo alimenta al conversacional |
| Cambié el modelo en el prompt y sigue igual | el modelo sale del hook `tracking_bot` del inbox |
| La respuesta se corta | tope de 250 tokens en el conversacional |
| Responde dos veces / no responde | ya había una respuesta automática posterior (`already_replied_by_bot?`) |

---

## 12. Límites conocidos del motor

Lo que hoy **no** se puede pedir por prompt, para no escribir reglas que nunca se cumplirán:

| Límite | Detalle |
|---|---|
| Una fuente por turno | no hay "buscá en el foro y si no en la hoja"; hay que elegir por rama |
| Sin tool calling nativo | el modelo no puede pedir una herramienta a mitad de la respuesta |
| Sin gate de evidencia | `@evaluar_evidencia` no existe: los estados EXACTA/PARCIAL/etc. son texto inerte |
| Router de intenciones apagado | `TRACKING_DETECT_INTENT=false`: la ruta es siempre `:tracking` |
| Adjuntos solo en el conversacional | `{{nombre}}` no se resuelve en el camino KBase |
| Grupos solo en predefinidas | `@buscar_articulo` y las fuentes Google no aceptan `(GRUPO)` |
| Escalamiento solo a ticket | `->` únicamente admite `@crear_ticket(...)` |
| `{{consulta:}}` no convive con nada | envía el prompt entero interpolado: es plantilla de mensaje, no fuente de consulta |
| Una fuente nativa por cuenta | índice único: no hay dos fuentes de predefinidas; por eso existen los grupos |
| El modelo se elige por inbox | no por agente ni por rama |
| Sin reintento entre fuentes | si la fuente de la rama no trae nada, se baja al escalamiento o al conversacional |

---

## 13. Referencias de código

| Archivo | Puntos clave |
|---|---|
| `app/models/message.rb` | `:138` `after_create_commit` → encola el job |
| `app/jobs/contact_tracking_response_analyzer_job.rb` | `:42` adjuntos · `:82` flujo por tracking · `:175` cascada · `:266` `branch_for` · `:459` `kbase_available?` · `:511` conversacional · `:545` blanqueo · `:1723` envío · `:1753` adjuntos |
| `app/services/knowledge_base_response_service.rb` | `:18` defaults · `:38` umbral de grupo · `:119` doble consulta · `:148` búsqueda · `:167` `detect_directive` · `:244` grupos · `:386` redacción · `:618` prompt del agente · `:649` regla de rama · `:740` etiqueta |
| `app/services/knowledge_base/directives.rb` | `:29` `CANNED_RE` · `:33` `detect` (precedencia) · `:69` `available?` |
| `app/services/contact_trackings/route_map.rb` | `:28` `LINE_RE` · `:29` `DEFAULT_RE` · `:33` `ARROW_RE` · `:58` `strip` |
| `app/services/contact_trackings/branch_classifier_service.rb` | `:27` `classify` · `:84` prompt del clasificador |
| `app/services/contact_trackings/engine_config.rb` | modelo por inbox · topes de tokens |
| `app/services/contact_trackings/keyword_action_service.rb` | palabras clave sin IA |
| `app/services/cases/ticket_creator_service.rb` | `:28` `DIRECTIVE_RE` · `:53` `fallback?` · intake, anti-duplicado, prioridad |
| `app/services/cases/ticket_status_service.rb` | `:19` directiva · patrones de consulta de estado |
| `app/services/external_db/consulta_directive_renderer.rb` | `:19` patrón `{{consulta:}}` · resolución de conexión |
| `app/services/sheet_query_service.rb` | modo Datos: traducción a `{op, column, filters}` |
| `app/models/knowledge_item.rb` | `search_by_embedding` (coseno, `1 - umbral`) |
| `app/jobs/knowledge_item_sync_job.rb` | qué se vectoriza como título y contenido |

### Glosario

| Término | Qué es |
|---|---|
| **Entrenamiento** | el campo `complementary_prompt` del Agente IA |
| **Rama** | una línea `@ruta`: un tema con su fuente, su etiqueta y su escalamiento |
| **Fuente** | de dónde sale la información: predefinidas, artículos, foro, doc, hoja, ERP |
| **Grupo** | prefijo del nombre de una respuesta predefinida usado para partir el corpus |
| **Escalamiento** | qué hacer si la fuente no resolvió el turno (hoy: abrir ticket) |
| **Cascada** | el orden fijo en que se evalúan los guardias del turno |
| **Camino KBase / conversacional** | responder con una fuente, o responder solo con el modelo |
