# Diagrama del Agente IA — plan

> Rama: `feat/diagrama_agente_ia` (desde `develop` 09f0278c, 28/10/2026)
> Estado: **solo plan**. No se implementa nada hasta el OK por fase.
> Pantalla: `/app/accounts/:id/tracking-dashboard/agents/:templateId` → Entrenamiento (el Asistente)

---

## 1. Para qué

Hoy un agente se crea conversando (chat del Asistente) y se prueba con dos herramientas
que **responden en texto y tablas**:

- **Prueba en seco** (`DryRunModal` + `dry_run_service.rb`): ruta, fuente, fragmentos, etiqueta
  y caso, pero **sin redactar la respuesta**.
- **Pila de pruebas** (`TestBatteryModal` + `test_battery*.rb`): el motor real contesta en el
  canal de pruebas y un juez califica. La ruta se **adivina** por la `#etiqueta` del texto.

Lo que falta es **ver** el agente: qué forma tiene, por dónde pasó cada respuesta y en qué
punto falla. Y que esa evidencia se pueda **llevar al chat de creación** para corregir con
pruebas en la mano, no a ciegas.

```
   CREAR ──────────► PROBAR ──────────► VER ──────────► CORREGIR ─┐
   (chat)            (pila)             (diagrama)      (chat +    │
     ▲                                                  evidencia) │
     └─────────────────── volver a correr la misma pila ◄──────────┘
                          y comparar antes / después
```

---

## 2. Lo que ya existe y se reutiliza

| Pieza | Archivo | Aporta al diagrama |
|---|---|---|
| Estructura (Definición · Rutas · Secciones) | `assistant/AgentStructure.vue`, `contact_trackings/training_structure.rb`, `training_routes.rb` | Los **nodos** |
| Comprobador | `ValidatorService`, `ValidationBadge.vue` | Puntos rojos sobre los nodos |
| Prueba en seco | `assistant/dry_run_service.rb` | Camino barato (sin respuesta) |
| Pila: escenarios | `assistant/test_battery_scenarios.rb` (por ruta / por regla) | «Generar pruebas» |
| Pila: correr + juez | `assistant/test_battery.rb`, `test_battery_judge.rb`, `TestBatteryJob` | Veredicto por prueba |
| Ir a una línea | `assistant/draftNavigation.js` | Clic en nodo → línea del Entrenamiento |
| Revisar conversación real | `assistant/conversationReview.js`, `conversation_review.rb` | Pintar una conversación real |
| Pestañas del editor | `Assistant.vue` → `draftTab`: `editor · configure · log · versions` | Aquí entra **Diagrama** |
| Panel izquierdo | `Assistant.vue` → `leftPanel`: `chat · instructions · structure` | Aquí entra **Pruebas** |

---

## 3. El hueco: el motor no deja traza

Cuando el agente contesta de verdad, **no queda registrado por dónde pasó**. Hoy:

```
KnowledgeBaseResponseService#perform
   detect_directive ─► perform_<fuente> ─► generate_contextual_reply ─► with_branch_tag ─► send_reply
        │                    │                       │                        │               │
     (modo)            (fragmentos)            (modelo, tokens)          (#etiqueta)     Message ✗ sin traza
```

`test_battery_judge.rb#route_ok` busca la `#etiqueta` dentro del texto. Eso falla en tres casos:
cuando el modelo pone otra etiqueta, cuando la ruta no tiene etiqueta y cuando se trata de una
ruta de información.

**F0 agrega la traza** en `send_reply`, que es donde ya se conocen `@route`, la directiva y el
texto final:

```ruby
reply_message.content_attributes[:traza] = {
  v: 1,
  ruta:       { nombre:, etiqueta:, por_qué:, por_defecto: bool },   # router / clasificador
  secciones:  ["Tono", "Precios"],                                   # las que entraron al prompt
  fuente:     { modo: "google_doc", nombre: "Lista", ejecutada: true },
  fragmentos: [{ titulo:, similitud: 0.82 }],                         # máx. 5, sin el texto completo
  directivas: ["@crear_ticket", "{{catalogo}}"],                     # las que dispararon
  etiqueta:   "#cotizar", etiqueta_repuesta: bool,                   # with_branch_tag
  variables:  { cambiaron: ["nombre"] },
  agenda:     bool,                                                  # calendar_took_over
  modelo:, tokens:, ms:
}
```

- La traza **no** guarda el texto del cliente ni los fragmentos completos: solo nombres,
  títulos y números. Así no crece la BD ni se duplican datos sensibles.
- La `v: 1` permite cambiar el formato sin romper los diagramas de conversaciones viejas.
- ⚠ Verificar en F0 si los **seguimientos** (`ContactTrackingJob` y el analizador) contestan
  por otro camino que no pasa por `send_reply`. Si es así, la traza también se escribe ahí.

---

### 3.1 F0 — hecho (28/10/2026)

**Qué se hizo.** `ContactTrackings::EngineTrace` (`app/services/contact_trackings/engine_trace.rb`)
abre un registro mientras `ContactTrackingResponseAnalyzerJob` atiende un mensaje del cliente
(`EngineTrace.run` en `perform`; el reparto pasó tal cual a `coordinate`). Cada etapa anota lo suyo
y, al terminar el turno, la traza se escribe en `content_attributes['traza']` de **cada respuesta
del bot creada en ese turno** (todas las conversaciones, decisión D2).

**Cómo funciona.** Se escribe al FINAL y no al crear el mensaje: el camino se sabe cuando el
handler devuelve, y el mensaje se crea adentro del handler. `Message` anota sus salientes con
`after_create :register_in_engine_trace` (un no-op fuera de un turno) y la traza se guarda con
`update_columns`: no dispara eventos ni callbacks. La traza **no sale en los webhooks**
(`Message#webhook_data` la quita).

**Formato real (v1)** — distinto del borrador de arriba:

```json
{
  "v": 1, "mensaje_id": 812, "camino": "kbase", "respuesta": "1/1", "ms": 2140,
  "ruta":       { "nombre": "cotizar", "etiqueta": "#cotizar", "como": "clasificada" },
  "fuente":     { "modo": "google_doc", "nombre": "Lista" },
  "fragmentos": [{ "titulo": "Lista de precios", "similitud": 0.82 }],
  "etiqueta_repuesta": "#cotizar",
  "uso":        { "llamadas": 2, "tokens": 1830, "modelos": ["gpt-4o"] }
}
```

| Llave | Quién la anota | Valores |
|---|---|---|
| `camino` | el job (`answered`) | bienvenida · palabra_clave · eleccion_horario · correo_cita · confirmar_servicio · solicitudes · rechazo · interes · agenda · botseller · estado_ticket · ticket · kbase · conversacional |
| `ruta.como` | `BranchClassifierService` | unica · clasificada · por_defecto · sin_ruta |
| `fuente` | `KnowledgeBaseResponseService#perform` | la directiva de la ruta (o la global) |
| `fragmentos` | `search_items` (búsqueda local) | máx. 5, título + similitud; **sin el texto** |
| `etiqueta_repuesta` | los dos `with_branch_tag` | solo si el motor tuvo que reponerla |
| `uso` | clasificador, respuesta conversacional, `call_openai_simple` | suma de todas las llamadas del turno |

**Lo que NO trae, y por qué.** `secciones`: el Entrenamiento entra completo al prompt, el motor no
elige secciones; el diagrama las dibuja desde la Estructura, no desde la traza. Tampoco el texto
del cliente ni el de los fragmentos.

**Pila de pruebas.** `spec/services/contact_trackings/engine_trace_spec.rb`: lo que anota cada
etapa, varias respuestas por turno (1/2, 2/2), que no guarda textos, que no toca otra conversación
ni los entrantes, no-op fuera de turno, limpieza si el turno falla, fuera del webhook, y el job de
punta a punta por la bienvenida. **8/8 en verde**, y 777/777 en las suites del job, la base de
conocimiento, el Asistente, la bienvenida, las rutas y `Message` (commit 553300a1).

**Cómo verlo.** En una conversación del canal de pruebas, después de que conteste el agente:
`Message.where(conversation_id: N).outgoing.last.content_attributes['traza']`.

---

## 4. Cómo se ve

### 4.1 Distribución en pantalla

```
 Nombre del agente                                ← Agentes IA · Bandeja · v12
 [ Entrenamiento ]  Ficha   Versiones
┌─[Chat] [Pruebas] [Estructura]──────┐┌─ Editor · Configurar · Registro · Diagrama ───────────┐
│                                    ││                                                       │
│  PILA DE PRUEBAS (12)   ✅9  ❌3    ││                  (ver 4.2)                            │
│  ┌──────────────────────────────┐  ││                                                       │
│  │▸❌ ¿precio del kit?    Cotizar│  ││                                                       │
│  │ ✅ quiero agendar      Agenda │  ││                                                       │
│  │ ✅ no me llegó         Soporte│  ││                                                       │
│  │ ❌ ¿eres un robot?     regla  │  ││                                                       │
│  └──────────────────────────────┘  ││                                                       │
│  [+ Generar]  [+ Escribir]         ││                                                       │
│  [▶ Correr todo]   ~$0.04 · 12     ││                                                       │
│  ──────────────────────────────    ││                                                       │
│  Cliente: ¿precio del kit?         ││                                                       │
│  Agente : Claro, el kit cuesta...  ││                                                       │
│  ❌ Inventó un precio (regla 3)     ││                                                       │
│  [💬 Llevar al chat] [↻ Volver a correr]                                                   │
└────────────────────────────────────┘└───────────────────────────────────────────────────────┘
```

- **Pruebas** es un panel nuevo de la columna izquierda, igual que Chat y Estructura (uno a la vez).
- **Diagrama** es una pestaña nueva del editor, después de Configurar.
- La pila y la prueba en seco dejan de ser modales y se mueven a este panel.
  Los modales actuales se reutilizan por dentro como componentes.

### 4.2 El diagrama (SVG)

Columnas de izquierda a derecha, una por etapa del motor:

```
 MENSAJE      RUTA              SECCIONES        FUENTE              ACCIONES        SALIDA
┌───────┐   ┌──────────┐      ┌───────────┐    ┌──────────────┐    ┌────────────┐  ┌─────────┐
│Cliente│═══│▣ Cotizar │══════│ Tono      │════│{{doc:Lista}} │════│@crear_ticket│══│#cotizar │══► Respuesta
└───────┘ ╔═└──────────┘      │ Precios   │    │ 3 frag · 0.41⚠│   └────────────┘  └─────────┘
          ║ ┌──────────┐      └───────────┘    └──────────────┘
          ╟─│░ Soporte │──────── ░ ─────────────── ░ predefinidas
          ║ └──────────┘
          ║ ┌──────────┐
          ╚─│░ Agenda  │──────── ░ ─────────────── ░ calendario
            └──────────┘
            ┌──────────┐
            │◇ Por def.│  (ruta por defecto, línea punteada)
            └──────────┘

  ══ camino recorrido     ░ no tocado     ⚠ punto débil (similitud baja, fuente no ejecutada)
  ● rojo = aviso del comprobador          ✕ = donde el juez dice que falló
```

**Interacción**

| Acción | Resultado |
|---|---|
| Elegir una prueba en la pila | Se ilumina su camino; el resto queda tenue |
| Clic en un nodo | Ficha lateral: por qué se eligió la ruta, los fragmentos con su similitud, la línea del Entrenamiento |
| «Ir a la línea» en la ficha | Salta al Editor en esa línea (`draftNavigation`) |
| Ninguna prueba elegida | **Mapa de calor** (4.3) |
| Pegar el link de una conversación en el chat | Se pinta su traza real (desde F0 en adelante) |

### 4.2.1 F1 — hecho (28/10/2026)

**Qué se hizo.** Pestaña **Diagrama** en el editor del Asistente, después de Configurar
(`Assistant.vue`, `draftTab === 'diagram'`), siempre visible (D1). `AgentDiagram.vue` dibuja en SVG
lo que calcula `agentDiagramLayout.js` (función pura).

**Cómo funciona.**
- Sale de la **misma estructura en bloques** que el árbol (`trainingStructure`, la que sincroniza
  `training_preview`) y de los **mismos hallazgos** (`nodeIssues`): lo que dice el árbol lo dice el dibujo.
- Una fila por ruta: **Cliente → Ruta → Fuente → Acción → Etiqueta**. La fuente se dice en palabras
  (Google Doc · Lista, Respuestas predefinidas · Gestión, Consulta al ERP…); la directiva cruda va en el
  tooltip. Sin acción, la fuente va directo a la etiqueta.
- Punteado: ruta sin fuente (contesta conversando) y el ramal de **Bienvenida** (solo el primer mensaje).
- Se marcan la **ruta por defecto**, la **etiqueta que falta** («no dispara automatizaciones») y la
  línea de ruta **mal escrita**; el punto rojo/ámbar es el del comprobador, con su texto en el tooltip.
- **Secciones** como fichas debajo: el motor las lee completas en cada respuesta (F0 §3.1), no son una
  columna del camino.
- Clic (o Enter) en un nodo → cambia a la pestaña del editor y selecciona su línea
  (`goToRouteFromDiagram` / `goToSectionFromDiagram`, con `first_line` de la estructura).
- Sin rutas: una sola fila «Sin rutas · contesta con todo el Entrenamiento» (estilo válido, no error).
- Ids de nodo estables y por nombre (`route:cotizar`, `source:cotizar`…): son los que F2 ilumina.
- Colores con `fill-`/`stroke-` de Tailwind (modo oscuro y temas `woot-*`); sin librería nueva.

**Pila de pruebas.** `agentDiagramLayout.spec.js` (23) y `AgentDiagram.spec.js` (6): filas y columnas,
sin acción, sin fuente punteada, por defecto, etiqueta faltante, bienvenida, cliente centrado, curvas,
hallazgos por nodo y por grupo, sin rutas, secciones, ruta rota, medidas, vacío, fuentes y acciones en
palabras; clic → `goToRoute`/`goToSection`, punto del comprobador, estado vacío. Toda la carpeta
`contactTrackings`: 200/200. Webpack: «Compiled successfully». ⚠ **Sin probar en navegador.**

**Cómo pedírselo al Asistente.** No hace falta: la pestaña está siempre; en el chat se puede decir
«mira el diagrama: la ruta soporte no tiene etiqueta» y el Asistente la agrega en el Entrenamiento.

### 4.2.2 F2 — hecho (28/10/2026)

**Qué se hizo.**
- Panel **Pruebas** en la columna izquierda (`leftPanel === 'tests'`, junto a Estructura, Chat e
  Instrucciones): `assistant/TestsPanel.vue`.
- Elegir una prueba → la pestaña **Diagrama** se abre con su camino iluminado (`diagramTest`).
- Backend: la pila acepta **pruebas escritas a mano** (`messages[]` en `POST …/test_battery`,
  máx. 10, `TestBatteryScenarios.own`, `kind: 'propia'`); cada resultado trae su **traza** (la de la
  primera respuesta del turno, `TestBatteryJob#trace`); el juez decide la ruta con la **traza** y solo
  sin traza cae a la `#etiqueta` (`TestBatteryJudge#route_ok`).

**Cómo funciona.**
- **En seco** (barato, contra el borrador, sin guardar): `dryRun` → `pathFromDryRun`.
- **En vivo** (el agente guardado contesta en el canal de pruebas): una prueba escrita o **Correr la
  pila** (las generadas) → `pathFromTrace`. La última pila del agente se retoma al volver (su id en
  `localStorage` por agente; el resultado vive dos días en la caché).
- `testPath.js` (puro) traduce cada resultado a ids de nodo del diagrama actual; **no inventa**: si la
  ruta ya no existe, no pinta y lo dice. El diagrama calcula el camino él mismo (`test` → `highlight`).
- Lo recorrido con el color del tema, lo demás tenue; **⚠ punto débil**: la fuente que no trajo nada y
  el turno cayó a conversar (en vivo), o la búsqueda vacía / fuente rota (en seco). Detalles en el nodo:
  «3 fragmentos · mejor 0.82», «cayó por defecto», «fuente en vivo: no se consulta en seco».
- Camino que contestó antes de las rutas (palabra clave, solicitudes, estado de caso…): se dice en la
  nota y solo se enciende el cliente.
- `testBatteryRunner.js` (mixin): arrancar y seguir la pila; lo usan el panel y `TestBatteryModal`.

**Lo que quedó para F3 (D4 a medias).** Los botones «Probar sin enviar nada» y «Probar el agente» de
la barra **siguen abriendo sus modales**: el modal en seco tiene historial y pruebas sugeridas que el
panel aún no tiene. Se quitan cuando la pila se guarde en BD (F3). Las pruebas en seco del panel viven
mientras la pantalla esté abierta.

**Pila de pruebas.** `testPath.spec.js` (12), `TestsPanel.spec.js` (4), `AgentDiagram.spec.js` (+2),
`test_battery_spec.rb` (+5: ruta por traza, pruebas propias, tope y limpieza, sin propias, traza de la
primera respuesta). Carpeta `contactTrackings`: 218/218; backend del Asistente: 569/569. Webpack:
«Compiled successfully». ⚠ **Sin probar en navegador ni contra un agente real.**

**Cómo pedírselo al Asistente.** Desde el panel Pruebas; en F4 «Llevar al chat» manda la prueba con
su camino al chat de creación.

### 4.3 Mapa de calor de la pila

```
                ┌──────────────┐
          ┌─────│ Cotizar  7 ❌2│  ← rojo: aquí está el problema
 Cliente ─┤     └──────────────┘
   12     │     ┌──────────────┐
          ├─────│ Soporte  4 ✅ │
          │     └──────────────┘
          │     ┌──────────────┐
          └─────│ Agenda   0    │  ← gris: ninguna prueba la toca → [+ Generar para Agenda]
                └──────────────┘
```

El grosor de cada línea es proporcional al número de pruebas que pasaron por ahí.

### 4.3.1 F3 — hecho (28/10/2026)

**Qué se hizo.**
- **Pila guardada por agente**: tabla `tracking_test_cases` (`TrackingTestCase`, migración
  `20261101100000`), tope 40 por agente. Cada prueba guarda su último resultado y el anterior, en seco y
  en vivo (`last_dry`/`previous_dry`, `last_live`/`previous_live`): el «antes» de F4 ya está.
- `ContactTrackings::Assistant::TestCases` + `AssistantTestCasesController`
  (`…/assistant/test_cases`: index, create, generate, update=fijar, destroy, run_dry, run_live).
- **Generar las que faltan**: una por ruta y una por regla (`TestBatteryScenarios`); `source_key`
  («ruta:cotizar», «regla:p1») evita duplicar.
- **Toda en seco** (`TestCasesDryJob`, contra el borrador) y **toda en vivo** (`TestBatteryJob` con
  `case_ids`: cada resultado vuelve a su prueba con su traza y sus tokens).
- **D5 al publicar**: `AssistantController#save` → `TestCases.after_publish` corre toda la pila en seco
  contra lo publicado, en el backend (la pantalla se vuelve a montar al publicar). Al abrir el panel:
  «la pila sigue igual (N)» o «N cambiaron de camino» + **Probar en vivo esas N · ~X tokens**
  (`live_candidates`: cambiaron de camino + rojas + fijadas 📌, tope `MAX_LIVE_OFFER` = 10). El aviso se
  da por visto por corrida (`localStorage`).
- **Mapa de calor** en el Diagrama sin prueba elegida (`heatFromCases`): «3 pruebas · 1 con falla» en cada
  ruta, la línea del cliente engorda con las pruebas, ruta con fallas en ámbar, ruta **sin pruebas**
  punteada y contada arriba («N rutas sin pruebas: genéralas en el panel Pruebas»).
- **D4**: «Probar el agente» abre el panel (y el Diagrama); `TestBatteryModal.vue` se eliminó (su lógica
  quedó en `testBatteryRunner.js`, el informe .md se descarga desde el panel).

**Cómo funciona la firma del camino.** `TestCases.dry_path`: ruta · modo y nombre de la fuente · motivo ·
¿trajo fragmentos? · ¿abre caso? · etiqueta. No entra la similitud: cambia con cualquier edición del
corpus y no es «otro camino».

**Costo.** Se muestra en **tokens** (de `traza.uso.tokens` de F0, o el promedio de la pila si una prueba
nunca corrió), no en $: el precio depende del modelo de la bandeja.

**Lo que sigue abierto (D4 a medias).** «Probar sin enviar nada» conserva su modal: ahí viven las
**pruebas sugeridas por IA** (Fase E) y el historial que alimenta el hito «Probado». Las pruebas en seco
del panel ya cuentan para «Probado» (`onPanelDryRun`). Pasar las sugeridas al panel (como «agregar a la
pila») queda para F4.

**Pila de pruebas.** `test_cases_spec.rb` (9), `assistant_test_cases_controller_spec.rb` (7),
`TestsPanel.spec.js` (6), `AgentDiagram.spec.js` (+2), `testPath.spec.js` (+1). Backend relacionado:
1074/1074; carpeta `contactTrackings`: 223/223. Webpack: «Compiled successfully».
⚠ **Sin probar en navegador ni contra un agente real.**

### 4.4 Antes / después

Tras corregir y volver a correr la **misma** pila:

```
 Prueba «¿precio del kit?»
   antes (v12)  Cliente ══► Soporte ══► predefinidas ══► #soporte      ❌
   ahora (v13)  Cliente ══► Cotizar ══► {{doc:Lista}} ══► #cotizar     ✅

 Pila: 9/12 ✅ → 11/12 ✅    ⚠ 1 prueba que antes pasaba ahora falla: «quiero agendar»
```

---

## 5. Evidencia → chat de creación

«💬 Llevar al chat» inserta en el chat del Asistente una tarjeta con la prueba:

```
┌ Evidencia · prueba 1 de la pila (v12) ─────────────────┐
│ Cliente: ¿precio del kit?                               │
│ Agente : Claro, el kit cuesta $450...                   │
│ Camino : Cotizar → {{doc:Lista}} (0.41 ⚠) → #cotizar    │
│ Juez   : ❌ Inventó un precio que no está en la Lista     │
└─────────────────────────────────────────────────────────┘
 ¿Qué cambiarías para que no pase?
```

- Al Asistente le llega la traza completa como contexto. Propone el cambio con el mismo
  mecanismo que ya usa para editar el Entrenamiento.
- Después de aplicarlo, el chat ofrece «↻ Volver a correr la pila» y muestra el antes y
  después (4.4).
- Se puede llevar **varias** pruebas a la vez (por ejemplo, todas las rojas de Cotizar).

### 5.1 F4 — hecho (29/10/2026)

**Qué se hizo.**
- **💬 Llevar al chat** (panel Pruebas): la prueba elegida, o **todas las rojas** a la vez (máx. 5), van
  al chat de creación como un turno normal (`testEvidence.js#evidenceMessage`): cliente, respuesta,
  camino (`pathSummary`), veredicto con sus fallas, «Prueba #N del canal de pruebas» y la pregunta
  «¿qué cambiarías en el Entrenamiento… dime qué cambia y por qué antes de aplicarlo?». El Asistente
  propone el cambio con el mecanismo de siempre (cambios visibles, nunca solo). Solo aparece con un
  Entrenamiento en pantalla.
- **Antes / ahora** por prueba (corrida anterior contra la última, en vivo o en seco) y **Ver antes en el
  Diagrama**, que ilumina la corrida anterior.
- **Pila antes / ahora** (`compareRuns`): «antes 9 de 12 cumplían, ahora 11» y **⚠ antes pasaba y ahora
  falla: «…»** por cada una que se rompió.
- **Sugerir con IA** en el panel (las pruebas sugeridas de la Fase E, con el clasificador real): cada una
  con su ruta esperada → **Agregar** a la pila como prueba de ruta (el juez califica a dónde cayó); sin
  guardar, queda como prueba suelta.
- **D4 cerrada**: «Probar sin enviar nada» y «Probar el agente» abren el panel y el Diagrama. Se
  eliminaron `DryRunModal.vue`, `DryRunPanel.vue` y `SuggestedTestsPanel.vue` (y 54 llaves de i18n que
  solo usaban ellos y el modal de la pila). Las pruebas en seco del panel siguen contando para el hito
  «Probado».

**Cómo funciona.** La evidencia es texto, no un formato nuevo para el backend: entra a
`sendMessage(texto, { evidence: true })`. `evidence` evita que un mensaje del cliente que diga
«conversación 5» desvíe el turno a la revisión de conversación (`mentionsConversation`); por lo mismo el
número de la prueba va como «Prueba #N», que no coincide con ese patrón (probado en el spec).

**Pila de pruebas.** `testEvidence.spec.js` (8), `TestsPanel.spec.js` (+5), `test_cases_spec.rb` (+1:
sugerida con ruta esperada). Carpeta `contactTrackings`: 235/235; backend del Asistente verde.
Webpack: «Compiled successfully». ⚠ **Sin probar en navegador ni contra un agente real.**

**Cómo pedírselo al Asistente.** Panel Pruebas → elegir la roja → **Llevar al chat** (o «Llevar las N
rojas al chat»). Después de aplicar el cambio: **Toda en vivo** (o publicar, y aceptar «Probar en vivo esas
N») y mirar «antes / ahora».

---

## 6. Qué más lo hace eficiente

1. **La pila se guarda con el agente**: hoy vive en la caché (`Rails.cache`) y se pierde. Se
   guarda en BD por agente y se vuelve a correr después de cada «Publicar cambios», para
   detectar si el cambio rompió algo.
2. **Comparar versiones**: correr la misma pila contra la v11 y la v12.
3. **Pruebas de varios turnos**: un diálogo corto (2–4 mensajes del cliente) para probar agenda,
   variables y `@crear_ticket`, que dependen de lo que ya se habló.
4. **Costo visible**: tokens y $ por prueba y por pila, antes de correr («~$0.04») y después.
5. **Seco o vivo por prueba**: la prueba en seco es barata y da solo el camino; la prueba en
   vivo da el camino y la respuesta. El diagrama dibuja las dos y marca cuál fue.
6. **Exportar evidencia**: el diagrama en SVG/PNG y la pila en .md (como en Grúas).
7. **Generar faltantes**: en el mapa de calor, «+ Generar para Agenda» sobre cualquier nodo gris.

### 6.1 F5 — hecho (29/10/2026)

**Qué se hizo.**
- **Pruebas de varios mensajes** (punto 3): `tracking_test_cases.turns` (migración `20261101110000`),
  2–4 mensajes del cliente. En el panel, casilla **Diálogo**: un mensaje por línea (Enter es otra línea).
  - **En vivo**: los mensajes van uno por uno a la misma conversación de prueba y cada uno espera su
    respuesta (`TestBatteryJob#converse`); la traza es la del último turno; el juez ve como «cliente»
    todo el diálogo hasta el último mensaje y califica la última respuesta (`#graded`). El panel muestra
    el diálogo turno por turno.
  - **En seco**: el último mensaje se clasifica con los anteriores como contexto
    (`TestCases.dry_inputs` → `DryRunService` con `recent_context`, como en producción); también la prueba
    suelta (`dry_run` acepta `recent_context`).
  - La evidencia al chat lleva cada turno.
- **Comparar versiones** (punto 2): **Comparar con una versión** → elegir la versión guardada →
  `TestCasesCompareJob` corre toda la pila en seco contra el texto de esa versión
  (`TrackingTemplateVersion#snapshot['complementary_prompt']`) y contra el borrador. «Contra la v7: 3 de 12
  toman otro camino», marca «distinta en v7» en cada prueba y **Ver en la v7 (soporte)** ilumina ese
  camino. Solo en seco (en vivo siempre contesta el agente guardado); no toca `last_dry`: es una consulta.
- **Exportar** (punto 6): **Descargar SVG / PNG** debajo del diagrama (`svgExport.js`): copia a cada
  elemento su estilo ya calculado (las clases de Tailwind no existen fuera del dashboard) y le pone el fondo
  del panel, así sale igual en claro u oscuro; el PNG va al doble de tamaño. Nombre: `diagrama-<agente>`.

**Costo (punto 4).** Ya estaba desde F3: tokens por prueba (`traza.uso.tokens`) y el estimado del aviso
de publicar. No se agregó un tablero de costo aparte.

**Pila de pruebas.** `test_cases_spec.rb` (+5: diálogo, tope de 4, contexto en seco, el job contesta cada
turno y lo que ve el juez, comparar versiones sin tocar resultados), controlador (+2), `TestsPanel.spec.js`
(+4), `testEvidence.spec.js` (+2), `svgExport.spec.js` (2), `AgentDiagram.spec.js` (+1). Frontend 244/244;
backend relacionado verde. Webpack: «Compiled successfully». ⚠ **Sin probar en navegador ni contra un
agente real.**

---

## 7. Fases

| Fase | Qué | Archivos principales | Se puede probar así |
|---|---|---|---|
| **F0** | Traza en el motor (`content_attributes.traza`) + spec | `knowledge_base_response_service.rb` (`send_reply`, `with_branch_tag`), router/clasificador, ¿camino de seguimientos? | Conversación en el canal de pruebas → la traza aparece en el mensaje |
| **F1** | Diagrama **sin iluminar** en la pestaña Diagrama (nodos desde la Estructura + avisos del comprobador) | `assistant/AgentDiagram.vue` (nuevo), `agentDiagramLayout.js` (nuevo, función pura + spec), `Assistant.vue` | Abrir agente #12877 → se ve su forma |
| **F2** | Panel **Pruebas** a la izquierda (pila + escribir una) y una prueba ilumina su camino | `assistant/TestsPanel.vue` (nuevo), reutiliza `TestBatteryModal`/`DryRunModal` por dentro, juez usa la traza en vez de la `#etiqueta` | Correr 1 prueba → se pinta |
| **F3** | Pila guardada en BD + mapa de calor + generar faltantes | migración `assistant_test_runs` (o similar), `test_battery.rb` | Correr la pila 2 veces, ver las dos |
| **F4** | Llevar al chat + volver a correr + antes/después | `Assistant.vue` (chat), servicio del Asistente | Corregir 1 falla desde el chat |
| **F5** | Varios turnos, comparar versiones, costo, exportar | `test_battery_scenarios.rb`, `AgentVersions` | — |

Al cerrar cada fase se registra en este .md qué se hizo, cómo funciona, su pila de pruebas
y cómo pedírselo al Asistente.

---

## 8. Reglas técnicas

- **SVG dibujado a mano en Vue**, sin librería nueva. El layout es una función pura
  (`agentDiagramLayout.js`) con su spec. Los colores salen del tema (incluido modo oscuro)
  y de los 10 temas del dashboard.
- Panel, ficha lateral, botones y tabla con **componentes nativos de Chatwoot**.
- `<template>` **sin `?.` ni `??`** (webpack 4): todo va a `computed`; verificar «Compiled successfully».
- Textos visibles en español de México con tú, y «ruta», nunca «rama».
- Las pruebas en vivo solo corren en el canal de pruebas (API sin webhook); nunca llegan a un cliente.
- RSpec con `POSTGRES_DATABASE=chatwoot_test`.

---

## 9. Decisiones abiertas

| # | Pregunta | Recomendación |
|---|---|---|
| **D1** | ¿El diagrama aparece solo con Pruebas abierto, o siempre (sin iluminar) mientras se crea? | **Siempre**, tenue; se ilumina con pruebas. Ver la forma ya ayuda a encontrar huecos |
| **D2** | ¿La traza se guarda en **todas** las conversaciones o solo en el canal de pruebas? | **Todas**: así «Revisar conversación real» también se pinta. Es pequeña (sin textos) |
| **D3** | ¿Las pruebas son de un solo mensaje o también de varios turnos? | Un mensaje en F2–F4; varios turnos en F5 |
| **D4** | ¿La pila y la prueba en seco dejan de ser modales y se mueven al panel Pruebas? | **Sí**; los modales quedan solo como componentes internos |
| **D5** | ¿Volver a correr la pila automáticamente al «Publicar cambios»? Cuesta tokens | ✅ **Decidida (28/10/2026)**, ver 9.1: en seco toda la pila siempre; en vivo solo lo que cambió, con OK y costo |
| **D6** | Quién puede correr pruebas en vivo (costo): ¿solo admin o también el agente humano? | Solo admin, igual que el Entrenamiento |

### 9.1 D5 — decidida (28/10/2026)

Importan las dos cosas: el gasto **y** que un cambio rompa algo sin que nadie lo note.

```
 Publicar cambios
       │
       ▼
 1. EN SECO toda la pila — automático, sin preguntar (DryRunService: ruta, fuente,
    fragmentos; no redacta) · ~1 llamada corta por prueba
       │
       ├── todas con el mismo camino ──────► ✅ «La pila sigue igual (12/12)»
       └── alguna cambió de ruta / fuente,
           o su similitud bajó ────────────► ⚠ «3 pruebas cambiaron de camino»
                                               [Probar en vivo esas 3 · ~$0.01] [Ahora no]
                                                      │
 2. EN VIVO solo las que cambiaron + las que ya estaban rojas + las reglas fijadas,
    con OK y costo a la vista → antes / después en el diagrama
```

- **Que no se rompa sin notarlo**: el seco corre siempre y sobre todo; no depende de acordarse.
- **El gasto**: lo caro (redactar + juez) solo en lo que cambió, y con OK. Sin cambios, $0 en vivo.
- **Punto ciego del seco**: el tono o una regla rota con el mismo camino. Por eso las pruebas de
  regla se pueden **fijar** para que siempre se ofrezcan en vivo, y queda «Correr todo en vivo».
- **Tope por publicación** (sugerido $0.10, configurable): si la corrida en vivo lo pasa, vuelve a
  pedir confirmación.
- **Estimado de costo**: promedio de `traza.uso.tokens` de las corridas anteriores de esa pila (F0).
- Se implementa en **F3** (pila guardada) + **F4** (antes/después).

