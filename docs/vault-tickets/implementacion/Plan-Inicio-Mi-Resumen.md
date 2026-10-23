# Inicio — «Mi resumen» (hecho)

> **Estado: ✅ HECHO** (2026-10-22). Relacionado: [[Plan-Empresa-Un-Solo-Hombre]] (es la puerta
> de entrada del humano) · [[Plan-Resumen-Negocio]] · [[Plan-Bandeja-Prioridad]] · [[Plan-Plantilla-Tareas-Etapa]]

## Qué es

Al iniciar sesión cada usuario aterriza en **Inicio («Mi resumen»)**: ¿qué tengo que hacer hoy?
El dueño también es usuario: aterriza en su resumen y desde ahí entra al **Resumen del negocio**
(botón arriba, solo si tiene acceso).

## Decisiones del usuario

1. Todos aterrizan en su resumen (el dueño incluido); el del negocio se abre desde ahí.
2. Bloques: avisos importantes · lo más urgente de Mi día · agenda de hoy · mis conversaciones ·
   mis casos · mis números de la semana.
3. Cada usuario elige dónde aterriza (perfil): Inicio (defecto) · Conversaciones · Mi día.

## Cómo quedó

- **Ruta** `accounts/:accountId/start` (`my_summary`), en el menú principal arriba de todo con
  ícono de casa (`home-outline`, agregado a `dashboard-icons.json`); solo con `case_management`
  (sin el módulo, la página manda a Conversaciones).
- **Aterrizaje** `routes/index.js → landingRoute`: solo en la PRIMERA navegación (iniciar sesión
  o abrir la app) hacia `home` (Conversaciones); lee `ui_settings.landing_page`
  (`summary` | `conversations` | `my_day`). Navegar a Conversaciones dentro de la app no redirige.
- **Perfil** `settings/profile/LandingPageSetting.vue`: «Al iniciar sesión, ir a».
- **Servidor** `GET my_summary` → `Cases::MySummary`: conversaciones (abiertas asignadas y las
  que esperan respuesta por `waiting_since`, la más vieja primero), casos (SLA en riesgo/vencido,
  etapas listas vía `StageAdvance`, promesas de pago de la semana) y números de la semana
  (resueltos/cerrados sin perdidas, tareas hechas, ganadas) contra el mismo tramo de la pasada.
- **Página** `views/gestorTickets/home/MySummary.vue`: saludo, `MyDayNotices`, top 5 de Mi día
  (`case_tasks?mode=my_day`) con «Ver todo» (`?tab=my_day` en Tareas), agenda de hoy, bloques
  que se ocultan si no tienen nada; clic abre el caso (`?tab=tasks`) o la conversación.
- Pruebas: `spec/services/cases/my_summary_spec.rb` (4), `routes/index.spec.js` (+4).
