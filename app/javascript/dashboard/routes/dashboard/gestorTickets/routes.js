// @tickets_cases
import { frontendURL } from '../../../helper/URLHelper';

export const routes = [
  {
    path: frontendURL('accounts/:accountId/tickets'),
    name: 'gestorTickets_index',
    meta: { permissions: ['administrator', 'agent'] },
    component: () => import('../../../views/gestorTickets/Index.vue'),
  },
  {
    path: frontendURL('accounts/:accountId/tickets/kanban'),
    name: 'gestorTickets_kanban',
    meta: { permissions: ['administrator', 'agent'] },
    component: () => import('../../../views/gestorTickets/Kanban.vue'),
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
    path: frontendURL('accounts/:accountId/tickets/metrics'),
    name: 'gestorTickets_metrics',
    meta: { permissions: ['administrator', 'agent'] },
    component: () => import('../../../views/gestorTickets/Metrics.vue'),
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
