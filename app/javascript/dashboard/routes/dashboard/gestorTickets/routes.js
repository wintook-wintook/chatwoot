// @tickets_cases
import { frontendURL } from '../../../helper/URLHelper';
import {
  CASE_CLASS_PATTERN,
  CLASS_VIEW_ROUTES,
  lastCaseClass,
} from '../../../helper/caseClasses';

// Plan-Casos E1 (F6) — Lista, Tablero y Métricas existen POR CLASE:
// `tickets/:caseClass/list|board|metrics`. Las rutas de siempre (`tickets`,
// `tickets/kanban`, `tickets/metrics`) quedan como redirección a la última clase
// usada: así no se rompen enlaces guardados, `$router.push({ name: ... })` de las
// vistas ni el menú, que apunta a ellas (neutras).
const toLastClass = view => to => ({
  name: CLASS_VIEW_ROUTES[view],
  params: {
    accountId: to.params.accountId,
    caseClass: lastCaseClass(to.params.accountId),
  },
});
const classProps = route => ({ caseClass: route.params.caseClass });
const AGENT = { permissions: ['administrator', 'agent'] };

export const routes = [
  {
    path: frontendURL('accounts/:accountId/tickets'),
    name: 'gestorTickets_index',
    meta: AGENT,
    redirect: toLastClass('list'),
  },
  {
    path: frontendURL('accounts/:accountId/tickets/kanban'),
    name: 'gestorTickets_kanban',
    meta: AGENT,
    redirect: toLastClass('board'),
  },
  {
    path: frontendURL('accounts/:accountId/tickets/metrics'),
    name: 'gestorTickets_metrics',
    meta: AGENT,
    redirect: toLastClass('metrics'),
  },
  // Con slug acotado (support|commercial) para no chocar con `tickets/types/:typeId`
  // ni con el catch-all `tickets/:id`.
  {
    path: frontendURL(
      `accounts/:accountId/tickets/:caseClass(${CASE_CLASS_PATTERN})/list`
    ),
    name: CLASS_VIEW_ROUTES.list,
    meta: AGENT,
    component: () => import('../../../views/gestorTickets/Index.vue'),
    props: classProps,
  },
  {
    path: frontendURL(
      `accounts/:accountId/tickets/:caseClass(${CASE_CLASS_PATTERN})/board`
    ),
    name: CLASS_VIEW_ROUTES.board,
    meta: AGENT,
    component: () => import('../../../views/gestorTickets/Kanban.vue'),
    props: classProps,
  },
  {
    path: frontendURL(
      `accounts/:accountId/tickets/:caseClass(${CASE_CLASS_PATTERN})/metrics`
    ),
    name: CLASS_VIEW_ROUTES.metrics,
    meta: AGENT,
    component: () => import('../../../views/gestorTickets/ClassMetrics.vue'),
    props: classProps,
  },
  // Plan-Trabajo-Campo R3 — Servicio › Despacho.
  {
    path: frontendURL('accounts/:accountId/tickets/dispatch'),
    name: 'gestorTickets_dispatch',
    meta: AGENT,
    component: () =>
      import('../../../views/gestorTickets/dispatch/Dispatch.vue'),
  },
  // Plan-Trabajo-Campo R4 — Servicio › Mantenimientos.
  {
    path: frontendURL('accounts/:accountId/tickets/maintenance'),
    name: 'gestorTickets_maintenance',
    meta: AGENT,
    component: () =>
      import('../../../views/gestorTickets/maintenance/MaintenancePlans.vue'),
  },
  // Plan-Catalogo-Cotizaciones — Ventas › Cotizaciones (lista, nueva y editor).
  {
    path: frontendURL('accounts/:accountId/tickets/quotes'),
    name: 'gestorTickets_quotes',
    meta: AGENT,
    component: () =>
      import('../../../views/gestorTickets/quotes/QuotesList.vue'),
  },
  {
    path: frontendURL('accounts/:accountId/tickets/quotes/new'),
    name: 'gestorTickets_quote_new',
    meta: AGENT,
    component: () =>
      import('../../../views/gestorTickets/quotes/QuoteEditor.vue'),
  },
  {
    path: frontendURL('accounts/:accountId/tickets/quotes/:id'),
    name: 'gestorTickets_quote',
    meta: AGENT,
    component: () =>
      import('../../../views/gestorTickets/quotes/QuoteEditor.vue'),
    props: route => ({ quoteId: Number(route.params.id) }),
  },
  // Plan-Catalogo-Cotizaciones — Ventas › Catálogo.
  {
    path: frontendURL('accounts/:accountId/tickets/catalog'),
    name: 'gestorTickets_catalog',
    meta: AGENT,
    component: () => import('../../../views/gestorTickets/catalog/Catalog.vue'),
  },
  {
    path: frontendURL('accounts/:accountId/tickets/tasks'),
    name: 'gestorTickets_tasks',
    meta: { permissions: ['administrator', 'agent'] },
    component: () => import('../../../views/gestorTickets/Tasks.vue'),
  },
  {
    path: frontendURL('accounts/:accountId/tickets/rules'),
    name: 'gestorTickets_rules',
    meta: { permissions: ['administrator'] },
    component: () => import('../../../views/gestorTickets/TicketRules.vue'),
  },
  {
    path: frontendURL('accounts/:accountId/tickets/types'),
    name: 'gestorTickets_types',
    meta: { permissions: ['administrator'] },
    component: () => import('../../../views/gestorTickets/TicketTypes.vue'),
  },
  {
    // Detalle de un tipo de caso: tabs de campos personalizados y columnas.
    // 3 segmentos → no choca con el catch-all `tickets/:id` (2 segmentos).
    path: frontendURL('accounts/:accountId/tickets/types/:typeId'),
    name: 'gestorTickets_type_detail',
    meta: { permissions: ['administrator'] },
    component: () =>
      import('../../../views/gestorTickets/TicketTypeDetail.vue'),
    props: route => ({ typeId: Number(route.params.typeId) }),
  },
  {
    path: frontendURL('accounts/:accountId/tickets/classification'),
    name: 'gestorTickets_classification',
    meta: { permissions: ['administrator'] },
    component: () => import('../../../views/gestorTickets/Classification.vue'),
  },
  {
    path: frontendURL('accounts/:accountId/tickets/config'),
    name: 'gestorTickets_config',
    meta: { permissions: ['administrator'] },
    component: () => import('../../../views/gestorTickets/FolioConfig.vue'),
  },
  {
    path: frontendURL('accounts/:accountId/tickets/sla'),
    name: 'gestorTickets_sla',
    meta: { permissions: ['administrator'] },
    component: () => import('../../../views/gestorTickets/SlaConfig.vue'),
  },
  {
    path: frontendURL('accounts/:accountId/tickets/ai'),
    name: 'gestorTickets_ai',
    meta: { permissions: ['administrator'] },
    component: () => import('../../../views/gestorTickets/AiConfig.vue'),
  },
  {
    path: frontendURL('accounts/:accountId/tickets/portals'),
    name: 'gestorTickets_portals',
    meta: { permissions: ['administrator'] },
    component: () => import('../../../views/gestorTickets/Portals.vue'),
  },
  {
    path: frontendURL('accounts/:accountId/tickets/commercial-settings'),
    name: 'gestorTickets_commercial_settings',
    meta: { permissions: ['administrator'] },
    component: () =>
      import('../../../views/gestorTickets/CommercialConfig.vue'),
  },
  // Catálogos › Motivos de cierre (salió de la página de arriba).
  {
    path: frontendURL('accounts/:accountId/tickets/close-reasons'),
    name: 'gestorTickets_close_reasons',
    meta: { permissions: ['administrator'] },
    component: () =>
      import('../../../views/gestorTickets/OutcomeReasonsConfig.vue'),
  },
  // Plan-Bandeja-Prioridad F3 — pesos del puntaje de «Mi día».
  {
    path: frontendURL('accounts/:accountId/tickets/task-settings'),
    name: 'gestorTickets_task_settings',
    meta: { permissions: ['administrator'] },
    component: () =>
      import('../../../views/gestorTickets/TaskPriorityConfig.vue'),
  },
  // «Mi resumen» (Inicio): donde aterriza cada usuario al iniciar sesión, salvo que
  // en su perfil elija otra página (ver routes/index.js → landingRoute).
  {
    path: frontendURL('accounts/:accountId/start'),
    name: 'my_summary',
    meta: AGENT,
    component: () => import('../../../views/gestorTickets/home/MySummary.vue'),
  },
  // «Resumen del negocio»: la ruta es de agente; el backend decide quién lo ve
  // (administradores y autorizados) y el menú lo oculta a los demás.
  {
    path: frontendURL('accounts/:accountId/tickets/summary'),
    name: 'gestorTickets_business_summary',
    meta: AGENT,
    component: () =>
      import('../../../views/gestorTickets/summary/BusinessSummary.vue'),
  },
  {
    path: frontendURL('accounts/:accountId/tickets/summary-access'),
    name: 'gestorTickets_business_summary_access',
    meta: { permissions: ['administrator'] },
    component: () =>
      import('../../../views/gestorTickets/summary/BusinessSummaryAccess.vue'),
  },
  {
    path: frontendURL('accounts/:accountId/tickets/settings'),
    name: 'gestorTickets_settings',
    meta: { permissions: ['administrator'] },
    component: () => import('../../../views/gestorTickets/Settings.vue'),
  },
  {
    path: frontendURL('accounts/:accountId/tickets/:id'),
    name: 'gestorTickets_detail',
    meta: { permissions: ['administrator', 'agent'] },
    component: () => import('../../../views/gestorTickets/TicketDetail.vue'),
    props: route => ({ ticketId: Number(route.params.id) }),
  },
];
