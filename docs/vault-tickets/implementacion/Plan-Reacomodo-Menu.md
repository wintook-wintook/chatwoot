# Plan — Reacomodo del menú (menú v2)

> Estado: ✅ **F1 + F2 hechas** (2026-10-23, rama `feat/nva_oportunidad`). Prototipo visual:
> artifact «Nuevo menú Wintook».

## Qué cambió
Menú principal por lo que hace la gente: **Inicio · Conversaciones · Agenda · Ventas · Servicio ·
Clientes · Campañas · Agentes IA · Informes · Ajustes**.

| Entrada | Submenú | Sale de |
|---|---|---|
| Inicio | Mi resumen · Mi negocio (visibleGetter); sin opción de avisos (campanita y Mi resumen) | Inicio, Resumen del negocio |
| Conversaciones | lo de antes + Vista de bandeja | Conversaciones + Vista de bandeja |
| Ventas | Embudo de contactos (qué embudo ver: combo dentro del tablero) · Oportunidades (adentro: Lista \| Tablero \| Dashboard) · Plantillas de WhatsApp · Etiquetas · Respuestas predefinidas (salen de Ajustes) | Tableros de conversaciones + Casos Comercial |
| Servicio | Casos (adentro: Lista \| Tablero \| Dashboard y la clase Soporte/OT/Proyecto) · Clasificación · SLA · Portales del cliente (salen de Casos y etapas) · Centro de ayuda (sale del menú principal; adentro manda su propio menú y solo se marca Servicio) | Casos Soporte/OT/Proyecto |
| Agenda | Tareas (abre en Mi día; adentro Mi día \| Mías \| No asignadas \| Todas) · Calendario · Prioridad de Mi día (sale de Casos y etapas) | Casos › Tareas + Google Calendar |
| Clientes | Todos los contactos · Atributos personalizados (sale de Ajustes) · Segmentos y Etiquetas (secciones de siempre) | Contactos |
| Agentes IA | Agentes · Seguimientos · Base de conocimiento · Entrenamiento ChatGPT · Análisis de sitio · Automatizaciones (salen de Ajustes; se quitó el duplicado «Agentes IA» de Ajustes y Capitán) | Agente IA campañas + Ajustes |
| Campañas | De agentes IA · Página web · SMS · Dashboard (antes «Resumen») | Agente IA campañas |
| Informes | Resumen del negocio (también en Inicio › Mi negocio) · Dashboard de ventas · Dashboard de servicio · Dashboard de campañas · ▸ Conversaciones (En vivo, Conversaciones, Por agente, Por equipo, Por bandeja, Por etiqueta, Satisfacción (CSAT), Bot); el SLA de Chatwoot sale del menú | Informes + Métricas de cada módulo |
| Ajustes | lo de Configuración + Embudos de contactos + grupo «Casos y etapas» | Configuración + config de Casos |

## Cómo está hecho (y cómo regresarlo)
- Archivos nuevos: `components/layout/config/sidebarItems/v2/index.js` (+ `index.spec.js`). Reusa y
  reparte los menús de antes; **no los modifica**.
- **Interruptor**: `MENU_V2` en `components/layout/config/menuVersion.js`. En `false` vuelve el
  menú anterior tal cual.
- Respaldos `_20261023m`: `Sidebar.vue`, `Secondary.vue`, `default-sidebar.js`, `es|en/settings.json`.
- `Sidebar.vue`: `matches(route)` para elegir menú por la clase de la ruta, `alternatives` en el menú
  principal (Agenda sin casos → Calendario; Agentes IA sin campañas → Capitán). `Secondary.vue`:
  `extraSections` (Ventas usa la sección dinámica de embudos).
- Ninguna ruta cambió. Textos nuevos con claves nuevas (`SIDEBAR.SALES`, `SETTINGS_V2`, …) para no
  tocar los del menú anterior.

## Formas de ver (Lista | Tablero | Dashboard)
- Van en `CaseClassSwitcher.vue` (ya estaba en el encabezado de Lista, Tablero y las 4 métricas).
  Con el menú v2: en Comercial no hay selector de clase (título «Oportunidades»), en Servicio solo
  sus clases. La última forma de ver se guarda por clase (`rememberCaseView`/`lastCaseView` en
  `helper/caseClasses.js`) y la opción del menú vuelve a ella (Oportunidades: Tablero la primera vez;
  Casos: Lista).
- El selector lleva ícono + texto (☰ Lista · ▦ Tablero · 📈 Dashboard) para que se note, y
  **Informes** también enlaza «Dashboard de ventas» y «Dashboard de servicio» (misma pantalla):
  quien analiza los busca ahí.
- La opción del menú se marca activa en las tres vistas con `activeRoutes` (`SecondaryNavItem.vue`).
- El interruptor vive en `components/layout/config/menuVersion.js` (`default-sidebar.js` lo reexporta).

## Nombres (decisión del usuario, 2026-10-23)
- **Ventas** = el área del menú y el nombre visible de la clase (antes «Comercial»; interno sigue
  `commercial`). **Oportunidades** = la pantalla; cada caso de Ventas es una oportunidad; el botón
  crea «+ Oportunidad» (`CASE_TICKETS.CLASSES.COMMERCIAL.NEW`). **Tipos de oportunidad** = los tipos
  de caso de la clase Ventas.
- Servicio: clases Soporte · Orden de trabajo · Proyecto; la pantalla es **Casos**.
- **Usuarios** = las personas del equipo (antes «agentes»; 2026-10-24). «Agente» queda **solo para
  la IA** (Agentes IA). Al asignar (conversación, caso, reportes de asignación) se dice
  **Responsable**. Solo cambian textos en español (`i18n/locale/es`, `config/locales/es.yml` y
  algunos textos fijos); código, API y rutas siguen con `agent`. Donde Chatwoot decía «usuario»
  por el **cliente** se cambió a «cliente»/«contacto» para que no se confunda.

## Detalles del menú
- Un grupo plegable se abre solo cuando estás en una de sus pantallas (`Secondary.vue`), y una
  opción dentro de un grupo respeta su función activa (`SecondaryNavItem.vue#visibleChildren`).
- Tareas: pestañas Mi día · Mías · No asignadas · Todas; la primera vez abre en Mi día y después en
  la última usada; desde el menú siempre en Mi día.

## Reglas finas
- El menú principal marca activo por prefijo de dirección: Servicio apunta a
  `tickets/<clase>/list`, no a `tickets` (si no, se marca también en Ventas).
- El detalle de un caso (`tickets/:id`) no trae la clase: usa la última clase visitada.

## Pendiente (siguientes fases)
- F3: botón «+ Nuevo» y contadores en el menú. F5: Ctrl K con casos/tareas.
- Cotizaciones y Productos (módulo del sistema administrativo).
- «Agentes IA» también es el nombre de las plantillas de seguimiento dentro de Ajustes (renombrar).

## Página del contacto (reacomodo 2026-10-24, C1–C3)
Antes todo iba apilado en una columna angosta y el área grande solo tenía «Notas». Ahora:
- **Encabezado a lo ancho** (`ContactInfo` con `layout="header"`): nombre, empresa, medios de
  contacto, **Responsable fijo**, etiquetas y acciones con nombre: **Mensaje · Editar · Más ▾**
  (`ContactMoreActions.vue`: Fusionar, Notas, Conversación privada / Programar mensaje y Nueva
  conversación en el panel de la conversación, Crear evento, Eliminar).
- **Columna «Datos»** (`ContactDataColumn.vue`): empresa, ubicación, alta, último contacto,
  descripción y atributos personalizados, siempre a la vista.
- **Pestañas** (`?tab=` en la dirección): **Resumen** (4 tarjetas + actividad reciente mezclada,
  `GET /contacts/:id/summary`) · **Conversaciones** · **Casos** (`ContactCasesTab`, abiertos o
  todos) · **Tareas** (`ContactTasksTab`, bandeja con `contact_id`) · **Notas**. Casos y Tareas
  solo con `case_management`. En celular las tres partes van una debajo de otra.
- El panel del contacto **dentro de una conversación** sigue angosto, con Mensaje · Editar · Más.
- Todo respeta el rol (Plan-Roles-Permisos): el resumen y las conversaciones del contacto
  cuentan solo lo que el usuario puede ver, y sin «ver montos» no van importes.
- **Editar / Nuevo contacto** (`ContactForm.vue`, 2026-10-24): panel más ancho (`size="wide"` en
  `Modal.vue`, 45rem), secciones (Cómo contactarlo, Ubicación, Redes sociales), campos en pareja a
  dos columnas, foto con vista previa («Cambiar foto · Quitar»), redes sociales solo las que tienen
  dato (+ «Agregar red»), botones fijos abajo («Guardar cambios» / «Crear contacto»). Mismos
  campos, validaciones, avisos y búsqueda en CRMZeus (Enter en teléfono/correo, Agregar/Buscar
  empresa). ⚠️ Ya venía de antes: la foto elegida al editar NO se guarda (`getContactObject` no la
  manda); «Quitar» sí funciona.
