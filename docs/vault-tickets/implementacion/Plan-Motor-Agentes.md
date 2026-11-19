# Plan — Motor nuevo de agentes (agentes base + habilidades)

> Acordado con el usuario el 2026-11-09. **Estado: guardado, sin empezar.** Se retoma
> cuando el usuario diga; la idea es construirlo todo de un jalón (M1–M5) y probar después.
>
> **Actualizado 2026-11-14 — ver sección 11.** Cambia la opción B (secciones 2 y 5): el 2.0
> vive aparte, como Agentes listos, y **Agentes a medida no se toca** (ni interruptor dentro de
> él). Un solo motor con dos puertas (listo / a medida 2.0). **Para retomar: leer 11.10.**

## 1. Por qué

Los agentes del módulo «Agentes IA» se sienten cortados en la plática. Causa (revisada en
el código, no supuesta):

- El motor viejo (`app/jobs/contact_tracking_response_analyzer_job.rb`, ~2,500 líneas, más
  `app/services/knowledge_base_response_service.rb`, ~1,350) es una **cadena de decisores**.
  Cada mensaje pasa por estos pasos, en orden:
  1. baja;
  2. palabras clave;
  3. reglas de casos;
  4. estado de caso;
  5. **clasificador de intención con IA** (`ContactTrackings::RouterService`);
  6. **clasificador de rama con IA** (`BranchClassifierService` + `RouteMap`);
  7. búsqueda en conocimiento **con su propio prompt**;
  8. flujos de citas;
  9. y al final, la respuesta conversacional.
- Cada paso contesta con su prompt y ve solo parte de la plática. El cliente nota el cambio.
- Necesita un minilenguaje (`@ruta`, `@crear_ticket`, `{{hoja:…}}`) para declarar todo.
  - Por eso el generador crea muchas rutas.
  - Es frágil: existe un comprobador solo para cazar Entrenamientos rotos.
- El motor del Seguimiento IA (`app/services/ai_follow_ups/runner.rb`, ~1,000 líneas en total)
  es fluido porque es **un modelo con herramientas**:
  - lee la plática completa e instrucciones en lenguaje normal;
  - decide solo qué herramienta usar;
  - contesta un solo mensaje.

## 2. Decisión: opción B — cambiarle el «cerebro» al módulo actual

- **No** se parcha el motor viejo (opción A): mejoraría poco, la causa sigue.
- **No** se hace un módulo aparte: habría que reconectar todo lo que ya cuelga del módulo
  actual:
  - campañas (inscritos, clasificación, entregar interesado);
  - asignación masiva;
  - tablero de seguimientos;
  - automatizaciones que prenden un agente (`trigger_tracking`);
  - baja, palabras clave y bienvenida.
- **Sí:** el motor nuevo es código nuevo y limpio, con la forma del Seguimiento IA, y se
  conecta al módulo actual:
  - cada agente (`TrackingTemplate`) tiene un interruptor **«Motor: clásico / nuevo»**, por
    omisión **clásico**;
  - al llegar un mensaje de un seguimiento cuyo agente está en «nuevo», contesta el motor
    nuevo; si no, el viejo, como hoy.
- **Prioridad para que nunca contesten dos:**
  1. Seguimiento IA vivo (`AiFollowUp.live_for?`, ya en `Message`, ~línea 496).
  2. Agente con motor nuevo.
  3. Motor viejo.
- Si una persona escribe en la conversación, el agente se pausa en esa plática. En la
  conversación se ve «Atendida por [agente]» con Pausar / Reanudar.

## 3. Agentes base (puestos) y habilidades

Dos capas:

- **Agente base = el puesto:** a quién le habla, quién empieza, objetivo, tono y cuándo
  termina.
- **Habilidades = lo que sabe hacer:** cada una trae sus instrucciones y **solo** sus
  herramientas. El modelo recibe únicamente las herramientas de las habilidades prendidas.

### Agentes base (6)

| Agente | A quién le habla | Quién empieza | Objetivo | Termina cuando… |
|---|---|---|---|---|
| Atención a prospectos | Gente nueva (anuncios, página) | Cliente | Entender, calificar y llevar a cita, cotización o vendedor | Calificado y entregado, o descartado |
| Vendedor | Prospectos interesados | Cualquiera | Cerrar: dudas, objeciones, cotizar, compromiso | Acepta, rechaza o pide tiempo |
| Campañas | Una lista de contactos | Agente | Ofrecer algo concreto y detectar interés | Le interesa (pasa al Vendedor) o dice que no |
| Atención a clientes | Clientes actuales | Cliente | Resolver dudas, estado de servicio o pedido, quejas | Resuelto o pasa a una persona |
| Soporte técnico | Clientes con falla | Cliente | Diagnosticar y resolver o abrir caso u orden de trabajo | Resuelto o con caso abierto |
| Cobranza | Clientes con saldo | Agente | Recordar, negociar fecha, lograr pago o promesa | Paga, promete fecha o pasa a una persona |

- **Mismo número para atención y soporte:** un solo agente de Atención a clientes con la
  habilidad Soporte técnico.
- **Soporte con número o equipo propio:** agente aparte.

### Habilidades (8)

| Habilidad | Qué hace | Herramientas (recursos del motor viejo que se reusan) |
|---|---|---|
| Conocimiento (siempre) | Contesta con la información de la empresa | Búsqueda en bases de conocimiento, respuestas predefinidas y hojas (lo útil de `KnowledgeBaseResponseService`, `SheetLookup`) |
| Calificar | Preguntas clave y las anota | Datos del contacto, etapa del embudo |
| Cotizar | Arma y manda cotización | Catálogo + `Quotes::Builder` / `Quotes::Delivery` (como Dali, `Assistant::QuoteTools`) |
| Agendar citas | Horarios libres; agendar, mover, cancelar | `ContactTrackings::AvailabilitySlotService`, calendarios (Google) — **la parte con más detalles: ir con cuidado** |
| Soporte técnico | Diagnóstico guiado; si no, caso u orden | Base técnica + `Cases::TicketCreatorService` |
| Estado de su caso o servicio | «¿Cómo va lo mío?» | `Cases::TicketStatusService` |
| Pagos y facturas | Saldo, facturas, promesa de pago | **Hoy solo con hojas**; conectar ERP es un paso posterior |
| Pasar a una persona (siempre) | Lo pide el cliente o no puede resolver | Asignar a persona o equipo; pausa el agente en esa plática |

Herramientas transversales:
- **baja:** `ContactTrackings::OptOut`;
- **plantillas con la ventana de 24 h cerrada:** como `AiFollowUps::TemplateTurn` / `AiFollowUps::Templates`.

## 4. El prompt: tres capas y tres formas de editar

Prompt final = **puesto** (nuestro, global) + **habilidades prendidas** (nuestras, globales)
+ **lo de la empresa** (editable). Si la parte de la empresa contradice a las otras, gana
la de la empresa.

Formas de editar la parte de la empresa (todas sobre el mismo texto, con versiones):

1. **Platicando con Dali:** «al agente de atención dile que no dé precios de instalación».
   Tarjeta con el cambio exacto (qué se agrega o quita) → confirmar → versión nueva.
2. **Ficha del agente:** campos guiados (tono, temas, reglas «nunca», datos de la empresa,
   horarios, a quién pasar) + «Instrucciones adicionales» libre.
3. **Modo avanzado:** «Ver prompt final» y editarlo.

Otras reglas:
- **«En blanco»** (desde cero, a la medida): instrucciones completas propias + habilidades.
  No recibe nuestras mejoras al catálogo.
- Los puestos y las habilidades viven como archivos globales, igual que las guías de Dali
  (`config/assistant/guides`). Por ejemplo `config/agents/bases/*.md` y
  `config/agents/skills/*.md`. Si mejoramos uno, mejora para todas las empresas.

## 5. Pantallas (dentro del módulo actual de Agentes IA)

- **Interruptor «Motor: clásico / nuevo»** en la ficha.
- **«Nuevo agente»:** elegir un puesto del catálogo o «En blanco».
- **Ficha con motor nuevo:**
  - **Instrucciones:** campos guiados + libre + ver prompt final.
  - **Habilidades y fuentes:** casillas en vez de directivas.
  - **Probar:** chat de prueba donde tú eres el cliente. Muestra la respuesta y qué
    herramientas usó, sin mandar nada.
  - **Versiones.**
- **Agentes existentes: «Convertir al motor nuevo».**
  - Dali/IA traduce rutas y directivas a instrucciones + habilidades y crea un **borrador
    aparte**; no toca el original.
  - Se compara en seco contra el viejo con conversaciones reales (ya existe
    `ContactTrackings::Assistant::DryRunService`).
  - Si convence, se cambia el interruptor. Regresar a «clásico» es un clic.
- **Activación en el canal:** la misma de hoy (automatizaciones, campañas, asignación
  masiva). No hay que reconectar nada.

## 6. Dali

- **Crear:** «quiero un agente de atención a clientes con soporte y ventas para el WhatsApp
  principal».
  - Dali pregunta solo lo que cambia por empresa (4–6 preguntas del puesto).
  - Lo que ya sabe de la cuenta (fuentes, respuestas predefinidas, tipos de caso) lo
    propone él; se puede reusar `ContactTrackings::Assistant` (inventario, comprobador).
  - Tarjeta «Nuevo agente IA» → borrador → ofrecer probarlo.
- **Ajustar:** «al agente de atención dile que…» → tarjeta con el cambio → versión nueva.

## 7. Pasos (ritmo real de trabajo)

| Paso | Qué | Ritmo |
|---|---|---|
| M1 | Motor nuevo (runner con herramientas) + herramientas básicas (conocimiento, crear caso, estado de caso, pasar a persona, baja) + interruptor por agente + bitácora por turno | 1 sesión |
| M2 | Ficha: instrucciones (3 formas), habilidades y fuentes, chat de prueba, versiones, ver prompt final | 1 sesión |
| M3 | Citas (calendarios), hojas y plantillas de WhatsApp como herramientas | 1 sesión |
| M4 | «Convertir al motor nuevo» + comparación en seco | media sesión |
| M5 | Catálogo: 6 puestos + 8 habilidades (archivos globales) + Dali crea y ajusta agentes | media sesión |

Escribirlo son ~3–5 días de trabajo. Lo que marca el ritmo después:
- probar con conversaciones reales (en dev no hay WhatsApp);
- las citas con Google;
- la revisión y subida del programador;
- 1–2 semanas de piloto con un agente real antes de pasar los demás.

## 8. Reglas para construirlo de un jalón (acordadas)

- **Rama nueva `feat/motor_agentes`** desde lo último; un commit por paso (M1…M5).
- **Respaldo de cada archivo antes de editar** (`archivo_YYYYMMDD`); pruebas automáticas en
  cada paso; al final, pasada completa en el navegador:
  1. crear desde el catálogo;
  2. chat de prueba;
  3. convertir uno existente;
  4. pedírselo a Dali.
- **Decisiones:** las toma Claude sin detenerse y las anota con su motivo para revisarlas al
  final.
- **Ayudantes en paralelo:** se pueden usar, por ejemplo para analizar el flujo de citas
  del motor viejo o para la revisión final. El código lo integra uno solo.
- **Sin el usuario, NO:**
  - mensajes a clientes reales ni activar el motor nuevo en una bandeja real (todo queda
    en «clásico»);
  - subir a GitHub ni tocar producción;
  - borrar o modificar agentes existentes («convertir» crea borrador aparte);
  - cambiar tablas existentes más allá de lo necesario (lo nuevo en columnas o tablas
    nuevas).
- **Si algo se bloquea por permisos:** se salta, se anota y se sigue.
- **Entrega final:**
  - rama con M1–M5;
  - resumen;
  - lista de decisiones;
  - qué falta probar en real (WhatsApp, Google);
  - pasos para que el usuario pruebe.

## 9. Pendiente de confirmar al retomar

- Nombre y lugar exacto en el menú (dentro de Agentes IA; los viejos siguen igual).
- Contenido fino de cada puesto y habilidad (lo redacta Claude; el usuario revisa).
- Pagos y facturas: confirmar que basta con hojas en esta etapa.

## 10. Después del motor: buscador de productos (decidido 2026-11-09)

Orden acordado: **primero el motor (M1–M5); después, el buscador de productos.**

Comparación hecha (en 2026-11-09):
- **Cotizaciones de Dali (`Assistant::QuoteTools#search_catalog`):**
  - carga hasta 2,000 productos del Catálogo de Kontrolya en memoria y compara palabras;
  - **no sirve con bases de 50 mil productos.**
- **Vendedor transaccional (Daiko):**
  - proyecto aparte en Node.js: `/home/chatwoot/daikov2/backend`, repo `daiko-v1`;
  - Kontrolya le pasa los mensajes por `BotSeller::Dispatcher` (`INTERNAL_WEBHOOK_URL`);
  - busca en el ERP CRM Zeus por API (`apiCrm/externalAccess/.../api/Daiko/v1/...`), con precios y existencias en vivo;
  - lógica madura: búsqueda guiada (usos, calidades, estados), normalización y relevancia, en `utils/crm.js`, `busqueda_guiada.js`, `canonicalizacion_service.js` y `relevancia.js`;
  - su plática es clasificador + prompt por etapa (rígida).

Propuesta para entonces: **un solo buscador de productos en Kontrolya**, usado por las cotizaciones de Dali y por la habilidad «Cotizar» del agente Vendedor.
- **Catálogo propio:** índice en PostgreSQL (pg_trgm o texto completo) en lugar de cargar en memoria.
- **Catálogo externo por API:** CRM Zeus o el ERP, con los mismos servicios de Daiko; precios y existencias en vivo.
- **Lógica de Daiko:** traer la búsqueda guiada, la normalización y la relevancia.
- **La IA solo ve los 8–10 mejores resultados** y pregunta para acotar.
- **Daiko** podría quedar después como un agente más del motor nuevo.

Mientras tanto, en el motor (M1–M5) la habilidad «Cotizar» usa el Catálogo de Kontrolya tal como está. Sirve para catálogos chicos.

Preguntas abiertas:
- ¿Dónde viven los 50 mil productos: CRM Zeus, el Catálogo de Kontrolya o los dos?
- ¿Qué empresas usan hoy el vendedor transaccional?

## 11. Agentes a medida 2.0 (acordado 2026-11-14)

Esta sección manda sobre las secciones 2 y 5 donde se contradigan.

### 11.1 Las tres partes de un agente

| Parte | Quién la pone | Qué aporta |
|---|---|---|
| **Modelo** (OpenAI) | Lo rentamos | Sabe del mundo, entiende y redacta. No conoce el negocio ni tiene memoria propia |
| **Código** (la plataforma) | Nosotros | Memoria, reglas que deben cumplirse siempre y habilidades |
| **Lo que dicta el usuario** | La empresa | Instrucciones (tono, objetivo, qué no hacer) y conocimiento (precios, carreras, fuentes) |

- No se entrena (fine-tuning) al modelo: «entrenar» un agente = darle instrucciones y conocimiento.
- **Regla para decidir dónde va cada cosa:**
  - **instrucciones:** tono, qué decir, qué información dar;
  - **habilidad con estado en el código:** orden, límites, cosas que no se repiten ni se adelantan.

### 11.2 Qué está mal del motor viejo

Hace las tres partes, pero con los papeles al revés:
- **El código decide la plática** (cadena de 9 pasos y rutas), cuando eso lo hace mejor el modelo.
- **El modelo carga las reglas**, cuando le tocan al código:
  - las variables las escribe el mismo modelo;
  - la búsqueda le pasa información que no debe usar todavía (las dos becas juntas).
- **Lo del usuario es un prompt técnico** (`@ruta`, `@buscar_…`, variables), difícil de escribir.
  Por eso los agentes no salen a la primera.

### 11.3 Un solo motor, dos puertas

| | Agentes listos | A medida 2.0 |
|---|---|---|
| Para quién | Quien quiere que funcione ya (dos clics) | Quien quiere control |
| Fuentes | Las del puesto | Las que quiera (Excel, docs, ERP, varias) |
| Instrucciones | Puesto + «Cómo habla tu empresa» | Puesto (si parte de uno) + las suyas |
| Habilidades | Las del puesto | Las que prenda |
| Motor | El mismo (el de Seguimiento IA) | El mismo |

- **«Personalizar»** en un agente listo abre la ficha completa del **mismo agente** (no lo copia); ver 11.9.
- Cada habilidad nueva sirve a las dos puertas. No repetir el error de tener dos motores.
- **Tablas compartidas, pantallas separadas (acordado 2026-11-16, reemplaza «el 2.0 vive
  aparte»):**
  - el 2.0 usa la misma lista y las mismas tablas de Agentes a medida: `tracking_templates`
    gana `engine` («1.0» por omisión / «2.0») y columnas nuevas para lo del 2.0;
    `contact_trackings` no cambia. Así campañas, asignación masiva, automatizaciones, tablero
    y «Delegar a agente» funcionan con agentes 2.0 sin reconectar nada;
  - **«Nuevo»** en la lista pregunta «Motor 1.0 / Motor 2.0»; al abrir un agente se va a la
    pantalla de su motor; etiqueta «2.0» en la lista;
  - **la ficha 1.0 no se mueve**; la ficha 2.0 es nueva, en archivos propios;
  - **desvío** en `Message#analyze_for_active_trackings`: si el agente del seguimiento es 2.0,
    contesta el motor nuevo; si no, igual que hoy;
  - **el motor 1.0 no se toca** (`ContactTrackingResponseAnalyzerJob`, `RouterService`, su
    prompt). Esas cuatro cosas son la única excepción autorizada a «no tocar Agentes a medida».
- **«Pasar a 2.0»:** el mismo agente cambia de motor y se llenan sus campos nuevos a partir
  de lo que tiene (se puede regresar a 1.0). Cuando no quede ninguno en 1.0, se apagan su
  motor y su pantalla.
- Motor **de cero**; pantallas y aprendizaje **no**: la ficha nueva se hace copiando la idea
  de la actual, sin editar la actual.

### 11.4 Sin rutas; el prompt en tres capas

- Desaparecen las rutas, `@ruta`, `@buscar_…`, `@ruta_por_defecto`, el tope de 20 rutas, el
  diagrama de rutas, la prueba del clasificador, `training_structure` y la cadena de 9 pasos.
  El modelo decide hacia dónde va la plática.
- Lo útil de las rutas pasa a la ficha:

| Hoy en una ruta | En el 2.0 |
|---|---|
| `@buscar_…` en tal fuente | Fuentes marcadas |
| Si pide humano o se enoja → persona | Campo «Cuándo pasar a una persona» y a quién |
| Si quiere cita → agenda | Habilidad Citas |
| Si es queja → ticket | Habilidad Tickets, con motivos |
| Manda tal imagen en tal momento | Archivos con su regla |
| Precio → beca 1 → beca 2 | Habilidad Ofertas escalonadas |

- **Prompt = puesto (nuestro) + habilidades (nuestras) + instrucciones de la empresa** (texto
  libre, sin minilenguaje).

### 11.5 Qué se reusa de las pantallas de Agentes a medida

Inventario hecho el 2026-11-14 (rutas en `app/javascript/dashboard/routes/dashboard/contactTrackings/routes.js`;
ficha en `app/javascript/dashboard/views/contactTrackings/ficha/AgentFicha.vue`).

**Tal cual (la idea y los campos):**
- **Agente y canal:**
  - nombre, nombre que ve el cliente, objetivo, contexto;
  - canal, intentos e intervalo;
  - plantillas de WhatsApp por intento, firma de correo.
- **Fuentes de datos** (tarjetas): sheet, doc, articles, canned, forum, contpaq, discourse, erp.
- **Agenda:** calendarios, duración, presentación de horarios, en qué calendario se aparta la cita.
- **Tickets:** tipos de caso, motivos y prioridad.
- **Archivos:** con regla de cuándo se mandan (bienvenida, intento, ruta, cita).
- **Bienvenida.**
- **Preguntas:** una a la vez, en qué variable se guarda y qué respuestas acepta.
- **Datos del negocio:** pares dato/valor.
- **Palabras clave** (`keyword_actions`): cancel, pause, objective_met, interested, booked.
- **Versiones:** diff campo por campo y restaurar sin borrar.
- **Campañas:**
  - audiencia, ritmo, tope diario;
  - prueba A/B del asunto y cortes;
  - calificación caliente/tibio y traspaso al tablero.
- **Tablero de métricas.**
- **«¿Listo para atender?».**
- **Galería e importar.**

**Se reusa cambiando el fondo:**
- **Variables con reglas `{when, to}`:** las mueve el código, no el modelo. Es la base de las
  habilidades con estado.
- **Comprobador:** revisa que la ficha esté completa y sin contradicciones, no la sintaxis del prompt.
- **Asistente de entrenamiento** (entrevista, encargo .md, «Esto entendí»): llena la ficha en
  lugar de escribir un prompt.
- **«Configurar» / `adaptation_answers`:** detectar lo que el agente usa y la cuenta no tiene.
  Se aplica a la ficha.
- **Casos de prueba** (`tracking_test_cases`): de «debe ir a la ruta X» a «debe / no debe hacer
  esto».
- **Probar fuentes:** igual.

**Se deja atrás:** todo lo de la lista de 11.4.

**Ejemplo Casauranc → ficha 2.0:**

| Prompt de hoy | Ficha 2.0 |
|---|---|
| [ROL], bienvenida | Agente y Bienvenida |
| [DATOS DE LA ESCUELA] | Datos del negocio |
| [CATÁLOGO] | Fuentes (respuestas predefinidas) |
| [IMÁGENES DE BECA] | Archivos |
| [PRECIO Y BECAS] | Ofertas escalonadas |
| [VARIABLES] | Variables movidas por el código |
| [ESTILO], [PROHIBIDO] | Instrucciones de la empresa |

### 11.6 Receta para crear una habilidad nueva

Cada habilidad es un paquete de 5 piezas:

| Pieza | Qué es | Ejemplo: Ofertas escalonadas |
|---|---|---|
| Campos de la ficha | Lo que llena la empresa | Escalones: texto, precio, cupón, imagen, liga; qué cuenta como objeción |
| Herramienta | Lo que el modelo puede llamar | `siguiente_oferta` |
| Memoria | Lo que el código guarda por cliente | «Va en el escalón 2» |
| Instrucciones | Unas líneas nuestras en archivo | «Si objeta el precio, usa `siguiente_oferta` y da solo lo que te regrese» |
| Pruebas | Pláticas que deben salir bien | «Nunca aparecen dos becas en el mismo mensaje» |

- **Clave:** el modelo no ve todos los escalones; pide el siguiente y el código le da solo ese
  y avanza. Lo que no tiene a la vista no lo puede filtrar.
- **Ofertas escalonadas es genérica:**
  - becas (escuelas);
  - descuentos (tiendas);
  - plazos o meses sin intereses (ventas);
  - quitas o convenios (cobranza).
- **Cómo nace una habilidad:**
  1. **detectar:** prompts que nos traen, pláticas que salen mal, reportes del entrenador;
  2. **decidir:** si hay que recordar algo, respetar un orden, poner un límite o conectarse a
     algo, es habilidad; si es tono o forma de decir, va en las instrucciones;
  3. **construir:** las 5 piezas, en una rama;
  4. **probar:** primero las pruebas, luego un agente real;
  5. **soltar:** disponible para todos los 2.0; si conviene, de fábrica en un agente listo.
- **Reglas:**
  - mejorar una habilidad mejora a todos los que la usan, así que las pruebas son obligatorias;
  - una habilidad hace una sola tarea;
  - debe poder explicarse en una línea en la ficha.
- **Primeras probables:**
  - Ofertas escalonadas;
  - Preguntas (una a la vez, guardando la respuesta);
  - Leer Excel/Sheets;
  - Buscar en ERP;
  - Citas;
  - Tickets;
  - Mandar archivos según regla;
  - Pasar a una persona.

  Varias ya existen a medias en Seguimiento IA o en Agentes listos.

### 11.7 Corregir ahí mismo: el entrenador y los tres tipos de error

> El flujo completo del probador y las correcciones está en **11.8**, que manda sobre esta
> sección donde se contradigan. Aquí quedan los tres tipos de error y el ejemplo real.

**Botón «Corregir esta respuesta»,** en pruebas o en pláticas reales:
1. El usuario marca la respuesta mala y escribe qué esperaba.
2. Un entrenador (como Dali) clasifica el error:

| Tipo | Cómo se reconoce | Qué hace el entrenador | Quién lo arregla |
|---|---|---|---|
| **1. Faltaba información** | Dice algo nuevo: horario, precio, tono, a quién pasar | Propone el cambio en instrucciones, datos, fuentes o campo de habilidad; el usuario aprueba | El usuario, ahí mismo |
| **2. Falta una habilidad** | Pide algo que el motor no sabe hacer (inventario, Excel) | Avisa que falta esa función; mientras, aplica lo mejor posible con instrucciones (p. ej. pasar a persona); manda reporte | Nosotros |
| **3. Indicación ignorada** | La corrección ya estaba escrita y no se obedeció | Avisa que es falla nuestra; refuerza la indicación para ese agente; manda reporte con prioridad alta | Nosotros, con prioridad |

**Reglas:**
- **No aprende solo sin aprobación.** El entrenador propone, enseña el cambio, corre las pruebas
  y el usuario confirma.
- **Cada corrección aprobada:**
  - queda como versión (se puede deshacer);
  - se guarda como **prueba nueva**, para que el error no regrese sin avisar.
- **Reportes (tipos 2 y 3):**
  - llegan a una lista en Super Admin, como las «preguntas sin respuesta» de Dali, con la
    plática, lo esperado y qué falta;
  - se ordenan por cuántos piden lo mismo.

Así crece el motor: con los errores que los usuarios reportan, no uno por uno a mano.

**Ejemplo real de tipo 3 (2026-11-12, Seguimiento IA):**
- **Qué pasó:** las indicaciones decían «es una distribuidora, pregúntale si ya le pasó la
  cotización a su cliente», y el agente le preguntaba a ella si había visto la cotización.
- **Causa:** estaba en nuestra capa. El prompt base hablaba de «el cliente» y el caso aparecía
  como suyo.
- **Arreglo:** el objetivo y las indicaciones mandan y el caso es solo contexto
  (`app/services/ai_follow_ups/prompt.rb`, commit d616aadb), y el campo nuevo «Quién es quién»
  en Cómo habla tu empresa (commit 7c72bb1b).
- **Le sirvió a todos** los agentes de Seguimiento IA y Agentes listos.

### 11.8 Probador y correcciones (acordado 2026-11-14)

Hoy los usuarios prueban directo en WhatsApp o Telegram, y lo que sale mal nos lo traen a mano.
El 2.0 debe permitir corregir donde se prueba.

**1. Probador dentro del 2.0**
- Se parte del chat de prueba de Agentes listos:
  - `ReadyAgentModal.vue`;
  - `ReadyAgents::Runner#test`;
  - `POST /ready_agents/test`.
- Como allá, el usuario es el cliente y no se guarda ni se manda nada.
- Se le agregan tres cosas:
  - **👍 / 👎 en cada respuesta;**
  - **qué hizo el agente:** qué fuente consultó, qué habilidad usó y en qué escalón va;
  - **guardar la plática como prueba.**

**2. Al dar 👎:** el usuario escribe qué estuvo mal y cómo debió responder. El entrenador contesta
en el mismo chat según dónde esté el error:

| Dónde está el error | Qué hace el entrenador |
|---|---|
| Instrucciones del agente | **Lo corrige solo:** muestra el cambio, ofrece **Deshacer**, deja versión y vuelve a contestar el mismo mensaje para comparar |
| Respuestas predefinidas | **No las cambia solo** (las usan otros agentes y personas). Dice exactamente qué corregir y ofrece **Aplicar este cambio** a quien tenga permiso |
| Campo de la ficha (escalones, horario, a quién pasar) | Dice qué campo y qué valor; botón **Aplicar** |
| No sabe resolverlo (falta habilidad o indicación ignorada) | «Esto no lo puedo corregir yo. Ya lo reporté al equipo y te aviso cuando quede.» → reporte |

**Condiciones para corregir solo las instrucciones:**
- se ve el cambio;
- se puede deshacer;
- queda como versión;
- antes de aplicarlo **corre las pruebas guardadas**. Si rompe algo que ya funcionaba, avisa en
  lugar de aplicar.

Cada 👎 corregido se guarda como **prueba**. Al cambiar algo después, se vuelve a correr y avisa si
el error regresó.

**3. Reporte de lo que no sabe resolver**
1. **Se guarda** en una tabla de reportes con:
   - la plática completa;
   - lo que respondió y lo que el usuario esperaba;
   - el agente, la empresa y el tipo de error (falta habilidad / indicación ignorada).
2. **Nos llega:**
   - un **correo** al equipo;
   - una **lista en Super Admin**, como «preguntas sin respuesta» de Dali, ordenada por cuántos
     piden lo mismo.

   Estados: nuevo, en revisión, corregido, no procede.
3. **Lo corregimos** en el motor, en una habilidad o creando una nueva (receta de 11.6).
4. **Al marcar «corregido»:**
   - el usuario recibe un aviso: «Ya quedó lo que reportaste del agente X, pruébalo de nuevo»;
   - la prueba guardada se corre sola para confirmar.

**4. Corregir desde el canal real (WhatsApp / Telegram)**
- **👍 / 👎 en la conversación real** dentro de la plataforma, en cada mensaje del agente, con el
  mismo flujo de corrección.
- **Número de prueba:** se marca el teléfono del dueño como «probador».
  - Si escribe `corrige: …`, ese mensaje no lo contesta el agente: va al entrenador.
  - El entrenador responde ahí mismo y sigue el mismo flujo.

**Pendiente de decidir al construir:**
- a qué correo llegan los reportes;
- quién puede «Aplicar» cambios en respuestas predefinidas;
- si el número de probador se marca en la ficha o en el contacto.

### 11.9 Una ficha, un probador y varios agentes (acordado 2026-11-14)

**Una sola ficha para todos los agentes, con dos vistas:**
- **Vista corta (agente listo):**
  - solo las preguntas que sabemos que lleva ese puesto; lo demás viene del puesto;
  - dos clics y funciona.
- **Vista completa (botón «Personalizar»):**
  - el **mismo agente**, no una copia, con todas las secciones abiertas;
  - las respuestas de la vista corta ya aparecen llenas;
  - sigue en su bandeja; no hay dos agentes que mantener.

| # | Sección | Qué lleva |
|---|---|---|
| 1 | Agente | Nombre, nombre que ve el cliente, objetivo, canal, tono |
| 2 | Qué sabe | Fuentes: respuestas predefinidas, Excel/Sheets, docs, artículos, ERP |
| 3 | Qué hace | Habilidades: preguntas, ofertas escalonadas, citas, tickets, archivos, cotizar |
| 4 | Reglas | Palabras clave, cuándo pasar a persona y a quién, lo que nunca debe hacer |
| 5 | Instrucciones de la empresa | Texto libre: tono y matices |
| 6 | Probar | Chat con 👍/👎 y correcciones (11.8) |
| 7 | Versiones | Cambios y restaurar |

- **Mejoras nuestras:** personalizar fuentes, habilidades, reglas o instrucciones **sigue
  recibiendo** las mejoras del puesto y las habilidades. Solo si se edita el texto del puesto
  en modo avanzado deja de recibirlas, y se avisa antes.
- **Seguimiento IA entra igual:**
  - sus plantillas (recetas) son su vista corta;
  - «Personalizar» abre la misma ficha;
  - mismo motor.

**Un solo probador** para las dos vistas:
- mismas pruebas guardadas y mismo historial de correcciones;
- en la vista corta, si la corrección cae en algo que esa vista no muestra (p. ej. una fuente
  nueva), el entrenador dice «Esto se arregla en Personalizar › Qué sabe» y lleva ahí.

**Varios agentes del mismo tipo:**
- **Hoy** ya se pueden crear varios agentes listos del mismo tipo, pero solo uno activo por
  bandeja (`one_agent_per_inbox`, `app/models/ready_agent.rb:69`).
- **En el 2.0, varios en la misma bandeja con regla de reparto:**
  - anuncio o campaña de origen;
  - palabra del primer mensaje;
  - etiqueta o etapa del contacto;
  - horario;
  - si no cumple ninguna, el **agente principal** de la bandeja.
- **Una sola lista de agentes** (listos y personalizados juntos). Cualquiera se puede elegir en:
  - campañas;
  - asignación masiva;
  - automatizaciones;
  - «Delegar a agente» del caso;
  - Dali.
- **Quién contesta si hay varios en una plática** (gana el más específico):
  1. Seguimiento IA delegado a esa conversación;
  2. el agente de la campaña que le escribió a ese contacto;
  3. el que gane por la regla de reparto de la bandeja;
  4. el agente principal de la bandeja.

  Ejemplo: la campaña de becas le escribe a Juan con «Becas Derecho». Cuando Juan contesta, lo
  sigue atendiendo ese agente aunque la bandeja tenga otro.

### 11.10 Dónde nos quedamos (2026-11-14) — para retomar

**Estado:** solo plan y diseño; **no hay código del 2.0**. Agentes a medida (viejo) sigue intacto
y no se toca.

**Ya acordado** (secciones 11.1–11.9):
- 11.1: las tres partes;
- 11.2: qué falla del viejo;
- 11.3: un motor, dos puertas; tablas compartidas con el 1.0 y pantallas separadas (2026-11-16);
- 11.4: sin rutas, prompt en tres capas;
- 11.5: inventario de pantallas a reusar;
- 11.6: receta de habilidades (5 piezas), con Ofertas escalonadas como primera;
- 11.7–11.8: probador con 👍/👎, entrenador y reportes;
- 11.9: ficha única con vista corta y completa, probador único, varios agentes con reparto y
  prioridad.

**Lo que ya existe y se usa como base:**
- motor de Seguimiento IA / Agentes listos (`AiFollowUps::Runner`, `ReadyAgents::Runner`);
- chat de prueba de Agentes listos (`ReadyAgentModal.vue`, `ReadyAgents::Runner#test`);
- «Cómo habla tu empresa» (`AgentBase::CompanyVoice`, incluye «Quién es quién»);
- nota del contacto para IA (`AgentBase::ContactNote`);
- «preguntas sin respuesta» de Dali (modelo para la lista de reportes en Super Admin);
- ficha de Agentes a medida (`views/contactTrackings/ficha/`) como modelo de secciones.

**Pendiente de decidir al retomar:**
- Rehacer la tabla de pasos (sección 7, M1–M5). Fue pensada para la opción B y hay que
  ajustarla al 2.0 (tablas compartidas, pantalla propia): ficha única, probador, reportes,
  reparto y «Pasar a 2.0».
- ~~Si el 2.0 crece sobre la tabla `ready_agents` o usa una tabla nueva.~~ Decidido 2026-11-16: comparte las tablas de Agentes a medida (11.3).
- A qué correo llegan los reportes.
- Quién puede «Aplicar» cambios en respuestas predefinidas.
- Dónde se marca el número de probador (ficha o contacto).
- Qué reglas de reparto van en la primera versión.
- Lo de la sección 9 que siga abierto.

**Antecedente que motivó el 2.0:** el prompt de Casauranc. Las becas salían juntas y las variables
no siempre lo controlaban. El arreglo de texto quedó en el scratchpad de esa sesión; no está en el
repo.

**Siguiente paso al retomar:**
1. leer la sección 11 completa;
2. proponer la nueva tabla de pasos;
3. esperar el «sí» del usuario.

### 11.11 Decisiones del 2026-11-16 y pasos para construir

**Decisiones del usuario:**
- **Tablas compartidas, pantallas separadas** (11.3). «Nuevo» pregunta 1.0 / 2.0. La ficha 1.0 no se mueve.
- **Intentos (cuando el cliente no contesta):**
  - un agente 2.0 los escribe con el motor 2.0, en modo seguimiento como el Seguimiento IA nuevo;
  - un agente 1.0 sigue con su seguimiento de adentro (`ContactTrackingJob`).
- **Desvíos autorizados en código compartido:** cada uno es «si el agente es 2.0 → motor 2.0; si no, igual que hoy»:
  - `Message#analyze_for_active_trackings`;
  - `ContactTrackingJob#generate_ai_message` (también lo usa el despachador, `TrackingDispatch::SendJob`), con `Motor2::AttemptHook` (prepend) sin editar el job.
- **Piezas del 1.0 que ya funcionan:** el 2.0 las llama tal cual, sin editarlas. Si hay que mejorar una, se copia al 2.0. Ejemplos:
  - búsqueda en fuentes, hojas y lectura de adjuntos;
  - horarios, palabras clave, baja y clasificador de prospectos.
- **El 2.0 es su propio motor.** No se arma modificando el de Agentes listos ni el de Seguimiento IA. Esos dos se conectan al 2.0 después, y cada uno conserva sus pantallas y sus tablas.
- **Galería y publicar prompts** con agentes 2.0: después.
- **Entrenador con tres salidas claras** al dar 👎 (manda sobre la tabla de 11.8):
  - **✏️ Instrucciones o ficha del agente:** lo corrige solo. Le dice «ya lo corregí, pruébalo de nuevo», con Deshacer y versión. Antes corre las pruebas guardadas.
  - **📚 Fuente:** enseña el texto exacto que encontró y ofrece arreglarlo («Arréglalo tú» / «Lo corrijo yo»). Avisa si esa fuente la usan otros agentes. Si la fuente es externa, dice qué hoja, fila y columna cambiar.
  - **🔧 Motor:** «Esto no lo puede hacer el motor todavía: búscalo con tu Kontrolya». El reporte sale automático.
  - Decide con la traza: qué fuente consultó, qué le regresó, qué habilidad usó y qué dicen las instrucciones. Si hay duda, hace una sola pregunta. Si hay dos causas, muestra las dos.
  - Cada 👎 resuelto se guarda como prueba.

**Nombres en el código:**
- Módulo `Motor2::` (app/services/motor2/).
- Columnas nuevas:
  - `tracking_templates.engine` («1» por omisión / «2»);
  - `tracking_templates.motor2` (jsonb, la ficha 2.0);
  - `contact_trackings.motor2_state` (jsonb, la memoria por contacto que mueve el código).
- Tablas nuevas: `motor2_tests` y `motor2_reports`.

**Pasos** (rama `feat/motor_agentes_2`, un commit por paso):

| Paso | Qué |
|---|---|
| M1 | **Motor.** Columnas; `Motor2::Runner` con las habilidades base (Qué sabe, Datos del cliente, Pasar a persona, Terminar); turno de respuesta con las garantías (espera y candado, solo el último mensaje, baja, vendedor atendiendo, palabras clave, bienvenida, clasificador de campaña, antifuga, ligas, reintento); los dos desvíos; intentos con el motor 2.0; traza por respuesta |
| M2 | **Habilidades.** Ofertas escalonadas, Citas, Tickets, Archivos con regla |
| M3 | **Pantalla.** API de la ficha 2.0; «Nuevo» con 1.0 / 2.0; etiqueta «2.0» en la lista; abrir según el motor; ficha con 7 secciones y «¿Listo para atender?»; versiones |
| M4 | **Probador y entrenador.** Chat con traza y 👍/👎; las tres salidas; pruebas guardadas y «Correr todas»; reportes (tabla, lista en Super Admin, correo) |
| M5 | «Pasar a 2.0», 👍/👎 en la conversación real, guía de Dali, pasada final |
| Después | Varios agentes por bandeja con reparto; conectar Agentes listos y Seguimiento IA al 2.0; ver imágenes y transcribir audios; galería; puestos de fábrica |

### 11.12 Estado (2026-11-17): M1–M5 hechos en `feat/motor_agentes_2`

**Hecho:** motor, habilidades, ficha 2.0, probador con entrenador, pruebas, reportes, «Pasar a 2.0» / «Regresar a 1.0», 👎 en conversación real y guía de Dali. Rama local, sin subir.

**Decisiones que tomé al construir** (para revisar):
1. **Versiones del 2.0 en su propia tabla** (`motor2_versions`): el callback del 1.0 ya versiona sus columnas y habría duplicados.
2. **Desvío de los intentos:**
   - se hace con `prepend` sobre `ContactTrackingJob#generate_ai_message`, sin editar el job;
   - en `generate_message` no se puede, porque RSpec no permite simular un método antepuesto con `any_instance` y las pruebas del 1.0 lo simulan;
   - los intentos del 2.0 llevan la misma marca « #IA» que los del 1.0.
3. **Seguimiento pausado = no contesta** (lo atiende una persona). El 1.0 también contestaba en pausado.
4. **Calificación de campañas:** el 2.0 usa tal cual el clasificador del 1.0 (`TrackingCampaigns::ProspectClassifier`). La habilidad «Calificar» queda para después.
5. **Qué sabe:** búsqueda por parecido en las fuentes marcadas (predefinidas, artículos, documentos, hojas, foro, CONTPAQi). Todavía **no** están la búsqueda exacta en hojas (`hoja_buscar`) ni las consultas al ERP en vivo. Si un agente las necesita, el entrenador lo reporta como falta del motor.
6. **Montos y ligas:**
   - un precio, monto o porcentaje que el agente no vio en ningún lado se reescribe una vez; si insiste, no se manda;
   - las ligas que no vio se quitan (LinkGuard).
7. **Entrenador:**
   - corrige solo instrucciones, «nunca», bienvenida y datos del negocio;
   - si la habilidad está apagada, dice «Ir a Qué hace»;
   - de las fuentes, solo arregla respuestas predefinidas; las demás dice dónde corregirlas;
   - usa el modelo de análisis de la cuenta;
   - antes de aplicar corre hasta 8 pruebas recientes que pasaban;
   - si el modelo no pone el tipo de error, se deduce;
   - solo reemplaza una frase concreta; si la frase abarca casi todo el campo, agrega en vez de reemplazar.
8. **«Pasar a 2.0»** vive en «Nuevo agente» › «Motor 2.0» (la pantalla del 1.0 no se toca). Es el mismo agente y su Entrenamiento 1.0 se queda en su columna. **«Regresar a 1.0»** está arriba en la ficha 2.0.
9. **Reportes:** correo a `MOTOR2_REPORTS_EMAIL`; sin esa variable, solo la lista en Super Admin.
10. **Permisos:** la ficha 2.0 y el 👎 en conversaciones reales son solo para administradores.
11. **Archivos:** comparten la regla por archivo del 1.0 (`resources['files']`).

**Falta probar en real:** conversación por WhatsApp con un agente 2.0, intentos con plantilla, cita en Google, caso con sus reglas, campaña con agente 2.0, correo de reportes y la página de Super Admin con los archivos del front compilados.

**Después:**
- número probador con `corrige:`;
- varios agentes por bandeja con reparto;
- conectar Agentes listos y Seguimiento IA al 2.0;
- ver imágenes y transcribir audios;
- búsqueda exacta en hojas y ERP como habilidades;
- habilidad Calificar;
- galería;
- puestos de fábrica.

### 11.13 Probador de agentes (2026-11-17, rama `feat/probador_agentes`)

**Qué es:** una pantalla aparte, en el menú de Agentes IA debajo de Macros, para probar como cliente cualquier agente 1.0 o 2.0.

**Lo que decidió el usuario:**
- el probador viejo del 1.0 no se toca;
- se elige el agente (1.0 o 2.0);
- lo usa el mismo usuario que hoy prueba por WhatsApp, y corrige él mismo lo que es de prompt y de contenido.

**Cómo funciona:**
- **Canal de pruebas:** una bandeja API sin webhook, la misma idea que la pila de pruebas del 1.0; si no existe, se crea «Probador de agentes».
  - Cada plática es un contacto y una conversación nuevos, con el agente asignado por `ActionService#assign_tracking_template`.
  - El seguimiento queda «activo» para que no salgan intentos a media prueba.
  - Contesta el motor real, por el mismo camino que con un cliente.
  - El 1.0 usa el modelo de la bandeja del agente: el canal de pruebas copia su `model_ia`.
- **Entrenador** (`AgentTester::Trainer`) con cuatro salidas; nada se aplica solo:
  - **prompt:** da la indicación lista para pegar. En el 2.0 el usuario pulsa «Aplicar»; en el 1.0 la copia y la pega en su Entrenamiento.
  - **contenido:** enseña lo que dice la fuente; si es una respuesta predefinida, se corrige ahí mismo.
  - **modelo:** solo se acepta si el entrenador cita textual lo que el agente no siguió y esa cita está en el prompt o en los fragmentos. Si no, se trata como falta de indicación en el prompt.
  - **motor:** se manda el reporte a Kontrolya (`motor2_reports`).
  - Todo queda en `agent_test_logs`.
- **Lotes** (`agent_test_batches` / `agent_test_cases`) y **corridas** (`agent_test_runs`):
  - una plática por prueba, con el motor real;
  - un juez califica la última respuesta.
- **Bitácora:** corridas y correcciones; las del motor muestran el estado de su reporte.
- **Permiso:** área Agentes IA en «todo».

**Probado en desarrollo con el modelo real:**
- un agente 1.0 contestó en el canal de pruebas, con su traza;
- el entrenador clasificó bien un error de prompt (con la indicación nueva redactada) y uno de motor.

**Ajuste 2026-11-17 (decisión del usuario):**
- **Dónde está:** el probador vive en el menú **Inicio › Probar agentes**, para cualquier usuario.
- **Agentes «En prueba»:** el combo solo trae agentes «En prueba» (`tracking_templates.testing`).
  - Se prenden en la lista de agentes, en el renglón de cada uno; sirve para 1.0 y 2.0 sin tocar la ficha del 1.0.
  - En el 2.0 también se prenden desde su ficha.
  - Solo los prende quien puede cambiar agentes.
- **Lo que hace cualquier usuario:** probar, dar 👎 y guardar pruebas. Solo ve sus propias pláticas.
- **Solo quien cambia agentes:** «Aplicar», «Corregirla» (respuestas predefinidas), lotes y bitácora.
- **Menú «Nuevo agente»:** dice «Motor 2.0 (beta)» y va al final.

### 11.14 Un solo motor, agentes por función con su asistente (acordado 2026-11-19)

**Idea del usuario:** un solo motor (el 2.0). Encima viven tres clases de agente: **listos**, **a medida** y **seguimiento**. Cada **función** (atención a prospectos, atención a clientes, cobranza, vendedor de campaña, seguimiento) tiene **su propio asistente** (wizard): el usuario solo contesta preguntas, le pone nombre y guarda.
- Puede tener **varios del mismo tipo**, por ejemplo «Prospectos Facebook» y «Prospectos página».
- Todos quedan en **la lista de agentes**. Al abrir uno se abre el asistente de su función, porque el agente sabe de qué función es.
- Por estar en la lista, se usan **en toda la plataforma**: campañas, asignación masiva, automatizaciones, «Delegar a agente» del caso, Dali y comandos.
- **Ahora** solo se hacen los asistentes por función. **El asistente genérico de a medida queda para después.**
- Todo lo que se construye para una función (habilidades, revisiones, entrenador) se queda en el motor. Así, cuando se haga el genérico, ya «sabe» todo.

#### 11.14.1 Cómo está hoy (análisis)

Hay **tres motores y tres tablas** que hacen casi lo mismo:

| | Agentes a medida 2.0 | Agentes listos | Seguimiento IA |
|---|---|---|---|
| Tabla del agente | `tracking_templates` (engine '2', `motor2`) | `ready_agents` (`kind`, `settings`) | No hay agente: cada seguimiento es una fila (`ai_follow_ups`). Las «recetas» viven en `ai_follow_up_presets` |
| Plática en curso | `contact_trackings` (+ `motor2_state`) | `ready_agent_sessions` (`answers`) | `ai_follow_ups` (estado, intentos, log) |
| Cómo entra a una plática | Automatización, campaña, asignación masiva, Delegar, Dali (crean `contact_tracking`) | **Por bandeja**: atiende al que escribe si nadie le ha contestado (`ReadyAgents::Router`); uno por bandeja | Delegar desde el caso o Dali, con objetivo propio de esa vez |
| Motor | `Motor2::Runner` + habilidades | `ReadyAgents::Runner` | `AiFollowUps::Runner` |
| Revisa montos, ligas y fugas, con traza | ✅ | ❌ | ❌ |
| Probador y entrenador | ✅ | Solo su chat de prueba | ❌ |
| ¿Sale en la lista y en toda la plataforma? | ✅ | ❌ (solo su pantalla) | ❌ |

Quién contesta, en `Message#analyze_for_active_trackings`, en este orden: Seguimiento IA → 2.0 → agente listo de la bandeja → 1.0.

Lo que **ya existe** y sirve de base:
- `tracking_templates` ya es «la lista»: campañas, `ActionService#assign_tracking_template`, asignación masiva, `Assistant::DelegationRunner` y comandos ya la usan.
- `contact_trackings` ya guarda **objetivo, intentos e intervalo propios por asignación** (`objective`, `ai_context`, `max_attempts`, `retry_interval_*`). Es justo lo que pide «Delegar seguimiento» con objetivo de esa vez.
- El 2.0 ya tiene intentos (`Motor2::Attempt` + `AttemptHook`), citas, casos, archivos, ofertas escalonadas, datos del cliente y pasar a persona.
- Los puestos ya son archivos globales (`config/ready_agents/<kind>.md`, con `title`, `summary` y el texto del puesto). Si mejoramos uno, mejora para todas las empresas.
- `ReadyAgentModal.vue` ya tiene las preguntas de Prospectos (calificar, objetivo, citas, tono, cliente existente) y el chat de prueba.

Lo que **falta en el 2.0** para que las funciones vivan ahí:
- **Entrar por bandeja** (lo que hace `ReadyAgents::Router`). Sin esto, un agente de prospectos solo atiende si una automatización lo asigna.
- Habilidades de los otros motores:
  - **Calificar** (`prospecto_calificado` / `descartar`, con sus resultados: oportunidad, pasar, recolectar);
  - **Catálogo** (`buscar_en_catalogo`);
  - **Seguimiento** (`programar_siguiente_contacto`, `marcar_cumplido`, `cerrar_sin_exito`, y el turno de plantilla con la ventana de WhatsApp cerrada);
  - avisos a quien delegó (`AiFollowUps::Notifier`).
- **Capa «puesto»** en `Motor2::Prompt`: hoy el prompt es habilidades + instrucciones de la empresa; falta el texto del puesto de la función.

#### 11.14.2 Cómo queda

```
                    MOTOR 2.0 (Motor2::Runner + habilidades + revisiones + traza)
                                          │
      ┌───────────────────────────────────┼───────────────────────────────────┐
  Función: Prospectos      Clientes   Cobranza   Vendedor campaña   Seguimiento     A medida (después)
  (puesto + habilidades fijas + preguntas del asistente + valores por omisión + pruebas)
      │
  Asistente de la función ──► guarda un tracking_template (engine '2', function 'prospects', nombre)
      │
  Lista de agentes (todos) ──► campañas · asignación masiva · automatizaciones · Delegar · Dali · bandeja
      │
  Plática en curso = contact_tracking (motor2_state) — una sola forma para todos
```

- **Una tabla de agentes:** `tracking_templates` gana `function`, con valores `prospects`, `customers`, `collections`, `campaign_seller`, `follow_up` y `custom`. `custom` es el a medida 2.0 de hoy.
- **Una tabla de pláticas:** `contact_trackings`. Los seguimientos y las sesiones de agentes listos pasan a ser `contact_trackings` de un agente 2.0.
- **Una función = un archivo de catálogo** (`config/agent_functions/<function>.yml` + el `.md` del puesto). Trae:
  - **puesto:** el texto del puesto, que va en el prompt;
  - **habilidades** que trae prendidas y las que el asistente deja escoger;
  - **preguntas del asistente**, con su campo en `motor2` y su valor por omisión;
  - **cómo entra:** por bandeja, asignado o delegado;
  - **pruebas base:** pláticas que todo agente de esa función debe pasar (para el probador).
- **El asistente lee el catálogo** y escribe en la misma ficha `motor2` que el a medida. Por eso, cuando exista el genérico, un agente de función se puede abrir ahí («Personalizar») sin copiarlo.
- **Mejoras:** quien edita en el asistente sigue recibiendo las mejoras del puesto y de las habilidades. Solo dejaría de recibirlas al editar el texto del puesto en el genérico, y se avisa antes (§11.9).
- **Entrar por bandeja:** la ficha guarda «Atiende a quien escribe a la bandeja X».
  - Para el 2.0 se copia la regla de `ReadyAgents::Router`: atiende si nadie del equipo ha contestado, crea el `contact_tracking` y, si una persona escribe, se hace a un lado.
  - **Un agente principal por bandeja** (como hoy). El reparto entre varios queda para después (§11.9).
- **Seguimiento como función:**
  - «Delegar seguimiento» (caso o Dali) sigue pidiendo el objetivo de esa vez. Por dentro crea un `contact_tracking` del agente de seguimiento, con su objetivo, intentos e intervalo.
  - Las **recetas** (`ai_follow_up_presets`) pasan a ser **agentes de la función Seguimiento** en la lista.
  - Cada cuenta tiene uno base, «Seguimiento», para delegar sin receta.
  - Quien delegó recibe los mismos avisos de hoy.
- **El orden de quién contesta** se simplifica: el `contact_tracking` vivo de la plática (2.0) → si no hay, el agente principal de la bandeja → 1.0.

#### 11.14.3 Pasos (un commit por paso, rama nueva desde develop)

| Paso | Qué | Resultado para el usuario |
|---|---|---|
| **F0 Base** | `tracking_templates.function` (los 2.0 de hoy → `custom`); catálogo de funciones (`Motor2::Functions`) leído de `config/agent_functions`; capa «puesto» en `Motor2::Prompt`; la lista muestra la función y abre su asistente; «Nuevo agente» muestra las funciones (las que faltan, «Próximamente») | Nada cambia todavía; la lista ya distingue funciones |
| **F1 Entrar por bandeja** | «Atiende a quien escribe a la bandeja» en el 2.0 (router propio, un principal por bandeja, se hace a un lado si escribe una persona); ese lugar va en `analyze_for_active_trackings` | Un agente 2.0 puede atender una bandeja sin automatización |
| **F2 Habilidades que faltan** | Calificar, Catálogo, Seguimiento (siguiente contacto, cumplido, cerrar sin éxito, plantilla con ventana cerrada) y avisos a quien delegó, cada una con sus 5 piezas (§11.6) y pruebas copiadas de los motores viejos | El motor ya sabe todo lo que saben los tres |
| **F3 Prospectos** | Asistente paso a paso (preguntas de `ReadyAgentModal`, una por pantalla, con el chat de prueba al final, nombre y guardar), sobre `tracking_templates`; migración `ready_agents` → `tracking_templates` (`function: prospects`); sesiones activas → `contact_trackings`; «Cómo habla tu empresa» sigue igual | Prospectos en la lista, varios por cuenta, usables en campañas y automatizaciones |
| **F4 Seguimiento** | Función `follow_up`: recetas → agentes; «Delegar seguimiento» y Dali crean `contact_tracking`; avisos; los `ai_follow_ups` vivos terminan con el motor viejo y los nuevos van al 2.0 | Un solo motor para seguimientos, con traza y probador |
| **F5 Probador por función** | El probador trae todos los agentes de la lista; el entrenador corrige en la pregunta del asistente donde vive el error («Esto se cambia en el paso Calificar»); cada función trae sus pruebas base | Los 👎 llevan a la pantalla que el usuario conoce |
| **F6 Funciones nuevas** | Atención a clientes (casos, estado, quejas), Cobranza (promesa de pago), Vendedor de campaña. Cada una = puesto + habilidades (las que falten se agregan al motor) + asistente + pruebas base. Una por commit | Más agentes listos, cada uno en dos clics |
| **F7 Limpieza** | Se borran `ReadyAgents::Runner`, `AiFollowUps::Runner` y sus rutas de respuesta, y las tablas viejas cuando no quede nada vivo; guías de Dali; el «Agentes listos» del menú lleva a la lista filtrada | Un motor, una lista |
| **Después** | Asistente genérico de a medida (todas las habilidades, «Personalizar»); varios agentes por bandeja con reparto; apagar el 1.0 | — |

#### 11.14.4 Cuidados y decisiones que tomé (para revisar)

- **No se toca el 1.0** (excepción de §11.3: los desvíos para que conteste el 2.0).
- **Migraciones sin perder nada:** cada agente listo y cada receta pasan con su nombre, bandejas, preguntas y estado. Las pláticas vivas pasan sin cortar, o terminan con el motor viejo (Seguimiento IA).
- **Antes de borrar un motor viejo**, sus pruebas actuales se pasan al 2.0 y tienen que pasar.
- **Varios del mismo tipo:** se pueden tener varios Prospectos. Para atender la misma bandeja, solo uno es el principal; los demás entran por campaña, automatización o asignación.
- **Interruptor por cuenta** mientras se prueba en real (por ejemplo, Prospectos sigue con el motor viejo). Se quita en F7.
- **Pendiente de decidir con el usuario:**
  - el orden de las funciones nuevas en F6;
  - si «Agentes listos» sigue como entrada del menú (catálogo de funciones) o solo queda «Nuevo agente» en la lista.

#### 11.14.5 Decisiones del 2026-11-19 y plan de Atención a prospectos (la primera función)

**Decisiones del usuario:**
- **Primero Atención a prospectos.** Se alinea al motor 2.0 y queda como modelo para las demás funciones. Después sigue Atención a clientes, y así una por una.
- **Catálogo de funciones en archivos** (`config/agent_functions/<función>.yml` + `.md` del puesto), no en una tabla.
- **Agentes creados en `tracking_templates`** (columna `function`). Los campos especiales de cada función van en `motor2.answers`, que son **las respuestas del asistente tal cual**. El motor arma el prompt al vuelo con el puesto y esas respuestas, así que mejorar el uso de una respuesta mejora a todos los agentes de esa función.
- **«Agentes listos» se queda en el menú como catálogo:** una tarjeta por función, con los agentes que tiene la empresa y «+ Crear uno». Los agentes también salen en la lista de agentes con su etiqueta y se abren con su mismo asistente.

**Lo que hace hoy el agente de Atención a prospectos (y tiene que seguir haciendo):**
- **Entrar:** atiende por bandeja (varias bandejas por agente) al que escribe si nadie del equipo le ha contestado, con un agente prendido por bandeja. Si una persona escribe, se hace a un lado.
- **Preguntas para calificar:** 7 armadas que se prenden y editan (necesidad, cuándo, presupuesto, quién decide, ubicación, cantidad, de dónde viene), más preguntas propias.
- **Cuándo califica y cuándo se descarta**, con **temperatura** (caliente, tibio, frío) y su etiqueta.
- **Objetivo al calificar:** pasar a persona o equipo, crear la oportunidad, juntar datos, o agendar cita.
- **Datos obligatorios antes de pasarlo:** nombre, correo, empresa, ciudad.
- **Objeciones frecuentes** con su respuesta.
- **Tu negocio:** qué vende, a quién, cobertura, por qué elegirnos, datos prácticos y, si se quiere, el Catálogo de productos.
- **Ya es cliente:** se lo pasa a su responsable fijo o a quien se eligió, y no entra al embudo.
- **Citas** en Google con varias personas a elegir, con duración, tipo y lugar.
- **Resultados que mueven el embudo de contactos:** etiqueta «interesado», nota con las respuestas, oportunidad, conversación resuelta al descartar.
- **«Cómo habla tu empresa»** y la nota del contacto para IA.
- En la conversación, el panel del contacto muestra el estado del agente (`ReadyAgentStatus.vue`).

**Pasos** (rama nueva desde develop, un commit por paso):

| Paso | Qué | Detalle |
|---|---|---|
| **P0 Base** | Función en el agente y catálogo | `tracking_templates.function` (los 2.0 de hoy → `custom`) y `tracking_templates.attend_inbox_ids` (bigint[]: las bandejas que atiende sin automatización). `config/agent_functions/prospects.yml` (título, resumen, habilidades, preguntas del asistente, valores por omisión, cómo entra) y `prospects.md` (el puesto que hoy está en `config/ready_agents`). `Motor2::Functions` lee el catálogo. `Motor2::Prompt` gana la capa «puesto» y los bloques que salen de `answers` (preguntas, objeciones, datos obligatorios, negocio, cita), copiados de `ReadyAgents::Prompt` |
| **P1 Entrar por bandeja** | Que un agente 2.0 atienda una bandeja | `Motor2::InboxRouter`, copia de la regla de `ReadyAgents::Router`. Al primer mensaje crea el `contact_tracking` del agente, activo y **sin intentos** (el de prospectos no persigue al cliente; si un día se quiere, se prende). Un agente principal por bandeja (validación). Se hace a un lado si una persona escribe. Su lugar en `analyze_for_active_trackings`: después del 2.0 con seguimiento vivo y antes del agente listo viejo |
| **P2 Habilidades** | Lo que el 2.0 no sabe y prospectos sí | **Calificar** (`prospecto_calificado` / `descartar`, con temperatura y los resultados de `ReadyAgents::Outcomes`, copiados). **Catálogo** (`buscar_en_catalogo`). **Ya es cliente** (`ClientCheck` + `ClientHandoff`, copiados). **Datos obligatorios** con la habilidad Datos (nombre, correo, empresa, ciudad → contacto). **Citas:** la del 2.0 gana «personas a elegir» además de las agendas de la ficha. Cada una con sus pruebas, copiadas de `spec/services/ready_agents` |
| **P3 Asistente** | La pantalla paso a paso | Pasos: 1 nombre y bandejas · 2 tu negocio · 3 qué le preguntas · 4 cuándo califica y cuándo no · 5 qué hacer al calificar y a quién · 6 objeciones · 7 tono e indicaciones · 8 pruébalo (chat con el motor 2.0 real y su traza) · 9 guardar. Al editar se abre el mismo asistente y se puede saltar a cualquier paso. La tarjeta de «Agentes listos» lista los agentes `prospects`; la lista de agentes los muestra con la etiqueta «Prospectos» y abre su asistente |
| **P4 Migración** | Pasar los que ya existen | Cada `ready_agent` → `tracking_template` (`function: prospects`, `engine: '2'`, mismo nombre, `attend_inbox_ids`, `answers` = sus `settings`, prendido o apagado igual). Cada sesión activa → `contact_tracking` con sus respuestas en `motor2_state`. Las tablas viejas no se borran todavía: quedan de respaldo hasta P6 |
| **P5 Probador, panel y Dali** | Que todo lo demás lo vea | Los agentes de prospectos salen en el probador («En prueba»); el entrenador dice en qué paso del asistente se corrige. El panel de la conversación muestra su estado desde el `contact_tracking`. Guía de Dali `agentes_listos.md` |
| **P6 Limpieza** | Quitar el motor viejo de prospectos | Se borran `ReadyAgents::Runner`, `Router`, `ReplyJob`, el modal viejo y sus rutas. Las tablas `ready_agents` y `ready_agent_sessions` se borran en una migración aparte cuando ya esté probado en real |

**Al terminar:** el agente de Atención a prospectos ya funciona con el motor 2.0. Se puede tener varios, salen en la lista y se pueden usar en campañas, automatizaciones, asignación masiva, «Delegar a agente» y Dali. Todo lo que se hizo (puesto, calificar, catálogo, ya es cliente, entrar por bandeja) queda en el motor para las funciones siguientes.

**Cuidados:**
- El 1.0 no se toca.
- Seguimiento IA no se toca en esta etapa: va en su propio turno, como función.
- Mientras exista el motor viejo, nunca contestan dos. Una bandeja tiene agente principal 2.0 o agente listo viejo, no los dos: la migración apaga el viejo al prender el nuevo.

**Nombres (decisión del usuario, 2026-11-19):** la **función** se llama siempre con su nombre completo: «Atención a prospectos», «Atención a clientes», «Cobranza», «Vendedor de campaña», «Seguimiento». Ese nombre sale en la tarjeta, en la etiqueta de la lista y en el asistente; no se abrevia a «Prospectos». El **nombre del agente** lo pone cada empresa («Ana – Facebook»). La clave `prospects` solo vive en el código.

#### 11.14.6 Estado (2026-11-19): P0–P6 hechos en `feat/atencion_prospectos_motor2`

**Hecho:** «Atención a prospectos» funciona con el motor 2.0. El agente vive en la lista de agentes, se crea y edita con su asistente paso a paso y puede haber varios.

**Decisiones que tomé** (para revisar):
1. **Columnas:** se llaman `agent_function` (no `function`, para no chocar con la palabra de SQL ni con métodos de Ruby), `attending` (prendido/apagado) y `attend_inbox_ids`. Los 2.0 que ya existían quedan como `custom`.
2. **Catálogo:** `config/agent_functions/*.yml` + `prospects.md`. Las funciones que aún no existen salen como «Próximamente» porque no tienen clase (`Motor2::Functions::CLASSES`).
3. **Respuestas del asistente** en `motor2['answers']`. Las indicaciones van en `motor2['instructions']`, el mismo campo que corrige el entrenador. Por eso, en un agente de función, todo lo que corrige el entrenador cae en «Indicaciones», que es el único texto libre que enseña el asistente (`Motor2::Trainer::AgentFix`).
4. **Nombre que ve el cliente** separado del nombre del agente: el asistente pregunta los dos. Los agentes listos de antes pasan con su nombre en los dos.
5. **Entrar por bandeja** (`Motor2::InboxRouter`): el seguimiento se crea **activo, con 1 intento y fecha a 10 años**. `ContactTrackingJob` no corre intentos en activo y nadie lo toma por pendiente. Si mientras espera una automatización le da un agente 1.0 a la conversación, contesta ese 1.0 (`Motor2::ReplyJob#hand_to_v1`).
6. **Quién gana:** si la conversación ya tuvo un agente (campaña o automatización), contesta ese y no el de la bandeja (§11.9).
7. **Resultados** (`Motor2::Functions::ProspectOutcomes`, copia de `ReadyAgents::Outcomes`):
   - calificado → `objective_met` (outcome `qualified…`);
   - descartado → `cancelled` (outcome `discarded`) y la conversación se resuelve;
   - pasado a persona → `paused` (outcome `handed_off`, se puede reanudar);
   - era cliente → `objective_met` (outcome `client`);
   - con cita → sigue activo (outcome `Cita …`).
8. **Habilidades nuevas del motor** (sirven a todos los agentes 2.0): **Calificar** (`qualify`) y **Catálogo** (`catalog`). Con Calificar prendida no sale `objetivo_cumplido` y `pasar_a_humano` acepta temperatura. **Citas** acepta `user_ids` y `minutes` de la función. Al agendar, la función hace lo suyo (`Motor2::Outcomes#booked`).
9. **Ya es cliente** (`Motor2::ClientCheck`): se revisa al empezar, sin llamar al modelo.
10. **Borrar** un agente de función con historia lo **archiva**. Las versiones y pruebas no dejan borrarlo por llave foránea, cosa que ya pasaba con los 2.0. La lista de agentes ya no enseña los archivados.
11. **Migración** (`20261119120000_agent_functions`, una sola): pasa cada agente listo y sus pláticas vivas, apaga el de antes y guarda `settings.moved_to`. No pasa dos veces. Si el nombre ya existe, le agrega «(Atención a prospectos)». Las tablas `ready_agents` y `ready_agent_sessions` se quedan de respaldo; el panel de la conversación todavía enseña las sesiones viejas.
12. **Limpieza (P6):**
    - se borraron `ReadyAgents::Runner`, `Router`, `Prompt`, `Outcomes`, `Qualification`, `Appointments`, `ClientCheck`, `ClientHandoff`, `CatalogSearch`, `Catalog`, `ToolDefinitions`, `ReplyJob` y `config/ready_agents`;
    - se quedan los modelos `ReadyAgent` / `ReadyAgentSession` (respaldo);
    - los datos del negocio de la cuenta, si nunca se guardaron, salen ahora del agente de función.

**Falta probar en real:** una bandeja de WhatsApp con el agente prendido, cita con Google, oportunidad, y la migración con los agentes listos de dev.wintook.com.

**Siguiente función:** Atención a clientes, con la misma receta (yml + md + clase de la función + asistente).

#### 11.14.7 Qué sabe cada agente y dónde busca (2026-11-19)

**Pedido del usuario:**
- en el asistente se eligen las fuentes;
- el agente debe saber qué hay en cada una para buscar en la que corresponde;
- la búsqueda nueva de predefinidas, que ya usa el 2.0, se queda.

**Hecho:**
- **Bases de conocimiento sigue siendo el único lugar para conectar fuentes.** Cada tarjeta gana «¿Qué hay aquí y para qué sirve?» (`knowledge_sources.config['purpose']`, `PATCH knowledge_base/sources/:id/purpose`). Vacío, enseña lo que se calcula de lo que tiene.
- **`Motor2::SourceMap`**: qué hay en cada fuente, sin IA. Usa el `purpose` o lo calculado:
  - predefinidas: sus categorías General / Fichas / Objeciones con algunos nombres;
  - hoja: sus columnas, cuántas filas y si es de datos exactos;
  - documento y artículos: algunos títulos;
  - foro: se consulta en vivo.
- **El agente recibe «DÓNDE BUSCAR»** en las instrucciones de «Qué sabe» (solo con dos fuentes o más): busca primero con `fuente` en la que corresponde y, si no sale, en todas.
- **Hojas en modo «Datos»**: `Motor2::Search` las busca exacto con `SheetQueryService`, como el 1.0, en vez de por parecido. Cierra el hueco de la hoja de Google del 17/11.
- **Asistente de Atención a prospectos**: paso nuevo «Qué sabe», después de «Tu negocio». Las predefinidas van siempre y las demás se marcan; se guardan en `motor2['sources']`.
- **Entrenador**: causa nueva «🧭 Dónde busca» (`where`). El dato estaba en otra fuente y su «¿Qué hay aquí?» no lo dejaba ver. Propone el texto y «Cambiar «¿Qué hay aquí?»» lo guarda de un clic (`agent_tester/fix_purpose`). El entrenador recibe `mapa_de_fuentes`.

### 11.15 Atención a clientes — análisis y plan (2026-11-19; C0–C5 hechos el mismo día, ver §11.15.6)

**Base:** el «PLAN FUNCIONAL — RAMAS COMERCIAL Y ADMINISTRATIVO» del Agente Coordinador Kontrolya V1.0 (lo pasó el usuario; define Comercial y Administrativo; Soporte solo se menciona, con severidades #soporte1/2/3). Lo traduzco al motor 2.0: **sin rutas ni @directivas**, con **áreas** que se eligen en el asistente y reglas que **manda el código** (lo que aprendimos con Atención a prospectos: lo que solo se le pide al modelo, a veces no lo hace).

#### 11.15.1 Cómo lo resuelven otros (investigación 19/11)

| Plataforma | Idea que tomamos |
|---|---|
| Intercom Fin | **Procedures:** instrucciones en lenguaje natural con controles deterministas (condiciones, conectores de datos). **Cuándo se activa:** descripción corta + ejemplos de «sí aplica» y «no aplica» (hasta 20). **Escalación** en dos capas: reglas por datos (sentimiento, tipo, VIP) y guía en texto; recomiendan guía concreta («más reglas = más escalaciones»); nunca ofrecer escalar dos veces seguidas. Se prueban con simulaciones antes de publicar. |
| Zendesk AI agents | Respuestas generativas para preguntas frecuentes (desde el centro de ayuda); **procedimientos** paso a paso con entradas y salidas; al pasar a una persona, el contexto viaja y se rutea al equipo correcto. |
| Salesforce Agentforce | El agente = **temas** (ahora «subagentes») con **instrucciones + acciones**, y un **router** que elige el tema. Guardrails en las instrucciones (p. ej. «si la base tiene información contradictoria, no contestes: ofrece levantar un caso»). |
| HubSpot Customer Agent | Fuentes sincronizadas (artículos, páginas, archivos); pasa a una persona cuando **la confianza es baja** o se cumple una regla; reparto por equipo/canal. |
| Decagon (AOPs) | Por cada mensaje: **extraer la intención con toda la plática**, elegir el procedimiento; si ninguno aplica, contestar con la base de conocimiento. Las acciones sensibles solo por procedimiento. |

Coinciden en: (1) un **clasificador** que mira la plática completa (no la palabra), (2) cada tema con **qué hace y qué no**, (3) **contestar solo con lo que está en las fuentes**, (4) **acciones reales** (crear caso, agendar) y nunca simuladas, (5) **ejemplos de sí/no** para afinar la clasificación y **probar antes de publicar**.

#### 11.15.2 Cómo queda en el motor 2.0

- **Función** `customers` («Atención a clientes») en `config/agent_functions` + `Motor2::Functions::Customers`, con su asistente (mismo patrón que prospectos).
- **Áreas** (las de tu plan): **Soporte**, **Comercial**, **Administrativo**; se prenden las que la empresa atiende (y se puede agregar «Otra» con su nombre). Cada área trae: cómo se reconoce (ejemplos sí/no, ya llenos con la matriz del plan), qué hace, a quién se pasa y qué fuentes usa.
- **Clasificador (router) del código** — `Motor2::Triage`, revisión corta con IA (como `AnswerCheck`) en cada mensaje del cliente, con la plática y lo pendiente:
  `{ areas: ['comercial', 'administrativo'], intencion: 'cotización de 10 usuarios', suficiente: true|false, aclaracion: '¿Qué deseas cotizar?', sub: 'informacion'|'gestion', severidad: 1..3 }`.
  - **Continuidad (§18):** si quedó una aclaración pendiente, el siguiente mensaje se evalúa primero contra ella («10 usuarios» completa «cotización»), guardado en `motor2_state['pendiente']`.
  - **Multi-intención (§19):** se guardan todas en `motor2_state['pendientes']` y se atienden una por una; ninguna se pierde (el código le recuerda las que faltan).
  - **Por intención, no por palabra (§2):** ejemplos de la matriz («No puedo enviar una cotización a pedido» → Soporte) van en el prompt del clasificador.
- **Lo que manda el código en cada turno** (no solo se le pide al modelo):
  - **Solo herramientas del área en curso** (Administrativo no tiene buscar; Comercial no levanta casos de soporte): así no invade otra área.
  - **Insuficiente → una sola aclaración y no busca** (§5): ese turno no tiene herramienta de búsqueda y el mensaje se revisa para que sea una sola pregunta.
  - **Evidencia (§6–8, fail closed):** en Comercial, antes de mandar, una revisión con IA compara la respuesta con lo que trajo la búsqueda: EXACTA → se manda; PARCIAL/NO_CONFIRMADA/CONTRADICTORIA/SIN_EVIDENCIA → se reescribe diciendo lo que sí está confirmado y que lo demás no se puede confirmar. Incluye el **candado**: no cambiar la intención (visita ≠ demo).
  - **No simular acciones (§13, inv. 12):** si el mensaje dice «ya agendé / ya levanté tu caso / ya te pasé» sin que la herramienta lo haya hecho, se reescribe (como la revisión de «prometió pasarlo»).
  - **Información ≠ acción (inv. 8):** «Quiero una demo» con evidencia de que hay demos → se reconoce la gestión y se hace la acción elegida (agendar / pasar al vendedor); nunca «ya quedó» sin herramienta.

#### 11.15.3 El asistente (wizard) que propongo

| Paso | Qué pregunta | Notas |
|---|---|---|
| 1 El agente | Nombre, nombre que ve el cliente, tono, bandejas, prendido | Igual que prospectos |
| 2 Tu negocio | Qué vendes / a quién / cobertura | Reusa |
| 3 Qué atiende | Tarjetas: **Soporte**, **Comercial**, **Administrativo** (+ «Otra área»). En cada una: «Cómo se reconoce» con ejemplos **sí** y **no** (vienen llenos con la matriz del plan; se editan) | La matriz del §15 ya queda como ejemplos y como pruebas |
| 4 Soporte | Fuentes (foro, predefinidas, CONTPAQi); si no se resuelve: **levantar caso** (tipo) con su **severidad** (bloqueo total / parcial / duda) o **pasar al equipo**; preguntas mínimas (qué pasa, desde cuándo, a cuántos afecta) | Severidad la decide el código con el clasificador |
| 5 Comercial | Fuentes (predefinidas, catálogo, hojas); qué hace con cada gestión: **cotización** (crear oportunidad / pasar al vendedor), **demo** y **visita** (agendar con quién / pasar), **hablar con vendedor** (a quién) | Candado visita ≠ demo fijo |
| 6 Administrativo | A quién se pasa (persona o equipo); ¿levantar un caso administrativo? | No consulta fuentes (fijo en esta versión) |
| 7 Cómo platica | Bienvenida; si no es cliente (atenderlo igual / pasarlo al agente de «Atención a prospectos» / a una persona); si pide una persona (de inmediato / primero entender qué necesita); varias cosas a la vez (atiende una por una — fijo) | Mismo estilo de opciones que prospectos |
| 8 Indicaciones | Texto libre (opcional) | |
| 9 Pruébalo | Chat de prueba **+ «Probar la matriz»**: corre todos los ejemplos sí/no y muestra área detectada vs esperada (✅/❌) | Lo que recomiendan Intercom y Zendesk: probar antes de publicar |

#### 11.15.4 Pasos (cada uno con pruebas con el modelo real, como con prospectos)

| Paso | Qué |
|---|---|
| C0 | Función `customers` (catálogo, clase, asistente pasos 1–2–7–8–9), estado de su caso (`estado_caso`) y «¿es cliente?» con su opción |
| C1 | **Clasificador** (`Motor2::Triage`): áreas, suficiencia, continuidad, multi-intención; paso 3 del asistente; **«Probar la matriz»** |
| C2 | **Administrativo:** entender y canalizar, sin fuentes, sin pedir datos de más (el más simple; sirve para probar el clasificador de punta a punta) |
| C3 | **Comercial:** información con **evidencia (fail closed)** y candado de intención; gestiones (oportunidad, cita de demo/visita, vendedor) |
| C4 | **Soporte:** fuentes técnicas, severidad, levantar caso / pasar, estado de caso |
| C5 | No simular acciones, pide persona, no es cliente, probador por área, guía de Dali |

#### 11.15.5 Decisiones que tomé (para revisar)

1. **Áreas fijas (Soporte, Comercial, Administrativo) + «Otra»**, no texto libre: es lo de tu plan y lo que hacen Salesforce (temas) e Intercom (procedimientos); «Otra» cubre negocios distintos.
2. **El clasificador es una llamada aparte con IA** (gpt-4.1-mini, AiModels::REVIEW), no el modelo que contesta: así decide con la plática completa y su decisión la usa el código (herramientas del turno, continuidad), como el router de Agentforce y la extracción de intención de Decagon.
3. **Severidad de soporte** (tu plan solo la nombra): #soporte1 = no puede operar (bloqueo total); #soporte2 = funciona con falla o a medias; #soporte3 = duda de uso o configuración. Se puede cambiar en el asistente.
4. **Evidencia fail closed solo en Comercial** (tu plan); en Soporte se contesta con fuentes y, si no hay, se levanta caso o se pasa.
5. **«Probar la matriz»** usa los mismos ejemplos sí/no del paso 3; los que fallen se pueden mandar al probador (lotes).
6. **Quien no es cliente:** por omisión se pasa al agente de «Atención a prospectos» de la bandeja (si hay) o a una persona.

#### 11.15.6 Cómo quedó (2026-11-19, rama feat/atencion_clientes_motor2)

| Paso | Hecho | Dónde |
|---|---|---|
| C0 | Función `customers` disponible; puesto, negocio, precios, tono; «¿no es cliente?» | `config/agent_functions/customers.{yml,md}`, `Motor2::Functions::Customers`, `CustomerOutcomes` |
| C1 | Clasificador con continuidad, multi-intención, severidad, pide persona; «Probar la matriz» (22/22 con los ejemplos de fábrica) | `Motor2::Triage`, `Motor2::TriageMatrix`, `POST /ready_agents/matrix` |
| C2 | Administrativo: sin fuentes, una pregunta y canaliza (o caso administrativo) | `Motor2::Skills::Areas` + `AreaActions` |
| C3 | Comercial: evidencia fail closed (`Motor2::EvidenceCheck`), candado visita ≠ demo, oportunidad / vendedor / cita | `AreaSales`, `Motor2::AreaChecks#ensure_evidence` |
| C4 | Soporte: fuentes, severidad → prioridad (1 urgente sin preguntar, 2 alta, 3 media), caso sin duplicar, `estado_caso` | `AreaActions#create_case` |
| C5 | No simular acciones (también la cita en prospectos), pide persona (pregunta una vez y canaliza al área), par prospectos + clientes por bandeja, asistente, guía de Dali | `Motor2::AreaChecks`, `Motor2::InboxRouter`, `TrackingTemplate::ATTENDING_PAIR`, `CustomersAgentModal.vue` |

**Decisiones al hacerlo (cambian lo de §11.15.5):**
- **No es cliente:** por omisión **lo atiende igual** (`not_client: serve`); muchos clientes reales no están marcados como tales (sin organización en etapa Cliente ni casos), y rechazarlos sería peor. Si la bandeja tiene el par, los que no son clientes ya van con el de prospectos.
- **Una pregunta y se actúa:** en Administrativo, Soporte y una gestión comercial, después de una aclaración el código obliga a actuar (levantar, registrar o canalizar); nada de pedir datos uno por uno.
- **Multi-intención:** se atiende la primera; si se canaliza, lo pendiente de la cola va en la nota para la persona (no se pierde) en vez de seguir el agente con otra área ya pausado.
- **Severidad fija** (no se cambia en el asistente): se explica en el paso de Soporte.
- Finish (`objetivo_cumplido` / `descartar`) no aplica en clientes; `pasar_a_humano` solo sin área (con área se usa `canalizar`, que asigna a la persona o equipo de esa área).
- **Pruebas con el modelo real:** cotización incompleta → aclaración → oportunidad; RFC → una pregunta → canaliza a Administrativo; «no puedo operar» → caso urgente al instante; «¿qué planes tienen?» sin fuente → no inventa y ofrece vendedor; «quiero hablar con una persona» → pregunta qué necesita → canaliza al área.

