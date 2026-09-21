# Automatización de campañas: la campaña con ventana

Rama: `feat/automatizacion_campanas` (desde `develop`, 21/09/2026). **Solo plan**: nada se programa
hasta que el usuario lo revise.

Pantalla: `/app/accounts/:id/tracking-dashboard/campaigns`.

---

## 1. Qué se pide

Una campaña tiene **nombre**, **Agente IA**, **fecha y hora**, y una **audiencia** que se arma por
**segmento** o por **etiqueta**. Además, el nombre de la campaña se tiene que poder usar en una
**automatización**, para que la automatización vaya **agregando contactos** a la campaña.

El dilema: si la audiencia llega de a poco por la automatización, ¿qué significan la fecha y la hora?

**Decisión (usuario, 21/09/2026):** la fecha y la hora pasan a ser una **VENTANA** (desde / hasta), no
"el momento del envío".

---

## 2. Lo que hay hoy (medido en `develop`)

```
 Nueva campaña (CampaignForm.vue)                     Automatizaciones (automation/)
 ────────────────────────────────                     ─────────────────────────────
 nombre · Agente IA · fecha (futura)                  acción "Asignar Agente IA"
 audiencia: segmento o etiqueta                        (assign_tracking_template)
 vista previa (listos / ya activos / excluidos)          │
        │                                                │  crea un ContactTracking SUELTO:
        ▼                                                │  sin campaña, programado a
 BulkAssignService ──► BulkAssignJob                     │  "ahora + intervalo de la plantilla"
   · valida (plantilla con inbox, ≤ 100 contactos)       ▼
   · crea la TrackingCampaign                        (no aparece en ninguna campaña)
   · crea un ContactTracking por contacto,
     todos con scheduled_for = la fecha
        │
        ▼
 ExecutePendingJob (cada 5 min) → los que ya vencieron → el agente escribe
```

| Pieza | Hoy |
|---|---|
| `TrackingCampaign` | `name`, `objective`, `status` (draft · running · paused · finished; nace en `running`), `scheduled_for`, `inbox_id` (fijo), `tracking_template_id`, `user_id`. Agrupa sus `contact_trackings`. |
| La audiencia | se resuelve **una vez**, al crear, con el filtro del segmento o la etiqueta. No se guarda cuál era. |
| La fecha | una sola, obligatoria y futura: todos los seguimientos quedan programados a esa hora. |
| Duplicados | un solo seguimiento activo por (contacto, inbox): el bulk omite a los que ya tienen uno ("ya activos"). |
| Automatización | "Asignar Agente IA" existe, pero no sabe de campañas. |

Lo que falta para la idea: que una campaña pueda **seguir recibiendo** gente, que la automatización
pueda **nombrar la campaña**, y que la fecha diga **hasta cuándo** se recibe.

---

## 3. La idea: dos tipos de campaña y una ventana

```
 POR LOTE (audiencia fija)                     CONTINUA (audiencia dinámica)
 ─────────────────────────                     ──────────────────────────────
 audiencia = segmento o etiqueta                audiencia = quien las automatizaciones
             tomada una vez                                 inscriben mientras la ventana
                                                            esté abierta
 ventana = inicio (y fin opcional)              ventana = inicio → fin (fin opcional)

   lun 10:00 ──► 150 inscritos a la vez          01/oct ────────────────────── 31/oct
                                                   │ 03/oct Ana (etiqueta demo)  ✔ inscrita
                                                   │ 05/oct Luis (conv. nueva)   ✔ inscrito
                                                   │ 05/oct Ana otra vez         ⊘ ya inscrita
                                                   ▼ 02/nov Eva                  ⊘ ventana cerrada
```

### 3.1 Nombres

| Concepto | Nombre en la pantalla |
|---|---|
| Campaña que se arma una vez, con segmento o etiqueta | **Por lote** |
| Campaña que va recibiendo contactos por automatización | **Continua** |
| Audiencia del segmento o la etiqueta | **Audiencia fija** |
| Audiencia que llega por automatización | **Audiencia dinámica** |
| Cada contacto que entra a una campaña | **Inscripción**; los contactos, **inscritos** |
| Contacto que no entró (y por qué) | **Omitido** |

### 3.2 La ventana

```
            inicio                                        fin (opcional)
 ──────────────┼──────────────────────────────────────────────┼──────────►
  PROGRAMADA   │                 EN CURSO                     │  FINALIZADA
  (programada) │  recibe inscripciones; el agente conversa    │  no recibe más;
               │                                              │  los ya inscritos
               │                                              │  terminan su conversación
```

- **Antes del inicio:** la campaña está programada. Una inscripción que llegue antes queda **programada
  para el inicio** (no se pierde).
- **Durante:** cada inscrito recibe al Agente IA.
- **Después del fin:** la campaña pasa sola a **finalizada** y la automatización ya no inscribe a nadie
  (se cuenta como omitido "ventana cerrada").
- **Sin fin:** queda en curso hasta que alguien la pause o la termine.

### 3.3 Cuándo le escribe el agente a un inscrito

```
   hora de la inscripción
          │
          ▼
   + espera de la campaña (0 min por defecto; p. ej. "1 hora después de entrar")
          │
          ▼
   no antes del INICIO de la ventana
          │
          ▼
   dentro del HORARIO DE ATENCIÓN del inbox (si la campaña lo pide):
   fuera de horario → la siguiente apertura del inbox
          │
          ▼
   ¿cae después del FIN?  ── sí ──► omitido "fuera de ventana"
          │ no
          ▼
   ContactTracking programado (scheduled_for) → ExecutePendingJob lo toma a su hora
```

En **por lote** es el mismo cálculo para todos a la vez: hoy la fecha es "cuándo"; con la ventana es
"el inicio", y el horario de atención reparte el lote si cae fuera de horario.

---

## 4. La automatización: "Agregar a campaña"

```
 Automatización
   CUANDO     se crea una conversación · se actualiza (p. ej. se agrega la etiqueta "demo") · …
   SI         inbox = WhatsApp Ventas · etiqueta contiene "demo" · …
   ENTONCES   ➕ Agregar a campaña   [ Campaña Octubre · En curso · 01/10 → 31/10 ▾ ]
```

- **Se elige por nombre, se guarda el id.** Renombrar la campaña no rompe la automatización.
- El desplegable muestra el **estado y la ventana** de cada campaña. Lista también las finalizadas (una
  regla vieja tiene que seguir mostrando la suya); el backend no inscribe en una cerrada.
- Si la campaña se **borra**, la acción queda "campaña eliminada" en la automatización y no hace nada.
- La acción vieja **"Asignar Agente IA"** sigue funcionando igual (decisión 5).

### 4.0 Conversación en vivo (encontrado al implementar la F2)

Si la conversación que dispara la automatización es **del mismo inbox** que la campaña, el cliente ya
está escribiendo y el analizador le contesta por ahí. Un primer mensaje proactivo "ya" saldría doble.
Por eso, igual que la acción vieja "Asignar Agente IA", el seguimiento usa **esa** conversación y su
primer mensaje proactivo se corre al **intervalo de reintento de la plantilla** (si el cliente se queda
callado). La ventana se juzga con la hora de la inscripción. Además `Message` sabe que esta acción crea
seguimientos, para que el analizador espere los 5 s que ya espera con "Asignar Agente IA".

### 4.1 Qué pasa cuando la automatización inscribe a alguien

```
 automatización dispara ──► TrackingCampaigns::Enroll (el mismo que usa el lote)
                               │
          ┌────────────────────┼────────────────────────────────────────────┐
          ▼                    ▼                    ▼                        ▼
   campaña pausada,     el contacto ya        ya tiene un Agente IA      calcular la hora
   terminada o          está inscrito en      activo en el inbox         (§3.3)
   borrada              esta campaña          de la campaña                 │
          │                    │                    │                  ¿dentro de la ventana?
          ▼                    ▼                    ▼                   sí │        │ no
   omitido:             omitido:              omitido:                    ▼        ▼
   "campaña cerrada"    "ya inscrito"         "Agente IA activo"     ✔ inscrito   omitido:
                                                                     + ContactTracking  "fuera de
                                                                                         ventana"
```

Cada intento queda registrado (§5), así la campaña puede decir **cuántos entraron por cada
automatización y cuántos no, y por qué**.

---

## 5. Datos

### 5.1 `tracking_campaigns` (columnas nuevas)

| Columna | Tipo | Para qué |
|---|---|---|
| `mode` | string, default `batch` | `batch` (por lote) · `continuous` (continua). Las que ya existen quedan `batch`. |
| `ends_at` | datetime, null | fin de la ventana. `scheduled_for` sigue siendo el **inicio** (no se renombra: hay datos y código que lo leen). |
| `entry_delay_minutes` | integer, default 0 | espera después de la inscripción. |
| `respect_working_hours` | boolean, default true | usar el horario de atención del inbox. |
| `daily_cap` | integer, null | tope de inscripciones por día en las continuas (decisión 7); vacío = sin tope. |
| `audience` | jsonb, default `{}` | en por lote, **qué** se eligió (segmento o etiqueta + filtro). Hoy no se guarda. |

### 5.2 `tracking_campaign_entries` (tabla nueva: las inscripciones)

| Columna | Tipo | Para qué |
|---|---|---|
| `tracking_campaign_id`, `account_id`, `contact_id` | bigint | quién y dónde |
| `source` | string | `batch` · `automation` |
| `automation_rule_id` | bigint, null | qué automatización lo inscribió |
| `conversation_id` | bigint, null | la conversación que disparó la automatización |
| `status` | string | `enrolled` · `skipped` |
| `reason` | string, null | `campaign_closed` · `already_enrolled` · `active_tracking` · `not_contactable` (sin teléfono en WhatsApp, sin correo en Email…) · `outside_window` · `daily_cap` |
| `contact_tracking_id` | bigint, null | el seguimiento que se creó |

Índice único (`tracking_campaign_id`, `contact_id`) **solo para los inscritos**: un contacto entra una
sola vez por campaña (decisión 4); los omitidos se pueden repetir, y cuentan.

Las inscripciones se crean también en **por lote**, así las dos audiencias se miden igual.

---

## 6. Ciclo de vida

| Estado | Qué hace | Quién lo cambia |
|---|---|---|
| **Programada** (`draft`) | antes del inicio; las inscripciones quedan programadas para el inicio | nace así si el inicio es futuro |
| **En curso** | recibe inscripciones; el agente conversa | solo, al llegar el inicio; o a mano |
| **Pausada** | **no recibe** inscripciones; los ya inscritos **siguen** conversando (decisión 2) | a mano |
| **Finalizada** | no recibe más; los inscritos terminan su conversación | sola, al llegar el fin; o a mano |

`TrackingCampaigns::WindowJob`, cada 5 minutos, abre las que llegan a su inicio y cierra las que pasan
su fin. Es el estado que se ve: las inscripciones miran la hora del fin en el momento, sin esperar al job.
Una campaña con inicio futuro nace **Programada** (antes nacía "En curso").

---

## 7. Pantallas

### 7.1 Nueva campaña (formulario de hoy + tipo + ventana)

```
┌─ Nueva campaña ─────────────────────────────────────────────────────────────────┐
│ Nombre        [ Campaña Octubre                               ]                 │
│ Agente IA     [ Agente Vendedor v6.11                       ▾ ]                 │
│                                                                                 │
│ Tipo          (•) Por lote — audiencia fija     ( ) Continua — audiencia dinámica│
│                                                                                 │
│ Ventana       Inicio [ 01/10/2026 10:00 ]   Fin [ 31/10/2026 23:59 ] (opcional) │
│               [✓] Respetar el horario de atención del inbox                     │
│               Escribir  [ 0 ] minutos después de la inscripción                 │
│                                                                                 │
│ ── Por lote ─────────────────────────────────────────────────────────────────── │
│ Audiencia     (•) Segmento [ Prospectos Colima ▾ ]   ( ) Etiqueta [ demo ▾ ]    │
│               150 contactos · 142 listos · 8 ya tienen Agente IA   (vista previa)│
│ ── Continua ─────────────────────────────────────────────────────────────────── │
│ Audiencia     La llenan las automatizaciones con "Agregar a campaña".           │
│               Automatizaciones que la usan: ninguna todavía                     │
│               [+ Crear automatización para esta campaña]                        │
└─────────────────────────────────────────────────────────────────────────────────┘
```

Con componentes nativos (`woot-tabs`, `woot-button`, los selectores de fecha del dashboard).

### 7.2 Detalle de la campaña: pestaña "Inscritos"

```
 Inscritos 186  ·  por lote 150  ·  por automatización 36  ·  omitidos 11
 ┌──────────────────┬───────────────────────┬──────────┬───────────────────────┐
 │ Contacto         │ Entró por             │ Estado   │ Cuándo                │
 ├──────────────────┼───────────────────────┼──────────┼───────────────────────┤
 │ Ana Pérez        │ Automatización "Demo" │ Inscrita │ 03/10 11:02           │
 │ Ana Pérez        │ Automatización "Demo" │ Omitida: ya inscrita │ 05/10 │
 │ Eva Ruiz         │ Automatización "Demo" │ Omitida: ventana cerrada │ 02/11 │
 └──────────────────┴───────────────────────┴──────────┴───────────────────────┘
```

Las métricas que ya tiene el detalle (enviados, respondieron, agendaron, embudo) siguen igual: salen de
los `contact_trackings` de la campaña, lleguen por lote o por automatización.

### 7.3 Listado de campañas

Una columna **Tipo** (Por lote / Continua) y la **ventana** (01/10 → 31/10) en vez de la fecha sola.

---

## 8. Riesgos y cómo se cubren

| Riesgo | Cobertura |
|---|---|
| Una automatización mal hecha inscribe a miles | el Agente IA respeta el horario y la ventana; decisión 7 propone un **tope diario** opcional por campaña |
| Doble mensaje al mismo contacto | "una vez por campaña" + "un Agente IA activo por inbox" (la regla que ya existe) |
| La automatización dispara en un inbox y la campaña es de otro | la campaña fija su inbox: el agente escribe **por el inbox de la campaña**, como hoy el bulk |
| WhatsApp fuera de las 24 h | igual que hoy: el Agente IA usa la plantilla de WhatsApp de su entrenamiento para abrir |
| Renombrar o borrar la campaña rompe automatizaciones | se guarda el id; borrada → la acción se ve como "campaña eliminada" y no hace nada |
| Lógica de inscripción duplicada entre lote y automatización | un solo servicio `TrackingCampaigns::Enroll`, que usa también el bulk |

---

## 9. Fases (días hábiles)

| Fase | Entrega | Cómo se verifica | Días |
|---|---|---|---|
| **F0** ✅ Datos | columnas nuevas en `tracking_campaigns`, tabla `tracking_campaign_entries`, las existentes quedan "por lote" | spec del modelo; migración tolerante | 1 |
| **F1** ✅ Inscribir (`Schedule` · `TrackingBuilder` · `Enroll`) | `TrackingCampaigns::Enroll`: ventana, espera, horario, duplicados, omitidos; el bulk pasa a usarlo | specs de cada caso de §4.1 | 1,5 |
| **F2** ✅ La automatización | acción "Agregar a campaña" (backend + desplegable con estado y ventana) | spec de la acción; Vitest del desplegable | 1 |
| **F3** ✅ Ciclo de vida | job que abre y cierra campañas por su ventana | spec del job | 0,5 |
| **F4** Formulario | tipo, ventana, espera, horario; "Continua" sin selector de audiencia | Vitest + navegador | 1,5 |
| **F5** Detalle y listado | pestaña "Inscritos" con fuente y omitidos; tipo y ventana en el listado | Vitest + navegador | 1 |
| **F6** Prueba real | campaña continua en "Agents IA Test" + automatización por etiqueta | conversación de punta a punta en develop | 0,5 |

**Total: 7 días hábiles.**

---

## 10. Decisiones para el usuario

> **21/09/2026:** el usuario aceptó las propuestas de las decisiones 1 a 7. La 8: el límite del lote se
> queda en **100**.

1. **Nombres** (§3.1): "Por lote / Continua", "audiencia fija / dinámica", "inscritos / omitidos".
   ¿Así, o prefieren otros?
2. **Pausada:** propuesta: deja de recibir inscripciones, pero los ya inscritos **siguen** conversando.
   Alternativa: pausar también sus conversaciones.
3. **Horario:** propuesta: respetar el horario de atención del inbox (activado por defecto); fuera de
   horario, la siguiente apertura.
4. **¿Un contacto puede volver a entrar a la misma campaña** cuando terminó su conversación? Propuesta: no,
   una vez por campaña.
5. **La acción vieja "Asignar Agente IA":** propuesta: se queda como está (hay automatizaciones que la
   usan); la nueva es "Agregar a campaña".
6. **Por lote: ¿la audiencia se toma al crear** (como hoy) **o al llegar el inicio?** Propuesta: al crear,
   como hoy; la vista previa muestra exactamente a quién le va a escribir.
7. **Tope diario de inscripciones** en las continuas (por ejemplo 200 al día). Propuesta: opcional, vacío
   = sin tope.
8. **Límite del lote (100):** ¿se queda, o se sube ahora que corre en segundo plano?
