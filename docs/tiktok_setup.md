# Poner en marcha el canal de TikTok

Guía de puesta en marcha para esta instalación (`develop.wintook.com`). Cubre lo que hay
que hacer en TikTok, lo que hay que configurar en Chatwoot y cómo comprobar que funciona.

Basada en la [documentación oficial de Chatwoot][doc] y en lo implementado en la rama
`feat/inbox_tiktok`.

[doc]: https://developers.chatwoot.com/self-hosted/configuration/features/integrations/tiktok

---

## ⚠️ Antes de empezar: comprueba que puedes usarlo

Dos restricciones de TikTok que no dependen de nosotros y que invalidan todo lo demás si
no se cumplen:

| Restricción | Detalle |
|---|---|
| **Región** | La Business Messaging API **no está disponible** para cuentas registradas en el **Espacio Económico Europeo, Suiza y Reino Unido**. Cuenta el país de registro de la cuenta de TikTok, no el tuyo. |
| **Tipo de cuenta** | Solo **cuentas de empresa** (Business Account). Las cuentas personales no sirven. |

Además, aunque la cuenta sea válida, TikTok **solo entrega los mensajes entrantes de
usuarios que estén fuera del EEE, Suiza y Reino Unido**. Un cliente que te escriba desde
España no llegará al inbox. No es un fallo de la integración: es su política.

---

## Lo que necesitas conseguir

Al final de esta guía debes tener estos tres datos:

| Dato | De dónde sale | Dónde se mete |
|---|---|---|
| `TIKTOK_APP_ID` | *Client key* de tu app en TikTok | Super Admin |
| `TIKTOK_APP_SECRET` | *Client secret* de tu app en TikTok | Super Admin |
| `TIKTOK_API_VERSION` | Ya viene puesto: `v1.3` | Super Admin (solo si cambia) |

`TIKTOK_APP_SECRET` se usa para tres cosas: canjear el código OAuth, firmar el `state` del
flujo de autorización y **verificar la firma de cada webhook**. Trátalo como una
contraseña: nunca sale al navegador.

---

## Paso 1 — Cuenta de desarrollador en TikTok

1. Entra en <https://developers.tiktok.com> y regístrate.
2. Verifica el correo y acepta los términos de servicio.

## Paso 2 — Crear la aplicación

En <https://business-api.tiktok.com/portal/apps>, crea una aplicación nueva. Te pedirá:

- **Nombre** — algo reconocible, p. ej. `Wintook - Chatwoot`
- **Descripción**
- **Icono** — el logotipo de la empresa
- **URL de términos de servicio**
- **URL de política de privacidad**

Al crearla te da el **App ID (Client key)** y el **App Secret (Client secret)**.
**Guárdalos ahora**: el secreto no se vuelve a mostrar.

## Paso 3 — Pedir acceso a la Business Messaging API

Esto es una **solicitud que TikTok revisa a mano**, no un interruptor. Hay que explicar:

- para qué la vas a usar (atención al cliente por mensajes directos),
- cómo tratas los datos,
- información de la empresa.

> La aprobación **suele tardar unos días** y puede alargarse. Hasta que no esté aprobada,
> la autorización fallará aunque todo lo demás esté bien.

Activa también el permiso **"TikTok Accounts"** en *Scope of permission*.

### Permisos que pide esta integración

El callback **rechaza la autorización si el usuario no los concede todos**, porque con
permisos a medias el canal no puede leer ni enviar y quedaría un inbox inútil:

```
user.info.basic        user.info.username     user.info.stats
user.info.profile      user.account.type      user.insights
message.list.read      message.list.send      message.list.manage
```

## Paso 4 — Registrar la URL de retorno

En la configuración de la app, como **Authorization Redirect URL**:

```
https://develop.wintook.com/tiktok/callback
```

Tiene que coincidir **carácter por carácter** con lo que manda Chatwoot. Si no estás
seguro de cuál es, te la dice el diagnóstico del Paso 7.

---

## Paso 5 — Configurar Chatwoot

### 5.1 Credenciales

Super Admin → Configuración, o directamente:

```
https://develop.wintook.com/super_admin/app_config?config=tiktok
```

Rellena **TikTok App ID** y **TikTok App Secret**. `TikTok API Version` ya viene con
`v1.3`; no lo toques salvo que TikTok publique otra.

### 5.2 Activar la función en la cuenta

Super Admin → **Accounts** → la cuenta → **Features** → activar **`channel_tiktok`**.

Sin esto, la tarjeta de TikTok **no aparece** en el listado de canales. La tarjeta exige
las dos cosas a la vez: la función activada **y** el `TIKTOK_APP_ID` configurado.

### 5.3 Registrar el webhook — el paso que más se olvida

En TikTok el webhook se registra **por aplicación y una sola vez para toda la
instalación**, no por cuenta como en Meta. Si falta, **no llega ni un solo mensaje, no se
registra ningún error y el inbox parece perfectamente sano**.

```bash
cd /opt/chatwoot
RAILS_ENV=production bundle exec rake tiktok:register_webhook
```

Registra `https://develop.wintook.com/webhooks/tiktok`. Es idempotente: se puede repetir
sin miedo.

> La documentación oficial manda hacerlo desde la consola de Rails
> (`Tiktok::AuthClient.update_webhook_callback`). La tarea rake hace exactamente lo mismo,
> pero avisa si TikTok lo rechaza.

---

## Paso 6 — Conectar la cuenta

1. En el dashboard: **Ajustes → Bandejas de entrada → Añadir bandeja**.
2. Elige **TikTok**.
3. Pulsa **Continuar con TikTok** y autoriza **todos** los permisos.
4. Al volver se crea la bandeja y pasas a asignar agentes.

Si algo falla, la pantalla te dice el motivo concreto:

| Mensaje | Qué pasó | Qué hacer |
|---|---|---|
| Cancelaste la autorización | Le diste a rechazar en TikTok | Repetir |
| El enlace de autorización caducó | Pasaron más de 15 minutos entre abrir y autorizar | Repetir |
| TikTok no devolvió el código | Fallo por parte de TikTok | Repetir |
| Debes conceder todos los permisos | Autorizaste solo algunos | Repetir concediéndolos todos |
| Esa cuenta ya está conectada en otra cuenta de Chatwoot | El mismo perfil de TikTok está en otra cuenta | Desconectarlo allí primero |
| Hubo un error al conectar | Cualquier otra cosa | Ver Paso 7 y los logs |

---

## Paso 7 — Comprobar que está todo bien

```bash
cd /opt/chatwoot
RAILS_ENV=production bundle exec rake tiktok:doctor
```

Responde en un vistazo qué falta:

```
== Configuración ==
  ✔ TIKTOK_APP_ID
  ✔ TIKTOK_APP_SECRET
  ✔ FRONTEND_URL = https://develop.wintook.com
   URL de callback OAuth : https://develop.wintook.com/tiktok/callback
   URL del webhook       : https://develop.wintook.com/webhooks/tiktok

== Webhook registrado en TikTok ==
  ✔ registrado: https://develop.wintook.com/webhooks/tiktok

== Cuentas con el canal habilitado ==
  ✔ #2 Admin

== Canales dados de alta ==
  · inbox #123 Mi Marca (business_id 7xxxxxxxxxxxxxxx)
    ✔ access_token válido hasta 2026-08-08 20:17:23 UTC
    ✔ refresh_token válido hasta 2026-09-05 20:17:23 UTC
    ✔ autorización al día
```

Las dos URLs que imprime son las que hay que copiar en el portal de TikTok: si no cuadran,
ese es el problema.

---

## Cómo funciona una vez conectado

### Los dos tokens

TikTok no da tokens de larga duración como Meta:

- el **token de acceso** dura **~1 día** y se renueva solo la primera vez que se usa
  después de caducar — no hace falta hacer nada;
- el **token de refresco** dura **~30 días** y **rota en cada renovación**.

Mientras haya actividad, la cadena se mantiene sola. Si un canal pasa más de 30 días sin
usarse, el token de refresco caduca y **hay que volver a autorizar a mano**: aparece un
aviso de reconexión en los ajustes de la bandeja. `rake tiktok:doctor` distingue los dos
casos.

### Qué se puede enviar y recibir

| | Soportado |
|---|---|
| **Recibir** | texto, imagen, vídeo de TikTok compartido |
| | pegatinas: se guardan marcadas como "no soportado" para que no quede un hueco en la conversación |
| **Enviar** | texto (hasta 6000 caracteres) |
| | **una** imagen JPG o PNG de **menos de 3 MB**, y solo si la conversación lo permite |
| **No se puede** | mezclar texto y adjunto en el mismo mensaje — el dashboard los manda como dos mensajes separados |
| | varios adjuntos a la vez, audio, vídeo, documentos |

### Ventana de respuesta

**48 horas** desde el último mensaje del cliente (Meta da 24). Pasado ese plazo el
dashboard bloquea la respuesta.

### Un detalle a tener en cuenta

La API de TikTok gira sobre la **conversación**, no sobre la persona: no expone un
identificador estable de usuario con el que agrupar. Por eso, si el mismo usuario abriera
dos hilos distintos, aparecerían como **dos contactos**. El `user_id` sí se guarda en los
atributos del contacto por si algún día se puede unificar.

---

## Cuando algo no va

| Síntoma | Causa más probable |
|---|---|
| **No llega ningún mensaje** y no hay errores | El webhook no está registrado → `rake tiktok:register_webhook` |
| Llegan los que envío pero no los que recibo | El cliente escribe desde el EEE, Suiza o Reino Unido: TikTok no los entrega |
| La tarjeta de TikTok no sale al añadir bandeja | Falta la función `channel_tiktok` en la cuenta, o falta `TIKTOK_APP_ID` |
| "Requiere reautorización" en los ajustes | Caducó el token de refresco (>30 días parado) → reconectar desde el aviso |
| La autorización devuelve error siempre | La Business Messaging API todavía no está aprobada, o el redirect URI no coincide |

Los logs llevan el prefijo `[TikTok]`:

```bash
grep -i tiktok log/production.log | tail -50
```

---

## Resumen para copiar y pegar

```bash
# 1. Credenciales:  Super Admin -> /super_admin/app_config?config=tiktok
# 2. Función:       Super Admin -> Accounts -> Features -> channel_tiktok
# 3. Webhook (una sola vez para toda la instalación):
RAILS_ENV=production bundle exec rake tiktok:register_webhook

# 4. Comprobar:
RAILS_ENV=production bundle exec rake tiktok:doctor
```

| En el portal de TikTok | Valor |
|---|---|
| Authorization Redirect URL | `https://develop.wintook.com/tiktok/callback` |
| Webhook URL | `https://develop.wintook.com/webhooks/tiktok` (lo registra la tarea rake) |
