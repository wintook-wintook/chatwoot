# Instagram — puesta en marcha

Guía operativa para dejar funcionando el canal nativo de Instagram.
El diseño y las decisiones están en `docs/instagram_plan.md`; esto es solo el "cómo".

En cualquier momento puedes comprobar en qué punto estás:

```bash
bundle exec rake instagram:doctor                 # configuración global
bundle exec rake instagram:doctor ACCOUNT_ID=1    # además, el flag de esa cuenta
```

---

## 0. Antes de empezar

Lo que el canal nativo **no** necesita: Página de Facebook, ni vincular Instagram a una
Página, ni el SDK de Facebook en el navegador. El agente autoriza su cuenta de Instagram
Business directamente.

Lo que sí necesita:

- Una cuenta de **Instagram Business** (no personal ni de creador)
- Una app en developers.meta.com con el producto **Instagram** configurado
- Que `https://aux.wintook.com` sea accesible desde internet (Meta entrega ahí los
  webhooks y descarga los adjuntos)

---

## 1. App de Meta

Se decidió usar **una app separada de la de Messenger**, para que una revisión de
Instagram no pueda afectar al canal que ya está en producción.

En developers.meta.com, en la app de Instagram:

| Dónde | Qué poner |
|---|---|
| Instagram → API con Instagram Login → URI de redirección OAuth | `https://aux.wintook.com/instagram/callback` |
| Instagram → Webhooks → URL de devolución de llamada | `https://aux.wintook.com/webhooks/instagram` |
| Instagram → Webhooks → Token de verificación | El mismo valor que pongas en `IG_VERIFY_TOKEN` |
| Instagram → Webhooks → Campos suscritos | `messages`, `messaging_seen` |
| Permisos | `instagram_business_basic`, `instagram_business_manage_messages` |

> ⚠️ Los nombres de permisos y la versión de API (`v22.0`) se escribieron sin consultar la
> documentación de Meta en vivo. **Contrástalos con la doc vigente antes de configurar.**
> Si cambian, la versión se ajusta en Super Admin y los permisos en
> `app/services/instagram/oauth_service.rb` (constante `SCOPE`).

La URI de redirección tiene que coincidir **carácter por carácter** con la que genera
Chatwoot. `rake instagram:doctor` te la muestra.

---

## 2. Credenciales en Chatwoot

`/super_admin/app_config?config=instagram`

| Campo | De dónde sale |
|---|---|
| `IG_APP_ID` | App de Meta → Instagram → **Instagram App ID** (no el Facebook App ID) |
| `IG_APP_SECRET` | App de Meta → Instagram → **Instagram App Secret** |
| `IG_VERIFY_TOKEN` | Lo inventas tú; el mismo string va en el webhook de Meta |
| `INSTAGRAM_API_VERSION` | Déjalo en `v22.0` salvo que Meta indique otra |

> El grupo `config=facebook` no se toca. Messenger sigue configurándose exactamente igual.
> `IG_VERIFY_TOKEN` aparece en ambas pantallas a propósito: es la misma fila, no puede
> desincronizarse.

### ⚠️ Trampa: `.env` gana sobre Super Admin

Si `.env` declara la variable **vacía**, ENV tiene prioridad sobre la base de datos y el
valor que guardes en Super Admin **no surte efecto**, aunque la pantalla lo muestre
guardado. Es silencioso: el webhook rechazará a Meta y no habrá ningún error visible.

El `.env` de esta instalación tiene hoy:

```
IG_VERIFY_TOKEN=
FB_VERIFY_TOKEN=
FB_APP_SECRET=
FB_APP_ID=
```

Todas vacías. Antes de configurar nada en Super Admin, **borra esas líneas de `.env`**
(o dales valor ahí directamente) y reinicia la aplicación. `rake instagram:doctor` avisa
explícitamente cuando detecta este caso.

Ojo, esto afecta también a Messenger: con `FB_APP_SECRET` vacío, el envío por la ruta
legacy de Instagram falla en silencio, porque el cálculo de la firma revienta y la
excepción se traga.

---

## 3. Activar el canal en la cuenta

Super Admin → Cuentas → editar la cuenta → marcar **`channel_instagram`**.

Nace apagado a propósito: así se puede empezar por una sola cuenta piloto.

Hasta que el flag esté activo **y** `IG_APP_ID` tenga valor, la tarjeta de Instagram
aparece atenuada en *Añadir bandeja*. Si no la ves, ese es el motivo.

---

## 4. Conectar la primera cuenta

Configuración → Bandejas → **Añadir bandeja** → **Instagram** → *Iniciar sesión con
Instagram* → autorizar → añadir agentes.

Si algo falla, el callback devuelve a la misma pantalla con un mensaje concreto:

| Mensaje | Qué pasó |
|---|---|
| Cancelaste la autorización | El usuario dijo que no en Instagram |
| La autorización caducó | Pasaron más de 10 minutos entre empezar y volver |
| Esa cuenta ya está conectada en otra cuenta | Ese Instagram pertenece a otra cuenta de Chatwoot |
| Instagram rechazó la autorización | Credenciales, permisos o redirect URI mal configurados |

---

## 5. Comprobación funcional

En este orden, porque cada paso depende del anterior:

1. **Recepción** — escribe un DM a la cuenta desde otro Instagram.
   Debe aparecer una conversación nueva, con el nombre y la foto del contacto.
   Si no llega: el webhook no está entregando. Revisa el token de verificación y que
   Meta muestre la suscripción como activa.

2. **Envío** — responde desde Chatwoot. Debe llegar al Instagram del cliente.
   Si el mensaje queda en **fallido**, el motivo aparece en el propio mensaje: ahora los
   rechazos de Meta se ven, antes se ocultaban.

3. **Adjuntos** — envía una imagen. Meta la descarga de `https://aux.wintook.com/...`,
   así que si el host no es accesible públicamente esto falla aunque el texto funcione.

4. **Leído** — cuando el cliente abra el mensaje, debe marcarse como leído.

5. **Ventana de 24 h** — pasadas 24 h sin mensaje del cliente, el compositor debe
   bloquearse. Es el comportamiento correcto, no un fallo.

---

## 6. Migrar las cuentas que ya usaban Instagram vía Messenger

**El orden importa.** Conectar primero, desconectar después: durante el solapamiento los
mensajes llegan por las dos rutas y la idempotencia por `mid` los absorbe. Al revés se
abre un hueco en el que los DMs no llegan a ningún sitio.

```bash
# 1. Ver qué queda por migrar
bundle exec rake instagram:pending

# 2. Conectar esa cuenta por Instagram Login (paso 4 de esta guía)

# 3. Simular el traslado — no cambia nada
bundle exec rake instagram:migrate LEGACY_INBOX_ID=12 NATIVE_INBOX_ID=34

# 4. Aplicarlo
bundle exec rake instagram:migrate LEGACY_INBOX_ID=12 NATIVE_INBOX_ID=34 APPLY=true

# 5. En la app vieja de Messenger, quitar el permiso/suscripción de Instagram
```

Qué se mueve: conversaciones de Instagram, sus mensajes, contactos e informes. Los agentes
se **copian** al inbox nuevo. El inbox de Messenger se queda intacto con sus
conversaciones, y suelta el `instagram_id` para que el router deje de resolverlo por ahí.

---

## 7. Mantenimiento

- El token caduca a los **60 días**. Un cron diario (03:00 UTC) lo renueva con 10 días de
  margen. Si Meta rechaza la renovación, el administrador recibe un correo y aparece un
  banner de reconexión en el inbox.
- `rake instagram:doctor` lista los canales conectados y cuántos días le quedan a cada
  token.
- Si un inbox muestra "reconectar", basta con pulsar el banner: rehace el OAuth y
  actualiza el canal existente, sin duplicarlo ni perder conversaciones.

---

## 8. Límites conocidos

- **Sin plantillas.** Fuera de la ventana de 24 h no hay forma de iniciar conversación,
  a diferencia de WhatsApp. Con el tag `HUMAN_AGENT` aprobado por Meta la ventana se
  amplía a 7 días (`ENABLE_MESSENGER_CHANNEL_HUMAN_AGENT` en Super Admin).
- **Los seguimientos IA respetan esa ventana**: si está cerrada, el seguimiento se marca
  como fallido en vez de gastar un intento en un mensaje que Meta rechazaría.
- **Eventos no soportados todavía**: reacciones, borrado de mensajes (`message_unsend`) e
  icebreakers. Están contemplados en el plan como fase posterior.
- **El webhook no valida la firma de Meta** (`X-Hub-Signature-256`). Es deuda anterior a
  este trabajo; con `IG_APP_SECRET` ya configurado, cerrarlo es sencillo.
