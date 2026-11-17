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
