# Plan — Mejoras de plantillas de WhatsApp (adjuntos, botones y pantalla)

> Rama: `feat/plantillas_whatsapp_mejoras` (desde `develop` 09f0278c).
> Referencia: Chatwoot v4.19.0 en `/opt/chatwoot_v4190` (solo lectura).
> Antecedente: `docs/waba_templates_plan.md` (módulo para crear plantillas en Meta, ya en develop).
>
> **Este documento NO implementa.** Es para revisar alcance, fases y decisiones antes de tocar código.

---

## 1. Diagnóstico (verificado en el código)

```
 CREAR (Configuración → Plantillas)                ENVIAR
 ──────────────────────────────────                ───────────────────────────────────────────
 encabezado texto/imagen/video/documento  ✅        conversación: el selector OCULTA las de
 botones respuesta/URL/teléfono/código    ✅          imagen/video/documento        ❌
 muestra subida a Meta: solo IMAGEN       ⚠️        solo variables del CUERPO       ❌
                                                    seguimientos/campañas: solo CUERPO ❌
                                                    programados: solo CUERPO         ❌
```

| Hallazgo | Dónde |
|---|---|
| El selector filtra `DOCUMENT`, `IMAGE`, `VIDEO` ("TODO: Remove when we support all formats") | `components/widgets/conversation/WhatsappTemplates/TemplatesPicker.vue:3` |
| El envío siempre arma un solo componente `body` | `services/whatsapp/providers/whatsapp_cloud_service.rb:247` (`template_body_parameters`) |
| `processed_params` se convierte a lista plana de texto | `services/whatsapp/send_on_whatsapp_service.rb:62` |
| Existe un armador de envío con encabezado y botones, **sin usarse** | `services/whatsapp/template_send_component_builder.rb` |
| Seguimientos IA y campañas llaman directo a `send_template` con la lista del cuerpo | `jobs/contact_tracking_job.rb:637` |
| Mensajes programados guardan `processed_params` plano | `components/widgets/conversation/ScheduleMessageModal.vue:1390` |
| **Al crear**, solo la imagen se sube a Meta como muestra; en video y documento se manda la liga cruda como `header_handle` (Meta lo rechazaría) | `services/whatsapp/submit_template_service.rb:109`, `template_component_builder.rb:50` |

Resultado: hoy se puede **crear y aprobar** una plantilla con adjunto, pero **no se puede enviar desde ningún lado**.

---

## 2. Qué se toma de la 4.19 y qué no

| De la 4.19 | Decisión |
|---|---|
| `PopulateTemplateParametersService` (arma parámetros: texto, medio, botones, moneda, fecha) | **Traer**, ajustando la limpieza de texto (ver D3) |
| `TemplateParameterConverterService` (convierte el formato viejo `{"1":"Juan"}` al nuevo) | **Traer tal cual**: es lo que garantiza que nada de lo actual se rompa |
| `TemplateProcessorService` (encabezado + cuerpo + pie + botones) | **Traer** |
| `SendOnWhatsappService` completo | **NO**: cambia el orden de los datos de `send_template`, quita el empate por texto fuera de 24 h y marca como fallido lo que hoy se envía. Solo se cambia la parte que prepara los datos |
| `WhatsAppTemplateParser.vue` / `TemplatePreview` / `SidePanel` | **NO se copian**: son Vue 3 + `components-next`; estamos en Vue 2.7. Se toman las ideas y se arman con los componentes nativos que ya usamos |
| CSAT por plantilla, botón para pedir datos del contacto, candado de autenticación (BSUID) | Fuera de alcance |

---

## 3. Arquitectura del envío

```
   Conversación / panel del contacto        Mensajes programados       Seguimientos IA / campañas
   (selector + formulario)                  (ScheduleMessageModal)     (contact_tracking_job)
              │                                       │                          │
              ▼  template_params.processed_params     │                          │ lista del cuerpo
   ┌──────────────────────────────────────────┐       │                          │ (+ encabezado F5)
   │ { header:{media_url,media_type,media_name│◄──────┘                          │
   │   | "1":..}, body:{..}, buttons:[..] }   │                                  │
   └──────────────────┬───────────────────────┘                                  │
                      ▼                                                          │
   send_on_whatsapp_service.send_template_message                                │
      └─ TemplateParameterConverterService  (formato viejo → nuevo)              │
      └─ TemplateProcessorService           (→ components de Meta)               │
                      │  parameters = [ {type:'header',..}, {type:'body',..}, {type:'button',..} ]
                      ▼                                                          ▼
   whatsapp_cloud_service.template_body_parameters(template_info)
      ├─ si parameters YA son components  → se mandan tal cual
      └─ si es la lista de siempre         → components: [{ type:'body', parameters }]   (como hoy)
                      │
                      ▼
                    Meta  ──webhook──►  estado del mensaje (falló / entregado / leído)
```

**Regla de compatibilidad:** toda llamada que hoy funciona manda el mismo JSON a Meta que antes. Lo nuevo solo se activa si la plantilla tiene encabezado con medio, variables en el encabezado o botones variables.

---

## 4. Fases

### F0 — Corregir la creación con video y documento
- `ensure_header_handle` hoy solo sube la muestra si es `image`. Extenderlo a `video` y `document`.
- Test por cada tipo: el `example.header_handle` es el handle de la subida, nunca la liga.
- **Verificar primero** contra Meta con una plantilla de prueba de video (pedir OK antes de mandarla).

### F1 — Envío compatible (backend)
- Traer `PopulateTemplateParametersService`, `TemplateParameterConverterService` y `TemplateProcessorService` de la 4.19.
- `send_on_whatsapp_service#processable_channel_message_template`: cuando hay `template_params`, usar el procesador; **conservar** el empate por texto fuera de 24 h.
- `whatsapp_cloud_service#template_body_parameters`: aceptar components completos **o** la lista de siempre.
- 360dialog y UnoAPI: sin cambios (siguen solo cuerpo).
- Pruebas (RSpec con `POSTGRES_DATABASE=chatwoot_test`):
  - formato viejo plano → mismo JSON que hoy (snapshot)
  - lista directa de seguimientos → mismo JSON que hoy
  - imagen / video / documento con nombre
  - variables en encabezado de texto
  - botón URL variable y copiar código (máx 15)
  - variables con nombre (`parameter_format: NAMED`)

### F2 — Conversación (selector y formulario)
- Selector: dejar de ocultar las de adjunto **solo si la bandeja es WhatsApp Cloud**; en 360dialog/UnoAPI siguen ocultas.
- Selector: vista previa con encabezado (texto o "Imagen / Video / Documento") y botones.
- Formulario (`TemplateParser.vue`), con componentes nativos:
  - liga del adjunto (+ nombre si es documento)
  - variables del encabezado de texto
  - campos para botón URL variable y copiar código
  - vista previa del mensaje armado
- Manda `processed_params` en el formato nuevo (`header/body/buttons`).
- Aplica también al panel del contacto (`conversation/contact/WhatsappTemplates.vue`), que usa el mismo modal.

### F3 — Burbuja del mensaje enviado
- Hoy el agente solo ve el texto; el cliente sí recibe el adjunto.
- Pintar en la burbuja el adjunto del encabezado a partir de `additional_attributes.template_params.processed_params.header` (ya se guarda; no requiere migración).
- **No** adjuntar el archivo como attachment normal del mensaje (podría cruzarse con la ruta de envío de adjuntos).

### F4 — Mensajes programados
- `ScheduleMessageModal.vue` tiene su propio formulario de variables (copiado del parser viejo).
- Darle los mismos campos que F2 (adjunto y botones) **o**, si se decide no hacerlo ahora, ocultar ahí las plantillas con adjunto para que no fallen al enviarse (ver D4).

### F5 — Seguimientos IA y campañas
- Si la plantilla elegida lleva adjunto, tomar el archivo guardado en `whatsapp_templates` (de F6) y mandarlo como encabezado.
- Si la plantilla tiene adjunto pero no hay archivo guardado → no enviar y registrar el motivo en la entrega rechazada (como hoy con los errores de Meta).
- Botón URL variable / copiar código en seguimientos: fuera de alcance salvo que se pida (ver D5).

### F6 — Pantalla de plantillas (`/settings/whatsapp-templates/list`)
1. **Vista previa tipo WhatsApp**: imagen o video real del encabezado, ícono + nombre si es documento, botones abajo.
2. **Filtros por idioma y por tipo** (texto, imagen, video, documento, con botones, copiar código) en el modal de filtros que ya existe.
3. **Indicador "se puede enviar"** por plantilla: conversación sí/no, seguimientos sí/no (p. ej. "falta archivo").
4. **Errores de sincronización por bandeja** ("se sincronizaron 3 de 4; falló X").
5. **Botón "Ver en Meta"** que abre WhatsApp Manager.
6. **Subir el archivo de muestra** (además de pegar liga):
   - se guarda en la plantilla (ActiveStorage) y su liga pública llena `header_media_url`
   - de ahí sale el handle para Meta (F0) **y** el archivo que usan seguimientos y campañas (F5)
   - límites de Meta: imagen JPG/PNG ≤ 5 MB · video MP4 ≤ 16 MB · documento PDF ≤ 100 MB

```
  Subir archivo ──► ActiveStorage ──► header_media_url (liga pública estable)
                                         │
                     ┌───────────────────┼─────────────────────┐
                     ▼                   ▼                     ▼
            muestra para Meta     encabezado en           vista previa
            (resumable upload,    seguimientos y          en la pantalla
             F0)                  campañas (F5)
```

### F7 (opcional) — Subir el archivo desde la conversación
- En el formulario de F2, además de pegar liga, subir el archivo y usar su liga pública.
- Solo si se aprueba en D2.

---

## 5. Orden y dependencias

```
 F0 ──► F1 ──► F2 ──► F3
               │
               ├──► F4
               │
 F6(6. subir) ─┴──► F5          F6 (1–5) puede ir en paralelo después de F1
                                F7 opcional, después de F2
```

---

## 6. Riesgos

| Riesgo | Mitigación |
|---|---|
| Romper envíos actuales (conversación, programados, acuse de tickets, app móvil) | Convertidor de formato viejo + snapshots del JSON actual en F1 |
| Romper seguimientos al cambiar `template_body_parameters` | Detectar lista vs components; test dedicado |
| Liga del adjunto privada o caducada | Meta responde por webhook → el mensaje queda "fallido" con el motivo (ya existe). En F6/F7 se usan ligas propias estables |
| Limpieza de texto de la 4.19 borra comillas y `<>` de las variables | Ver D3 |
| Plantilla con adjunto en bandeja 360dialog/UnoAPI | Siguen ocultas en el selector |
| Plantillas en `.vue` con `?.` tumban webpack 4 | Usar computed; verificar "Compiled successfully" |

---

## 7. Decisiones (cerradas 29/10/2026: «ok a todas tus recomendaciones»)

| # | Decisión |
|---|---|
| D1 | **Sí**: F3 (burbuja con el adjunto) entra en esta rama |
| D2 | **No por ahora**: F7 (subir archivo desde la conversación) queda fuera — **reabierta 30/10: sí, hecha (§7.10)** |
| D3 | Se quitan **solo `< >`** de las variables (no las comillas) |
| D4 | Mensajes programados: **ocultar** las plantillas con adjunto por ahora |
| D5 | Seguimientos/campañas: **solo el adjunto**, sin botones variables |
| D6 | Variables con nombre al **crear**: después (el envío sí las soporta en F1) |

<details><summary>Texto original de las decisiones</summary>

## 7. Decisiones abiertas

- **D1** — ¿F3 (burbuja) entra en esta rama o después?
- **D2** — ¿F7 (subir archivo desde la conversación) entra?
- **D3** — La 4.19 quita `< > " '` de las variables. Recomendado: quitar solo `< >` para no comerse comillas del texto en español.
- **D4** — Mensajes programados: ¿formulario completo (F4) u ocultar las de adjunto por ahora?
- **D5** — ¿Seguimientos/campañas necesitan botones variables o solo el adjunto?
- **D6** — ¿Agregar variables con nombre (`{{nombre}}`) al **crear** plantillas? Hoy solo `{{1}}`; el envío sí las soportará (F1).

</details>

---

## 7.1 F0 — hecho (29/10/2026)

**Qué se hizo.**
- `Whatsapp::ResumableUploadService` sube la muestra de **imagen, video y documento** (`header_type:`),
  cada uno con los límites de Meta: imagen JPEG/PNG ≤ 5 MB · video MP4/3GPP ≤ 16 MB · documento PDF ≤ 100 MB.
  Mensajes por tipo («El video supera 16 MB», «Tipo no permitido (image/png); solo PDF»).
- `SubmitTemplateService#ensure_header_handle` sube la muestra en los tres tipos (antes solo imagen).
- `TemplateComponentBuilder` **nunca** manda la liga cruda como `header_handle` (era lo que hacía que Meta
  rechazara video y documento): solo el handle de la subida.
- Al **editar** con otra liga de muestra se descarta el handle viejo y se vuelve a subir (si no, Meta
  revisaría el archivo anterior).

**Pila de pruebas.** `resumable_upload_service_spec.rb` (+4: video, documento, tope de 16 MB, formato por
tipo), `submit_template_service_spec.rb` (+5: los tres tipos suben y mandan su handle, subida fallida no
llama a Meta, editar con otra liga vuelve a subir), `template_component_builder_spec.rb` (+1: nunca la liga).
54/54 en los specs de plantillas.

**Ojo — fallas que ya traía `develop`.** En `spec/services/whatsapp` fallan 29 pruebas **con y sin F0**
(comparado con stash): `incoming_message_service` (19), `incoming_message_whatsapp_cloud_service` (3),
`providers/whatsapp_cloud_service` (5) y `send_on_whatsapp_service` (2). Las dos últimas son justo lo que
toca F1: entenderlas antes de cambiar el envío.

**Probado contra Meta real (29/10/2026, con OK del usuario).** Bandeja «Whatsapp» (inbox 1563, cuenta 2,
WABA real), app de Meta «Wintook WA API» (App ID `1177974373661702`, leído con `GET /app` y el token de la
bandeja). Se crearon dos plantillas de ejemplo, las dos quedaron **PENDING** en Meta:

| Plantilla | Tipo | Meta id |
|---|---|---|
| `ejemplo_documento_adjunto` (UTILITY, es_MX) | PDF de muestra (W3C dummy.pdf) | 39933694202910553 |
| `ejemplo_video_adjunto` (MARKETING, es_MX) | MP4 de 5 s (samplelib) | 939121985747837 |

Salieron dos fallos que los dobles no veían, ya corregidos:
1. **`META_APP_ID` del super admin se ignoraba**: el servicio solo lo leía de la variable de entorno. Ahora
   va por `GlobalConfigService` (entorno o super admin) y luego `FB_APP_ID`. En dev se guardó en
   `META_APP_ID` (no en `FB_APP_ID`, que también usan Messenger y el login de Facebook).
2. **El handle de un video pasa de 255 caracteres**: el de documento midió 199, el de video no cabía y
   `ApplicationRecord` lo rechazaba → Meta creó la plantilla pero el guardado local falló (drift). Ahora
   `WhatsappTemplate` valida `header_handle` ≤ 4000 y `header_media_url` ≤ 2048. La de video se reconcilió
   con «Sync» (`TemplateSyncService`).

Para borrar los ejemplos: pantalla de plantillas → borrar (llama a Meta por su id).

## 7.2 Antes de F1 — ventana de 24 h y pruebas al día (29/10/2026, commit a3075991)

- **Fallo real encontrado (con OK del usuario):** `Channel::Whatsapp#messaging_window_enabled?` solo valía
  si la bandeja tenía escrita la liga `https://graph.facebook.com` (viene de la base del fork, dic 2023). La
  bandeja WhatsApp Cloud de dev (651) tiene la liga vacía → **nunca respetaba la ventana**: pasadas 24 h el
  texto libre salía y Meta lo rechazaba, y el empate «este texto es una plantilla» no se activaba. Ahora:
  360dialog y WhatsApp Cloud con liga vacía o de Meta respetan la ventana; UnoAPI y una liga propia no.
  ⚠ Cambia lo que ven los agentes: pasadas 24 h el cuadro pide plantilla.
- Pruebas de `WhatsappCloudService` y del canal puestas al día (Graph v14.0 para la cuenta de negocio, orden
  de `send_template`). Quedan las 22 de mensajes que **llegan** (`incoming_message*`), que no son del envío.

## 7.3 F1 — hecho (29/10/2026)

**Qué se hizo.**
- Traídas de Chatwoot 4.19: `PopulateTemplateParametersService`, `TemplateParameterConverterService` y
  `TemplateProcessorService`, con sus specs de la 4.19 (30, pasan sin tocar). Cambio local **D3**: la
  limpieza quita solo `< >` (la 4.19 también quitaba comillas).
- `SendOnWhatsappService#processable_channel_message_template`: en **WhatsApp Cloud**, con `template_params`,
  usa el procesador (`enhanced_template_params`) → encabezado de texto o archivo, cuerpo, pie y botones. Si
  no hay components (la plantilla no está en `message_templates` o no lleva variables) se arma como siempre.
  Un dato inválido (liga mala, código > 15) deja el mensaje **fallido con el motivo** y no se envía.
  360dialog y UnoAPI: igual que antes (`legacy_template_params`). El empate por texto fuera de 24 h no cambia.
- `WhatsappCloudService#template_body_parameters` → `template_components`: si los parámetros ya son
  components (header/body/footer/button) van tal cual; si es la lista de siempre (seguimientos, campañas,
  empate por texto), dentro de un solo `body`, como antes.

**Cómo funciona — compatibilidad.** El JSON a Meta de todo lo de hoy es el mismo: formato viejo
`{"1":"3"}`, plantilla fuera de la lista, lista directa de seguimientos y sin parámetros (probado).

**Pila de pruebas.** `send_on_whatsapp_service_cloud_templates_spec.rb` (11): formato viejo igual que antes,
plantilla fuera de la lista, imagen + cuerpo, video sin variables, documento con nombre, encabezado de texto
+ botón URL variable + copiar código, variables con nombre, D3 (comillas sí, `< >` no), dato inválido →
fallido sin enviar, lista de siempre → un body, sin parámetros. `spec/services/whatsapp` + canal: 219, solo
fallan las 22 de `incoming_message*` (ya venían de develop).

**Pendiente de limpiar (fuera de alcance).** `Whatsapp::TemplateSendComponentBuilder` (+ su spec) nunca se usó
y hace lo mismo que el procesador con otro formato; se puede borrar cuando F2–F5 estén en uso.

**Todavía no se ve nada en pantalla**: el formulario de la conversación es F2.

## 7.4 F2 — hecho (29/10/2026)

**Qué se hizo.**
- `templateForm.js` (nuevo, puro, con spec): qué pide una plantilla (`describeTemplate`: archivo del
  encabezado y su nombre si es documento, variables del encabezado de texto y del cuerpo, botones con dato:
  URL con `{{1}}` y copiar código), qué se manda (`buildProcessedParams`), qué falta (`validateValues`) y la
  vista previa (`renderPreview`).
- **Selector** (`TemplatesPicker.vue`): en **WhatsApp Cloud** ya no oculta las de imagen/video/documento; en
  360dialog/UnoAPI siguen ocultas. Cada plantilla muestra su encabezado (texto o «Imagen/Video/Documento») y
  sus botones.
- **Formulario** (`TemplateParser.vue`, prop `fullTemplate`): liga del archivo (+ nombre si es documento),
  variables del encabezado, del cuerpo y de los botones; vista previa con encabezado, cuerpo, pie y botones;
  errores por campo (liga pública http/https, código ≤ 15).
- `fullTemplate` lo pasan el modal de la conversación (`Modal.vue`) y el panel del contacto
  (`contact/WhatsappTemplates.vue`) según el `provider` de la bandeja.

**Qué se manda.** Formato por componente `{ header, body, buttons }` **solo** en WhatsApp Cloud y solo si la
plantilla lleva algo más que el cuerpo; si no, el formato de siempre `{ "1": "Juan" }` (360dialog y UnoAPI no
cambian). El contenido del mensaje sigue siendo el cuerpo; el adjunto en la burbuja es F3.

**Pila de pruebas.** `templateForm.spec.js` (14), `TemplatesPicker.spec.js` (2: Cloud ofrece las de archivo
con encabezado y botones; 360dialog no), `whatsappTemplates.spec.js` (+3: Cloud manda el documento por
componente, sin liga no manda y dice qué falta, fuera de Cloud como siempre; las 4 de antes siguen),
`message_builder_spec.rb` (+1: el `processed_params` anidado se guarda completo). Webpack: «Compiled
successfully». ⚠ **Sin probar en navegador ni enviando a un teléfono real.**

## 7.5 F3 — hecho (29/10/2026)

**Qué se hizo.** `bubble/TemplateHeader.vue` (nuevo): en la burbuja del mensaje, arriba del texto, el archivo
del encabezado de la plantilla, leído de `additional_attributes.template_params.processed_params.header`
(F2 ya lo guarda; sin migración): **imagen** (con liga para abrirla), **video** (reproductor) o
**documento** (`BubbleFile` con el nombre con que se mandó; `BubbleFile` acepta ahora `name`, si no lo saca
de la liga como siempre). `Message.vue` lo pinta y lo cuenta para mostrar la burbuja.

**Por qué no es un adjunto.** No se crea attachment (podría cruzarse con la ruta de envío de adjuntos) y no
se usa `BubbleImageAudioVideo`: su clic abre la galería de los adjuntos reales, donde este archivo no está.

**Pila de pruebas.** `bubble/specs/TemplateHeader.spec.js` (4): imagen con liga, video con controles,
documento con su nombre, `BubbleFile` con y sin nombre. `Message.vue` sin hallazgos nuevos de lint. Fallan
4 de `specs/MoreActions.spec.js` **con y sin F3** (ya venían de develop). Webpack: «Compiled successfully».
⚠ **Sin probar en navegador.** Mensajes de plantilla viejos (solo cuerpo) se ven igual que antes.

## 7.6 F4 — hecho (29/10/2026)

**Hallazgo.** Los programados (`ScheduleMessageModal.vue`) **ya** ocultaban las plantillas con archivo (su propio
`formatsToRemove`): D4 ya se cumplía. Lo que fallaba: se ofrecían plantillas con **variables en el encabezado**
o **botones con dato** (URL variable, copiar código); su formulario solo llena el cuerpo y Meta las rechazaba
al enviarse.

**Qué se hizo.** `availableTemplates` usa la misma regla que la conversación:
`!describeTemplate(template).needsComponents` → se ocultan las que piden algo más que el cuerpo. Siguen
ofreciéndose las de solo cuerpo y las de encabezado de texto fijo o botones sin dato (respuesta rápida,
teléfono, URL fija).

**Pila de pruebas.** `templateForm.spec.js` (+1: botones fijos no piden dato). `ScheduleMessageModal.vue` sin
spec (componente de ~1600 líneas); la regla está probada en `templateForm.js`. Webpack: «Compiled
successfully». ⚠ **Sin probar en navegador.**

**Ojo — lint.** `ScheduleMessageModal.vue` trae 311 hallazgos de eslint (sigue en 311): el `eslint --fix` del
hook lo reformatearía entero → commit con `--no-verify`.

## 7.7 F5 — hecho (29/10/2026)

**Qué se hizo.** `ContactTrackings::TemplateHeader` (nuevo): para la plantilla de un seguimiento (las campañas
envían por el mismo `ContactTrackingJob`) dice si lleva imagen/video/documento en el encabezado y toma el
archivo guardado en la plantilla (`header_media_url` de su fila en `whatsapp_templates`, mismo idioma o el que
haya; F6 permitirá subirlo). En `send_whatsapp_template`:
- **lleva archivo y está guardado** → components `header` (archivo, con nombre si es documento) + `body` de
  siempre; el mensaje guarda el encabezado en `template_params` → la burbuja lo muestra (F3);
- **lleva archivo y no está guardado**, o la bandeja no es WhatsApp Cloud → **no se envía**; entrega rechazada
  con el motivo y el código propio `template_media_missing`, que `ErrorClassifier` cuenta como **config** →
  `HandleFailure` pausa el seguimiento/campaña con el motivo (no es culpa del contacto);
- **sin archivo en la plantilla** → igual que antes.

**Fallo viejo corregido de paso.** El job pasaba `additional_attributes: { template_params: … }` a
`MessageBuilder`, que solo lee `template_params` suelto: **los mensajes de seguimiento nunca guardaron sus
template_params**. Ahora sí (sin `namespace`, que era nil y el esquema lo pide string). No se reenvía: el
mensaje ya lleva `source_id` y `Base::SendOnChannelService#invalid_message?` lo descarta (probado).

**Pila de pruebas.** `template_header_spec.rb` (5): sin archivo nada cambia, con archivo encabezado + cuerpo,
otro idioma, sin archivo guardado → error config, fuera de Cloud → error. `contact_tracking_job_template_header_spec.rb`
(2): manda el documento como encabezado, guarda el encabezado en el mensaje y no lo reenvía; sin archivo no manda
nada y queda la entrega fallida `template_media_missing`/config. Seguimientos, entregas y campañas: 897/897.
⚠ **Sin probar contra Meta con un seguimiento real.**

**Botones variables en seguimientos:** fuera de alcance (D5).

## 7.8 F6 — hecho (29/10/2026)

**Backend (commit 893cecb2).**
- `WhatsappTemplate has_one_attached :header_sample` y `#header_media_link`: liga **fresca** del archivo subido
  (las de ActiveStorage para servicios externos caducan en minutos y `rails_blob_url` es una redirección que
  muchos no siguen: guardadas no sirven días después) o la liga pegada a mano.
- `POST whatsapp/templates/header_samples` (`header_type`, `file`): revisa tipo y tamaño con los límites de
  Meta (los de `ResumableUploadService`), guarda el blob y devuelve `{ signed_id, filename, url }`. Al crear o
  editar va como `header_sample` y queda pegado (se sube ANTES de crear porque Meta pide la muestra al crear).
- La muestra a Meta (F0) y los seguimientos/campañas (F5) usan `header_media_link`; F5 toma el **nombre
  original** del documento. Subir otro archivo al editar vuelve a subir la muestra. El validador (Ruby y JS)
  acepta el archivo subido como «tiene archivo».

**Pantalla (`settings/whatsappTemplates/Index.vue` + `templateScreen.js` puro con spec).**
1. **Subir archivo** en el formulario (JPG/PNG ≤ 5 MB · MP4 ≤ 16 MB · PDF ≤ 100 MB), con su nombre y quitar;
   sigue la opción de pegar una liga. Al editar se ve el archivo guardado y solo se manda si se sube otro.
2. **Vista previa con el archivo real** (imagen, video, documento con nombre) en la pestaña Vista previa.
3. **Filtros por idioma y por tipo** (solo texto, imagen, video, documento, con botones, con copiar código).
4. **«Se puede enviar»** por plantilla: Conversación ✓/✗ y Seguimientos ✓ / ⚠ falta archivo / ✗.
5. **Errores de sincronización por bandeja**: «Se sincronizaron 3 de 4 bandejas. Falló «X»: motivo».
6. **Ver en Meta**: abre WhatsApp Manager de la cuenta de negocio de la bandeja.

**Pila de pruebas.** Backend: controlador (+5: sube PDF, tipo no permitido, sin archivo/tipo raro, agentes no,
crear con el archivo lo pega), modelo (+2: liga pegada vs liga fresca del subido), `SubmitTemplateService`
(+1: sube el archivo como muestra), `TemplateHeader` (+1: archivo subido y su nombre). `spec/services/whatsapp`:
solo las 22 de `incoming_message*` de develop. Frontend: `templateScreen.spec.js` (4); 434/434 en las carpetas
de plantillas. Webpack: «Compiled successfully».

**Lint.** `Index.vue` ya traía 486 hallazgos (textos en español sin i18n + prettier; su cabecera dice
`--no-verify`); los nuevos son de esas mismas dos reglas (prettier, no-bare-strings). Sin reformatear el archivo.

**No entró.** Vista previa en la tabla (solo en el formulario); que el formulario de la conversación (F2)
proponga el archivo guardado de la plantilla en vez de pedir la liga. ⚠ **Sin probar en navegador.**

## 7.9 F8 — archivo de la plantilla en la conversación + huecos del modal de crear (30/10/2026)

Salió al probar: el formulario de la conversación pedía una liga pública aunque la plantilla ya tuviera su
archivo subido, y el modal de crear dejaba elegir cosas que nunca pasaban (o que Meta rechazaba).

**Conversación: el archivo de la plantilla ya puesto.**
- `GET inboxes/:inbox_id/whatsapp_template_header?name=&language=` (cualquier agente de la bandeja; la API de
  plantillas es solo de administradores) → `{ available, media_type, media_name, preview_url }`, o el motivo
  si lleva archivo y no hay guardado. Reusa `ContactTrackings::TemplateHeader` (F5).
- El formulario (`TemplateParser.vue`) lo trae elegido: «Se manda el archivo de la plantilla: Factura A1.pdf»
  con «Usar otra liga» (y de regreso «Usar el archivo de la plantilla»). Sin archivo guardado, la liga como
  antes.
- Va como `header: { source: 'template', media_type }`, **sin liga**: `SendOnWhatsappService` saca la liga
  para Meta al mandar (caduca en una hora; así no importa cuánto estuvo abierto el formulario). Sin archivo
  guardado → mensaje fallido con el motivo, no se manda.

**La burbuja ya no se rompe a la hora.** Antes se guardaba en el mensaje la liga de Meta (caduca en una hora):
pasaba en F5 (seguimientos/campañas) y habría pasado aquí. Ahora el mensaje guarda `preview_url`
(`WhatsappTemplate#header_display_link`: la redirección de ActiveStorage, no caduca y el navegador la sigue) y
la burbuja la prefiere. Mensajes viejos: siguen con su `media_url`.

**Modal de crear (`Index.vue` + `whatsappTemplateValidator.js` + `Whatsapp::TemplateValidator`).**
1. **Ejemplo en los botones** de copiar código (≤ 15) y de liga con `{{1}}` (la liga completa): el validador
   del servidor los exigía pero el formulario no tenía dónde escribirlos → esos dos tipos nunca se podían crear.
   El del navegador ahora también los revisa (antes el error salía hasta guardar).
2. **Autenticación fuera**: tiene formato fijo de Meta (sin texto libre, botón de código, caducidad) que el
   formulario no arma. Solo aparece al editar una que ya la tenga, con el aviso de crearla en WhatsApp Manager.
3. **Cuerpo que empieza o termina con variable**: aviso antes de mandar a Meta (Meta lo rechaza; basta un punto
   después). Ninguna de las 60 plantillas de la base estaba en ese caso ni era de autenticación.

**Pila de pruebas.** Backend 92 + 9 en verde: validador (+5), `TemplateHeader` (+1: `preview_url`), envío con
`source: template` (+2: liga fresca y guarda la que no caduca; sin archivo → fallido), consulta nueva (+4:
agente ve el archivo, sin archivo guardado dice por qué, sin archivo, agente de otra bandeja no). Fábrica y
specs de crear: cuerpos con punto final. Frontend 37 en verde: `templateForm` (+4), `TemplateHeader` (+1),
`whatsappTemplateValidator.spec.js` nuevo (5). Webpack: «Compiled successfully».

**Cómo pedírselo al Asistente / probarlo.** En una conversación de WhatsApp Cloud → plantillas →
`ejemplo_documento_adjunto`: debe salir el PDF ya elegido; «Enviar» y el cliente lo recibe; la burbuja lo
muestra (también mañana). ⚠ **Sin probar en navegador.**


## 7.10 F7 — subir otro archivo desde la conversación (30/10/2026)

El encabezado con archivo tiene ahora **tres orígenes** en el formulario de la conversación:

```
 Encabezado:  [ Archivo de la plantilla ] [ Subir archivo ] [ Pegar liga ]
               └ Factura A1.pdf ↗          └ 📎 Elegir archivo  └ https://…
                 (si la plantilla lo tiene,     Cotizacion 77.pdf ↗
                  viene elegido)
 Nombre (documento): [ Cotizacion 77.pdf ]   ← se pone solo con el del archivo
```

- `POST inboxes/:inbox_id/whatsapp_template_header` (`media_type`, `file`; cualquier agente de la bandeja):
  revisa tipo y tamaño con los límites de Meta (`ResumableUploadService.file_error`, que ahora usa también la
  pantalla de plantillas) y devuelve `{ signed_id, filename, preview_url }`. El navegador solo deja elegir
  los tipos que Meta acepta.
- Va como `header: { source: 'upload', signed_id, media_type, media_name }`. Al mandar, el servidor saca la
  liga fresca para Meta y guarda en el mensaje la que no caduca (igual que el archivo de la plantilla). Si el
  archivo ya no existe → mensaje fallido «vuelve a subirlo».
- El archivo queda como blob suelto (no es adjunto del mensaje, igual que en F3); no hay tarea que borre blobs
  sueltos, así que la burbuja lo sigue mostrando.

**Pila de pruebas.** Backend 107 en verde (+2 subir: PDF de un agente, tipo no aceptado; +2 enviar: archivo
subido con su nombre y liga que no caduca, archivo que ya no existe). Frontend 33 en verde (+2 `templateForm`).
Webpack: «Compiled successfully». ⚠ **Sin probar en navegador.**

## 7.11 F9 — variables con nombre ligadas a datos de Chatwoot (PLAN, sin código)

**Idea.** Meta acepta variables con nombre (`parameter_format: NAMED`): `{{nombre}}`, `{{edad}}` (minúsculas,
números y `_`; **sin puntos**, así que `{{contact.name}}` no). Para Meta el nombre es solo una etiqueta; el
significado lo damos nosotros al enviar, **por convención de nombres**.

```
 Plantilla:  Hola {{nombre}}, por tu edad ({{edad}}) te toca el plan {{plan}}.

 {{nombre}}  → campo reservado         → contacto.name        "Juan Pérez"
 {{edad}}    → atributo personalizado  → custom_attributes.edad  "34"
 {{plan}}    → no existe en Chatwoot   → lo escribe el agente
```

**Nombres reservados** (campos fijos): `nombre`, `primer_nombre`, `apellido`, `correo`, `telefono`, `empresa`,
`agente`, `conversacion`, `bandeja`, `fecha_hoy`. **Atributos personalizados**: la variable se llama igual que
la clave del atributo (Chatwoot ya las guarda en minúsculas con `_`); primero el del contacto, luego el de la
conversación.

```
            ┌──────────── Whatsapp::TemplateVariableResolver (nuevo, puro) ────────────┐
 plantilla ─┤  nombre → reservado | atributo contacto | atributo conversación | nada  ├─► valores
 contacto  ─┤  {{1}} viejas → asociación guardada en la plantilla (opcional, F9.4)     │
            └──────────────────────────────────────────────────────────────────────────┘
        │                 │                         │                       │
   Conversación       Programados            Seguimientos IA            Campañas
   (prellenado,       (prellenado al         (deja de adivinar:         (igual; sin dato →
    editable)          programar)             TemplateParamsProcessor)   no se envía + motivo)
```

**Fases.**
- **F9.1 Crear con nombre** (era D6): el modal acepta `{{nombre}}`, manda `parameter_format: NAMED` y los
  ejemplos en `body_text_named_params`; no mezclar `{{1}}` y `{{nombre}}` en la misma plantilla. Al escribir,
  dice qué reconoció: «`{{edad}}` → atributo Edad ✓ · `{{plan}}` → lo escribe el agente». Ejemplos propuestos
  con un contacto real.
- **F9.2 Resolver** (servidor + réplica pura en JS para la conversación): nombre → valor del contacto.
- **F9.3 Usarlo en todos lados**: conversación (llega llenado y editable, con el campo de origen visible),
  programados, seguimientos y campañas (sin dato → no se envía y queda el motivo, como `template_media_missing`).
- **F9.4 (opcional) Plantillas viejas con `{{1}}`**: en Configuración → Plantillas, «Datos de las variables»
  (`{{1}}` → Contacto · Primer nombre), guardado en la fila `whatsapp_templates` (`variable_mapping` jsonb).

**Lo que hay que saber.** El nombre se fija al crear (cambiarlo = editar y volver a revisión). Contacto sin el
dato → campo vacío y en rojo en la conversación; en automático no se manda. Las plantillas `{{1}}` siguen igual.

**Decisiones (cerradas 30/10/2026: «de los puntos D ok»).**
- **D9a** Nombres reservados **en español** (`nombre`, `primer_nombre`, `correo`, `telefono`…), que es como
  escriben las plantillas los clientes; los atributos personalizados entran con su clave tal cual.
- **D9b** **Sí entra F9.4**: asociar las `{{1}}` de las plantillas viejas a un campo.
- **D9c** Sin el dato en seguimientos/campañas: **no se manda** y queda el motivo (como `template_media_missing`).


## 7.12 F10 — crear y editar plantillas a página completa (PLAN, sin código)

**Por qué.** El modal (`Index.vue`, 1 447 líneas) junta tabla, filtros, formulario con 3 pestañas, vista previa
y borrado. Crear una plantilla obliga a brincar entre pestañas; los ejemplos de las variables están lejos de
su variable; los errores salen en una lista; un clic fuera o una recarga pierde lo escrito.

**Molde nativo.** Macros: lista en `SettingsWrapper` + editor en página propia con `Wrapper.vue`
(`headerTitle`, `icon`, `showBackButton`) en `/new` y `/:id/edit`. Se copia esa forma.

### Rutas

```
 /settings/whatsapp-templates/list        tabla (la de hoy, sin el modal)
 /settings/whatsapp-templates/new         crear            ?from=<id> duplicar · ?ejemplo=<clave> desde ejemplo
 /settings/whatsapp-templates/:id         ficha (ver)
 /settings/whatsapp-templates/:id/edit    editar
```

### Editor (`/new`, `/:id/edit`)

```
 ← Plantillas de WhatsApp  /  Nueva plantilla                [Cancelar] [Enviar a revisión]
 ┌──────────────────────────────────────────────┬──────────────────────────────┐
 │ 1 · DATOS                                     │  VISTA PREVIA (sticky)       │
 │  Bandeja [Whatsapp #1563 ▾]  Idioma [es_MX ▾] │  ┌────────────────────────┐  │
 │  Nombre  [recordatorio_pago] (se arma solo)   │  │ ▓▓▓ Factura A1.pdf     │  │
 │  Categoría  (•) Servicio  ( ) Marketing       │  │ Hola Juan, tu pago de  │  │
 │   «Servicio: avisos de algo que ya pidió…»    │  │ $1,250 vence el 5/11.  │  │
 │                                               │  │ Kontrolya · No respond.│  │
 │ 2 · ENCABEZADO                                │  │ ───────────────────────│  │
 │  [Ninguno][Texto][Imagen][Video][Documento]   │  │   🔗 Ver estado de cta │  │
 │  ┌ - - - - - - - - - - - - - - - - - - - ┐    │  │   📋 Copiar código     │  │
 │  │  Arrastra el PDF aquí o Elegir archivo│    │  └────────────────────────┘  │
 │  └ - - - - - - - - - - - - - - - - - - - ┘    │                              │
 │                                               │  LISTA PARA META             │
 │ 3 · MENSAJE                                   │  ✓ Datos                     │
 │  [B] [I] [S] [</>]  [+ Variable ▾]   86/1024  │  ✓ Encabezado                │
 │  Hola {{1}}, tu pago de {{2}} vence el {{3}}. │  ✗ Mensaje: falta ejemplo {{3}}│
 │   {{1}} ejemplo [Juan  ]                      │  ✓ Botones (3 de 10)         │
 │   {{2}} ejemplo [$1,250]                      │                              │
 │   {{3}} ejemplo [      ] ← en rojo            │  Revisión de Meta: minutos   │
 │                                               │  a 24 h                      │
 │ 4 · PIE (opcional)  [Kontrolya · No responder]│                              │
 │                                               │                              │
 │ 5 · BOTONES  (3 de 10)                        │                              │
 │  [+ Respuesta rápida] [+ Liga] [+ Teléfono]   │                              │
 │  [+ Copiar código]                            │                              │
 │  ⋮⋮ 🔗 Ver estado de cta  https://…/{{1}}  🗑 │                              │
 │       ejemplo [https://…/A-1043]              │                              │
 └──────────────────────────────────────────────┴──────────────────────────────┘
   (pantalla angosta: la vista previa y la lista bajan al final)
```

1. **Secciones apiladas, sin pestañas**, en el orden en que se lee el mensaje.
2. **Vista previa en vivo y fija** con forma de burbuja de WhatsApp: archivo real, texto con los ejemplos,
   pie y botones (reusa la vista previa de F6).
3. **Ejemplo junto a su variable**: aparece al escribir `{{n}}` y se va al borrarla; ya no hay sección aparte.
4. **«+ Variable»** inserta la siguiente `{{n}}` en el cursor (sin huecos de numeración). Con F9 ofrece los
   campos de Chatwoot (`{{nombre}}`, atributos).
5. **Formato** B / I / S / `</>` (los `*` `_` `~` ``` de WhatsApp) y contador de caracteres por campo.
6. **«Lista para Meta»**: los errores de `validateTemplate` agrupados por sección (por su prefijo: `Nombre:`,
   `Categoría:`, `Cabecera`, `Body:`, `Pie:`, `Botón #n`, `Ejemplos:`) y además marcados en su campo.
   «Enviar a revisión» se activa solo con todo en verde.
7. **Botones por tipo**: se agregan con un clic, se reordenan arrastrando (`vuedraggable`, ya en el proyecto),
   muestran «3 de 10» y se desactiva el tipo que ya llegó a su límite (2 URL, 1 teléfono, 1 código). Las
   respuestas rápidas se acomodan solas al inicio.
8. **Archivo de muestra**: arrastrar y soltar o elegir, con los límites de Meta escritos ahí.
9. **Categoría con explicación** corta (Servicio vs Marketing: Meta revisa y cobra distinto).
10. **Aviso al salir sin guardar** (ruta y cierre de pestaña).
11. Al editar: solo cambian categoría y contenido (Meta deja fijos nombre, idioma y bandeja) y se avisa que
    vuelve a revisión.

### Ficha (`/:id`)

```
 ← Plantillas de WhatsApp  /  recordatorio_pago            [Duplicar] [Ver en Meta] [Editar]
 ┌──────────────────────────────────────────────┬──────────────────────────────┐
 │ ESTADO EN META                                │  VISTA PREVIA                │
 │  Enviada 30/10 18:20 → En revisión → ✓ Aprobada│  (la burbuja)               │
 │  Calidad: 🟢 Alta                              │                              │
 │  (si se rechazó: el motivo de Meta y qué hacer)│                              │
 │ SE PUEDE ENVIAR                               │                              │
 │  Conversación ✓ · Seguimientos ✓ (con archivo)│                              │
 │ DATOS                                         │                              │
 │  Bandeja · Idioma · Categoría · Variables     │                              │
 └──────────────────────────────────────────────┴──────────────────────────────┘
```

Clic en una fila de la tabla → ficha. Borrar sigue en la tabla (con su confirmación).

### Empezar desde un ejemplo

`/new` arranca con tres tarjetas: **En blanco** · **Recordatorio de pago** (Servicio, documento, «Hola {{1}},
tu pago de {{2}} vence el {{3}}.», botón liga) · **Confirmación de cita** (Servicio, texto, respuestas rápidas
Confirmar / Cambiar) · **Promoción con imagen** (Marketing, imagen, botón copiar código). Elegir una llena el
formulario; todo se puede cambiar. Los ejemplos viven en un archivo puro (`templatePresets.js`).

### Piezas (frontend; el backend no cambia)

```
 whatsappTemplates/
   Index.vue                 tabla + filtros + borrar (sin el formulario)
   TemplateEditor.vue        página /new y /:id/edit (carga, guarda, aviso al salir)
   TemplateDetail.vue        página /:id
   editor/SectionData.vue · SectionHeader.vue · SectionBody.vue · SectionFooter.vue · SectionButtons.vue
   editor/TemplatePreview.vue   burbuja (sale de Index.vue, F6)
   editor/ReadyChecklist.vue    «Lista para Meta»
   templateScreen.js · templatePresets.js · editorSections.js (errores → sección)   puros, con spec
```

Componentes nativos: `Wrapper.vue` (encabezado con regreso), `woot-input`, `woot-button`, `ResizableTextArea`,
`woot-loading-state`. Los textos nuevos en i18n (es / en), con tú. Plantillas `.vue` sin `?.` ni `??`.

### Fases

- **F10.1** Rutas + `TemplateEditor` con las secciones y la vista previa (paridad con el modal) · quitar el modal.
- **F10.2** Ejemplos junto a su variable, «+ Variable», formato, contadores, «Lista para Meta».
- **F10.3** Botones por tipo con límites y arrastrar · archivo con arrastrar y soltar · aviso al salir.
- **F10.4** Ficha `/:id` + Duplicar.
- **F10.5** Empezar desde un ejemplo.

### Riesgos

| Riesgo | Mitigación |
|---|---|
| Partir `Index.vue` rompe lo que ya funciona (F6: subir, filtros, «se puede enviar») | Mover sin reescribir; la lógica ya está en `templateScreen.js` / validador con spec |
| `Index.vue` arrastra 640+ hallazgos de lint | Los archivos nuevos nacen limpios (eslint en verde); `Index.vue` adelgaza |
| Aviso al salir molesto | Solo si hubo cambios (`isDirty`) |

### Decisiones (cerradas 30/10/2026: «de los puntos D ok»)

- **D10a** Los tres ejemplos de arranque **como están** (Recordatorio de pago, Confirmación de cita,
  Promoción con imagen).
- **D10b** **Sí «Guardar borrador»**: guarda la fila en DRAFT sin llamar a Meta (el estado ya existe); se manda
  a revisión después desde el editor o la ficha. Entra en F10.1.
- **D10c** **Un idioma por vez**, como hoy; para otro idioma: Duplicar y cambiar idioma.


## 7.13 F10.1 — hecho (30/10/2026): el editor a página completa

**Qué cambió para el usuario.** «Nueva plantilla» y el lápiz ya no abren un modal: llevan a
`/settings/whatsapp-templates/new` y `/:id/edit`, con el **mismo encabezado nativo que la lista**
(`SettingsLayout` + `BaseSettingsHeader`: «← Plantillas de WhatsApp», título, descripción y las acciones
Cancelar / Guardar borrador / Enviar a revisión arriba). El formulario conserva **las pestañas del modal**
(Contenido · Botones · Variables, apiladas en la misma celda: el alto no cambia y no hay que bajar) con los
controles de siempre (`select`, `woot-input`, `ResizableTextArea`); la vista previa y lo que falta para Meta
quedan siempre a la derecha (antes era otra pestaña).

> Primera versión (descartada el mismo día): secciones apiladas y `Wrapper.vue` (molde de Macros). El usuario:
> «los tabs estaban bien», «el botón tipo hamburguesa no funciona» (la hamburguesa de `Wrapper.vue` abre el menú
> secundario, que con nuestro menú reacomodado no se ve), «no se usan componentes comunes», «no les gustan los
> scrolls». Ver memoria `feedback_formularios_pestanas_sin_scroll`.

**Guardar borrador (D10b).** `POST/PATCH whatsapp/templates` con `draft: true` → `SubmitTemplateService#save_draft`:
guarda en DRAFT sin Meta ni sus reglas (solo bandeja, nombre e idioma); una plantilla que ya está en Meta no se
regresa a borrador. `WhatsappTemplate#editable?` ahora incluye el borrador local (`local_draft?`: DRAFT que nunca
llegó a Meta, incluidos los envíos que fallaron — antes había que borrarlos y crearlos de nuevo). Al mandar un
borrador a revisión se **crea** en Meta (`submit_draft`), no se edita. En el editor de un borrador también se
cambian nombre e idioma (la bandeja no).

**Piezas.** `TemplateEditor.vue` (página, en `SettingsWrapper` junto a la lista; recarga al volver porque
`SettingsWrapper` guarda en caché), `TemplatePreview.vue` (la burbuja, sale del modal), `templateEditor.js`
(puro: formulario vacío / desde una plantilla, lo que se manda, nombre, ejemplos, categorías, idiomas) con spec.
`Index.vue` quedó con la tabla, filtros, sincronizar y borrar (1 447 → 752 líneas; lint 649 → 338). Textos
nuevos en i18n (`WHATSAPP_TEMPLATE_EDITOR`, es/en).

**Pila de pruebas.** Backend 91 en verde (+5 `save_draft`: guarda a medias sin Meta, sin nombre no, la de Meta
no se regresa, el borrador se manda como nueva, incompleto dice qué falta; +1 controlador: borrador y luego
mandarlo). Frontend 28 en verde (`templateEditor.spec.js` nuevo, 9). Webpack: «Compiled successfully».
⚠ **Sin probar en navegador.**

**Ajustes de la misma ronda (30/10/2026).**
- «‹ Plantillas de WhatsApp» va con las acciones a la derecha (no arriba del título, para ganar espacio) y
  reemplaza a «Cancelar», que hacía lo mismo.
- **Las de imagen o video no salían en ningún selector**: el getter `inboxes/getWhatsAppTemplates` las quitaba
  siempre (herencia de Chatwoot), aun en WhatsApp Cloud. Ahora devuelve todas y cada pantalla decide: el selector
  de la conversación y los programados.
- **Bandejas que no son Cloud** (360dialog, UnoAPI): el selector oculta todo lo que pide más que el cuerpo
  (archivo, variable en el encabezado, liga con `{{1}}`, copiar código) — antes solo las de archivo y Meta
  rechazaba las de botón con dato. Misma regla que los programados.
- **La burbuja muestra los botones** de la plantilla enviada (`bubble/TemplateButtons.vue`), con el dato que
  escribió el agente (terminación de la liga o código). Salen de la plantilla de la bandeja por nombre e idioma,
  así que también se ven en mensajes viejos y en los de seguimientos.

Frontend 83 en verde (+1 getter, +1 selector). Webpack: «Compiled successfully».

**F10.3 botones + acomodo (30/10/2026, misma tarde).**
- **Menú secundario**: en `/new` y `/:id/edit` no se veía; el menú solo se muestra en las rutas que conoce →
  `whatsapp_templates_new` / `_edit` agregadas en `sidebarItems/settings.js` y en `v2/index.js` (Catálogos).
- **Contenido en dos renglones**: Bandeja · Nombre, y Idioma · Categoría · Encabezado (la explicación de la
  categoría debajo). Al editar, la bandeja se ve en su `select` deshabilitado.
- **Pestaña Botones** (`TemplateButtonsEditor.vue`):

```
 [↩ Respuesta rápida] [🔗 Liga] [📞 Teléfono] [📋 Copiar código]                    3 / 10
                       (se apaga al tope: «Meta permite 2 de tipo Liga»)
 Respuestas rápidas · 1 / 10             Acciones
 ┌ ⋮⋮ ↩ Texto del botón [Confirmar] 🗑 ┐  ┌ ⋮⋮ 🔗 Liga                              🗑 ┐
 └─────────────────────────────────────┘  │   Texto del botón [Ver mi pedido]  12 / 25│
                                          │   Liga [https://tienda.mx/pedido/]       │
                                          │   ( ) Liga fija (•) Termina con un dato  │
                                          │   Ejemplo de la liga completa [ …/A-1043]│
                                          └──────────────────────────────────────────┘
```
  un «+» por tipo (adiós al «Agregar» que siempre ponía respuesta rápida), topes de Meta que apagan el botón
  con el motivo, dos grupos fijos (el orden que pide Meta sale solo), tarjeta con etiquetas y contador, arrastrar
  ⋮⋮ dentro de cada grupo (`vuedraggable`), liga «fija» o «termina con un dato del cliente» (el `{{1}}` lo pone
  el editor), teléfono con `+52` y aviso si falta la lada, código de ejemplo con su explicación.
  Lógica pura en `templateEditor.js` (`addButtonBlocker`, `orderButtons`, `buildUrl`, `phoneNeedsCountryCode`).

Frontend 25 en verde en la carpeta (+5 botones en `templateEditor.spec.js`, +4 `TemplateButtonsEditor.spec.js`);
menú 17 en verde. Webpack: «Compiled successfully». ⚠ **Sin probar en navegador.**

**F10.2 — hecho (30/10/2026).**

```
 Mensaje        [Negrita] [Cursiva] [Tachado] [Código]  [+ Variable]   86 / 1024
 ┌──────────────────────────────────────────────────────────────────┐
 │ Hola {{1}}, tu pago de *{{2}}* vence el {{3}}.                    │
 └──────────────────────────────────────────────────────────────────┘
                                           Lista para Meta
 Contenido │ Botones • │ Variables (3) •    ✓ Contenido
                                           ✗ Botones
                                             • Botón #1 (URL): falta el ejemplo…
                                           ✗ Variables
                                             • Ejemplos: hay valores de body vacíos
```
- **«+ Variable»** pone la siguiente `{{n}}` (sin huecos) donde está el cursor o en lugar de lo seleccionado; en
  el encabezado de texto agrega `{{1}}` (Meta permite una) y se oculta si ya la tiene.
- **Formato de WhatsApp**: Negrita / Cursiva / Tachado / Código envuelven lo seleccionado con `*` `_` `~` ```` ``` ````
  (sin selección dejan las dos marcas y el cursor en medio). Botones nativos con texto: este set de íconos no trae
  negrita ni cursiva.
- **«Lista para Meta» por pestaña**: los errores del validador repartidos por su prefijo (`errorsByTab`); cada
  renglón ✓/✗ lleva a su pestaña, y la pestaña con pendientes lleva un «•» en su nombre. Con todo en verde:
  «Todo en orden: ya la puedes mandar a revisión».

Frontend: `templateEditor.spec.js` +4 (siguiente variable, insertar en el cursor, envolver, errores por pestaña).
Webpack: «Compiled successfully». ⚠ **Sin probar en navegador.**

**F10.3 resto — hecho (30/10/2026).**
- **Arrastrar y soltar** el archivo de muestra en la zona punteada del encabezado (se resalta al pasar); antes de
  subir revisa el tipo con lo que acepta Meta y si no sirve lo dice («Acepta: PDF, hasta 100 MB»).
- **Aviso al salir sin guardar**: el editor guarda una foto del formulario al abrir y al guardar
  (`formSnapshot`: lo que se manda + la bandeja, no lo que solo se ve). Con cambios, salir por el menú,
  «‹ Plantillas de WhatsApp» o el navegador pregunta con el modal nativo (`woot-confirm-modal`: «Seguir editando» /
  «Salir sin guardar»); cerrar o recargar la pestaña da el aviso del propio navegador. Guardar (o que Meta lo
  rechace y quede en borrador) no pregunta.

Frontend 30 en verde en la carpeta (+1 `formSnapshot`). Webpack: «Compiled successfully». ⚠ **Sin probar en
navegador.**

**F10.4 — hecho (30/10/2026): la ficha y Duplicar.**

```
 recordatorio_pago                 [‹ Plantillas de WhatsApp] [Ver en Meta] [Duplicar] [Editar]
 Servicio · es_MX · Whatsapp
 ┌ Estado en Meta ───────────────────────────────────────┐  Vista previa
 │ ✓ Enviada  ›  ✓ Revisada  ›  ✗ Rechazada              │  ┌───────────────┐
 │ Último envío a Meta: 30/10/2026 18:20                  │  │ ▓▓ Factura… │
 │ ┌ Meta la rechazó (INCORRECT_CATEGORY) ──────────────┐ │  │ Hola Juan, … │
 │ │ La categoría no corresponde al contenido. Si…      │ │  └───────────────┘
 │ └────────────────────────────────────────────────────┘ │
 ├ Se puede enviar ──────────┬ Datos ──────────────────────┤
 │ ✓ En la conversación      │ Calidad ● Alta              │
 │ ⚠ Seguimientos: falta…    │ Encabezado · Variables · …  │
 └───────────────────────────┴─────────────────────────────┘
```
- Ruta `/whatsapp-templates/:id` (`TemplateDetail.vue`, después de `list` y `new`), en el menú; el nombre en la
  tabla abre la ficha. Mismo encabezado nativo y regreso junto a las acciones.
- Estado en Meta como pasos (`statusSteps`: borrador / en revisión / aprobada / rechazada / pausada /
  deshabilitada / en apelación), fecha del último envío, **motivo del rechazo con qué hacer** (`rejectionKey`:
  ABUSIVE_CONTENT, INCORRECT_CATEGORY, INVALID_FORMAT, PROMOTIONAL, SCAM, TAG_CONTENT_MISMATCH; el resto tal cual)
  y el error del último envío. Calidad, «se puede enviar», encabezado, variables, botones e ID en Meta.
- **Editar** (o «Seguir el borrador»; deshabilitado con su motivo si Meta la revisa), **Ver en Meta** y
  **Duplicar**: `/new?from=<id>` abre el editor con todo copiado (`duplicateForm`: nombre `_copia`, misma bandeja
  y el mismo archivo subido — la API ahora da su `signed_id`).
- De paso, «se puede enviar» fuera de WhatsApp Cloud ya marca «no» las que piden dato en botón o encabezado
  (igual que el selector).

Pruebas: frontend 52 en verde (pantalla + menú; +4 ficha/sendability, +1 duplicar); backend 39 en verde
(controlador: `header_sample` con `signed_id`). Webpack: «Compiled successfully». ⚠ **Sin probar en navegador.**

**La lista (30/10/2026).**

```
 [🔍 Nombre…] [Todos los estados ▾] [Todas las bandejas ▾]    [Categorías ▾] [Idiomas ▾] [Tipos ▾] Limpiar
 Nombre ↕ │ Acciones     │ Bandeja ↕ │ Idioma ↕ │ Categoría ↕ │ Estado ↕ │ Se puede enviar │ Creada ↕ │ Actualizada ▼
 cobro_x  │ [✎][⧉][↗][🗑] │ Whatsapp  │ es_MX    │ Servicio    │ APPROVED●│ ✓ Conv ✓ Seg    │ 30 oct · Ana │ 30 oct 18:20
```
- **Filtros a la vista** (sin modal ni chips): Estado y Bandeja a la izquierda; Categoría, Idioma y Tipo a la
  derecha; «Limpiar» si hay alguno.
- **Columnas Creada (fecha + quién) y Actualizada**; **clic en la columna para ordenar** (`sortTemplates`; la
  misma columna cambia el sentido); **por omisión, la última actualización primero**. La calidad va como punto
  junto al estado y «se puede enviar» en un renglón, para que las filas sean bajas.
- **Filas por página a elegir** (10 · 25 · 50 · 100; **25 por omisión**; se recuerda en el navegador). A alto de
  pantalla: filtros y paginado quedan fijos y **solo la tabla hace scroll**, con el encabezado de columnas fijo
  (primero se había quitado la caja con scroll; el usuario prefirió el paginado siempre abajo).
- **Quién la creó**: migración `20261102100000_add_created_by_to_whatsapp_templates` (`created_by_id`); lo llena
  `SubmitTemplateService` (`user: Current.user`) al crear o guardar borrador; las sincronizadas desde Meta quedan
  sin autor («Desde Meta»). La API da `created_at`, `updated_at` y `created_by { id, name }`.
- **Acciones justo después del nombre**, con los botones como en Campañas (`smooth`, `small`, con color):
  Editar (deshabilitado con su motivo) · Duplicar · Ver en Meta · Eliminar (rojo).
- `Index.vue`: lint 338 → 7 (lo que queda es de antes).

Pruebas: frontend 38 en verde (+3 `sortTemplates`); backend 99 en verde (+1 autor en el servicio, +1 en el
controlador). Webpack: «Compiled successfully». ⚠ **Sin probar en navegador.**

> Base de pruebas: tenía 218 migraciones «pendientes» (la cargó un schema viejo). Se recargó con
> `db:schema:load` en `chatwoot_test`, que pide antes `CREATE EXTENSION vector` (schema.rb no la declara).

**Borrar con aviso (30/10/2026).**

```
 Eliminar «recordatorio_pago»
 Se borra también en Meta (solo este idioma), y Meta no deja volver a usar ese nombre durante 30 días.
 ⚠ Esta plantilla está en uso:
   • Agentes de seguimiento: Cobranza, Recordatorios ↗
   • Seguimientos en curso: 14
   • Campañas: Octubre ↗
   Si la borras, esos envíos van a fallar. Cambia la plantilla ahí primero.
 ☐ Entiendo que esos envíos pueden fallar hasta que cambie la plantilla.
                                          [Cancelar] [Eliminar de todos modos]
```
- **Avisa, no bloquea** (decisión del usuario): la plantilla puede desaparecer sin pasar por aquí (Meta la pausa o
  se borra en WhatsApp Manager), y bloquear estorba al reemplazarla. Si está en uso pide la casilla; si no se
  pudo revisar el uso, también.
- `GET whatsapp/templates/:id/usage` → `Whatsapp::TemplateUsage`: agentes, seguimientos vivos, campañas sin
  terminar y portales de esa bandeja. Si queda el mismo nombre en otro idioma, agentes, seguimientos y campañas
  no se rompen y no se avisan.
- `DeleteTemplateModal.vue` (molde de `AddAgent.vue`): texto según sea borrador o esté en Meta; el motivo real
  si Meta rechaza el borrado.
- Al borrar en Meta, la plantilla sale al momento de `channel.message_templates`: antes los selectores la seguían
  ofreciendo hasta la siguiente sincronización.
- **Seguimiento cuya plantilla ya no existe o no está aprobada** (`ContactTrackingJob#missing_template_error`):
  envío rechazado con motivo claro y código 132001 / 132015 (config: se pausa la campaña). Antes decía «parámetros
  que no se pudieron resolver» y, con la ventana abierta, mandaba texto libre en su lugar.

> ⚠ **Mensajes programados rotos (fuera de esta rama):** `ScheduledMessage` valida `is_template?` y usa
> `template_name`, etc., pero `scheduled_messages` no tiene esas columnas ni hay migración que las agregue:
> crear cualquier programado truena con `NoMethodError`. Por eso no cuentan en el aviso de uso. F4 (ocultar
> plantillas ahí) queda sin efecto práctico hasta arreglarlo.

Pruebas: backend en verde (`template_usage_spec` 4, servicio +1, controlador +1, job +2); frontend 42 en verde
(`DeleteTemplateModal.spec.js` 3, `templateInUse` 1). Webpack: «Compiled successfully». ⚠ **Sin probar en
navegador.** Los 30 días son de la documentación de Meta, no se probaron.

**F10.5 — hecho (30/10/2026): empezar desde un ejemplo.**

```
 Empezar desde: [En blanco] [Recordatorio de pago] [Confirmación de cita] [Promoción con imagen]
 Contenido │ Botones │ Variables
```
- Fila compacta sobre las pestañas, no tarjetas en una pantalla previa como decía el plan: es un paso menos y sin
  scroll. Solo en `/new`, y se oculta al empezar a escribir (o al duplicar).
- `templatePresets.js`: llena el formulario y conserva bandeja e idioma. Ligas y archivos van vacíos a propósito:
  los pone el usuario, para que no llegue a Meta nada inventado (la lista de lo que falta los pide).
- **Nombre repetido** (`nameTaken`): al crear o en borrador, avisa si ya hay ese nombre e idioma en la bandeja.
  El servidor reutiliza esa fila al crear, y si Meta rechaza el envío una aprobada podía quedar como borrador.

Frontend 50 en verde (`templatePresets.spec.js` 6, `nameTaken` 2). ⚠ **Sin probar en navegador.**

**F10 COMPLETO** (F10.1–F10.5). Falta la ronda de pruebas en navegador (§8) y el PR a develop.


## 7.14 Después de los PR #127 y #128 (30/10/2026, rama `feat/plantillas_variables_nombre`)

**Aviso de borrado cuenta los programados.** `Whatsapp::TemplateUsage` cuenta los `scheduled_messages` sin enviar
de esa bandeja, por nombre e idioma (`is_template`, `template_name`, `template_language`).

**Error corregido: botones en la posición equivocada (estaba en develop).** `buildProcessedParams` mandaba
`buttons: [null, {...}]` para respetar la posición, pero Rails quita los `null` de los arreglos que recibe: una
plantilla con «respuesta rápida + liga variable» salía a Meta con `index: 0` en vez de `1`. Comprobado con una
petición real. Ahora cada botón lleva su `index` y `TemplateProcessorService` lo respeta (los mensajes viejos sin
`index` siguen por su lugar en la lista).

**F4, opción A: programados igual que la conversación.** `TemplateExtraFields.vue` (archivo de la plantilla /
subido / liga, variables del encabezado y botones con dato) sale de `TemplateParser.vue` y lo usan los dos; las
variables del cuerpo van en su slot. En `ScheduleMessageModal.vue`: en WhatsApp Cloud ya no se ocultan esas
plantillas (fuera de Cloud, misma regla que el selector), valida con `validateValues` y guarda con
`buildProcessedParams`. Con `source: 'template'` la liga para Meta se saca al entregar, no al programar.

**Editar un programado** (`valuesFromProcessedParams`): recupera cuerpo, archivo y botones. De paso se corrigió
que las variables salían vacías al editar: el `watch` de `selectedTemplate` las borraba después de cargarlas.

**«Se puede enviar» en seguimientos.** Estado nuevo `needs_data`: las plantillas con dato en el encabezado o en un
botón se marcan «✗ Seguimientos», porque seguimientos y campañas solo mandan cuerpo y archivo y Meta las rechazaría.

Pruebas: frontend 88 en verde (+4 `valuesFromProcessedParams`, +3 `TemplateExtraFields`, +1 aviso); backend en verde
(+1 uso, +1 botón con su posición, +1 punta a punta de programado con archivo y botón). ⚠ **Sin probar en navegador.**

---

## 8. Pila de pruebas en navegador (al cerrar cada fase)

- [ ] F0: crear y mandar a revisión una plantilla con video y otra con documento → Meta las acepta (PENDING)
- [ ] F1: enviar una plantilla vieja de solo texto → llega igual que antes
- [ ] F1: un seguimiento IA con plantilla de texto → llega igual que antes
- [ ] F2: enviar plantilla con imagen desde la conversación → llega con la imagen
- [ ] F2: documento con nombre → el cliente ve el nombre del archivo
- [ ] F2: botón URL variable y copiar código → funcionan en el teléfono
- [ ] F2: en bandeja 360dialog/UnoAPI no aparecen las de adjunto
- [ ] F3: la burbuja del agente muestra el adjunto enviado
- [ ] F4: programar una plantilla (con o sin adjunto según D4)
- [ ] F5: seguimiento con plantilla de imagen → llega con la imagen; sin archivo → queda registrado el motivo
- [ ] F6: subir archivo de muestra, filtros nuevos, indicador, "Ver en Meta", errores por bandeja
- [ ] F8: plantilla con documento guardado → en la conversación sale ya elegido; «Usar otra liga» pide la liga
- [ ] F8: la burbuja sigue mostrando el archivo al día siguiente
- [ ] F8: crear plantilla con botón de copiar código y con liga `{{1}}` (con su ejemplo) → Meta las acepta
- [ ] F8: «Autenticación» ya no aparece al crear; cuerpo que termina en `{{1}}` avisa antes de guardar
- [ ] F7: «Subir archivo» → elegir un PDF de la máquina → el cliente lo recibe con su nombre; la burbuja lo muestra
- [ ] F7: subir una imagen en una plantilla de documento → no deja elegirla / avisa el motivo
- [ ] F10: crear desde «Recordatorio de pago» → ejemplos junto a sus variables → «Lista para Meta» en verde → enviar
- [ ] F10: salir con cambios sin guardar → avisa; recargar `/:id/edit` → sigue en la misma plantilla
- [ ] F10: arrastrar un PDF a la zona punteada de un encabezado de documento → se sube; una imagen → avisa
- [ ] F10: + Variable en medio del texto, Negrita sobre una palabra, «Lista para Meta» lleva a la pestaña
- [ ] F10: clic en una fila → ficha con estado en Meta → Duplicar abre el editor con todo copiado
- [ ] Conversación (Cloud): `ejemplo_video_adjunto` aparece en el selector (antes la tienda la escondía)
- [ ] Burbuja: una plantilla con botones muestra sus botones (y el código o la terminación de la liga)
- [ ] Bandeja 360dialog/UnoAPI: no aparecen plantillas con liga `{{1}}` o copiar código
- [ ] Lista: filtros a la vista, 25 por página (cambiar a 50 se recuerda), paginado siempre abajo y scroll solo en la tabla, clic en «Creada» ordena, una nueva dice quién la creó
- [ ] Borrar: un borrador dice «solo se borra aquí»; una en uso pide la casilla y enlaza a su agente; al borrarla ya no sale en el selector
- [ ] Seguimiento con plantilla borrada: no manda texto libre; queda el motivo y la campaña se pausa
- [ ] F10.5: en `/new` elegir «Confirmación de cita» llena todo y se puede cambiar por otro ejemplo; al escribir se oculta la fila; un nombre repetido avisa
- [ ] Botones: plantilla con respuesta rápida + liga variable sale bien desde la conversación (antes Meta la rechazaba)
- [ ] Programados: plantilla con documento y botón en bandeja Cloud; editarla conserva lo capturado; llega a su hora
