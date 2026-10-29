# Plan — Roles y permisos por área

> Estado: ✅ **P1 + P2 + P3 hechas** (2026-10-24, rama `feat/nva_oportunidad`, sin commit).
> Relacionado: [[Plan-Reacomodo-Menu]] (las áreas del menú v2 son las que se permiten o se niegan).

## Qué hay hoy
- Roles de Chatwoot: **Administrador** y **Agente**.
- Roles personalizados (`enterprise/app/models/custom_role.rb`): 6 permisos, solo de conversaciones,
  contactos, informes y base de conocimiento. Su opción en Ajustes está **comentada** en
  `sidebarItems/settings.js` (`custom_roles_list`) y tiene paywall (`CustomRolePaywall`).
- Casilla por agente «Mostrar solo conversaciones asignadas al agente»
  (`account_users.custom_attributes.showOnlyMine`, en `settings/agents/EditAgent.vue`; texto con
  dedazo «Mostar»). En `ChatList.vue` deja solo la pestaña «Mías». **Solo esconde la pestaña**: el
  servidor entrega todo y no aplica a casos, tareas ni dashboards.
- Casos, oportunidades, tareas y dashboards: **sin ninguna restricción**.

## Cómo se arma un rol (3 controles)
1. **A qué áreas entra**: Conversaciones · Agenda · Ventas · Servicio · Clientes · Campañas ·
   Agentes IA · Informes · Ajustes. Sin acceso, el área **sale del menú** y el servidor contesta
   «sin permiso» aunque se entre por URL.
2. **Alcance en los datos**: **solo lo suyo** (pestañas Mi día · Mías · No asignadas; dashboard con
   sus números) o **todo** (más «Todas»; dashboard del negocio). «Mi equipo» queda fuera de la
   primera versión.
3. **Qué puede hacer**: crear · reasignar · tomar no asignadas · borrar · exportar · ver montos ·
   configurar el área.

## Los 5 roles (plantillas)

| | Administrador | Supervisor | Vendedor | Técnico / Soporte | Consulta |
|---|---|---|---|---|---|
| Ajustes | ✓ | ✗ | ✗ | ✗ | ✗ |
| Ventas | ✓ todo | ✓ todo | ✓ solo suyas | ✗ | ✗ |
| Servicio | ✓ todo | ✓ todo | ✗ | ✓ solo suyos | ✗ |
| Conversaciones / Agenda / Clientes | ✓ todo | ✓ todo | solo lo suyo | solo lo suyo | ✗ |
| Campañas / Agentes IA | ✓ | solo ver | ✗ | ✗ | ✗ |
| Informes / Inicio › Mi negocio | ✓ | ✓ | ✗ (dashboard de ventas con sus números) | ✗ (dashboard de servicio con sus números) | ✓ solo ver |
| Montos | ✓ | ✓ | ✓ los suyos | ✗ | ✓ |
| Reasignar | ✓ | ✓ | ✗ | ✗ | ✗ |
| Borrar | ✓ | ✗ | ✗ | ✗ | ✗ |
| Exportar | ✓ | ✓ | ✗ | ✗ | ✓ |

- Los roles «solo lo suyo» ven «No asignadas» y pueden tomarlas.
- Consulta solo mira: no contesta, no crea, no mueve.
- **Administrador no se puede editar** (para que nadie se quede fuera).

## Decisiones del usuario
- Cada empresa **edita los roles directo**, con botón **«Restaurar como venía»** (no se copian).
- Son **5 roles**.
- **Migración: todos los agentes actuales pasan a Supervisor**, tengan o no la casilla
  «solo mis conversaciones». Los administradores siguen como Administrador. Después el
  administrador de cada empresa les cambia el rol.

## Dónde va en pantalla
- **Ajustes › Roles** (nueva, junto a Agentes y Equipos): lista de roles con cuántos agentes lo
  usan; al abrir uno, las casillas por área; botón «Restaurar como venía». Revisar si se reaprovecha
  la pantalla de roles personalizados que está escondida.
- **Ajustes › Agentes › Editar agente**: el combo «Rol» muestra los 5 roles; **se quita la casilla
  «Mostrar solo conversaciones asignadas»** (lo decide el rol).
- Solo el Administrador entra a Ajustes.

## El candado va en el servidor
Esconder la pestaña no basta. El alcance se aplica en **un solo lugar del backend** (un *scope* por
usuario) que usan la lista, el tablero, tareas, contadores, builders de dashboards y exportación.
Así pantalla y API siempre dicen lo mismo.

## Fases
- **P1 — Backend**: modelo de permisos por rol (áreas, alcance, acciones), las 5 plantillas por
  cuenta, migración (agentes → Supervisor) y el scope aplicado en casos, tareas, dashboards y
  conversaciones.
- **P2 — Pantalla**: menú, pestañas, filtros, montos y botones según el rol.
- **P3 — Ajustes › Roles**: editar las casillas y «Restaurar como venía»; combo de rol en Agentes.

## Cómo quedó hecho

**P1 — servidor**
- Tabla `access_roles` (migración `20261029100000_create_access_roles`) + `account_users.access_role_id`.
  Modelo `AccessRole`: `DEFAULTS` (las 4 plantillas), `AREA_LEVELS` (qué niveles admite cada área:
  «solo lo suyo» solo en las áreas con dueño; Ajustes solo «No entra»), `for_account` (las crea
  la primera vez), `restore!`. El **Administrador no se guarda**: es `role = administrator`.
- `Access::Grant` (`app/services/access/grant.rb`): EL lugar que decide. `level`, `can?`,
  `case_tickets(scope)` (Ventas = Comercial, Servicio = el resto, con subconsultas — Trampas #21),
  `conversations`, `contacts` (suyos = con conversación o caso asignado a él),
  `assignment_allowed?`, `to_h` (va al perfil como `access`).
- `AccessAreaGuard` (concern en `Api::V1::Accounts::BaseController`): área por controlador →
  403 si no entra, o si escribe con «Ve todo». Los que se leen desde otras pantallas
  (tableros, plantillas, config de casos) solo cierran la escritura.
- Aplicado en: casos (los 10 controladores usan `account_case_tickets`; crear/asignar/lote
  respetan «reasignar»; sin «ver montos» los importes van vacíos), Tareas (`limit_to_own_tasks`),
  dashboards (`case_reports`: entra con Informes o con el área; «solo lo suyo» → sus números;
  `metrics` de Servicio también con Informes), Conversaciones (`ConversationFinder`, filtros,
  búsqueda, abrir por URL, asignar), Contactos (lista y búsqueda), exportar contactos
  (`ContactPolicy#export?`), Informes de Chatwoot (`ReportPolicy#view?` y `report_manage` en
  `AccountUser#permissions`), Resumen del negocio (`CaseSetting#business_summary_visible_to?`).
- **Borrar**: Chatwoot ya solo deja borrar contactos/conversaciones al Administrador; la casilla
  queda para cuando haya borrados de agente.

**P2 — pantalla** (`helper/accessHelper.js`)
- El menú principal esconde las áreas sin acceso (`Sidebar.vue`).
- Entrar por URL a un área sin acceso manda a Inicio (`routeHelpers.js#areaRedirect`, usa el
  menú v2 para saber de qué área es la ruta).
- Pestañas «¿de quién?» según el rol: Conversaciones (`ChatList.vue`, **reemplaza la casilla
  `showOnlyMine`**), Tareas (`Tasks.vue`) y Lista/Tablero de casos (`CaseScopeBar.vue`).

**P3 — Ajustes › Roles**
- `GET/PATCH /access_roles`, `POST /access_roles/:id/restore` (solo admin). Pantalla
  `settings/accessRoles/Index.vue` (ruta `access_roles_list`, menú «Roles» bajo Agentes):
  lista con cuántos agentes lo usan y «Modificado»; casillas por área y por acción, se guardan
  solas; «Restaurar como venía» con confirmación en línea.
- Editar agente: el combo «Rol» trae Administrador + los 4 roles (manda `access_role_key`); se
  quitó la casilla «Mostrar solo conversaciones asignadas». La lista de agentes muestra el rol.

**Pruebas**: `spec/requests/api/v1/accounts/access_roles_scope_spec.rb` (10) y
`access_roles_spec.rb` (5); `helper/specs/accessHelper.spec.js`. Probado en el navegador con un
Vendedor (menú, pestañas, redirecciones, dashboard) y como admin (Roles, Editar agente).

## Efectos a saber (por la decisión «todos son Supervisor»)
- Los agentes que tenían la casilla «solo mis conversaciones» **ahora ven todo** hasta que el
  administrador les ponga Vendedor o Técnico.
- Todos los agentes ahora ven **Informes** y el **Resumen del negocio**, y pueden **exportar
  contactos** (antes solo el admin).
- Las escrituras de configuración de casos/tableros (columnas, tipos, SLA…) quedan solo para
  el Administrador (antes algunas no tenían candado).

## Pendiente
- «Mi equipo» (alcance por equipo) — versión posterior.
- «Agregar agente» sigue ofreciendo Administrador/Agente (el agente nace Supervisor).
