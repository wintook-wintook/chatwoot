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
    path: frontendURL('accounts/:accountId/tickets/:id'),
    name: 'gestorTickets_detail',
    meta: { permissions: ['administrator', 'agent'] },
    component: () => import('../../../views/gestorTickets/TicketDetail.vue'),
    props: route => ({ ticketId: Number(route.params.id) }),
  },
];
