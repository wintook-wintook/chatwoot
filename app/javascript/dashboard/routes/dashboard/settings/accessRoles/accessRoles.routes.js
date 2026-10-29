// Plan-Roles-Permisos P3 — Ajustes › Roles.
import { frontendURL } from '../../../../helper/URLHelper';

const SettingsWrapper = () => import('../SettingsWrapper.vue');
const AccessRolesHome = () => import('./Index.vue');

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/roles'),
      component: SettingsWrapper,
      children: [
        { path: '', redirect: 'list' },
        {
          path: 'list',
          name: 'access_roles_list',
          component: AccessRolesHome,
          meta: { permissions: ['administrator'] },
        },
      ],
    },
  ],
};
