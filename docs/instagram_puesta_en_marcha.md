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

## 1. App de Meta — paso a paso

Se decidió usar **una app separada de la de Messenger**, para que una revisión de
Instagram no pueda afectar al canal que ya está en producción.

### 1.1 Crear la app

1. Entra en <https://developers.facebook.com/apps> → **Crear aplicación**
2. En el asistente, elige el caso de uso **«Gestionar mensajería y contenido en Instagram»**
   (*Manage messaging & content on Instagram*). Es el que habilita *API setup with
   Instagram Login* y el permiso `instagram_business_basic`
3. Completa nombre, correo de contacto y crea la app

> La documentación de Chatwoot describe este paso como «tipo de app *Business* + añadir el
> producto Instagram». Meta ha cambiado el panel desde entonces y ahora se hace eligiendo
> el caso de uso. Si ves el flujo antiguo, el resultado buscado es el mismo: una app con el
> producto Instagram y *API setup with Instagram Login* disponible.

### 1.2 Permisos

En el menú lateral: **Instagram → API setup with Instagram Login**

Pulsa **«Add required messaging permissions»** — no «Add all required permissions», que es
para publicación de contenido. Deben quedar:

- `instagram_business_basic`
- `instagram_business_manage_messages`

### 1.3 Credenciales

En esa misma pantalla, apartado **3. Set up Instagram business login → Business login
settings**, están el **Instagram App ID** y el **Instagram App Secret**. Son los que van a
Chatwoot (paso 2 de esta guía).

> No los confundas con el *Facebook App ID* / *App Secret* de la app: son valores
> distintos aunque estén en la misma aplicación.

### 1.4 URI de redirección OAuth

En **Business login settings**, campo *OAuth redirect URIs*:

```
https://aux.wintook.com/instagram/callback
```

⚠️ Tiene que coincidir **carácter por carácter** con la que genera Chatwoot. La propia doc
de Meta avisa de que el panel a veces **añade una barra final** al guardar; si la añade,
bórrala o la autorización fallará. `rake instagram:doctor` te muestra la URI exacta.

Si el panel te pide *Deauthorize callback URL* y *Data deletion request URL*, Chatwoot no
expone endpoints propios para eso: apunta a tu página de privacidad.

### 1.5 Webhooks

En **Instagram → Webhooks**:

| Campo | Valor |
|---|---|
| URL de devolución de llamada | `https://aux.wintook.com/webhooks/instagram` |
| Token de verificación | El mismo string que pongas en `INSTAGRAM_VERIFY_TOKEN` |

Pulsa **Verificar y guardar**. La verificación tiene que salir bien antes de poder
suscribir campos — ese handshake ya está probado y funcionando en esta instalación.

Campos a suscribir (según la documentación de Chatwoot para este canal):

- **`messages`** — imprescindible, es por donde llegan los DMs
- **`messaging_seen`** — acuses de lectura
- **`message_reactions`** — reacciones (el código todavía no las procesa; suscribirlo
  ahora no molesta y evita volver a tocar la configuración cuando se implementen)

### 1.5b ⚠️ La app tiene que estar en modo **Live**

Aquí está el detalle que más tiempo puede hacerte perder: **en modo desarrollo Meta no
entrega webhooks**. La autorización funcionará, el inbox se creará, y no llegará ni un
mensaje, sin ningún error.

Cambia la app a **Live** con el interruptor de la cabecera del panel. Con la app en Live y
la cuenta dada de alta como tester (paso siguiente) se puede probar el ciclo completo sin
haber pasado App Review.

### 1.6 Cuenta de prueba (para probar sin App Review)

La app nace en **modo desarrollo**: solo funciona con cuentas dadas de alta como
administrador, desarrollador o tester. Eso basta para probarlo todo sin pasar revisión.

1. **Roles → Instagram Testers** → añade el usuario de Instagram con el que vas a probar
2. Desde esa cuenta, en Instagram web: **Configuración → Aplicaciones y sitios web** →
   aceptar la invitación pendiente

Sin ese paso, la autorización falla aunque todo lo demás esté bien.

### 1.7 App Review (solo para producción)

Para usarlo con cuentas que no sean testers hay que solicitar acceso avanzado a
`instagram_business_basic` e `instagram_business_manage_messages`. Se puede dejar para
después de validar el funcionamiento con la cuenta de prueba.

---

## 2. Credenciales en Chatwoot

`/super_admin/app_config?config=instagram`

| Campo | De dónde sale |
|---|---|
| `INSTAGRAM_APP_ID` | App de Meta → Instagram → **Instagram App ID** (no el Facebook App ID) |
| `INSTAGRAM_APP_SECRET` | App de Meta → Instagram → **Instagram App Secret** |
| `INSTAGRAM_VERIFY_TOKEN` | Lo inventas tú; el mismo string va en el webhook de Meta. El webhook también acepta el `IG_VERIFY_TOKEN` que ya usaba la ruta legacy, así que basta con tener uno de los dos |
| `INSTAGRAM_API_VERSION` | Déjalo en `v25.0` salvo que Meta indique otra |

> El grupo `config=facebook` no se toca. Messenger sigue configurándose exactamente igual.
> `IG_VERIFY_TOKEN` aparece en ambas pantallas a propósito: es la misma fila, no puede
> desincronizarse.

### ⚠️ Trampa: `.env` gana sobre Super Admin

Si `.env` declara la variable **vacía**, ENV tiene prioridad sobre la base de datos y el
valor que guardes en Super Admin **no surte efecto**, aunque la pantalla lo muestre
guardado. Es silencioso: el webhook rechazará a Meta y no habrá ningún error visible.

✅ **Ya resuelto en esta instalación**: esas líneas (`IG_VERIFY_TOKEN`, `FB_VERIFY_TOKEN`,
`FB_APP_SECRET`, `FB_APP_ID`) están comentadas en `.env` con una nota, y el servicio se
reinició. El handshake del webhook quedó verificado por HTTP contra el dominio público.

Si despliegas en otra máquina, repítelo allí: `.env` está en `.gitignore`.
`rake instagram:doctor` avisa explícitamente cuando detecta este caso.

Ojo, esto afecta también a Messenger: con `FB_APP_SECRET` vacío, el envío por la ruta
legacy de Instagram falla en silencio, porque el cálculo de la firma revienta y la
excepción se traga.

---

## 3. Activar el canal en la cuenta

Super Admin → Cuentas → editar la cuenta → marcar **`channel_instagram`**.

Nace apagado a propósito: así se puede empezar por una sola cuenta piloto.

Hasta que el flag esté activo **y** `INSTAGRAM_APP_ID` tenga valor, la tarjeta de Instagram
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
- **Eventos no soportados todavía**: reacciones (`message_reactions`), borrado de mensajes
  (`message_unsend`) e icebreakers. Están contemplados en el plan como fase posterior;
  suscribir el campo en Meta desde ya no causa ningún problema.
- **El webhook no valida la firma de Meta** (`X-Hub-Signature-256`). Es deuda anterior a
  este trabajo; con `INSTAGRAM_APP_SECRET` ya configurado, cerrarlo es sencillo.
