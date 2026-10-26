# Plan · Chat interno entre agentes

> Rama: `feat/chat_interno` (desde `develop` fc062ced) · 26/10/2026 · **Solo plan, sin código**

---

## ⚠️ Plan v2 · «Interno» como canal real (26/10/2026)

> Decidido por el usuario tras F0–F3: **«que Interno sea como cualquier otro canal, pero interno»**.
> Reemplaza al módulo aparte (secciones 2–7 y el registro de F0–F3 quedan como historia).

### Idea

```
 Cuenta ──▶ Bandeja «Interno» (Channel::Internal, una por cuenta, todos los agentes son miembros)
              │
              ├─ Conversación «# general»   participantes: todos los agentes
              ├─ Conversación «# ventas»    participantes: miembros del equipo (una por equipo)
              └─ Conversación «Ana ↔ Luis»  participantes: los dos (directo, privado)

 Todo lo de una conversación funciona tal cual: lista y filtros, búsqueda, adjuntos, emojis,
 editor, predefinidas, @menciones, notas, etiquetas, escribiendo…, notificaciones, menú del mensaje.
```

### Lo que hay que ajustar (lo único que no es nativo)

| # | Ajuste | Por qué |
|---|---|---|
| A1 | **Contacto oculto** «Chat interno», uno por cuenta, fuera de Clientes | Chatwoot exige contacto en cada conversación |
| A2 | **Privacidad:** una conversación interna solo la ven sus participantes (lista, abrirla, búsqueda) | Un directo es de dos; un equipo, de sus miembros |
| A3 | **Apagado** en Interno: IA/bots, automatizaciones, casos, embudo, reportes, SLA, CSAT, webhooks, integraciones, seguimientos, palabras clave, vendedor | No son clientes |
| A4 | **Por quien mira:** lo de otros a la izquierda; nombre/foto de la sala (# general, # equipo, el otro agente) en tarjeta y cabecera | Todos los mensajes son de agentes (salientes) |
| A5 | **No leídos por agente** (`conversation_participants.last_read_at`) | Chatwoot solo cuenta mensajes de clientes y tiene un «visto» compartido |
| A6 | **«Nuevo chat»** (+) en la lista de la bandeja Interno: abre/crea el directo | No hay «nueva conversación» con un agente |
| A7 | Salas de equipo **sincronizadas** con Equipos (alta, baja, miembros) | Grupos = equipos |

### Fases

| Fase | Qué |
|---|---|
| **R1** | `Channel::Internal`, bandeja por cuenta (respeta el interruptor), miembros = todos los agentes, contacto oculto, conversaciones de general/equipos/directos con participantes, sincronía con equipos |
| **R2** | Privacidad (A2) en buscador, carga de conversación y búsqueda |
| **R3** | Apagado (A3) con una sola regla `conversation.internal?` |
| **R4** | Frontend: el grupo «Interno» del menú = la bandeja; dirección y título por quien mira (A4); no leídos por agente (A5); «Nuevo chat» (A6) |
| **R5** | Pruebas, quitar el módulo aparte (tablas `internal_chat_*`, API, store, vistas) y lo que ya no se use en los componentes nativos |

---

## 1. Qué se quiere

Un **chat interno por cuenta**: los agentes de una misma cuenta conversan entre ellos dentro
de Wintook, sin clientes de por medio. Nadie de fuera de la cuenta lo ve, y ningún cliente
puede escribir en él.

Chatwoot no lo trae, ni siquiera en la 4.19: lo más cercano son las **notas privadas** y las
**menciones** dentro de la conversación de un cliente. Se construye desde cero, reusando piezas
que ya existen.

---

## 2. Decisión de diseño: módulo propio, no una bandeja

La idea natural es «una bandeja más», pero en Chatwoot toda conversación de bandeja es
**cliente ↔ agente**: el contacto es obligatorio, y alrededor hay muchas cosas que reaccionan a
cada mensaje.

```
          Si fuera una BANDEJA (Inbox)                   Como MÓDULO PROPIO
 ┌───────────────────────────────────────┐   ┌───────────────────────────────────────┐
 │ mensaje de agente A a agente B        │   │ mensaje de agente A a agente B        │
 │   ├─▶ hay que fingir un «contacto»    │   │   └─▶ solo lo ven los miembros        │
 │   ├─▶ Agente IA / seguimientos ⚠      │   │       de esa sala                     │
 │   ├─▶ automatizaciones ⚠              │   │                                       │
 │   ├─▶ reportes y SLA ⚠ (se ensucian)  │   │  sin contacto, sin IA, sin reportes,  │
 │   ├─▶ campañas, webhooks ⚠            │   │  sin automatizaciones: nada que       │
 │   └─▶ «Conversaciones» del cliente ⚠  │   │  apagar ni que se cuele                │
 └───────────────────────────────────────┘   └───────────────────────────────────────┘
```

**Recomendación: módulo propio**, con tablas y pantalla propias. Para el usuario se ve como «un
canal más» en el menú, pero por dentro no comparte nada con las conversaciones de clientes.

---

## 3. Cómo se ve

```
 ┌─ Menú ───────────┐ ┌─ Chat interno ──────────────────────────────────────────────┐
 │ Conversaciones   │ │ ┌──────────────────┐ ┌────────────────────────────────────┐ │
 │ Contactos        │ │ │ 🔍 Buscar        │ │ # ventas                 👥 5      │ │
 │ ...              │ │ │                  │ │────────────────────────────────────│ │
 │ 💬 Chat interno 3│ │ │ GRUPOS           │ │ Ana  10:02                         │ │
 └──────────────────┘ │ │  # general       │ │  ¿Quién toma al cliente de Puebla? │ │
                      │ │  # ventas      2 │ │ Luis 10:03                         │ │
                      │ │                  │ │  Yo, ya lo tengo (conv. #4521)     │ │
                      │ │ DIRECTOS         │ │                                    │ │
                      │ │  ● Ana         1 │ │                                    │ │
                      │ │  ○ Luis          │ │────────────────────────────────────│ │
                      │ │  ● Marta         │ │ [ Escribe un mensaje…        ] ➤   │ │
                      │ │ + Nuevo          │ │                                    │ │
                      │ └──────────────────┘ └────────────────────────────────────┘ │
                      └─────────────────────────────────────────────────────────────┘
   ● en línea  ○ desconectado        3 = mensajes sin leer
```

- **Directos (1 a 1)** entre dos agentes de la cuenta.
- **Grupos** con nombre (# ventas, # soporte) y miembros elegidos.
- Contador de no leídos en el menú y en cada sala, en tiempo real.
- Estado en línea de cada agente (ya existe en Chatwoot).

---

## 4. Modelo de datos (3 tablas nuevas)

```
 accounts ──1:N──▶ internal_chat_rooms ──1:N──▶ internal_chat_messages
                         │                              │
                         └──1:N──▶ internal_chat_members ◀── users (agentes de la cuenta)
```

| Tabla | Campos principales |
|---|---|
| `internal_chat_rooms` | `account_id`, `kind` (`direct` / `group`), `name` (solo grupos), `created_by_id`, `last_message_at` |
| `internal_chat_members` | `room_id`, `user_id`, `last_read_at` (para los no leídos), `muted`, `role` (`owner` / `member`) |
| `internal_chat_messages` | `room_id`, `user_id`, `content`, adjuntos (ActiveStorage), `edited_at`, `deleted_at` |

Reglas:
- Un directo entre dos agentes es **único** (índice sobre el par).
- Solo pueden ser miembros los **agentes de esa cuenta** (`account_users`). Al quitar a un agente de la cuenta, sale de todas sus salas.
- Los mensajes **nunca** se cruzan con `conversations` ni `messages`.

---

## 5. Tiempo real (reusa lo que ya existe)

```
 Agente A escribe ─▶ POST /internal_chat/rooms/:id/messages
                          │
                          ▼
                 InternalChat::Message guardado
                          │
                          ▼
     ActionCableBroadcastJob (ya existe) ─▶ pubsub_token de CADA miembro de la sala
                          │                         (RoomChannel, ya existe)
                          ▼
     Agente B (y los demás miembros) lo ven al instante + contador de no leídos
```

Eventos nuevos: `internal_chat.message.created`, `.updated`, `.read`, `.typing`.
Solo se mandan a los **miembros de la sala**, nunca a toda la cuenta.

---

## 6. Permisos

| Quién | Puede |
|---|---|
| Cualquier agente de la cuenta | Abrir directos con otros agentes · crear grupos · escribir en sus salas |
| Dueño del grupo / administrador | Renombrar el grupo · agregar y quitar miembros |
| Nadie de otra cuenta | Nada: todo se filtra por `account_id` y por membresía |

Decidido (D2): el administrador **no** lee los directos de otros; solo ve los grupos donde está.

---

## 7. Fases

| Fase | Qué | Resultado visible |
|---|---|---|
| **F0** | Bandera `internal_chat` por cuenta (al final de `features.yml`: posición 64, `enabled: true`) + tablas y modelos | Nada todavía |
| **F1** | API: salas (listar, crear directo/grupo, miembros), mensajes (listar paginado, enviar), marcar leído | Se puede probar por API |
| **F2** | Tiempo real: eventos por ActionCable a los miembros | Llegan al instante |
| **F3** | Pantalla: menú «Chat interno», lista de salas, sala con mensajes y caja de texto (componentes nativos) | Ya se usa |
| **F4** | No leídos en el menú, sonido y notificación del navegador, estado en línea | Se nota cuando escriben |
| **F5** | Adjuntos (imagen/archivo), editar y borrar los propios, «escribiendo…» | Completo |
| **F6** | Extras: buscar mensajes, enlazar `#4521` a la conversación del cliente, @menciones | Comodidad |

Cada fase con sus pruebas (RSpec en `chatwoot_test`, Vitest) y registrada en este documento.

---

## 8. Decisiones (todas resueltas el 26/10/2026 con la recomendación)

| # | Pregunta | Recomendación |
|---|---|---|
| D1 | ¿Grupos o solo directos 1 a 1? | Ambos: los grupos (# ventas, # soporte) son lo que más se usa |
| D2 | ¿El administrador puede leer los directos de otros? | No: solo ve los grupos donde está; da confianza al equipo |
| D3 | ¿Adjuntos? | Sí, imágenes y archivos (F5) |
| D4 | ¿Editar y borrar mensajes propios? | Sí, con marca «editado» / «mensaje borrado» |
| D5 | ¿Cuánto tiempo se guarda el historial? | Para siempre en v1 |
| D6 | ¿Encendido por cuenta (bandera) o para todas? | ✅ **Decidido (26/10/2026): encendido por omisión.** La bandera existe para poder apagarlo en una cuenta desde el super admin |
| D7 | ¿Un grupo «# general» automático con todos los agentes? | Sí, se crea al encender la bandera |

---

## 9. Cuidados conocidos

- `config/features.yml`: la bandera va **al final** (posición 64); nunca insertarla en medio.
- Migraciones con versión **no redonda** (no `…120000`) para no chocar con otras ramas.
- Plantillas `.vue` **sin `?.` ni `??`** (webpack 4 no las compila) y verificar «Compiled successfully».
- UI con los **componentes nativos** de Chatwoot, no réplicas.
- Textos en español de México, con tú.

---

## 10. Parte B · Bandejas agrupadas por tipo, en orden configurable

> Pedido el 26/10/2026 junto con el chat interno. Es **independiente** del chat: puede ir en
> esta rama o en su propio PR.

### 10.1 Hoy

En el menú de Conversaciones todas las bandejas van en **una sola carpeta**, «Bandejas de
entrada», ordenadas por nombre (`components/layout/sidebarComponents/Secondary.vue`,
`inboxSection`). Con muchas bandejas no se distingue cuál es de qué canal.

### 10.2 Cómo quedaría

```
 Conversaciones
 ├─ 💬 Todas las Conversaciones
 ├─ @  Menciones
 ├─ ✉  No Atendidas
 ├─ ⚙  Ordenar bandejas…        ◀── NUEVO: abre el modal
 │
 ├─ 📁 WhatsApp            (3)   ◀── un grupo por tipo, en el orden elegido
 │     ├─ Ventas MX
 │     ├─ Soporte
 │     └─ Cobranza
 ├─ 📁 Telegram            (1)
 ├─ 📁 Correo              (2)
 ├─ 📁 Meta (Messenger e Instagram) (2)
 ├─ 📁 Sitio web           (1)
 ├─ 📁 TikTok              (1)
 └─ 📁 Otros               (…)
 ├─ 🏷  Etiquetas …
```

- **Orden por omisión:** WhatsApp → Telegram → Correo → Meta (Messenger e Instagram) → todos los demás.
- Un grupo **sin bandejas no se muestra**.
- Dentro de cada grupo, las bandejas siguen ordenadas por nombre.

### 10.3 El modal «Ordenar bandejas»

```
 ┌─ Ordenar bandejas por tipo ─────────────────────┐
 │  Arrastra para cambiar el orden del menú.        │
 │                                                  │
 │   ⠿ 1  WhatsApp                       ▲ ▼        │
 │   ⠿ 2  Telegram                       ▲ ▼        │
 │   ⠿ 3  Correo                         ▲ ▼        │
 │   ⠿ 4  Meta (Messenger e Instagram)   ▲ ▼        │
 │   ⠿ 5  Sitio web                      ▲ ▼        │
 │   ⠿ 6  TikTok                         ▲ ▼        │
 │   ⠿ 7  SMS · Line · API · Otros       ▲ ▼        │
 │                                                  │
 │  [ Restablecer ]          [ Cancelar ] [Guardar] │
 └──────────────────────────────────────────────────┘
```

Se reordena arrastrando o con las flechas ▲▼, y «Restablecer» vuelve al orden por omisión.
Para arrastrar se usa `vuedraggable`, que Chatwoot ya trae.

### 10.4 Qué tipo de canal cae en qué grupo

| Grupo | Tipos de bandeja (`channel_type`) |
|---|---|
| WhatsApp | `Channel::Whatsapp` · `Channel::TwilioSms` con medio WhatsApp |
| Telegram | `Channel::Telegram` |
| Correo | `Channel::Email` |
| Meta (Messenger e Instagram) | `Channel::FacebookPage` · `Channel::Instagram` |
| Sitio web | `Channel::WebWidget` |
| TikTok | `Channel::Tiktok` |
| Otros | `Channel::Sms`, `Channel::TwilioSms` (SMS), `Channel::Line`, `Channel::Api`, `Channel::TwitterProfile` y cualquier tipo nuevo |

### 10.5 Dónde se guarda el orden

| Opción | Quién lo ve | Cómo |
|---|---|---|
| **A · Por agente** (recomendada) | Cada agente acomoda su menú | `ui_settings` del usuario (Chatwoot ya los guarda por usuario), con llave por cuenta |
| B · Por cuenta | El administrador lo fija para todos | `accounts.settings`; solo administradores ven «Ordenar bandejas…» |
| C · Ambas | La cuenta fija el orden base y cada agente puede cambiarlo | A + B |

### 10.6 Fases de la parte B

| Fase | Qué |
|---|---|
| **B1** | Agrupar por tipo con el orden por omisión (sin modal) |
| **B2** | Opción «Ordenar bandejas…» bajo «No Atendidas» + modal con arrastrar y ▲▼ + guardar (según D8) |
| **B3** | Pruebas (Vitest de la agrupación y el orden) y registro en este documento |

### 10.7 Decisiones de la parte B (resueltas el 26/10/2026 con la recomendación)

| # | Pregunta | Recomendación |
|---|---|---|
| D8 | ¿El orden es por agente, por cuenta o ambos? | A · por agente |
| D9 | ¿Los grupos se pueden plegar (abrir/cerrar)? | Sí, y se recuerda si estaba plegado |
| D10 | ¿Se muestra el número de bandejas en cada grupo? | Sí, entre paréntesis |
| D11 | ¿Va en esta rama o en su propio PR? | Su propio PR: se entrega antes y no espera al chat |

---

## 11. Registro de fases

### F0 – F3 · 26/10/2026 (rama `feat/chat_interno`)

**Qué se hizo**
- **F0 · Datos e interruptor.** Tablas `internal_chat_rooms`, `internal_chat_members`, `internal_chat_messages`
  (migración `20261026214739`). Tipos de sala: `general` (una por cuenta, de **todos** sus agentes, sin
  miembros fijos), `direct` (uno por pareja, `direct_key`) y `group` (dueño + miembros).
  ⚠️ **Cambio respecto al plan:** no es bandera de `features.yml`. Con 63 banderas el `bigint` ya está
  lleno y la 64 se desbordaría (2^63 no cabe en un bigint con signo; Chatwoot 4.19 lo resolvió con otra
  columna). Se guarda solo la excepción en `accounts.custom_attributes['internal_chat_disabled']`
  (concern `InternalChatToggle`), con la casilla **«Chat interno»** en Super Admin → Accounts.
- **F1 · API** `/api/v1/accounts/:id/internal_chat/rooms` (+ `messages`, `members`, `read`). Solo los
  miembros abren una sala; quien no es miembro recibe 404 (ni se entera de que existe), también el
  administrador (D2). Quitar a un agente de la cuenta lo saca de sus salas en ella.
- **F2 · Tiempo real** por el `pubsub_token` de cada miembro (`ActionCableBroadcastJob`):
  `internal_chat.message.created`, `internal_chat.room.updated`, `internal_chat.room.removed`.
- **F3 · Pantalla.** Entrada **«Chat interno»** en el menú principal (después de Conversaciones), con el
  contador de no leídos; ruta `/app/accounts/:id/internal-chat/:roomId?`. Izquierda: Grupos (la general
  primero) y Directos con sus no leídos; derecha: la sala, con «Cargar anteriores», mensajes agrupados por
  persona y caja de texto (Enter envía, Shift+Enter otra línea). Modal **«Nuevo chat»**: directo o grupo.
  Los grupos tienen «Salir del grupo».

**Cómo funciona**
- Backend: `InternalChatRoom/Member/Message`, `InternalChat::RoomList` (no leídos y último mensaje en una
  consulta cada uno), `InternalChat::Rooms` (abrir directo, crear grupo, miembros),
  `InternalChat::Broadcaster`, `InternalChat::Presenter`; controladores en `api/v1/accounts/internal_chat/`.
- Frontend: `api/internalChat.js`, store `internalChat` (eventos de tiempo real en `helper/actionCable.js`),
  `views/internalChat/` (`Index`, `RoomView`, `NewRoomModal`, `roomHelpers`).
- La primera vez que un agente entra, la general arranca «leída»: no le salen como pendientes los mensajes
  viejos de la cuenta.

**Pruebas**
- RSpec `spec/controllers/api/v1/accounts/internal_chat/internal_chat_api_spec.rb` (18, en `chatwoot_test`):
  puerta (apagado, otra cuenta), general única, no leídos, directos únicos, grupos, privacidad del
  administrador, envío y tiempo real solo a miembros, páginas, dueño/administrador, salir, salir de la cuenta, interruptor.
- Vitest `store/modules/specs/internalChat.spec.js` (9): orden, grupos/directos, no leídos, sin duplicados,
  sala abierta marca leído, sala desconocida recarga. Menú y bandejas: 61/61.
- Prueba en dev (cuenta 2): encendido por omisión; la general se crea con sus 5 agentes.
- ⚠️ Falta probarlo en el navegador con dos agentes a la vez.

**Ajustes del 26/10/2026 (pedidos después de F3)**
- **Dentro de Conversaciones, como un canal más** («canal visual»): sale la entrada del menú principal; en
  Conversaciones → Bandejas de entrada aparece el grupo **«Interno»** (primero por omisión, entra al acordeón
  y a «Ordenar bandejas…»; si un orden guardado no lo tiene, va primero). Cada sala es un renglón con sus no
  leídos, más «+ Nuevo chat». La sala se abre en el área de conversación (ruta dentro del menú de
  Conversaciones). Por dentro sigue separado: IA, automatizaciones, reportes y SLA no lo tocan.
- **Los grupos son los equipos de Chatwoot**: una sala por equipo (`kind: team`, `team_id`, migración
  `20261026221347`), con los miembros del equipo; se crean solas y se cambian en Ajustes → Equipos. Se quitaron
  crear grupos, renombrar, agregar/quitar miembros y «Salir del grupo». Borrar el equipo borra su sala.
- Pruebas: RSpec 17 (equipos en lugar de grupos); Vitest 62. Dev (cuenta 2): sala del equipo «infra qa»
  creada; no la ve nadie porque el equipo no tiene miembros.

**Pendiente (F4–F6):** sonido y aviso del navegador, adjuntos, editar/borrar, «escribiendo…», buscar,
`#4521` a la conversación, @menciones; renombrar y agregar miembros desde la pantalla (la API ya lo hace).

