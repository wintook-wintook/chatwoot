import settings from './settings/settings.routes';
import conversation from './conversation/conversation.routes';
import { routes as searchRoutes } from '../../modules/search/search.routes';
import { routes as contactRoutes } from './contacts/routes';
import { routes as notificationRoutes } from './notifications/routes';
import { routes as inboxRoutes } from './inbox/routes';
import { frontendURL } from '../../helper/URLHelper';
import helpcenterRoutes from './helpcenter/helpcenter.routes';

// KANBAN0725
import { routes as kanbanRoutes } from './kanban/routes'; // Añade esta línea
// KANBAN0725
// @tickets_cases
import { routes as gestorTicketsRoutes } from './gestorTickets/routes';
// proyecto@contact_tracking — Dashboard de Seguimientos
import { routes as contactTrackingsRoutes } from './contactTrackings/routes';

const AppContainer = () => import('./Dashboard.vue');
const Captain = () => import('./Captain.vue');
const Suspended = () => import('./suspended/Index.vue');

export default {
  routes: [
    ...helpcenterRoutes.routes,
    {
      path: frontendURL('accounts/:account_id'),
      component: AppContainer,
      children: [
        {
          path: frontendURL('accounts/:accountId/captain'),
          name: 'captain',
          component: Captain,
          meta: {
            permissions: ['administrator', 'agent', 'custom_role'],
          },
        },
        ...inboxRoutes,
        ...conversation.routes,
        ...settings.routes,
        ...contactRoutes,
        ...searchRoutes,
        ...notificationRoutes,
        // KANBAN0725
        ...kanbanRoutes,
        // KANBAN0725
        // @tickets_cases
        ...gestorTicketsRoutes,
        // proyecto@contact_tracking — Dashboard de Seguimientos
        ...contactTrackingsRoutes,
      ],
    },
    {
      path: frontendURL('accounts/:accountId/suspended'),
      name: 'account_suspended',
      meta: {
        permissions: ['administrator', 'agent', 'custom_role'],
      },
      component: Suspended,
    },
  ],
};
