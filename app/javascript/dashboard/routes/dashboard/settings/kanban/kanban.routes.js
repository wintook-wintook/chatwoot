import { frontendURL } from '../../../../helper/URLHelper';
import { ROLES } from 'dashboard/constants/permissions.js';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/kanban'),
      name: 'kanban_types_list',
      meta: {
        permissions: ROLES, // Solo administradores pueden gestionar tipos
        parentNav: 'settings'
      },
      component: () => import('./index.vue'),
    }
  ],
};