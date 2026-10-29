// Plan-Eventos E1 — Campañas › Eventos.
import { frontendURL } from '../../../helper/URLHelper';

const META = { permissions: ['administrator', 'agent', 'custom_role'] };

export const routes = [
  {
    path: frontendURL('accounts/:accountId/events'),
    name: 'events_list',
    meta: META,
    component: () => import('../../../views/events/EventsList.vue'),
  },
  {
    path: frontendURL('accounts/:accountId/events/:eventId'),
    name: 'event_detail',
    meta: META,
    component: () => import('../../../views/events/EventDetail.vue'),
  },
];
