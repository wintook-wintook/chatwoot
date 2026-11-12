# Agentes IA con herramientas — plan

> Rama: `docs/entender_agentes_ia` · 12/11/2026 · estado: **propuesta, sin implementar**.
> Diagrama del motor actual: [`diagrama_agente_ia_flujo.svg`](diagrama_agente_ia_flujo.svg).
> Este documento es autosuficiente: resume lo conversado para retomarlo desde otra instancia.

## 1. Objetivo

Un canal tiene **un solo bot** que lee la conversación, decide qué recurso usar (hojas de Google,
predefinidas, docs, foro, ERP, calendario…) y responde. Agregar una fuente nueva tiene que ser
**marcar una casilla**, no reescribir el prompt. El agente se arma **con unos cuantos clics**.

Caso piloto: **AGENTE ESCUELA** de la cuenta 1128.

## 2. Diagnóstico: cómo funciona hoy

### 2.1 Motor de seguimientos (el de AGENTE ESCUELA)

`app/jobs/contact_tracking_response_analyzer_job.rb` (~2,550 líneas), con
`process_message_for_tracking` y `try_kbase_then_conversational` como columna.

- **No es multiagente, y tampoco es un agente con herramientas.** Es una **cascada fija de unas 20
  guardias** en Ruby: la primera que contesta, corta (ver el diagrama, sección 2).
- El modelo solo **clasifica** (JSON corto: rama, acción de cita, consulta de hoja) y **redacta** con lo
  que Ruby ya buscó. **Nunca elige la fuente.**
- Por eso existe la gramática `@ruta(rama #etiqueta: descripción): fuente -> escalamiento`: alguien
  tiene que escribir a mano "si hablan de X, busca en Y". El prompt hace dos trabajos a la vez
  (configuración + personalidad) y es frágil: una directiva mal escrita no da error, simplemente
  no existe.
- Mucho de la complejidad (estados `[PENDING_SLOT]`/`[PENDING_EMAIL]`, "la agenda gana a la KBase",
  clasificador de ramas, SectionFit, TopicSwitch) son **parches de un diseño donde el modelo no
  puede elegir**.

### 2.2 Agentes listos (beta) — ya es el modelo propuesto

`app/services/ready_agents/runner.rb` (mismo motor que `app/services/ai_follow_ups/runner.rb`):

- Tool calling **nativo** de OpenAI (`tools:` + `tool_choice: 'auto'`), hasta `MAX_ROUNDS = 6`.
- El modelo lee **toda** la conversación y elige herramienta.
- Herramientas actuales (`app/services/ready_agents/tool_definitions.rb`): `buscar_respuesta_predefinida`,
  `buscar_en_catalogo`, `guardar_respuesta`, `actualizar_contacto`, `prospecto_calificado`,
  `descartar` y `pasar_a_humano`; con cita: `ver_horarios`, `agendar_cita`, `mover_cita` y `cancelar_cita`.
- Ya tiene chat de prueba (`Runner#test`), registro de herramientas usadas (`used_tools`) y
  configuración por formulario.
- **Le falta:** hojas de Google, docs, foro, ERP y CONTPAQi. Esas fuentes solo las conoce el motor viejo.

## 3. AGENTE ESCUELA hoy (plantilla 1583)

- **Plantilla 1583** «Agente Escuela Universidad v2 [TEST API]»: canal de prueba **2450**, regla **716**,
  Entrenamiento de **~12,000 caracteres**.
- **Plantilla 1581**: la del canal real **2449**, ~5,000 caracteres. No tiene los ajustes de la 1583.

Qué hay dentro del Entrenamiento de la 1583:

| Sección | Qué es en realidad | Dónde debería vivir |
|---|---|---|
| 3 líneas `@ruta` con listas enormes de palabras | ruteo a mano para que el clasificador acierte | desaparece: el modelo elige la herramienta |
| `[CATÁLOGO]` (10 carreras + RVOE) | datos, ya repetidos en las predefinidas | se saca de las fichas (`listar_carreras`) |
| `[IMÁGENES DE BECA]` (20 `{{imagen}}`) | datos | la imagen pegada a cada beca de la ficha |
| `[DATOS DE LA ESCUELA]` (dirección, pagos, documentos) | datos | formulario «Datos del negocio» |
| `[PRECIO Y BECAS — UN PASO POR MENSAJE]` + `[VARIABLES]` + `[CUÁNDO CAMBIAN LAS VARIABLES]` | máquina de estados escrita en prosa: el modelo lleva PRECIO_DADO / SIGUIENTE_OFERTA / CARRERA | Ruby lleva el paso (receta «ofertas escalonadas») |
| `[ROL]`, `[ESTILO]`, `[FIDELIDAD]`, `[DESPEDIDA]`, parte de `[PROHIBIDO]` | instrucciones de verdad | lo único que queda como prompt (~1,500 caracteres) |

**Datos de origen.** Las carreras vienen de una hoja de Google del cliente, que copiamos **a mano** a predefinidas:
- ids 2809-2818: una por carrera;
- 2819-2824: bloques comunes «Licenciaturas: …»;
- categorías: Licenciatura (4), Maestría (5) e Información (8).

**Último resultado (11/11/2026).** 23 hojas de pruebas, **410 preguntas**: **77% correctas**, 14 fallas graves.

Las fallas que quedan salen de esa mezcla:
- becas juntas;
- montos o becas de otra carrera;
- ligas inventadas;
- ficha cortada a 2,000 caracteres o fuera del top-3 de la búsqueda;
- "no tengo información" cuando la predefinida sí existe.

Ninguna se arregla con mejor prosa: hay que **sacar esas tareas del modelo**.

## 4. Diseño propuesto

### 4.1 Principios

1. **Cada fuente es una herramienta.** El modelo elige; la descripción de la herramienta reemplaza a `@ruta`.
2. **Los datos no van en el prompt.** Van en fuentes (hoja, predefinidas, formulario).
3. **La lógica con estado la lleva Ruby.** El modelo dispara la acción ("el cliente objetó el precio") y
   Ruby decide el paso que toca.
4. **Datos con forma de tabla → búsqueda exacta, no por parecido.** Una fila por carrera se lee por su
   clave (nombre), no con pgvector + top-3 + recortes.
5. **El prompt lo genera el sistema** desde el formulario y queda corto. Se admiten "reglas extra" en
   texto libre.
6. **Ruby conserva las guardias duras:**
   - baja (opt-out), un humano ya tomó la conversación, no contestar dos veces;
   - límite de rondas, zonas horarias / fechas, confirmar antes de agendar;
   - **todo monto de la respuesta debe aparecer en lo que devolvieron las herramientas** (si no, se
     regenera o se pasa a humano).

### 4.2 Herramientas para AGENTE ESCUELA

```
ficha_carrera(nombre)        → la fila completa de ESA carrera (búsqueda exacta, con alias/sinónimos);
                                Ruby guarda CARRERA en la conversación
listar_carreras()            → catálogo sacado de las mismas fichas (nivel, nombre, RVOE)
siguiente_oferta(carrera)    → receta «ofertas escalonadas»: precio normal → 1ª beca + imagen →
                                2ª beca + imagen → "es la mejor opción"; Ruby avanza el paso
                                (por carrera; si cambia de carrera, la otra conserva su paso)
buscar_info_general(tema)    → predefinidas de Información (pagos, documentos, presencial, titulación…)
pasar_a_humano(motivo)       → WhatsApp 55 6857 4646, 8–16 h L-S / asignar asesor
```

Con eso desaparecen por construcción:
- **Dos becas juntas:** la herramienta nunca las devuelve juntas.
- **Beca de otra carrera:** la ficha es exacta.
- **Liga inventada:** la liga viene en la ficha y Ruby puede validar que la URL de la respuesta esté en ella.
- **Fichas cortadas:** no hay recorte por similitud.

### 4.3 Herramientas genéricas (para cualquier canal)

| Herramienta | Reutiliza |
|---|---|
| `buscar_en_hoja(fuente, consulta)` / `fila_de_hoja(fuente, clave)` / `calcular_en_hoja(fuente, filtros)` | `KnowledgeBase::SheetRowFit`, `ContactTrackings::SheetLookup`, `SheetQueryService` |
| `buscar_predefinidas(grupo, consulta)` | `AiFollowUps::KnowledgeSearch`, `KnowledgeBaseResponseService.grouped_items` |
| `buscar_en_doc(fuente, consulta)` | `perform_google_doc` + `KnowledgeBase::SectionFit` |
| `buscar_en_foro(fuente, consulta)` | `KnowledgeBase::DiscourseSemanticSearch` |
| `consultar_erp(consulta, params)` | `ExternalDb::AskedConsulta` |
| `soporte_contpaq(pregunta)` | `Contpaq::ServiceAgent` |
| `ver_horarios` / `agendar_cita` / `mover_cita` / `cancelar_cita` | ya en `ReadyAgents::Appointments` (+ `AvailabilitySlotService`, `GoogleCalendarService`) |
| `crear_caso` / `estado_caso` | `Cases::TicketCreatorService`, `Cases::TicketStatusService` |
| adjuntar archivo | `ContactTrackings::AgentAttachments` (`{{nombre}}`) |

**Trabajo de fondo:** hoy esos servicios hacen "busca **y envía**" dentro de `KnowledgeBaseResponseService`.
Hay que separarlos en "busca y **devuelve** el resultado" para que funcionen como herramienta. El motor
viejo puede seguir usando la misma pieza.

**Muchas fuentes.** Hasta ~15-20, una herramienta por fuente, con su descripción. Con más, una
herramienta genérica `buscar(fuente, consulta)` con `enum` de fuentes y la descripción de cada una.

### 4.4 Asistente de configuración ("unos cuantos clics")

```
1. Canal ............ [2449 WhatsApp Universidad]
2. Quién es ......... Nombre · Empresa · Trato [tú/usted] · Emojis [sí/no] · Largo máx.
3. Qué sabe ......... ☑ Hoja "Carreras" (una fila = una carrera, clave: Nombre)
                      ☑ Predefinidas: Información
                      ☐ Calendario   ☐ Foro   ☐ ERP   ☐ Doc …
                      (cada una con "para qué sirve": sugerido por la IA leyendo el contenido, editable)
4. Recetas .......... ☑ Ofertas escalonadas: [Precio normal] → [1ª beca + imagen] → [2ª beca + imagen] → texto final
                      ☑ Despedida / pasar a humano: WhatsApp, horario
                      ☐ Agendar cita   ☐ Calificar prospecto   ☐ Levantar caso
5. Reglas extra ..... texto libre opcional ("no negar plantel ni bachillerato")
6. Probar ........... chat de prueba + batería de preguntas → % de aciertos  →  [Publicar]
```

El prompt se arma con 2 + 5 + las descripciones de 3 + las reglas de 4. Agregar una fuente = una casilla.

## 5. Qué se reutiliza y qué es nuevo

**Ya existe:**
- Ciclo con herramientas, chat de prueba y formulario: Agentes listos.
- Agenda: `ReadyAgents::Appointments`.
- Adjuntos, variables de conversación (`ContactTrackings::ConversationVariables`), lectura de hojas,
  búsqueda en predefinidas, docs, foro, ERP y CONTPAQi.
- Batería de pruebas del asistente: `ContactTrackings::Assistant::TestBattery`.

**Nuevo de verdad:**
1. `fila_de_hoja` / `ficha_carrera`: búsqueda **exacta** por clave en una hoja, con alias.
2. Receta **ofertas escalonadas**: estado por conversación y por clave (carrera), avanzado por Ruby.
3. Envolver las fuentes del motor viejo como herramientas (separar "buscar" de "enviar").
4. Paso 3 del asistente: elegir fuentes + descripción sugerida.
5. Guardia de montos y ligas: cada cifra o URL de la respuesta debe estar en los resultados de herramientas.

## 6. Fases

| Fase | Qué | Criterio de salida |
|---|---|---|
| F0 | Este plan + diagrama (hecho) | — |
| F1 | Prototipo AGENTE ESCUELA en Agentes listos con las 5 herramientas de §4.2 (hoja de carreras conectada directa), canal de prueba **2450** | contesta los 7 casos de la pila de fallas (convs 242-248) |
| F2 | Correr las **23 hojas / 410 preguntas** contra el prototipo | **> 77%** correctas y **0** montos/ligas inventados |
| F3 | Herramientas genéricas de §4.3 (hoja, doc, foro, ERP) + guardia de montos | un segundo agente real (otra cuenta) funcionando sin `@ruta` |
| F4 | Asistente de configuración §4.4 | crear AGENTE ESCUELA desde cero en < 10 min sin escribir prompt |
| F5 | Migración canal por canal; el motor viejo queda para agentes muy deterministas (bot cobrador ERP) | — |

## 7. Riesgos

- **El modelo no llama la herramienta y contesta de memoria** (`gpt-4o-mini` lo hace). Mitigación:
  - descripciones claras;
  - regla "nunca des un dato de la empresa sin herramienta";
  - guardia de montos;
  - medir con la batería; si no alcanza, probar `gpt-4o` u otro modelo solo para este agente.
- **Menos predecible que la cascada.** Mitigación: registrar herramientas + argumentos + resultados de
  cada turno (como `EngineTrace` / `used_tools`) y mostrarlos en el panel de pruebas.
- **Costo y latencia.** Son 2-4 llamadas por turno, parecido a hoy (clasificador + cita + redacción).
  Para bajarlo: prompt fijo al inicio (prompt caching) y resultados de herramientas cortos.
- **Dos motores conviviendo.** La regla debe dejar claro qué motor atiende cada canal; nunca los dos a la vez.

## 8. Decisiones pendientes (del usuario)

1. ¿El piloto se construye sobre **Agentes listos** (recomendado) o como modo nuevo de los seguimientos?
2. ¿Conectar la **hoja de carreras directa** y dejar de copiarla a predefinidas? ¿Cuál es la hoja vigente?
   La que se usó: `1a05CecUCndWkLs4ydJR8QukGXN6J5ZO0MLMeUf0o-CM`.
3. ¿Modelo para el piloto: `gpt-4o-mini` (default) o `gpt-4o`?
4. ¿La receta "ofertas escalonadas" se generaliza (cualquier negocio con descuentos por objeción) o
   arranca solo para escuela?

## 9. Para retomar en otra instancia

- Rama: `docs/entender_agentes_ia`. Diagrama + generador: `docs/diagrama_agente_ia_flujo.svg`,
  `docs/diagrama_agente_ia_flujo_gen.py`.
- **Manual del motor actual:** `docs/motor_agentes_ia_manual.md` (gramática `@ruta`, directivas,
  precedencia, estado entre turnos).
- **Ids de la cuenta 1128 (pueden no existir en otra BD):** plantillas 1583/1581, canal 2450 (prueba) / 2449 (real),
  regla 716, predefinidas 2809-2824.
- **Scripts de las pilas** (correr_pila, etiquetar, reporte): estaban en carpetas temporales de sesiones
  anteriores y **no persisten**. Para F2 hay que rehacerlos o usar `ContactTrackings::Assistant::TestBattery`.
