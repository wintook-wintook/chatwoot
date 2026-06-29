// @query_databases — rutas del módulo "Cobranza / ERP"
import { frontendURL } from '../../../helper/URLHelper';

export const routes = [
  {
    path: frontendURL('accounts/:accountId/erp/connections'),
    name: 'erp_connections',
    meta: { permissions: ['administrator'] },
    component: () => import('../../../views/erp/Connections.vue'),
  },
  {
    path: frontendURL('accounts/:accountId/erp/bots'),
    name: 'erp_bots',
    meta: { permissions: ['administrator'] },
    component: () => import('../../../views/erp/Bots.vue'),
  },
  {
    path: frontendURL('accounts/:accountId/erp/console'),
    name: 'erp_console',
    meta: { permissions: ['administrator', 'agent'] },
    component: () => import('../../../views/erp/Console.vue'),
  },
];
