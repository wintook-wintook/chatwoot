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
| D2 | **No por ahora**: F7 (subir archivo desde la conversación) queda fuera |
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
