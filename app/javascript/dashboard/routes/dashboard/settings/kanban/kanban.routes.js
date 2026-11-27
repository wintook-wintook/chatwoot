import { frontendURL } from '../../../../helper/URLHelper';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/kanban'),
      name: 'kanban_types_list',
      meta: {
        // Igual que el menú y KanbanTypeProcessPolicy: solo el Administrador los cambia.
        permissions: ['administrator'],
        parentNav: 'settings',
      },
      component: () => import('./index.vue'),
    },
  ],
};
