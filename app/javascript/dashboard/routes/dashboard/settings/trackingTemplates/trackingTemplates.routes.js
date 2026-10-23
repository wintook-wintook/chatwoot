// ================================================================================
// proyecto@tracking_templates
// ================================================================================
// Rutas: Settings > Agentes IA (tracking templates)
// Path: accounts/:accountId/settings/tracking-templates/list
// ================================================================================

import { frontendURL } from '../../../../helper/URLHelper';
import {
  ROLES,
  CONVERSATION_PERMISSIONS,
} from 'dashboard/constants/permissions.js';

const SettingsWrapper = () => import('../SettingsWrapper.vue');

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
          // feat/agentes_ia_unificado: una sola lista de Agentes IA (la de
          // Seguimientos). La de Ajustes lleva allá, conservando ?template_id.
          redirect: to => ({
            name: 'contact_trackings_agents',
            params: { accountId: to.params.accountId },
            query: to.query,
          }),
        },
      ],
    },
  ],
};
