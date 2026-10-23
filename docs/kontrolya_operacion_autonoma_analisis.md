# Kontrolya en modo automático — agentes IA, casos y humanos

**Análisis de arquitectura y propuesta** · 2026-10-21 · rama `feat/nva_oportunidad` · solo análisis, nada programado

> Principio que pidió el usuario: **los agentes hacen todo; el humano solo hace lo que los
> agentes no pueden.** Este documento revisa qué ya existe en Kontrolya, qué falta para
> conectarlo, cómo se activan los agentes, cómo entran los humanos (uno o varios) y qué
> hacer con el sistema administrativo (integrar el ERP o facturar desde Kontrolya).

---

## 1. Lo que ya existe (inventario real del código)

Kontrolya ya tiene casi todas las piezas. El problema no es que falten agentes: es que
**trabajan como islas**.

| Pieza | Qué hace hoy | Dónde |
|---|---|---|
| **Canales** | WhatsApp, Telegram, chat web, Instagram, correo (Chatwoot) | `channel/*` |
| **Motor de Seguimientos (Agentes IA)** | El agente conversacional: Entrenamiento + directivas (`@buscar_predefinidas`, `{{consulta:}}`, `@crear_ticket`, `@estado_ticket`, `@agendar_calendar`, `@ruta` por rama…). Hay un **coordinador** de 3 ramas (Soporte · Comercial · Administrativo) en prueba | `contact_trackings`, `tracking_templates`, `docs/motor_agentes_ia_manual.md`, `docs/agente_coordinador_kontrolya_analisis.md` |
| **BotSeller** | Agente externo (endpoint) cuando no hay seguimiento activo | `bot_seller/*`, `MessageCoordinator` |
| **Bot cobrador** | Modo A: recordatorios masivos de facturas por vencer/vencidas desde el ERP. Modo B: el cliente consulta su saldo por chat (function calling) | `erp_collection_bot`, `erp_collection/*` |
| **Agente de Servicio CONTPAQi** | Respuestas de la base de conocimiento remota de CONTPAQi | `contpaq/*` |
| **Comandos** | `/sigue`, `/siguecancelar` (agente por comando) | `command_agents/*` |
| **Consultas al ERP** | Aspel SAE, Microsip, CONTPAQi: **solo lectura**, consultas predefinidas (allowlist), la IA elige la consulta pero nunca escribe SQL | `external_db/*` |
| **Casos (MGCI)** | 4 clases (Soporte, Comercial, Orden de trabajo, Proyecto), reglas, SLA, etapas, reuniones con Google Calendar, portal del cliente | `case_*`, `cases/*` |
| **IA dentro de casos** | Clasificar, sugerir respuesta, resumir, detectar repetidos, seguimiento, intake (`@crear_ticket` arma el caso leyendo la conversación), plan de mi día, resumen del negocio, análisis de conversaciones. Cada acción con modo **off / suggest / auto** | `cases/ai/*`, `CaseAiConfig` |
| **Trabajo humano** | Tareas con puntaje y «Mi día»; asignación de conversaciones (Chatwoot); casos asignados | `case_tasks`, `TasksInboxQuery` |
| **Dueño** | Resumen del negocio (todas las clases + conversaciones + IA) | `BusinessSummaryBuilder` |
| **Campañas** | Agente vendedor sobre listas de contactos | `tracking_campaigns/*` |

### Lo que NO está conectado

1. **No hay una sola puerta de entrada.** `MessageCoordinator` decide «si hay seguimiento
   activo responde el seguimiento; si no, BotSeller». El cobrador, CONTPAQi y los comandos
   entran por otros caminos. Nadie tiene la foto completa del cliente.
2. **Los agentes no trabajan los casos.** Pueden crear un caso y decir su estado, pero no lo
   *llevan*: no avanzan etapas, no cumplen tareas, no reaccionan a sus eventos (SLA por
   vencer, promesa vencida, visita sin conformidad).
3. **El humano tiene cuatro bandejas**: conversaciones (Chatwoot), casos, tareas/«Mi día» y
   el resumen. No hay un lugar único donde diga «esto es lo que los agentes no pudieron».
4. **El paso de agente a humano no tiene forma.** Hoy el humano se entera porque mira la
   conversación o porque le asignan algo; no hay «el agente se detuvo aquí, por esto,
   necesita esto de ti, y cuando respondas sigue él».
5. **El ERP es de solo lectura.** Un agente puede decir el saldo, pero no levantar un pedido,
   emitir una factura ni registrar un pago. Ahí se corta la automatización del ciclo de venta.
6. **No se mide la autonomía.** No sabemos cuánto resolvieron los agentes solos ni cuánto
   tiempo humano costó cada caso.

---

## 2. El modelo propuesto: seis capas

```
 ┌──────────────────────────────────────────────────────────────────────────┐
 │ 1. ENTRADAS   canales · portal · ERP (factura vence) · calendario · reloj │
 └───────────────┬──────────────────────────────────────────────────────────┘
                 ▼
 ┌──────────────────────────────────────────────────────────────────────────┐
 │ 2. COORDINADOR   única puerta: identifica cliente, intención y área;     │
 │                  decide qué especialista atiende (o si ya hay un caso)    │
 └───────────────┬──────────────────────────────────────────────────────────┘
                 ▼
 ┌──────────────────────────────────────────────────────────────────────────┐
 │ 3. ESPECIALISTAS  Soporte · Comercial · Administración (cobranza,        │
 │                   facturación) · Operación (órdenes) · Proyectos         │
 │                   cada uno: herramientas permitidas + autonomía por acción│
 └───────────────┬──────────────────────────────────────────────────────────┘
                 ▼
 ┌──────────────────────────────────────────────────────────────────────────┐
 │ 4. CASOS = memoria y contrato   todo lo que no se resuelve en un turno es │
 │    un caso; sus tareas son de un AGENTE o de un HUMANO; la línea de      │
 │    tiempo registra a los dos                                              │
 └───────┬───────────────────────────────────────────────┬──────────────────┘
         ▼                                               ▼
 ┌─────────────────────────────┐          ┌──────────────────────────────────┐
 │ 5. HUMANOS  «Mi día» =      │          │ 6. ADMINISTRATIVO  ERP (leer y    │
 │ bandeja de excepciones,     │          │ escribir) o facturación propia    │
 │ aprobaciones y trabajo      │          │ vía PAC; pagos                    │
 │ físico. Dueño: Resumen      │          └──────────────────────────────────┘
 └─────────────────────────────┘
```

### Por qué el **caso** es el centro

El caso ya tiene lo que un sistema autónomo necesita: dueño, etapa, fechas, SLA, tareas,
historial (`case_events`, con origen `bot`/`agent`/`system`) y métricas. Si **todo trabajo de
más de un turno vive en un caso**, entonces:

- el agente tiene memoria (lee el caso, no la conversación entera);
- el humano tiene contexto (abre el caso y ve qué hizo el agente);
- el dueño tiene números (el resumen ya cuenta casos);
- y la entrega agente → humano → agente es solo **cambiar el responsable de una tarea**.

---

## 3. Cómo se activan los agentes

### 3.1 Disparadores

| Disparador | Ejemplo | ¿Existe? |
|---|---|---|
| **Mensaje entrante** | Cliente escribe por WhatsApp | ✅ (seguimientos / BotSeller) |
| **Evento de caso** | SLA por vencer, promesa de pago vencida, oportunidad sin moverse 15 días, visita sin conformidad | ⚠️ los eventos existen (`case_events`), nadie los escucha para despertar a un agente |
| **Evento del ERP** | Factura por vencer / vencida | ✅ cobrador modo A (por horario) |
| **Calendario** | Recordar la reunión, confirmar asistencia | ⚠️ parcial (seguimientos con calendario) |
| **Reloj** | Seguimientos, campañas, resumen semanal al dueño | ✅ seguimientos/campañas · ❌ resumen semanal |
| **Humano termina su parte** | Aprobó el descuento → el agente manda la cotización | ❌ |

**Propuesta:** usar el motor de **reglas de casos** (`case_rules`, `RuleEngineService`) como el
lugar único donde se declara «cuando pase X, el agente Y hace Z». Hoy las reglas asignan y
enriquecen; se agrega la acción **«encargar a un agente»**. Así no se crea otro motor: el
administrador configura en una pantalla que ya conoce.

### 3.2 Autonomía por acción (no por agente)

Cada acción que puede hacer un agente tiene un nivel, igual que ya funciona `CaseAiConfig`
(off / suggest / auto), pero **por acción y con umbrales**:

| Acción | Nivel inicial sugerido | Pasa a automático cuando… |
|---|---|---|
| Responder preguntas frecuentes | Automático | — |
| Crear / clasificar un caso | Automático | — |
| Agendar una reunión | Automático | — |
| Marcar «comprometida» una oportunidad | Automático | el cliente da fecha explícita |
| Enviar cotización | Sugerir | monto < umbral y lista de precios vigente |
| Dar un descuento | Sugerir (siempre humano arriba del X %) | descuento ≤ X % |
| Emitir factura | Sugerir | cliente recurrente, datos fiscales completos, monto < umbral |
| Cancelar factura / reembolso | **Siempre humano** | nunca |
| Cerrar un caso de soporte | Sugerir | el cliente confirmó |

**Regla de oro:** lo irreversible o lo que mueve dinero empieza en «Sugerir». Se sube a
«Automático» cuando la tasa de aprobación sin cambios pasa de un umbral (por ejemplo, 95 % en
50 casos). Eso se mide (ver §8).

### 3.3 Frenos que siempre aplican

- **Confianza baja** del modelo → excepción al humano.
- **Cliente molesto** (tono) o que pide «quiero hablar con una persona» → humano, siempre.
- **Dato faltante** que el agente no puede obtener → pregunta al cliente; si no responde,
  tarea al humano.
- **Cliente VIP** o monto arriba del umbral → humano aprueba.
- **Reintentos**: si el agente intentó 2 veces y no avanza → humano.
- **Horario y ventana de WhatsApp (24 h / plantillas)** → el agente respeta las reglas del
  canal o deja la tarea programada.

---

## 4. Cómo entran los humanos

### 4.1 Una sola herramienta: «Mi día» como bandeja de excepciones

El humano no debería «revisar conversaciones». Debería abrir **una lista ordenada** con solo lo
que le toca. «Mi día» ya ordena por puntaje; se le agrega el tipo **excepción del agente**:

| Tipo de excepción | Qué ve el humano | Qué puede hacer ahí mismo |
|---|---|---|
| **Aprobar** | «El agente quiere dar 15 % a Grúas del Norte (límite 10 %)» + resumen | Aprobar · Cambiar · Rechazar |
| **Dato faltante** | «No sé el RFC del cliente para facturar» | Escribir el dato |
| **Cliente molesto** | Resumen + últimas frases + caso | Tomar la conversación |
| **Baja confianza** | Pregunta del cliente + respuesta que propone el agente | Enviar · Corregir y enviar |
| **Trabajo físico** | Visita técnica, entrega | Marcar hecha / conformidad |
| **Decisión** | «El cliente pide plazo de 60 días» | Responder |

Cada excepción es una **tarea** del caso con: por qué se detuvo el agente, qué espera, fecha
límite y **botones**. Al resolverla, el agente **retoma** solo (vuelve a ser su tarea). Lo que el
humano corrigió alimenta el entrenamiento (respuestas predefinidas, base de conocimiento).

### 4.2 Tomar y devolver una conversación

- El humano **toma** la conversación → el agente se calla en ella (hoy se infiere por la
  asignación; conviene un estado explícito «atiende humano»).
- El humano **la devuelve al agente** con un botón → el agente sigue con el contexto, incluido
  lo que dijo el humano.

### 4.3 Uno o varios humanos

El mismo modelo sirve para los dos casos. La diferencia es **una tabla de responsables por
área**:

| Área | Empresa de 1 persona | Empresa con equipo |
|---|---|---|
| Ventas | Dueño | Gerente comercial (respaldo: dueño) |
| Soporte | Dueño | Supervisora de soporte |
| Cobranza / facturación | Dueño | Administración |
| Operación (visitas) | Dueño | Técnicos (por zona) |
| Escalaciones | — | Dueño |

- **Un solo humano:** todas las áreas apuntan a él. «Mi día» le muestra todo junto, ordenado
  por urgencia, y el **Resumen del negocio** es su tablero. Para que sea su *única*
  herramienta, la excepción se tiene que poder resolver **sin salir de «Mi día»** (aprobar,
  responder al cliente, capturar el dato, aprobar factura) y funcionar bien en el **celular**.
- **Varios humanos:** cada excepción va al responsable de su área (los *equipos* de Chatwoot
  ya existen y los casos ya tienen equipo). Si no la atiende en su SLA, escala al respaldo y
  luego al dueño. El dueño ve el resumen y solo las escalaciones.

---

## 5. El sistema administrativo: ¿integrar o facturar desde Kontrolya?

### 5.1 Hoy

Lectura de Aspel SAE, Microsip y CONTPAQi (saldos, facturas, productos), cobrador de
recordatorios y base de conocimiento de CONTPAQi. **No hay escritura**: el ciclo
venta → factura → cobro se corta en «ganada».

### 5.2 Opciones

| | **A. Conector ERP (leer y escribir)** | **B. Facturación propia (CFDI 4.0 vía PAC)** |
|---|---|---|
| Para quién | Clientes que ya usan CONTPAQi/Aspel/Microsip y su contador trabaja ahí | Pymes sin ERP o con ERP solo para contabilidad |
| Qué haría Kontrolya | Crear cotización/pedido/factura **en el ERP** | Emitir, cancelar y enviar CFDI; complemento de pago; catálogo de productos y datos fiscales |
| Ventaja | El ERP sigue siendo la verdad; no se duplica | Automatización completa y rápida de implementar por cliente |
| Costo / riesgo | Un conector por ERP (APIs/SDK distintas, algunas limitadas) | Regulación SAT (CFDI 4.0, cancelaciones, complementos), soporte fiscal, costo por timbre |
| Proveedores | SDK/API de cada ERP | PAC: Facturama, SW Sapien, Finkok, etc. |

### 5.3 Recomendación: híbrido, en este orden

1. **No hacer contabilidad.** Kontrolya opera (vende, atiende, cobra); la contabilidad se queda
   en el ERP o con el contador.
2. **Primero lo que cierra el ciclo sin tocar al SAT:** cotización → pedido, y **cobranza con
   liga de pago** (Mercado Pago, Conekta, Stripe, Clip). Con eso el agente puede cobrar y
   saber que se pagó, aunque la factura la siga haciendo el ERP.
3. **Facturación básica vía PAC** (opción B) para clientes sin ERP, con el agente en modo
   «Sugerir»: arma la factura borrador desde la oportunidad ganada u orden terminada, el
   humano la aprueba con un clic, se timbra y se envía por WhatsApp/correo.
4. **Conector de escritura al ERP** (opción A) solo para el ERP que más clientes usen
   (probablemente CONTPAQi, que ya está integrado en lectura).

---

## 6. Cómo se ve funcionando (de punta a punta)

### Venta
1. Llega un lead por WhatsApp → **coordinador** → rama Comercial.
2. **Agente comercial** califica, consulta precios en el ERP, crea la **oportunidad**, agenda
   la reunión en el calendario y da seguimiento.
3. El cliente dice «te pago el viernes» → el agente la marca **comprometida** con esa fecha.
4. El cliente pide 15 % → **excepción** «Aprobar descuento» en «Mi día» del vendedor (o del dueño).
5. Aprobado → el agente manda la cotización → **ganada**.
6. **Agente administrativo** arma la factura borrador → **excepción** «Aprobar factura» →
   timbrado → envío con liga de pago.
7. El viernes no pagó → **promesa vencida** (ya existe) → el cobrador escribe solo.
8. Pagó → se registra el pago → caso cerrado. **El humano tocó 2 veces: descuento y factura.**

### Soporte con visita
1. «No funciona el equipo» → agente de soporte crea el **caso**, busca en la base de
   conocimiento y guía al cliente.
2. No se resuelve → crea la **orden de trabajo**, agenda la visita en el primer hueco del técnico.
3. **Excepción de trabajo físico** para el técnico (lo único humano).
4. Conformidad en sitio → el agente cierra y, si es facturable, arma la factura (paso 6 de arriba).

---

## 7. Lo que falta, por fases

| Fase | Qué | Por qué primero |
|---|---|---|
| **F0 · Una sola puerta** | El coordinador es la entrada única; BotSeller, cobrador (modo B) y CONTPAQi pasan a ser especialistas que él invoca. Todo lo de más de un turno crea o continúa un caso | Sin esto, cada agente sigue siendo una isla |
| **F1 · Excepciones en «Mi día»** | Tarea tipo «excepción del agente» (aprobar, dato faltante, molesto, baja confianza, físico, decisión) con botones; al resolver, el agente retoma. Tomar/devolver conversación | Es la puerta de entrada del humano |
| **F2 · Autonomía por acción** | Ampliar `CaseAiConfig`: nivel por acción + umbrales (monto, confianza, descuento) | Permite subir la automatización con datos |
| **F3 · Eventos → agentes** | Acción «encargar a un agente» en las reglas de casos (promesa vencida, SLA por vencer, oportunidad estancada, visita sin conformidad) | Los agentes empiezan a trabajar los casos solos |
| **F4 · Responsables por área** | Tabla área → persona (+ respaldo + escalación) para uno o varios humanos | Ordena a quién le llega cada excepción |
| **F5 · Cobrar** | Cotización → pedido; liga de pago; registro de pago | Cierra el ciclo de dinero sin tocar al SAT |
| **F6 · Facturar** | CFDI vía PAC (borrador → aprobación → timbrado → envío) | La parte con más regulación, al final |
| **F7 · Tablero de agentes** | Qué hizo cada agente hoy, % autónomo, excepciones por tipo, costo de IA; KPI de autonomía en el Resumen del negocio | Sin medir no se puede subir autonomía |

---

## 8. Cómo saber si funciona

- **Tasa de autonomía:** % de casos cerrados sin ninguna excepción humana (por área).
- **Minutos humanos por caso** (tiempo entre que la excepción llega y se resuelve).
- **Aprobación sin cambios:** % de sugerencias que el humano aprueba tal cual (si es alta, esa
  acción puede pasar a automática).
- **Calidad:** satisfacción del cliente, reaperturas, quejas.
- **Costo de IA** por caso.

---

## 9. Riesgos

- **Acciones irreversibles** (facturar, cancelar, mover dinero): siempre empiezan en «Sugerir»
  y con umbral.
- **Alucinación:** los agentes solo usan datos de herramientas (ERP, casos, base de
  conocimiento); los ids se validan como ya se hace (intake, plan de mi día, análisis).
- **Datos personales:** el texto va a OpenAI; conviene aviso de privacidad y la opción de un
  modelo alterno por cuenta.
- **Reglas de WhatsApp** (ventana de 24 h, plantillas aprobadas) para todo lo proactivo.
- **El cliente que quiere una persona:** siempre debe existir la salida «hablar con alguien».
- **Regulación fiscal** (CFDI): mejor un PAC que lo resuelva que construirlo.

---

## 10. Decisiones para el usuario

1. ¿El **coordinador** es la puerta única de todos los canales (F0)?
2. ¿«Mi día» como la **única herramienta** del humano, con excepciones resolubles ahí mismo (F1)?
3. Umbrales iniciales: descuento máximo automático, monto máximo de factura automática.
4. ¿Primero **cobrar con liga de pago** (F5) y después **facturar vía PAC** (F6), o al revés?
5. ¿Qué ERP tiene más clientes para el conector de escritura (¿CONTPAQi?)?
6. ¿Empezamos por un área piloto (sugiero **Comercial**, donde ya está casi todo el ciclo)?
