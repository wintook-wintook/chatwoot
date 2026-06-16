// proyecto@contact_tracking — Dashboard de Seguimientos
import { frontendURL } from '../../../helper/URLHelper';

export const routes = [
  {
    path: frontendURL('accounts/:accountId/tracking-dashboard'),
    name: 'contact_trackings_dashboard',
    meta: { permissions: ['administrator', 'agent'] },
    component: () => import('../../../views/contactTrackings/Dashboard.vue'),
  },
  {
    // proyecto@contact_tracking — Agentes IA dentro del dashboard (reutiliza la vista de Settings)
    path: frontendURL('accounts/:accountId/tracking-dashboard/agents'),
    name: 'contact_trackings_agents',
    meta: { permissions: ['administrator', 'agent'] },
    component: () => import('../settings/trackingTemplates/Index.vue'),
  },
  {
    path: frontendURL('accounts/:accountId/tracking-dashboard/metrics'),
    name: 'contact_trackings_metrics',
    meta: { permissions: ['administrator', 'agent'] },
    component: () => import('../../../views/contactTrackings/Dashboard.vue'),
  },
];
