# Plan — Eventos (confirmaciones, asistencia y campañas)

> Estado: ✅ **E1, E2 y E3 hechos** (2026-10-29, rama `feat/identidad_agente_organizacion_llamadas`, sin commit). E4–E5 pendientes.
> Necesidad del usuario: registrar por contacto los eventos a los que **confirmó** y a los que
> **asistió**, para después hacerles campañas (enviarles el agente IA).

## Decisiones del usuario (2026-10-29)
- Para elegir a quién enviar se usan los **segmentos** (el filtro de contactos que ya existe) y
  las **campañas** que ya existen; nada de una pantalla de audiencias nueva.
- La campaña tiene un apartado **«Evento»** (evento + estado): así se sabe que la campaña es de
  ese evento y se arma su audiencia.

## Por qué no basta con etiquetas o campos del contacto
Un contacto va a muchos eventos y en cada uno tiene un estado (confirmó uno, asistió a otro, no
llegó a un tercero). Con etiquetas o atributos personalizados haría falta uno por evento: a los
pocos meses son decenas, sin fechas ni historial. Por eso el evento y su lista se guardan aparte,
y lo demás (segmentos, campañas, agente) se reusa.

## Cómo está hoy
| Pieza | Qué hay |
|---|---|
| Reuniones (`case_meetings`) | Citas 1 a 1 de un caso, con correos de invitados; sin confirmación ni asistencia por contacto. No sirven para un evento con muchos asistentes. |
| Filtro de contactos / segmentos | Filtra por datos del contacto (campos, etiquetas, ciudad…) y se guarda como segmento (custom view de Chatwoot). |
| Campañas (`tracking_campaigns`) | Audiencia por segmento o etiqueta (lote) o la inscriben las automatizaciones (continua); se les asigna un agente IA. |

## Propuesta

### Los datos
- **`events`** (por cuenta): nombre, tipo (feria, curso, demostración, webinar, otro), inicia /
  termina, lugar o enlace, cupo (opcional), descripción, responsable, estado (borrador / abierto /
  cerrado).
- **`event_attendees`**: evento + contacto (uno por par) con **estado**: `invited` (invitado),
  `confirmed` (confirmó), `attended` (asistió), `no_show` (no asistió), `cancelled` (canceló); las
  fechas de cada paso (`invited_at`, `confirmed_at`, `attended_at`…) y de dónde vino (a mano, CSV,
  agente IA, campaña). Bitácora de cambios.
- Al **cerrar** el evento, los `confirmed` sin asistencia pasan a `no_show` solos.

### Dónde se usa
| Lugar | Qué |
|---|---|
| Menú (Clientes o Campañas) › **Eventos** | Lista con cuántos invitados, confirmados y asistentes; alta del evento. |
| Página del evento | Asistentes con su estado; agregar contactos (buscador, un segmento completo o CSV); **check-in** del día (buscar y marcar «Asistió» en un clic); cerrar el evento; campañas de este evento y sus resultados. |
| Ficha del contacto | Pestaña **Eventos**: su historial (a cuáles fue, cuáles confirmó, a cuáles faltó). |
| **Filtro de contactos** | Condición nueva **«Evento»**: evento (o «cualquiera») + estado (+ desde / hasta). Se combina con las demás y **se guarda como segmento**. |
| **Campaña** | Apartado **«Evento»** (evento + estado): es su audiencia (cruzada con el segmento si se elige uno), la campaña queda marcada como de ese evento y, si es **continua**, inscribe sola a quien llegue a ese estado (p. ej. al marcar «Asistió» le llega el agradecimiento). |
| Agente IA | Puede **confirmar** (el cliente contesta «sí, ahí estaré» → `confirmed`) y cancelar; ve el evento en su contexto. |

### Ejemplos de campaña
- Feria de octubre · **Confirmó pero no asistió** → enviar el material.
- Cualquier curso este año · **Asistió** → ofrecer el siguiente.
- Feria de octubre · **Invitado** (sin confirmar) → recordatorio 2 días antes.

## E1 — Base (hecho)
| Pieza | Dónde |
|---|---|
| Tablas `events` (nombre, tipo, estado borrador/abierto/cerrado, inicio/fin, lugar, enlace, cupo, responsable) y `event_attendees` (estado + fecha de cada paso, origen, quién lo cambió; uno por contacto) | `db/migrate/20261031270000_create_events.rb`, `Event`, `EventAttendee` |
| API (área Campañas) | `events` index/show/create/update/destroy, `close` (confirmados sin check-in → no asistió), `reopen`, `attendees`, `add_attendees`, `update_attendee`, `remove_attendee`, `import` (CSV contacto + estado), `template`, `for_contact` |
| Pantallas | Campañas › **Eventos** (lista con invitados/confirmados/asistentes) · **página del evento** (pestañas por estado, buscar, agregar contacto con estado, check-in «Asistió» en un clic, cambiar estado, quitar, CSV, cerrar/reabrir, editar, eliminar) · pestaña **Eventos** en el contacto |

Specs: `spec/requests/api/v1/accounts/events_spec.rb`, menú v2.
«Agregar desde un segmento» pasa a E2 (con la condición «Evento» en el filtro).

## E2 — Segmentos (hecho)
| Pieza | Dónde |
|---|---|
| Condición **«Evento»** en el filtro de contactos: valor `«<event_id\|any>:<estado\|any>»`, operadores es / no es; se combina con las demás y se guarda como segmento | `lib/filters/filter_keys.yml` (`contacts.event`, data_type `event_status`), `FilterHelper#handle_standard_attributes`, `Contacts::FilterService#event_filter_query` (solo números y estados conocidos llegan al SQL) |
| Opciones en la pantalla del filtro: «Cualquier evento · …» y «<evento> · <estado>» | `contactFilterItems/index.js`, `ContactsAdvancedFilters.vue` (`eventOptions`) |
| **Agregar un segmento** a un evento (con el estado elegido; tope 5,000; solo contactos visibles) | `POST /events/:id/add_segment`, `EventDetail.vue` |

Specs: `spec/services/contacts/filter_service_event_spec.rb`, `events_spec.rb`.
Nota: `filter_service_spec.rb` «last_activity_at 2_days_before» ya fallaba antes (probado con los archivos originales).

## E3 — Campañas (hecho)
| Pieza | Dónde |
|---|---|
| `tracking_campaigns.event_id` + `event_status` (la campaña de un evento) | migración `20261031280000`, `TrackingCampaign`, `Events::CampaignEvent.attributes` (valida evento de la cuenta y estado) |
| Formulario de campaña: apartado **«¿Es de un evento?»** (evento + estado). **Por lote:** la audiencia = segmento/etiqueta **Y** la condición «Evento» (la de E2), la vista previa ya la cuenta; solo con evento también vale. **Continua:** guarda evento y estado | `CampaignForm.vue` (`effectiveFilterPayload`), `contactTrackingBulkAssigns.js`, `BulkAssignService` (`event:`), `TrackingCampaignContinuousParams` |
| **Inscripción automática:** al cambiar de estado un asistente entra a las campañas continuas **en curso** de ese evento y estado (origen `event` en la inscripción) | `EventAttendee` after_commit → `Events::CampaignEnrollJob` → `TrackingCampaigns::Enroll` |
| La lista de campañas muestra «Evento: X · estado»; la página del evento, sus campañas | `Campaigns.vue`, `EventsController#render_event`, `EventDetail.vue` |

Specs: `spec/jobs/events/campaign_enroll_job_spec.rb`, `events_spec.rb`, `CampaignForm.spec.js`; se actualizó `action_service_add_to_tracking_campaign_spec.rb` (la lista «lite» ya traía `purpose` y ahora el evento).

## Fases
- **E1 · Base:** tablas y modelos, API, menú Eventos, página del evento (asistentes, agregar a mano
  / desde segmento / CSV, cambiar estado, check-in, cerrar), pestaña Eventos en el contacto.
- **E2 · Segmentos:** condición «Evento» en el filtro de contactos (y guardarlo como segmento).
- **E3 · Campañas:** apartado «Evento» en la campaña (audiencia + marca), inscripción automática
  en las continuas, resultados de la campaña en la página del evento.
- **E4 · Agente IA:** confirmar / cancelar desde la conversación; el evento en su contexto;
  recordatorios.
- **E5 · Extras:** QR para el check-in, cupo con lista de espera, informe de asistencia.

## Supuestos (aceptados con «dale», 2026-10-29; sin etiquetas temporales)
1. **Tipo y tamaño de los eventos:** se supone que hay de todo (ferias de cientos, cursos de 20):
   el check-in tiene buscador y no hay límite.
2. **Cómo confirman hoy:** se supone que por WhatsApp (por eso E4) y a veces a mano.
3. **Cómo controlan la asistencia:** se supone que una persona en la entrada con la lista en el
   celular o la computadora (check-in con buscador; QR después).
4. **Dónde va «Eventos» en el menú:** propuesta: en **Campañas** (es para lo que se usa); otra
   opción, en Clientes.
5. **Mientras se programa:** ¿usar etiquetas temporales («evento-x-confirmo») y después importarlas
   al módulo?
