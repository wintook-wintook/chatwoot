// ================================================================================
// proyecto@tracking_templates
// ================================================================================
// Rutas: Settings > Plantillas de Seguimiento
// Path: accounts/:accountId/settings/tracking-templates/list
// ================================================================================

import { frontendURL } from '../../../../helper/URLHelper';
import {
  ROLES,
  CONVERSATION_PERMISSIONS,
} from 'dashboard/constants/permissions.js';

const SettingsWrapper = () => import('../SettingsWrapper.vue');
const TrackingTemplatesIndex = () => import('./Index.vue');

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/tracking-templates'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          redirect: 'list',
        },
        {
          path: 'list',
          name: 'tracking_templates_list',
          meta: {
            permissions: [...ROLES, ...CONVERSATION_PERMISSIONS],
          },
          component: TrackingTemplatesIndex,
        },
      ],
    },
  ],
};
