// feat/licencias (F5) — Configuración › Licencia: la cuenta ve su propia licencia, en solo lectura.
import { frontendURL } from '../../../../helper/URLHelper';

const SettingsWrapper = () => import('../SettingsWrapper.vue');
const LicenseHome = () => import('./Index.vue');

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/license'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          name: 'account_license_index',
          meta: { permissions: ['administrator'] },
          component: LicenseHome,
        },
      ],
    },
  ],
};
