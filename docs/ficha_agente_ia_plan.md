# La ficha primero — reformar la creación de Agentes IA — Plan v0.1

> Rama: `feat/crear_agente_conversando` (se construye encima de lo que ya tiene).
> Estado: **F0–F6 hechas** (09/11/2026), sin probar en navegador y sin PR (el usuario pidió no subir a develop todavía). D1–D6 tomadas como se recomendó (§11).
> Fecha: 09/11/2026.

---

## 1. La idea (en palabras del usuario)

> «Cuando creo un agente IA nuevo, se debe estructurar la ficha donde se cargan archivos,
> definición de calendarios, canal… al definir la ficha esos serían los recursos para usar en el
> agente IA, donde en la conversación tiene que observar qué se puede hacer con esos recursos de la
> ficha; ya teniendo los recursos en la ficha se puede crear el prompt, las rutas y las secciones y
> todo lo demás. […] También seleccionar las fuentes de datos que se usarán en el prompt, y se
> requiere que sea muy fácil.»

En una línea: **primero se dice con qué cuenta el agente; después la conversación propone qué
puede hacer con eso; al final el sistema escribe el prompt.** Hoy es al revés.

---

## 2. Hoy contra la propuesta

```
 HOY                                            PROPUESTA
 ───────────────────────────────────            ─────────────────────────────────────────
 1. Nombre, bandeja, objetivo                   1. LA FICHA  (casillas, sin escribir prompt)
 2. Chat: «¿qué quieres que haga?»                 canal · archivos · agenda ·
    el chat ve TODAS las fuentes de la cuenta      FUENTES DE DATOS elegidas · tickets
 3. Se escribe el prompt con directivas            cada recurso dice si está listo
    (@buscar_predefinidas, {{hoja:…}}…)                         │
    la persona tiene que saber cómo se llaman                   ▼
 4. Agendas y Archivos se llenan aparte,        2. LA CONVERSACIÓN lee la ficha y OFRECE:
    en otras pestañas, sin relación con           «con esto tu agente puede: cotizar,
    lo que el prompt usa                           agendar, mandar el catálogo…» (probado)
 5. Se descubre en una conversación real                        │
    que una fuente estaba vacía                                 ▼
                                                3. EL ARMADO: definición, rutas, secciones,
                                                   variables y datos fijos salen solos;
                                                   pruebas + diagrama antes de publicar
```

El hueco más grande: **las fuentes de datos no se eligen en ningún lado.** Solo existen escritas
dentro del prompt. Por eso hay que saber el nombre exacto, la directiva y si la fuente sirve.

---

## 3. Lo que ya existe y se reusa

| Pieza | Qué hace | Dónde |
|---|---|---|
| `InventoryService` | Lista, sin IA, las fuentes de la cuenta, columnas de hojas, grupos de predefinidas, tipos de caso, etiquetas, agenda, frases reales | develop |
| `EngineCatalog` | Qué hace cada directiva y si la cuenta la tiene | develop |
| `SourceProfiles` + `AssistantTools` (`ver_fuente`, `probar_fuente`, `probar_ruta`…) | El chat ve qué tiene cada fuente y la prueba con una búsqueda real | esta rama (FR) |
| «Probar fuentes» (P1–P3) | Probar una fuente con una frase: parecido, exacto, en vivo | esta rama (§15) |
| Variables, Datos fijos, `BriefFromChat`, `DraftingFields` | La conversación llena Definición, Variables y Datos fijos | esta rama (F1–F3) |
| Diagrama + Pruebas | Ver por qué ruta cae cada frase y probar antes de publicar | `feat/diagrama_agente_ia` (base de esta rama) |
| Pestañas Agendas y Archivos del agente | Calendarios (`calendar_integration_ids`, `booking_calendar_ids`) y archivos `{{nombre}}` | develop |
| Categorías de predefinidas | Agrupar respuestas por categoría | develop (PR #141); el motor aún busca por prefijo (R4) |

**Lo nuevo es poco:** la pantalla de la ficha, guardar qué fuentes eligió, el mapa recurso →
«lo que puede hacer», y que el chat y el comprobador respeten la ficha.

---

## 4. Paso 1 — La ficha

Una sola pantalla por secciones, sin scroll dentro de modales, con componentes nativos. **Nada
de directivas ni nombres técnicos a la vista.**

```
 ┌ Nuevo agente ─────────────────────────────────── ① Ficha  ② Conversación  ③ Armado ┐
 │                                                                                    │
 │  Nombre  [ Ventas Grúas Norte          ]   Canal  [ WhatsApp Ventas      ▾ ]      │
 │                                                                                    │
 │  ── Fuentes de datos ─ ¿de dónde saca las respuestas? ───────────────────────────  │
 │  ┌──────────────────────┐ ┌──────────────────────┐ ┌──────────────────────┐        │
 │  │ ☑ 📊 Hoja «Precios»   │ │ ☑ 💬 Predefinidas     │ │ ☐ 📄 Doc «Políticas»  │        │
 │  │ 48 filas · Servicio, │ │ PATITAS (14) ✓       │ │ 6 apartados          │        │
 │  │ Zona, Precio         │ │ SSUSA (6)   ☐        │ │                      │        │
 │  │ ✓ lista  [Ver] [Probar]│ │ ⚠ 2 sin vectorizar  │ │ ✓ lista  [Ver]       │        │
 │  └──────────────────────┘ └──────────────────────┘ └──────────────────────┘        │
 │  ┌──────────────────────┐ ┌──────────────────────┐                                │
 │  │ ☐ 🗣 Foro Kontrolya   │ │ ☐ 🏭 ERP (no conectado)│  [+ Conectar otra fuente]     │
 │  └──────────────────────┘ └──────────────────────┘                                │
 │                                                                                    │
 │  ── Agenda ─────────────────  ── Archivos ──────────────  ── Tickets ───────────  │
 │  ☑ Citas Sucursal Norte ✓   │  Catálogo.pdf   [Subir]   │  ☑ Cotización          │
 │    duración 30 min          │  Precios.pdf              │    pide nombre, tel.   │
 │                                                                                    │
 │  Listo para conversar: 4 recursos ✓ · 1 aviso ⚠        [Siguiente: conversar ▸]   │
 └────────────────────────────────────────────────────────────────────────────────────┘
```

### 4.1 Elegir fuentes de datos «muy fácil»

| Regla | Cómo |
|---|---|
| **Tarjetas con casilla**, no listas ni texto | Una tarjeta por fuente conectada en la cuenta; marcar = el agente la usa |
| **Cada tarjeta dice qué tiene** | De `SourceProfiles`: columnas y filas de la hoja, títulos del doc, categorías de predefinidas |
| **Cada tarjeta dice si está lista** | ✓ lista · ⚠ con aviso (sin vectorizar, hoja vacía, calendario sin conectar) · ✗ no conectada. El aviso trae el botón para arreglarlo |
| **Ver y Probar en la misma tarjeta** | [Ver] abre la ficha de la fuente; [Probar] es «Probar fuentes» con una frase |
| **Dentro de una fuente se elige el pedazo** | Predefinidas por categoría, artículos por categoría, ERP por consulta, hoja completa. Por omisión, toda la fuente |
| **Lo no conectado se ve, apagado** | «ERP (no conectado)» con [Conectar]: la persona descubre qué más puede tener |
| **Sugerir sin decidir** | Si la bandeja ya tiene un agente o hay frases reales, se pre-marcan las fuentes que más se parecen a lo que preguntan los clientes, con la etiqueta «sugerida» |

### 4.2 Qué se guarda

Una columna nueva `tracking_templates.resources` (jsonb). Agenda y archivos ya tienen sus
columnas y tablas; aquí solo se guarda lo que hoy no existe:

```json
{
  "sources": [
    { "type": "google_sheet",    "id": 12, "name": "Precios" },
    { "type": "canned_response", "categories": [3] },
    { "type": "article",         "categories": [] },
    { "type": "erp",             "queries": ["buscar_producto"] }
  ],
  "case_types": [5],
  "confirmed_at": "2026-11-09T18:00:00Z"
}
```

Por id, no por nombre: si renombran la hoja, la ficha no se rompe. El nombre se resuelve al
mostrar y al escribir la directiva.

---

## 5. El mapa recurso → «lo que puede hacer»

Es la pieza que convierte la ficha en ofertas que la persona entiende. Sale de `EngineCatalog`,
sin IA:

| Recurso en la ficha | Lo que el chat ofrece | Lo que escribe en el prompt |
|---|---|---|
| Hoja con columnas | «Contestar precios/datos exactos buscando en la hoja» | `{{hoja_buscar: …}}` / `{{hoja:…}}` |
| Documento | «Contestar con lo que dice el documento» | `{{doc:…}}` |
| Predefinidas (categoría) | «Contestar dudas frecuentes con tus respuestas» | `@buscar_predefinidas(CATEGORÍA)` |
| Artículos | «Contestar con tus artículos de ayuda» | `@buscar_articulo` |
| Foro / CONTPAQi | «Buscar soluciones en el foro» | `@buscar_foro(…)` / `@soporte_contpaq(…)` |
| ERP | «Consultar existencias, precios o saldos en el ERP» | `{{consulta:…}}` |
| Agenda | «Agendar citas y ofrecer horarios» | directivas de agenda |
| Archivo | «Mandar el archivo cuando lo pidan» | `{{nombre}}` |
| Tipo de ticket | «Abrir un ticket con los datos que pide» | `@crear_ticket(…)` |

Una prueba de completitud (como la de `InventoryService`) falla si un tipo de recurso no está en
el mapa.

---

## 6. Paso 2 — La conversación lee la ficha

```
 ficha ──► mapa §5 ──► probar_fuente con frases reales ──► primer mensaje del chat
                                                         (no espera a que escribas)

 Asistente: Revisé la ficha de «Ventas Grúas Norte». Con lo que le diste puede:
   ✓ Cotizar con la hoja «Precios»       probé «plataforma en el norte» → $1,800
   ✓ Contestar dudas con PATITAS (14)    probé «cancelar cita» → «Política de cancelación»
   ✓ Agendar en «Citas Sucursal Norte»
   ✓ Mandar «Catálogo.pdf» si lo piden
   ✓ Abrir un ticket «Cotización»
   ⚠ 2 respuestas de PATITAS no están vectorizadas: no las encontraría  [Vectorizar]
 ¿Cuáles quieres que haga? ¿Y qué hace si el cliente pide algo que no está aquí?
```

Cambios contra hoy:

- **El chat recibe la ficha, no toda la cuenta.** El inventario completo solo se usa para decir
  «esto también existe, ¿lo agrego a la ficha?».
- **Primer mensaje automático** con las ofertas ya probadas. Si una prueba falla, lo dice.
- **Solo pregunta lo que la ficha no dice:** objetivo, tono, a quién pasar, qué no debe hacer.
- **Si en la plática sale un recurso que no está en la ficha** («también quiero que mande la
  garantía»), el chat propone agregarlo: botón [Agregar a la ficha], sin salir de la conversación.

---

## 7. Paso 3 — El armado

Lo que ya hace la rama (F3 `BriefFromChat`, rutas probadas FD, diagrama), con dos reglas nuevas:

1. **Solo directivas de la ficha.** El redactor recibe la ficha; una ruta que use una fuente
   fuera de ella no se escribe.
2. **El comprobador lo vigila después.** Regla nueva: «esta ruta usa la hoja *Inventario*, que no
   está en la ficha» → pintado en el editor y con punto en el árbol (como pide el comprobador:
   todo lo mal escrito se ve).

```
 ① Ficha ✓   ② Conversación ✓   ③ Armado
 ┌───────────────────────────────────────────────────────────────┐
 │ Definición ✓   Rutas (4) ✓   Secciones ✓   Variables (2) ✓    │
 │ Pruebas: 12/12 frases caen en su ruta  [Ver diagrama]         │
 │                       [Volver a la conversación]  [Publicar]  │
 └───────────────────────────────────────────────────────────────┘
```

---

## 8. La ficha sigue viva

Después de crear el agente, la ficha es la **primera pestaña del espacio del agente**:

- Se agrega una fuente o un archivo → aviso en el chat: «tu agente ahora puede X, ¿agrego la
  ruta?».
- Se quita una fuente que una ruta usa → aviso antes de guardar, con las rutas afectadas.
- Una fuente deja de estar lista (OpenAI apagado, hoja borrada, calendario desconectado) → la
  tarjeta se pone ⚠ y el agente sale con aviso en la lista de agentes.

---

## 9. Agentes que ya existen

Su ficha se **deduce del prompt** con `KnowledgeBase::Directives.detect`: cada directiva que use se vuelve una
casilla marcada. La persona la ve con la etiqueta «deducida de tu prompt» y la confirma. Mientras
no la confirme, nada cambia en cómo contesta.

---

## 10. Fases

| Fase | Qué | Notas |
|---|---|---|
| **F0** | Poner la rama al día (rebase sobre `feat/diagrama_agente_ia` ya rebasada sobre develop) + medir: cuántos agentes de dev usan cuántas fuentes; cuántos usarían fuentes no listas | Sin código nuevo |
| **F1** | `resources` jsonb + API + mapa §5 + deducir la ficha del prompt (§9) | Sin IA. Specs de completitud |
| **F2** | Pantalla de la ficha (§4): tarjetas, estado listo/aviso, Ver/Probar, subselección por categoría | Reusa `SourceProfiles`, `SourceProbePanel`, Agendas y Archivos |
| **F3** | El chat lee la ficha: primer mensaje con ofertas probadas, [Agregar a la ficha] | Gasta OpenAI: pedir OK antes de la prueba real |
| **F4** | Armado respeta la ficha + regla nueva del comprobador | Probar contra todos los agentes de dev |
| **F5** | Asistente de 3 pasos en «Nuevo agente» + ficha como primera pestaña del agente + avisos de §8 | |
| **F6** | R4 de predefinidas (categoría o prefijo en `@buscar_predefinidas`) si D5 lo pide | Viene de `docs/respuestas_predefinidas_plan.md` |

---

## 11. Decisiones

| # | Pregunta | Recomendación |
|---|---|---|
| **D1** | ¿La ficha limita al agente cuando contesta, o solo guía la creación? | **v1: guía + comprobador** (no se publica una ruta con fuente fuera de la ficha). El motor no cambia. Limitar en el motor se decide después de usarla |
| **D2** | Agentes existentes | Deducir la ficha del prompt y que la persona confirme (§9) |
| **D3** | ¿Ficha obligatoria para agentes nuevos? | Sí. «Importar .md» y «Bajar prompt publicado» quedan como opción avanzada que también llena la ficha |
| **D4** | ¿Sobre qué rama? | `feat/crear_agente_conversando` (ya tiene casi todo). **Aceptada al pedir el plan** |
| **D5** | Predefinidas en la ficha: ¿por categoría o por grupo (prefijo)? | Por categoría, con R4 en F6; mientras tanto se muestran los grupos por prefijo |
| **D6** | ¿Dónde vive la ficha? | Asistente de 3 pasos al crear; después, primera pestaña «Ficha» del espacio del agente (las pestañas Agendas y Archivos de hoy se mueven ahí) |

---

## 12. Riesgos

| Riesgo | Cómo se cuida |
|---|---|
| La ficha y el prompt se desincronizan (alguien edita el prompt a mano) | Regla del comprobador (§7) + aviso al quitar fuentes (§8) |
| Una cuenta con muchas fuentes vuelve la pantalla larga | Tarjetas por tipo, plegables; arriba las sugeridas |
| El chat ofrece algo que la fuente no sostiene | Cada oferta va probada con `probar_fuente`; sin prueba buena, no se ofrece como ✓ |
| Costo de OpenAI al abrir la conversación | Las pruebas de parecido usan los vectores guardados; solo el primer mensaje del chat gasta |
| Esta rama no tiene PR y crece | F0 la pone al día; considerar PR de lo hecho (F0–F4 + §15) antes de F2 |

---

## 13. Avance (09/11/2026)

Pedido del usuario: «ejecuta todo y ya al final vemos cómo queda, pero me debe permitir generar un
agente IA en unos cuantos clics al definir lo que usará en la ficha… aún no se debe subir a
develop». Y: «si modifico la ficha se deben detectar esos cambios para el prompt y mencionarlo».

### F0 — rama al día ✅
`feat/crear_agente_conversando` rebasada sobre `feat/diagrama_agente_ia` (al día con develop
de9beb39); tag local `respaldo-crear-agente-antes-rebase-0911`. AgentWorkspace.spec contaba mal
las pestañas (faltaba «Probar fuentes»): corregido.

### F1 — guardar la ficha y el mapa recurso → oferta ✅
- `tracking_templates.resources` jsonb (migración `20261111100000`):
  `{ items: [{ key: 'google_sheet:12' }, { key: 'canned_response', parts: ['PATITAS'] }], confirmed_at }`.
- `ContactTrackings::Ficha::Catalog`: una tarjeta por recurso (hojas, documentos, artículos,
  predefinidas por grupo, foro, CONTPAQi, Discourse del canal, consultas del ERP, agendas, tipos de
  ticket, archivos del agente) con `status` ready/warn y el motivo (sin filas, sin vectorizar,
  falta OpenAI, Google vencido). Reusa `SourceProfiles`.
- `Ficha::CannedGroups`: categorías + prefijos de las que no tienen categoría, con `not_ready`.
- `Ficha::Offers`: cada recurso → «lo que puede hacer» + su ruta (`RouteMap::LINE_RE`):
  agenda y ticket como acción (`- -> …`), grupos de predefinidas con <4 respuestas juntos en una
  ruta sin grupo (como pide `CorpusChecks`), ERP con prefijo de conexión y `param=?`.

### F2/F5 — pantallas ✅
- Agente nuevo: **asistente de 3 pasos** en la pestaña «Recursos» (primera, D6):
  ① Recursos (nombre, canal, tarjetas) → ② Qué hará (ofertas prendidas, tono, datos del negocio)
  → ③ Revisar y crear (rutas en palabras, comprobador, «Ver el Entrenamiento»). La vista previa
  se recalcula sola. «Prefiero crearlo conversando» lleva al Entrenamiento de siempre.
- Agente que ya existe: pestaña **Recursos** con las tarjetas, «Cambios para el Entrenamiento»
  ([Agregar ruta] / [Quitar ruta] / [Aplicar todos]) y número en la pestaña si hay pendientes.
- Componentes: `ficha/FichaCards.vue`, `ficha/FichaWizard.vue`, `ficha/AgentFicha.vue`;
  API `dashboard/api/fichaAgente.js`.

### F3/F4 — generar sin IA y respetar la ficha ✅
- `Ficha::Generator`: escribe rutas + `@ruta_por_defecto` + [ROL] [ALCANCE POR RAMA] [FIDELIDAD]
  [ETIQUETAS] ([ARCHIVOS]) [ESTILO] [PROHIBIDO] y corre `ValidatorService`. **No gasta OpenAI.**
  Medido: con TODO lo de la cuenta 2 marcado (35 rutas) → 0 bloqueos, 0 avisos, 0 cosméticos;
  las 3 cuentas de dev con recursos → 0 hallazgos.
- `Ficha::Changes`: ficha contra prompt → `added` / `removed` / `not_ready`; `deduced` para los
  agentes que ya existían (D2). Medido contra los 18 agentes de dev con rutas: **0 cambios falsos**.
- `Ficha::PromptEditor`: aplica agregar/quitar ruta (con su línea de alcance y etiqueta, y la ruta
  por defecto si hacía falta); el resultado pasa por el comprobador antes de guardar.
- **El chat lo menciona**: `InterviewTurn` pasa `Changes#chat_lines` al Asistente («CAMBIOS EN LA
  FICHA… menciónalos y no cambies nada sin su OK»).
- D1: la ficha guía y el panel/chat avisan; el motor no cambia.

### F6 — R4 de respuestas predefinidas ✅
`@buscar_predefinidas(X)`: si hay una categoría X, busca por `metadata.category`; si no, por
prefijo. En el motor (`KnowledgeBaseResponseService.grouped_items`), en la prueba en seco
(`KnowledgeBase::CannedGroup`, amarradas por `canned_group_spec`) y en el conteo del comprobador
(`CorpusChecks#canned_count_for`).

### API
| | |
|---|---|
| `GET tracking_templates/ficha_catalog?inbox_id=` | tarjetas |
| `POST tracking_templates/ficha_preview` | ofertas + Entrenamiento + comprobador |
| `POST tracking_templates/ficha_create` | crea el agente (422 si el comprobador bloquea) |
| `GET/PATCH tracking_templates/:id/ficha` | ficha + cambios / guardar lo marcado |
| `POST tracking_templates/:id/ficha/apply` | `add[]` ofertas, `remove[]` rutas |

### Pila de pruebas
- rspec: `spec/services/contact_trackings/ficha/*` (catálogo → ofertas → generador sin
  hallazgos; cambios, deducción, predefinidas sin grupo, aplicar), `fichas_spec` (solo admin,
  catálogo → vista previa → crear, guardar → cambios → aplicar), `canned_group_spec` (categoría,
  negada, prefijo, paridad con el motor). Más 196 existentes de chat, comprobador y motor en verde.
- vitest: `ficha/Ficha.spec.js` (tarjetas, grupos, 3 clics, no crear con errores, aplicar todos
  sin repetir rutas) + `AgentWorkspace.spec.js`; 330 de Agentes IA en verde.

### Cómo se usa
1. Agentes IA → Nuevo → pestaña **Recursos**: nombre, canal, marcar tarjetas → Siguiente.
2. Quitar lo que no quieras que haga, tono → Siguiente.
3. Revisar → **Crear agente**. Abre el Entrenamiento para afinarlo con el Asistente o a mano.
4. Después, en **Recursos**: marcar/desmarcar → Guardar ficha → aplicar los cambios que se listan
   (o pedírselo al Asistente en el chat: ya los conoce).

### Pendiente
- Probar en navegador. - Subir archivos desde la ficha (hoy: Ficha › Archivos; `fix/archivos_varios`
  PR #150 trae subir varios). - Mover Agendas/Archivos dentro de Recursos (D6 completa).
- Avisar en el comprobador (pintado en el editor) la ruta con recurso fuera de la ficha: hoy se ve
  en Recursos y en el chat.

---

## 14. Avance (09/11/2026, segunda tanda)

Pedidos del usuario: siguiente-siguiente (Recursos → Ficha de Agente IA → Entrenamiento…),
Reglas, ✨ objetivo y contexto, continuar la conversación anterior, y las ideas 1 y 2 de
«más facilidad».

| Pieza | Qué hace | Commit |
|---|---|---|
| Recursos + menú + panel en vivo | Fuentes (buscador fijo, tipos, detalle) · Agenda · Tickets · Archivos · Reglas | 0721c535, b72d39d1, c316f486 |
| Siguiente-siguiente | Nuevo: solo Recursos → [Continuar] Ficha de Agente IA → [Crear] lo demás; orden de pestañas igual en existentes | 2d1dd3f9, b6b212bf |
| ✨ Proponer con IA | Ficha::Suggester (gpt-4o, 1 llamada): objetivo + contexto del negocio; faltantes como chips, nunca `<PENDIENTE:>` | 2d1dd3f9 |
| Continuar conversación | TrackingAssistantSession.previous_for / #continue_as: nueva con historial + Entrenamiento de hoy | f90d8090 |
| **Probar antes de crear** | Ficha::TestPhrases (frases del contenido de cada recurso + reales de clientes) → Tester (clasificador real) → TestJob (Redis/TurnProgress). Falla o ruta por defecto → [Agregar la frase a la ruta] (se suma a la descripción, sin IA) | a86128b6 |
| **Listo para atender** | Ficha::Readiness: OpenAI · canal · recursos con aviso · datos del negocio · quién se lo asigna; [Activar en su canal] = automatización conversation_created → assign_tracking_template (con confirmación; al crear, casilla) | a86128b6 |
| Arreglo Definición | La Estructura mostraba vacía la Definición de un agente existente (proposal = null); publicar en reemplazo ahora guarda objetivo/contexto (vacío no borra) | a86128b6 |

Medido en la cuenta 2 (con OK del usuario): prueba de 4 rutas = 14 llamadas en 12 s, 8/8
frases de recursos en su ruta; de 6 frases reales, 4 caían en la ruta por defecto; tras
agregar «¿a qué hora atienden?» a la agenda, esa frase ya cae ahí.

API nueva: `POST ficha_test` (202, turn_id) · `GET ficha_test/:turn_id` · `POST :id/ficha/activate`
· `ficha_create` con `activate` y `phrases` · `GET/POST assistant/sessions/previous|:id/continue`.

Pendiente: probar en navegador; juntar Agenda/Archivos solo en Recursos; «empezar desde un tipo
de negocio» (idea 3); PR (el usuario pidió no subir a develop todavía).
