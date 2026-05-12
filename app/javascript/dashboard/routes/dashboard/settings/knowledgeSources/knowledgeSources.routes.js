// ================================================================================
// @knowledge_sources
// Define las rutas de Vue Router para el módulo Base de Conocimiento.
// Path: /settings/knowledge-sources/list → KnowledgeSourcesHome (Index.vue)
// ================================================================================

import { frontendURL } from '../../../../helper/URLHelper';
import {
  ROLES,
  CONVERSATION_PERMISSIONS,
} from 'dashboard/constants/permissions.js';

const SettingsWrapper = () => import('../SettingsWrapper.vue');
const KnowledgeSourcesHome = () => import('./Index.vue');

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/knowledge-sources'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          redirect: 'list',
        },
        {
          path: 'list',
          name: 'knowledge_sources_list',
          meta: {
            permissions: [...ROLES, ...CONVERSATION_PERMISSIONS],
          },
          component: KnowledgeSourcesHome,
        },
      ],
    },
  ],
};
