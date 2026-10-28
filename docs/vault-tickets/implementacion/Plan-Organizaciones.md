# Plan — Organizaciones: prospectos y clientes

> Estado: ✅ **O1–O5 hechos** (2026-10-28, rama `organizaciones`, sin commit).
> Idea del usuario: el **contacto** (la persona) se queda igual; aparece la **organización**,
> que es la que es **prospecto** o **cliente** y tiene muchos contactos ligados. Pasar de
> prospecto a cliente solo cambia el tipo: todo lo demás queda igual.

## Lo que dijo el usuario
- Tabla nueva **organizaciones**; ahí viven los prospectos y los clientes.
- El contacto no cambia. Cuando el usuario lo decida, un contacto se convierte en prospecto
  y después en cliente (es decir, se liga a una organización que va cambiando de tipo).
- Una organización (prospecto o cliente) puede tener **muchos contactos**.
- Los formularios que hoy preguntan «cliente» (el contacto) tendrán también el campo
  **Organización**, que **filtra los contactos** que tiene.
- De prospecto a cliente **no se mueve nada**: solo cambia el tipo de la organización.
- Hay que definir **qué la pasa** a prospecto y a cliente, y **en qué partes** de Kontrolya.

## Cómo está hoy (lo que encontré)
| Tema | Hoy |
|---|---|
| Contacto | Tabla `contacts` de Chatwoot: persona con nombre, correo, teléfono, responsable fijo (`owner_id`), atributos. La empresa es solo texto libre en `additional_attributes.company_name` (no se puede filtrar ni agrupar). |
| ⚠️ `contacts.contact_type` | Ya existe un enum de Chatwoot **visitor / lead / customer**. Chatwoot lo pone solo: un visitante pasa a `lead` en cuanto deja correo o teléfono (`Contacts::SyncAttributes`). **No sirve** para nuestro prospecto/cliente (lo cambia el sistema, no el usuario, y es de la persona). Se deja como está y no se muestra. |
| Quién pide «cliente» | Todo apunta al **contacto** (`contact_id`): casos/oportunidades (`case_tickets`, además `requester_id`), cotizaciones (`quotes`), contratos (`contracts`), equipos del cliente (`customer_assets`), planes de mantenimiento (`maintenance_plans`), seguimientos/campañas (`contact_trackings`), notas, llamadas, conversaciones. |
| Formularios con selector de cliente | `ContactPicker` (casos internos, contratos), editor y panel de cotizaciones, alta de equipos y de planes de mantenimiento, ligar conversación a caso, detalle del caso. |
| «Prospecto» en otros lados | El **Embudo de contactos** (columna Convertido crea la oportunidad) y la **prospección** de campañas (`contact_trackings.prospect_score`, `prospect_stage`). Son del seguimiento, no de la empresa: no chocan, pero hay que cuidar los nombres. |
| Pendiente anotado | En el reacomodo del menú quedó: «etapa automática Contacto/Prospecto/Cliente en Clientes». Este plan lo reemplaza. |

## Propuesta

### El modelo
- Tabla **`organizations`** (por cuenta): nombre, **etapa** (`prospect` / `customer`), **tipo**
  (`company` / `general_public`: Empresa o Público en general, independiente de la etapa), RFC o
  identificador fiscal, sitio web y **dominio de correo**, giro, teléfono, dirección,
  **responsable** (usuario), datos propios (`custom_attributes`, como el contacto), notas,
  fechas **`became_prospect_at`** y **`became_customer_at`** (para medir conversión) y quién
  lo cambió (bitácora).
- **`contacts.organization_id`** (opcional): un contacto pertenece a **una** organización o a
  ninguna. Sin organización sigue siendo «contacto», como hoy.
- Se llama **organización** y no «empresa»/«company» para no chocar con lo que trae Chatwoot.

### Qué es cada cosa (las etapas)
| Etapa | Qué es | Cómo se ve |
|---|---|---|
| **Contacto** | Persona sin organización. Escribió, se importó o se dio de alta. | Igual que hoy. |
| **Prospecto** | Su organización es de tipo prospecto: hay interés real de venta. | Etiqueta «Prospecto» en el contacto y en la organización. |
| **Cliente** | Su organización es de tipo cliente: ya compró o tiene contrato. | Etiqueta «Cliente». |

La etapa de un contacto **sale de su organización**: si la organización pasa a cliente, todos
sus contactos se ven como de un cliente sin tocarlos.

### Qué la pasa a prospecto
Siempre se puede **a mano**. Además, propuesta de automáticos (cada uno se enciende o apaga en
Ventas › Parámetros de ventas):
1. **A mano — «Convertir en prospecto»** desde el contacto: crea la organización (con el nombre
   de la empresa que ya tenga escrito, o el del contacto) o lo liga a una existente.
2. **Al crear una oportunidad** para un contacto sin organización: el formulario pide
   organización y ofrece crearla como prospecto.
3. **Al llegar a «Convertido» en el Embudo de contactos** (que ya crea la oportunidad): lo
   mismo que el punto 2.
4. **Al enviar una cotización** a un contacto sin organización.

### Qué la pasa a cliente
Siempre se puede **a mano — «Marcar como cliente»**. Propuesta de automáticos (configurables):
1. **Oportunidad ganada** de la organización.
2. **Contrato nuevo** de la organización.
3. **Cotización aceptada**.

Ninguno mueve datos: solo cambia el tipo y guarda la fecha. Regresar de cliente a prospecto
solo a mano (por si fue un error).

### Dónde se hace en Kontrolya
| Lugar | Qué |
|---|---|
| **Clientes** (menú) | Nueva opción **Organizaciones** con pestañas **Prospectos · Clientes · Todas**, búsqueda, filtros (responsable, giro), importar CSV. «Contactos» se queda. |
| **Página de la organización** (nueva) | Datos, contactos ligados (agregar / quitar), y lo de todos sus contactos junto: conversaciones, oportunidades, cotizaciones, contratos, casos, equipos. Botones Convertir en prospecto / Marcar como cliente. |
| **Página del contacto** | Campo **Organización** (buscar, crear, quitar) y su etapa. Botón «Convertir en prospecto» cuando no tiene. |
| **Panel del contacto en la conversación** | Muestra la organización y la etapa; mismo botón. |
| **Embudo de contactos** | Columna Convertido = punto 3 de prospecto. |
| **Ventas › Parámetros de ventas** | Qué automáticos están encendidos (prospecto y cliente). |
| **Catálogos** | (Opcional) Giros de organización, si se quieren como lista y no texto libre. |

### Los formularios que piden «cliente»
Campo **Organización** antes del contacto, en: oportunidades/casos (incluido el alta interna),
cotizaciones, contratos, equipos del cliente y planes de mantenimiento.
- Elegir organización → el selector de contacto **muestra solo sus contactos**.
- Elegir primero el contacto → la organización **se llena sola** con la suya.
- Se guarda **`organization_id` en el registro** (no solo se deduce del contacto): si después
  el contacto cambia de empresa, lo que ya se hizo se queda con la organización de entonces, y
  los informes por organización no necesitan dar vueltas.
- El contacto sigue siendo obligatorio donde lo es hoy (las conversaciones son con personas).

### Responsable
La organización tiene **responsable**. Propuesta: sus contactos sin responsable fijo propio lo
heredan (se integra con `ContactOwnerAssignment` del Responsable fijo).

## O1 — Base (hecho)
| Pieza | Dónde |
|---|---|
| Tablas `organizations` (etapa `prospect`/`customer`, tipo `company`/`general_public`, RFC, giro, sitio, dominio, teléfono, dirección, responsable, datos propios, notas, fechas de etapa), `organization_events` (bitácora) y `contacts.organization_id` | `db/migrate/20261031220000_create_organizations.rb` |
| Modelo: Público en general sin RFC; `build_for(contact)` (su empresa escrita → Empresa; sin ella → Público en general con su nombre); `change_stage!` guarda fecha y bitácora; RFC único por cuenta; al borrar, los contactos quedan sin organización | `Organization`, `OrganizationEvent`, `Contact#organization` |
| API (área Clientes; «solo lo suyo» = a su cargo o de sus contactos) | `organizations` index (`q`, `stage`, `kind`, `owner_id`, `meta.counts`), show (contactos + bitácora), create (`contact_id` liga al contacto), update, destroy, `change_stage`, `add_contact`, `remove_contact` |
| Pantallas | Clientes › **Organizaciones** (pestañas Prospectos · Clientes · Todas, búsqueda, filtro de tipo, alta) · **página de la organización** (datos, contactos ligados, Marcar como cliente / Regresar a prospecto, editar, eliminar, bitácora) · bloque **Organización** en la página del contacto (Convertir en prospecto, ligar a existente, quitar) |

Front: `views/organizations/` (`OrganizationsList`, `OrganizationDetail`, `OrganizationForm`,
`organizationHelpers`), `routes/dashboard/organizations/routes.js`,
`contacts/components/ContactOrganization.vue`, i18n `organizations.json`.

Specs: `spec/models/organization_spec.rb`, `spec/requests/api/v1/accounts/organizations_spec.rb`,
`views/organizations/specs/OrganizationForm.spec.js`, menú v2.

## O2–O5 (hechos)
| Fase | Qué quedó | Dónde |
|---|---|---|
| O2 Formularios | `organization_id` en casos, cotizaciones, contratos, equipos y planes de mantenimiento: al crear toma la del contacto si no se elige y se queda aunque el contacto cambie. Filtro `organization_id` en sus listas. Campo «Organización» que filtra contactos (y se llena solo al elegir contacto) en alta de caso por clase, cotización y contrato. Página de la organización con Oportunidades · Casos · Cotizaciones · Contratos · Equipos | `OrganizationLinked`, migración `20261031230000`, `Organizations::Summary` (`GET /organizations/:id/summary`), `OrganizationPicker`, `OrganizationContactFields`, `ContactPicker :organization-id`, `OrganizationActivity` |
| O3 Automáticos | Reglas en Ventas › Parámetros de ventas: oportunidad nueva (incluye Convertido del embudo) y cotización enviada → prospecto; ganada, contrato y cotización aceptada → cliente. Cuentas existentes: todo apagado; nuevas: oportunidad, ganada y contrato encendidas. Bitácora con el motivo. Responsable heredado de la organización (conversaciones, casos, reglas y «solo lo suyo») | `case_settings.organization_rules` (migración `20261031240000`), `Organizations::StageRules`, `Contact#effective_owner_id` |
| O4 Datos existentes | Asistente con vista previa (agrupa por empresa escrita, dominio no gratuito o cliente-persona; propone etapa por contratos/ganadas; liga a la existente si coincide). Importar/plantilla CSV de organizaciones. Columna «organizacion» en importación de contratos (debe existir) y de contactos (si no existe, se crea como prospecto) | `Organizations::Suggestions`, `Organizations::CsvImport`, `OrganizationSuggestions.vue`, `DataImport::ContactManager` |
| O5 Informes e IA | Informes › Dashboard de clientes (totales, nuevos, conversión, días a cliente, llegadas por mes). Variables `{{organizacion.nombre|rfc|etapa|tipo|giro}}` (y `organization.*`) en mensajes, correos y la caja de respuesta. El agente IA recibe la organización del contacto | `Organizations::Metrics`, `OrganizationsDashboard.vue`, `OrganizationDrop`, `ReplyBox` (`organizationVariables`), `Organizations::PromptContext` |

## Contactos que entran y salen (2026-10-28)
Decisiones del usuario: el contacto es lo único obligatorio y la organización sale de él; un
contacto que ya tiene organización solo se cambia con una acción deliberada.
- **Ligar por primera vez** (a mano, asistente, importaciones, reglas): lo suyo **sin**
  organización pasa a ella (`Contact#adopt_unlinked_records`). Migración `20261031260000`
  rellenó una vez lo que ya existía.
- **«Cambiar de organización»** en la ficha del contacto (`ChangeOrganizationModal`,
  `Organizations::ChangeContactOrganization`, `GET /organizations/change_preview`,
  `POST /organizations/change_contact`):
  - «Sí, pasar todo» (estaba en la equivocada): todo lo suyo en la anterior pasa a la nueva.
  - «No, que todo se quede» (se cambió de empresa): **obligatorio** elegir quién queda en su
    lugar (otro contacto de la anterior o uno nuevo que se da de alta ahí). Lo **vivo** (casos
    y oportunidades abiertos, cotizaciones draft/sent/postponed, contratos no cancelados,
    equipos y planes activos) pasa a esa persona; lo **cerrado** se queda con él como historial.
  - Bitácora en las dos organizaciones.
- La organización muestra lo que tiene su `organization_id` (no lo de sus contactos): lo cerrado
  que se quedó en Acme no aparece en Globex. En la ficha del contacto, lo de otra organización
  lleva su etiqueta (`OrganizationTag`).
- Desde la organización, la importación CSV o la de contactos no se «roba» un contacto de otra:
  avisan que se use «Cambiar de organización». Quitar pide confirmación.

## Fases
- **O1 · Base:** tabla y modelo, `contacts.organization_id`, API, Clientes › Organizaciones
  (lista con pestañas), página de la organización, campo Organización en el contacto, botones
  manuales Convertir en prospecto / Marcar como cliente con bitácora. Permisos del área Clientes.
- **O2 · Formularios:** `organization_id` en casos, cotizaciones, contratos, equipos y planes de
  mantenimiento; campo Organización que filtra contactos y se autollena; filtros por
  organización en las listas.
- **O3 · Automáticos:** reglas de prospecto y cliente de arriba, configurables en Parámetros
  de ventas; Embudo de contactos; responsable heredado.
- **O4 · Datos que ya existen:** asistente con **vista previa** que agrupa contactos por el
  texto de empresa y por dominio de correo, y propone tipo (con contrato u oportunidad ganada →
  cliente; con oportunidad abierta → prospecto). Nada se aplica sin confirmar. Importación CSV
  de organizaciones y columna «organización» en la de contactos y contratos.
- **O5 · Informes e IA:** cuántos prospectos y clientes, conversión y tiempo de prospecto a
  cliente; variables `{{organizacion.nombre}}` en plantillas; los agentes IA ven la organización.

## Decisiones del usuario (2026-10-28)
1. ✅ Un contacto está en **una sola** organización.
2. ✅ **Empresa o Público en general** es un selector aparte de la etapa (ambos pueden ser
   prospecto o cliente) y lo que decide es **si se factura**:
   - **Empresa:** tiene RFC; incluye a la persona física con RFC. Muestra datos fiscales. El
     RFC es opcional al dar de alta (un prospecto se completa al facturar).
   - **Público en general:** sin factura; oculta RFC y datos fiscales. Toma el nombre del contacto.
   - Si alguien de público en general pide factura, se cambia a Empresa y se captura el RFC;
     nada más se mueve.
   - Por omisión Empresa; desde un contacto sin empresa escrita se sugiere Público en general.
3. ✅ Automáticos: cuentas **nuevas** con prospecto 2-3 y cliente 1-2 encendidos; cuentas
   **existentes**, todo apagado.
4. ✅ La organización **no es obligatoria** en oportunidad, cotización ni contrato: opcional y
   sugerida (se puede vender sin dar de alta la empresa).
5. ✅ Sin «ex cliente» por ahora; el estado del contrato ya lo dice.
6. ✅ El responsable de la organización se **hereda** a sus contactos sin responsable propio.

## Trampas
- **No usar `contacts.contact_type`** de Chatwoot: lo cambia el sistema solo.
- Fusionar contactos (Chatwoot) debe conservar la organización.
- Borrar una organización: no borra contactos ni registros; quedan sin organización.
- Nombres duplicados: avisar por RFC o dominio de correo, no bloquear.
- Base de desarrollo = base de pruebas: tras la migración, igualar `schema_sha1`.
