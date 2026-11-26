# Ventana «Nueva tarea agendada / Editar evento»: ordenada, sin scroll y con una sola lista de personas

> Rama: `feat/ventana_evento_calendario` (desde `fix/calendario_eliminar` 0430042e, PR #222; se
> rebasa sobre develop cuando ese PR entre) · Plan v1.3 · 26/11/2026 (v1.1: D1–D6 confirmadas, F0 completa · v1.2: F1 con ajustes del usuario · v1.3: F2 completa + F5 propuesta · v1.4: D7 confirmada, F3 completa · v1.5: F5 completa + agentes en pastillas)
> Estado: **D1–D7 confirmadas** · **F0–F3 y F5 completas** · falta F4 (navegador, con OK para crear datos de prueba).

---

## 1. Qué se pide

La ventana del calendario para crear o editar (**Nueva tarea agendada**, **Editar evento**):
- **tiene scroll y el usuario se pierde**;
- **agregar invitados es incómodo**: ¿existe una mejor forma?

---

## 2. Cómo está hoy

`components/GoogleCalendar/CreateEventModal.vue` (~1 000 líneas), **una sola columna**, ventana
de tamaño normal. Con todo visible (tarea agendada nueva con cliente) queda así:

```
  ┌ Nueva tarea agendada ──────────────────── ✕ ┐
  │ Agendar a          [ Yo ▾ ]                  │  ▲
  │ ☐ Interno (solo Google)                      │  │
  │ Contacto           [ buscar…   ]             │  │
  │ Organización       [ buscar…   ]             │  │
  │ Caso               [ Sin caso ▾ ]            │  │
  │ Calendario         [ Principal ▾ ]           │  │
  │ Título             [            ]  ◄─ lo     │  │  ~2 pantallas
  │ ☐ Todo el día                         más    │  │  de alto:
  │ Inicio [    ]  Fin [    ]          ◄─ importante │  scroll
  │ Descripción        [            ]   a la mitad │
  │ Participantes  (Ana) (Beto) (Caro)…          │  │
  │ ☐ Es visita   Dirección [      ]             │  │
  │ Invitados  [ correo, Enter… ]                │  │
  │ [Cancelar tarea agendada][Pasar a tarea] [Cerrar][Guardar] ◄─ hasta abajo
  └──────────────────────────────────────────────┘  ▼
```

Problemas concretos:

| # | Problema |
|---|---|
| P1 | Lo esencial (título y hora) queda a la mitad; lo primero que ves es «Agendar a» e «Interno». |
| P2 | Los botones (Guardar, Cancelar tarea, Eliminar) quedan abajo del scroll. |
| P3 | **Dos campos para «quién va»**: «Participantes» (agentes, como pastillas de todo el equipo) e «Invitados» (correos escritos a mano). |
| P4 | Invitados: hay que **escribir el correo completo**; no busca contactos ni agentes; pegar varios no funciona bien; un correo mal escrito no se marca. |
| P5 | Al **editar** una tarea agendada no se ven ni se cambian sus invitados por correo (el servidor no los devuelve ni los acepta en `update`), aunque al crearla sí se mandan (`attendee_emails`). |
| P6 | Al editar una tarea agendada el título dice «Editar Evento». |
| P7 | Los campos cambian según el modo (evento interno, tarea agendada, todo el día, participante, evento de Google sin tarea), y no hay una forma fija de encontrarlos. |

Modos que hoy resuelve la misma ventana:

```
  Nueva ── tarea agendada (cliente, participantes, visita)        ← la más larga
       └── evento interno (☑ Interno: solo Google, invitados)
       └── todo el día (tarea, solo fecha)
  Editar ─ tarea agendada (responsable)      → + Cancelar tarea agendada / Pasar a tarea
         ├ tarea agendada (participante)     → solo lectura + «No puedo ir»
         └ evento de Google sin tarea        → + ligarlo a una tarea / Eliminar evento
```

---

## 3. Cómo quedaría

### 3.1 Estructura: cabecera fija + pestañas + pie fijo

```
  ┌ Nueva tarea agendada ─────────────────────────────────────── ✕ ┐
  │ Título   [ Visita de instalación                            ]  │  CABECERA
  │ Inicio   [27/11/2026 10:00]  Fin [11:00]   ☐ Todo el día       │  (siempre
  │ Agendar a [ Yo ▾ ]             Calendario [ Principal ▾ ]      │   visible)
  │                                                                │
  │   Cliente •   Personas (3)    Detalles          ← woot-tabs    │
  │ ────────────────────────────────────────────────────────────── │
  │                                                                │  CUERPO
  │   (contenido de la pestaña, ALTURA FIJA: cambiar de pestaña     │  (no crece)
  │    no mueve la ventana ni los botones)                         │
  │                                                                │
  │ ────────────────────────────────────────────────────────────── │
  │ [Cancelar tarea agendada] [Pasar a tarea]   [Cerrar] [Guardar] │  PIE fijo
  └────────────────────────────────────────────────────────────────┘
```

- **Cabecera:** título, cuándo, para quién y en qué calendario (lo que se llena siempre).
  «Agendar a» y «Calendario» solo salen si aplican, como hoy.
- **Pestañas** nativas (`woot-tabs`, como «Compartir mi calendario»):

  | Pestaña | Qué lleva |
  |---|---|
  | **Cliente** | ☐ Interno · Contacto / Organización · Caso · ☐ Es visita + Dirección. Al editar: el resumen (contacto, organización, caso con liga). En un evento de Google sin tarea: «Sin tarea agendada» y el paso para ligarlo. |
  | **Personas (N)** | La lista única de §3.2 (participantes + invitados). Participante de una tarea: quién va y «No puedo ir». |
  | **Detalles** | Descripción / notas (y lo que se agregue después, p. ej. ubicación). |

- **Pie** siempre visible con las acciones de hoy (Cancelar tarea agendada, Eliminar evento,
  Pasar a tarea, Cerrar, Guardar) y sus confirmaciones en línea.
- **Error en otra pestaña:** si al Guardar falta algo de otra pestaña (p. ej. cliente), esa
  pestaña se marca con un punto rojo (`Cliente •`) y se abre sola.
- **Modo interno** (☑ Interno): la pestaña Cliente se reduce a esa casilla; **todo el día**:
  la cabecera muestra solo la fecha.

### 3.2 Pestaña «Personas»: una sola lista, un solo buscador

```
  Agregar personas [ jua                                          ]
   ┌──────────────────────────────────────────────────────┐
   │ (J) Juan Pérez — agente               ● ocupado 10:00 │ → participante
   │ (J) Juan Ruiz — juan@cliente.com — contacto           │ → invitado (correo)
   │ ✉  Invitar «jua…» por correo  (si parece correo)      │ → invitado (correo)
   └──────────────────────────────────────────────────────┘
  ★ Invitar al cliente: Juan Ruiz · juan@cliente.com            [Invitar]
  ──────────────────────────────────────────────────────────────
  (A) Andres Liverio    Participante              ● ocupado      ✕
  (J) Juan Ruiz         Invitado · juan@cliente.com              ✕
  (✉) jefe@empresa.com  Invitado                                 ✕
  (✉) jefe@empresa,com  Invitado  ⚠ correo inválido              ✕
```

Cómo se comporta:
- **Un buscador para todo:** al escribir (desde 2 letras, con pausa de 300 ms) busca
  **agentes del equipo** (lista local) y **contactos del sistema con correo**
  (`ContactsAPI.search`), y ofrece **invitar el correo escrito** si tiene forma de correo.
- **Agente → participante** (como hoy: lo ve en su Agenda, Mi día y Mi ruta y, si tiene Google
  conectado, le llega a su Google). **Contacto o correo → invitado** (`attendee_emails`, le llega
  la invitación de Google).
- **Pegar varios** correos (separados por coma, punto y coma, espacio o renglón) los agrega
  todos; los repetidos no se duplican.
- **Ocupado:** el aviso «ya tiene algo a esa hora» de los participantes (el de hoy,
  `AgendaItemsAPI.busy`) sale en su fila; no bloquea.
- **Sugerencia del cliente:** si la tarea tiene contacto con correo, sale «Invitar al cliente»
  con un clic. **No se agrega solo** (le llegaría un correo de Google) — ver D4.
- **Cada persona es una fila** con nombre, tipo y ✕; el correo inválido se marca en rojo y
  no deja guardar hasta corregirlo o quitarlo.
- **Evento interno / evento de Google:** solo invitados (agentes con Google van por su correo
  de Google; sin Google, por su correo del sistema). **Tarea agendada:** agentes como
  participantes y correos como invitados (requiere §3.3 para editar).

### 3.3 Servidor (pequeño)

```
  agenda_items#update   permit attendee_emails: []   (hoy solo en create)
  agenda_items#item_json  + attendee_emails           (para mostrarlos al editar)
  GoogleMirrorService     ya los manda a Google (NOTIFYING_FIELDS incluye attendee_emails)
```
Validar formato de correo en el servidor también (se descartan los inválidos con error 422).

### 3.4 Textos
- Título al editar: **«Editar tarea agendada»** si tiene tarea; **«Editar evento»** si es solo de
  Google (minúscula, como el resto).

---

## 4. Decisiones (recomendación primero) — ✅ confirmadas las 6 recomendaciones (26/11/2026)

| # | Pregunta | Recomendación | Alternativa |
|---|---|---|---|
| D1 | ¿Cómo quitar el scroll? | **Cabecera fija + pestañas + pie fijo** (como las páginas de Configuración y «Compartir mi calendario») | Ventana ancha en dos columnas (izq. lo esencial, der. cliente y personas) |
| D2 | ¿Participantes e invitados juntos? | **Sí, una sola lista «Personas»** con tipo por fila | Dejar dos campos, pero los dos con buscador |
| D3 | ¿Invitados por correo también al **editar** una tarea agendada? | **Sí** (§3.3; al crear ya se puede) | Solo al crear, como hoy |
| D4 | ¿El contacto del cliente se invita solo? | **No: se sugiere con un clic** (evita mandarle un correo de Google sin querer) | Agregarlo solo y que se quite si no se quiere |
| D5 | ¿Qué busca el buscador? | **Agentes + contactos con correo + correo libre** | Solo agentes y correo libre |
| D6 | ¿Con qué pestaña abre? | **Nueva tarea agendada → Cliente** (es lo que más falta); **evento interno o de Google → Personas**; **editar → la última usada en esa sesión** | Siempre la primera |

---

## 5. Fases

### F0 — Inventario y molde
- Recorrer en el navegador (cuenta 2) los 6 modos de §2 y anotar qué campos salen en cada uno
  (tabla en este .md). Es la lista de verificación de que nada se pierde al mover.
- Medir la altura máxima de la cabecera + pestaña más larga para fijar el alto del cuerpo
  (sin scroll en 768 px de alto).

#### ✅ F0 hecha (26/11/2026) — inventario medido en navegador

Navegador sin ventana (Chromium headless + playwright-core en el scratchpad) contra
`localhost:3000/app/accounts/2/google-calendar` como Admin #1, con una sesión temporal que se
borró al terminar. **Solo se abrió y cerró la ventana; no se guardó nada.**

Altura medida (contenido de la ventana contra el alto de la pantalla):

```
  Modo                                    contenido   1440×900     1366×768
  ──────────────────────────────────────  ─────────   ──────────   ──────────
  1 Nueva tarea agendada                   1 062 px    SCROLL       SCROLL (+294)
  2 Nueva · ☑ Interno                        772 px    sin scroll   SCROLL (+4)
  3 Nueva · ☑ Interno · ☑ Todo el día        826 px    sin scroll   SCROLL (+58)
  6 Editar evento de Google sin tarea        986 px    SCROLL       SCROLL (+218)
  4 Editar tarea agendada (responsable)     (sin datos de prueba en la cuenta 2: por código)
  5 Tarea agendada vista como participante  (sin datos de prueba en la cuenta 2: por código)
```

Campos por modo, en el orden en que salen hoy:

| Modo | Campos (orden actual) | Botones |
|---|---|---|
| 1 Nueva tarea agendada | Agendar a (+ ayuda) · ☐ Interno · Organización (opcional) · Contacto · Calendario · Título · Inicio · Fin · Descripción · Participantes (pastillas de todo el equipo + ayuda) · ☐ Es una visita al cliente (+ Dirección) · Invitados | Cancelar · Crear tarea agendada |
| 2 Nueva · Interno | Agendar a · ☑ Interno · Calendario · Título · ☐ Todo el día · Inicio · Fin · Descripción · Invitados | Cancelar · Crear tarea agendada |
| 3 Interno · Todo el día | igual que 2 con fechas sin hora | igual |
| 4 Editar tarea (responsable) | resumen (Contacto, Organización, Caso con liga) · Calendario · Título · Inicio · Fin · Descripción · Participantes (con su estado) | Cancelar tarea agendada · Pasar a tarea · Cerrar · Guardar cambios |
| 5 Tarea como participante | resumen · Título · Inicio · Fin · Descripción · «Vas como participante» + quiénes · nota + «No puedo ir» | Cerrar |
| 6 Evento de Google sin tarea | aviso «aún no tiene tarea agendada…» · ☐ Interno · Organización · Contacto · Calendario (bloqueado) · Título · Inicio · Fin · Descripción · Participantes · Invitados | Eliminar evento · Cerrar · Guardar cambios |

Hallazgos que entran a F1/F2:
- **H1** Inicio y Fin se acomodan mal: la etiqueta «Fin» queda en el mismo renglón que su fecha y,
  al editar, la fecha de Inicio cae debajo de su etiqueta. En la cabecera nueva van en una fila
  fija «Inicio | Fin | ☐ Todo el día».
- **H2** «Participantes» ofrece a **quien agenda** (sale «Admin» siendo Admin): al crear no se le
  pasa `organizerId` a `ParticipantsPicker`. En `PeoplePicker` el responsable nunca se ofrece.
- **H3** El modo 6 es el más confuso: mezcla el aviso naranja, Interno, cliente, participantes e
  invitados de un evento que todavía no es tarea. En el diseño nuevo el aviso y el «ligar a tarea»
  viven en la pestaña Cliente, y Personas muestra los invitados de Google.
- **H4** El título dice «Editar Evento» también en el modo 6; se corrige con §3.4.

Presupuesto de alto para no tener scroll en 1366×768 (≈ 720 px útiles):

```
  encabezado de la ventana ............  60
  cabecera (título · fecha/hora · agendar a/calendario) ... 210
  pestañas ............................  44
  pie (botones) .......................  60
  cuerpo de la pestaña ................ ~340   ← alto fijo del cuerpo
  ───────────────────────────────────────────
                                         714
```
- **Cliente** cabe si Organización y Contacto van **lado a lado** (ventana más ancha, ~720 px):
  Interno 30 + (Org | Contacto) 70 + Caso 70 + Visita 30 + Dirección 70 ≈ 270.
- **Personas**: buscador 70 + sugerencia del cliente 30 + filas de 36 px → caben ~6 personas;
  con más, **solo la lista** se desplaza por dentro (la ventana y los botones no se mueven).
- **Detalles**: la descripción ocupa el alto del cuerpo.

### F1 — Estructura (sin cambiar qué hace cada campo)
- Partir `CreateEventModal.vue` en piezas: `EventHeaderFields`, `EventClientTab`,
  `EventPeopleTab`, `EventDetailsTab` (mismo `form`, mismos envíos; solo se mueven).
- Cabecera, `woot-tabs` con conteo en Personas, pie fijo, error → punto en la pestaña y salto.
- Ventana más ancha (~720 px) para Organización | Contacto lado a lado; Inicio | Fin | Todo el
  día en una fila (H1); cuerpo de alto fijo según el presupuesto de F0.
- Títulos (§3.4).
- Vitest: cada modo muestra sus pestañas y campos (con la tabla de F0); las pruebas de
  «Agendar a», Cancelar tarea agendada y Eliminar evento siguen pasando.

#### ✅ F1 hecha (26/11/2026)

**Ajustes que pidió el usuario durante la F1 (cambian §3.1):**
- **Descripción debajo del Título** y **sin pestaña Detalles** (solo llevaba la descripción).
- La pestaña **«Personas» se llama «Participantes»**, y dentro el campo que decía
  «Participantes» (agentes del equipo) dice **«Agentes»** (solo en esta ventana:
  `ParticipantsPicker` recibe `label`; Tickets y Mi día siguen diciendo «Participantes»).
- En **Invitados**, aviso: «Separa varios correos con comas. También puedes pegarlos todos
  juntos.» — y ahora es cierto: `addAttendee` separa por coma, punto y coma, espacio o renglón
  (antes «a@x.com, b@y.com» quedaba como UN invitado con todo el texto); al pegar se separa
  solo; lo que no parece correo se queda en la caja.

**Cómo quedó**

```
  ┌ Nueva tarea agendada ──────────────────────────────────── ✕ ┐  woot-modal size="medium"
  │ Título       [                                           ]   │  (900 px, máx. 80 %)
  │ Descripción  [                                           ]   │
  │ Inicio [dd/mm/aaaa --:--]  Fin [dd/mm/aaaa --:--] (☐ Todo el día, solo interno)
  │ Agendar a [ Mí ▾ ]                Calendario [ Principal ▾ ] │
  │   Cliente •    Participantes (2)          ← woot-tabs         │
  │ ┌───────────────────────────────────────────────────────────┐│  cuerpo 210 px fijo
  │ │ Cliente: ☐ Interno · Organización | Contacto · Caso ·      ││  (si algo no cabe, se
  │ │          ☐ Es visita (+ Dirección)                          ││   desplaza SOLO el
  │ │ Participantes: Agentes (pastillas, ocupado) · Invitados     ││   cuerpo)
  │ │          (correos con comas) + aviso                        ││
  │ └───────────────────────────────────────────────────────────┘│
  │ [Cancelar tarea agendada] [Pasar a tarea] [Eliminar evento]  [Cerrar] [Guardar]
  └───────────────────────────────────────────────────────────────┘
```

- Sin pestañas (evento de todo el día de Google sin caso): no sale la barra.
- Falta el cliente al Guardar → «Cliente •» y se abre esa pestaña.
- D6: nueva tarea → Cliente; interno o evento de Google → Participantes; editar tarea → la
  última usada.
- H1: Inicio | Fin (| Todo el día) en una fila, con etiqueta arriba y campo con borde
  (`datetime-local` no tenía estilo global). H2: quien agenda ya no se ofrece como agente
  (`participantsOrganizerId`: el de la tarea, el de «Agendar a» o yo). H4/§3.4: «Editar tarea
  agendada» / «Editar evento».
- La ayuda de «Agendar a» solo sale agendando a otro o si nadie me dio permiso.
- Organización | Contacto lado a lado (`horizontal` que ya tenía el componente).

**Medido en navegador** (headless, Admin #1, cuenta 2, solo abrir y cerrar; sesión borrada):

```
  Modo                          antes (F0)   ahora    1366×768     1280×720
  1 Nueva tarea agendada         1 062 px    759 px   sin scroll   +39
  2 Nueva · Interno                772 px    759 px   sin scroll   +39
  3 Interno · Todo el día          826 px    759 px   sin scroll   +39
  6 Editar evento de Google        986 px    759 px   sin scroll   +39
```
La meta era 768 px de alto (laptop); en 720 px aún hay 39 px de scroll de la ventana.

**Incidente:** el formateo parcial con prettier mezcló bloques de la plantilla (div duplicado);
se reconstruyó la plantilla desde los bloques de 0430042e con todos los cambios y se pasó
prettier al archivo completo (en ese commit no tenía faltas).

**Pila de pruebas**
- Vitest `components/GoogleCalendar/specs/CreateEventModal.layout.spec.js` (9): comas, pegar,
  repetidos, pestañas Cliente | Participantes con conteo, sin pestañas, punto en Cliente, D6,
  recordar pestaña, H2, títulos. Calendario + agenda + store: **67 pruebas, 0 fallas**.
- eslint 0 en CreateEventModal, ParticipantsPicker y la prueba. webpack «Compiled successfully».

### F2 — Personas
- `PeoplePicker` (nuevo) reemplaza `ParticipantsPicker` + el campo de invitados en esta ventana
  (`ParticipantsPicker` se queda para las otras pantallas que lo usan).
- Buscador con agentes + `ContactsAPI.search` + correo libre, pegar varios, inválidos en rojo,
  ocupado por fila, sugerencia del cliente.
- Vitest: agente → participante, contacto/correo → invitado, pegar varios sin repetidos,
  inválido bloquea Guardar, sugerencia del cliente no se agrega sola.

#### ✅ F2 hecha (26/11/2026)

**Ajuste previo pedido por el usuario (pestaña Cliente):** primero Organización (opcional) |
Contacto, luego Caso, y abajo **en una sola fila** ☐ Interno, sin cliente (solo en Google) y
☐ Es una visita al cliente (Dirección debajo si se marca). `showInternalToggle`,
`showVisitToggle`.

**Qué se hizo**
- `components/GoogleCalendar/PeoplePicker.vue` (nuevo) reemplaza en esta ventana a
  `ParticipantsPicker` + el campo de invitados (el selector viejo sigue en Tickets y Mi día).
- `CreateEventModal.vue`: `<PeoplePicker :participant-ids.sync :attendees.sync>` con
  `allow-agents` (tarea agendada: agentes = participantes) y `allow-emails` (`showAttendees`);
  `flushPeople()` antes de guardar; `clientSuggestion` (D4). Se quitaron `addAttendee`,
  `removeAttendee` y `attendeeInputValue`.
- i18n `GOOGLE_CALENDAR.PEOPLE.*` (es/en); se quitó `ATTENDEES_HINT` y se regresó
  `ATTENDEES_PLACEHOLDER` (ya no se usan aquí).

**Cómo funciona**

```
  Agregar agentes o invitados [ andr                                   ]
   ┌──────────────────────────────────────────────┐
   │ Andres Liverio MX          Agente             │ ← agentes (lista local, sin el responsable)
   │ Andrés Liverio  aliverio.col@… · contacto     │ ← ContactAPI.search (≥2 letras, 300 ms, con correo)
   │ Invitar «x@y.com» por correo                  │ ← si lo escrito es un correo
   └──────────────────────────────────────────────┘
  Separa varios correos con comas. También puedes pegarlos todos juntos.
  [Invitar al cliente: Juan · juan@cliente.com]  [Invitar]      ← D4, no se agrega solo
  (A) Andres Liverio MX   Agente        ● ocupado: Visita (10:00–11:00)    ✕
  (A) a@x.com             Invitado                                          ✕
```
- Enter → la primera sugerencia; con comas o «@» → separa y agrega todos los correos.
- Pegar → separa al momento. Lo que no es correo se queda en la caja: «"juan" no es un correo
  válido» en rojo; **Guardar** no avanza («Hay un correo mal escrito en Participantes…») y abre
  la pestaña.
- Evento solo de Google: un agente va como invitado con su correo.
- Tarea agendada al editar: solo agentes (los correos llegan con F3).

**Medido en navegador** (Admin #1, cuenta 2, sin guardar; sesión borrada): buscar «andr» →
agente + contacto; pegar «a@x.com, b@y.com, juan» → 2 invitados + «juan» en rojo; pestaña
«Participantes 3»; ventana 759/768 **sin scroll** (la lista se desplaza dentro del cuerpo).

**Error encontrado por las pruebas:** la marca roja se borraba en el mismo instante en que
`flush` dejaba el texto malo en la caja (el vigilante de la caja lo limpiaba). Ahora solo se
borra cuando el usuario cambia el texto.

**Pila de pruebas**
- Vitest `specs/PeoplePicker.spec.js` (10): correos y comas, rojo, agente participante sin el
  responsable, agente como invitado en Google, contactos con correo y su nombre en la fila,
  correo escrito, sugerencia del cliente, quitar filas, ocupado, solo agentes.
  `CreateEventModal.layout.spec.js`: `flushPeople` y `clientSuggestion`.
  Calendario + agenda + store: **77 pruebas, 0 fallas**. eslint 0; prettier OK.

#### Ajuste del usuario después de F2: agentes en pastillas (26/11/2026)

«Como seleccionaba los agentes estaba muy bien, ya no aparecen»: con el buscador único los
agentes solo salían al escribir. Quedó así en la pestaña Participantes:

```
  Agentes   (Agente Ventas) (■ Andres Liverio MX) (Jose Luis) (Mario)   ← ParticipantsPicker de
            Otros del equipo que van contigo…  · aviso de ocupado         siempre, label «Agentes»
  Invitados [ Busca un contacto o escribe un correo ]                    ← PeoplePicker solo para
            Separa varios correos con comas…                               contactos y correos
            [Invitar al cliente: …]   (fila por invitado con ✕)
```
- `ParticipantsPicker` recibe otra vez `label` (Tickets y Mi día siguen con «Participantes»).
- `PeoplePicker` con `search-agents=false` cuando hay pastillas (tarea agendada); en un evento
  solo de Google (sin pastillas) el buscador sigue ofreciendo agentes como invitados.
- Medido en navegador: pastillas visibles, «andr» en Invitados → solo el contacto; pegar con
  comas y «juan» en rojo igual; ventana 759/768 sin scroll.

### F3 — Servidor: invitados al editar
- `agenda_items#update` acepta `attendee_emails`; `item_json` los devuelve; validación de formato.
- RSpec: editar invitados llega a Google (encola `Cases::MeetingSyncJob`), correo inválido → 422.

#### ✅ F3 hecha (26/11/2026)

**Qué se hizo**
- `app/controllers/concerns/attendee_emails_params.rb` (nuevo): `raw/clean_attendee_emails`
  (sin espacios, minúsculas, sin repetir) y `before_action :reject_invalid_attendee_emails`
  (422 «Correo no válido en invitados: …», no guarda nada).
- `agenda_items_controller.rb`: `update_attrs` acepta `attendee_emails` (solo si viene en la
  petición; si no viene, no se tocan); `create_attrs` los guarda limpios; `participation_json`
  devuelve `attendee_emails`. El cambio llega a Google con el `Cases::MeetingSyncJob` de siempre
  (`attendee_emails` está en `NOTIFYING_FIELDS` → avisa a los invitados).
- `CreateEventModal.vue`: Invitados se ve al editar una tarea agendada si soy el responsable
  (`showAttendees` = evento con hora y no participante); al abrir la tarea se cargan **solo sus
  `attendee_emails`** (antes los del evento de Google, que traen también organizador y
  participantes); al guardar se mandan.
- i18n `agenda_items.invalid_emails` (es/en).

**Pila de pruebas**
- RSpec `agenda_items_spec.rb` +5: editar invitados (limpios, sin repetir, encola el sync, los
  devuelve), correo mal escrito → 422 sin guardar, sin `attendee_emails` no se tocan, alta con
  correo malo no crea, alta guarda limpios. Con cancelaciones y calendario: **60 ejemplos,
  0 fallas**. Rubocop limpio (la validación se pasó a un concern para no inflar el controlador).
- Vitest +2 (`showAttendees` responsable/participante, `saveAgendaItem` manda los correos):
  **79 pruebas, 0 fallas**. webpack «Compiled successfully».
- Navegador: pendiente para F4 (en la cuenta 2 no hay tareas agendadas que editar).

### F4 — Pila de pruebas en navegador (cuenta 2)
1. Nueva tarea agendada con cliente, 2 participantes y 1 correo: todo sin scroll, Guardar
   siempre visible; llega la invitación al correo.
2. Pegar «a@x.com, b@y.com; c@z.com» → 3 filas.
3. Escribir un correo mal → rojo y no guarda.
4. Guardar sin cliente → se abre «Cliente» con el punto rojo.
5. Editar esa tarea: se ven y se cambian los invitados; «Editar tarea agendada».
6. Evento interno y evento de Google: abre en Personas; Eliminar evento sigue en el pie.
7. Como participante: solo lectura y «No puedo ir» en Personas.
8. En pantalla chica (768 px de alto) no hay scroll.

---

### F5 — (propuesta, D7 abierta) Cancelar o eliminar lo que agendé para un compañero

Pregunta del usuario: «si tengo permiso de crear una reunión para un compañero y después la
quiero cancelar o eliminar, ¿se puede?». **Hoy no, desde el calendario:**

```
  Tarea agendada para un compañero   organizer = él; el sistema NO guarda quién la creó.
                                     Mi calendario lista solo donde soy responsable o
                                     participante → no me sale. La veo como evento del
                                     compañero (solo lectura). El servidor sí deja cancelar
                                     (si mi Agenda no es «solo lo mío"); borrar solo admin.
  Evento interno en su calendario    Google me deja borrarlo (tengo «Hacer cambios"), pero en
                                     pantalla es solo lectura y no hay botón.
```
Propuesta: en la ventana del evento de un compañero, si me dio «Hacer cambios»:
«Cancelar tarea agendada» (si es una tarea, por `google_event_id`) o «Eliminar evento» (si es
solo de Google, con `calendar_id` = su calendario).

| # | Pregunta | Recomendación | Alternativa |
|---|---|---|---|
| D7 ✅ | ¿Quién puede cancelar/eliminar lo del compañero? | **Cualquiera con su «Hacer cambios»** (la regla de Google; sin cambios de base) — **confirmada 26/11/2026** | Solo quien la creó (hay que guardar `created_by_id` en la tarea agendada) |

#### ✅ F5 hecha (26/11/2026)

**Servidor**
- `GoogleCalendarCoworkerService#normalize`: cada evento trae `recurring_event_id` y `guests`
  (invitados sin contar organizador ni salas).
- `CoworkersController#events`: si el evento es una tarea agendada que **sigue agendada**, trae
  `agenda_item` { id, title, series, work_started, has_client } (lo que pide la ventana de motivo).
- `EventsController#destroy` acepta `agent_id`: el guardián (`GoogleCalendarScheduleGuard`)
  pregunta a Google si me dio «Hacer cambios» (D7); si sí, se borra en SU calendario
  (`calendar_id` = su correo de Google); si no, 403 con el motivo.
- `GoogleCalendarEventDeleter`: con `owner_email` el compañero cuenta como organizador (sus
  invitados sí reciben el aviso) y se limpia su caché de compañero.

**Pantalla**
- `CalendarView`: el evento del compañero lleva `eventId`, `recurringEventId`, `guests`,
  `agendaItem`, `canSchedule`.
- Ventana del evento del compañero (`GoogleCalendarView`): con «Hacer cambios» dice «…Te dio
  "Hacer cambios": puedes cancelarlo o eliminarlo» y muestra:
  - tarea agendada → **Cancelar tarea agendada** → la ventana de motivo **sin «¿Prefieres
    reprogramarla?»** (`CancelItemModal` prop nueva `allowReschedule`, por defecto true); al
    terminar se quita del calendario;
  - solo Google → **Eliminar evento** con confirmación (Solo este / Toda la serie, Avisar a los
    invitados (N)); el store lo quita al momento y lo regresa si Google falla.
  - Sin el permiso: solo lectura, como antes.
- Store: `removeCoworkerEvent`, `deleteCoworkerEvent`.

**Nota:** cancelar la tarea agendada usa la ruta de siempre (`PATCH /agenda_items/:id`), que
respeta el rol (Agenda «solo lo mío» no puede). El botón solo sale con «Hacer cambios».

**Pila de pruebas**
- RSpec: `coworkers_controller_spec` +1 (serie, invitados, tarea agendada solo si sigue
  agendada), `events_destroy_spec` +2 (con permiso borra en su calendario y avisa como
  organizador y limpia caché; sin permiso 403 sin borrar). Calendario + tareas: **70 ejemplos,
  0 fallas**. Rubocop: nuevos limpios; `events_controller.rb` sigue en sus 19 previas.
- Vitest: `coworkerDelete.spec.js` (3), `GoogleCalendarView.coworker.spec.js` (6, incluye la
  ventana de motivo sin reprogramar), `PeoplePicker.spec.js` +1. **89 pruebas, 0 fallas**.
  eslint sin faltas nuevas.
- Navegador: pendiente para F4 (Andres no tiene eventos en estas fechas).

## 6. Fuera de alcance
- Ubicación con Google Maps (sigue pendiente, como hoy).
- Repetir la tarea agendada (series) desde esta ventana.
- Cambiar `ParticipantsPicker` en las demás pantallas (Tickets, Mi día).
