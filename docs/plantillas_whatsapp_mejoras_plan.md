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

**Falta (pide OK).** Mandar a Meta una plantilla de prueba con video y otra con documento desde una bandeja
WhatsApp Cloud real, y ver que queden en revisión (PENDING). Sin eso F0 solo está probado con dobles.

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
