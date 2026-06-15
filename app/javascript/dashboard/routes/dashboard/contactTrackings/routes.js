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
    path: frontendURL('accounts/:accountId/tracking-dashboard/metrics'),
    name: 'contact_trackings_metrics',
    meta: { permissions: ['administrator', 'agent'] },
    component: () => import('../../../views/contactTrackings/Dashboard.vue'),
  },
];
