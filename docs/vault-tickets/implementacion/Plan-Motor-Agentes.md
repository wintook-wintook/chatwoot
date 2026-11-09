# Plan — Motor nuevo de agentes (agentes base + habilidades)

> Acordado con el usuario el 2026-11-09. **Estado: guardado, sin empezar.** Se retoma
> cuando el usuario diga; la idea es construirlo todo de un jalón (M1–M5) y probar después.

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
