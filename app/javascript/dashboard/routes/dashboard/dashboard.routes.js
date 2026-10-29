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
import { routes as contractsRoutes } from './contracts/routes'; // Plan-Contratos R1
import { routes as organizationsRoutes } from './organizations/routes'; // Plan-Organizaciones O1
import { routes as eventsRoutes } from './events/routes'; // Plan-Eventos E1
// proyecto@contact_tracking — Dashboard de Seguimientos
import { routes as contactTrackingsRoutes } from './contactTrackings/routes';
import { routes as whatsappCallsRoutes } from './whatsappCalls/routes'; // diag/llamadas_whatsapp

const AppContainer = () => import('./Dashboard.vue');
const Captain = () => import('./Captain.vue');
const Suspended = () => import('./suspended/Index.vue');
// Plan-Trabajo-Campo R2 — portal del técnico (celular, sin el menú).
const FieldApp = () => import('../../views/field/FieldApp.vue');
const FIELD_META = { permissions: ['administrator', 'agent', 'custom_role'] };

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
        ...contractsRoutes,
        ...organizationsRoutes,
        ...eventsRoutes,
        // proyecto@contact_tracking — Dashboard de Seguimientos
        ...contactTrackingsRoutes,
        ...whatsappCallsRoutes,
      ],
    },
    {
      path: frontendURL('accounts/:accountId/campo'),
      name: 'field_route',
      meta: FIELD_META,
      component: FieldApp,
    },
    {
      path: frontendURL('accounts/:accountId/campo/visita/:ticketId'),
      name: 'field_visit',
      meta: FIELD_META,
      component: FieldApp,
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
