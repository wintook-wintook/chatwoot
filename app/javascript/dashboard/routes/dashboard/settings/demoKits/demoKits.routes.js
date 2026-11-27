import { frontendURL } from '../../../../helper/URLHelper';

const SettingsContent = () => import('../Wrapper.vue');
const DemoKits = () => import('./DemoKits.vue');

// Ajustes › Demostraciones (solo administradores).
export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/demo-kits'),
      component: SettingsContent,
      props: {
        headerTitle: 'DEMO_KITS.HEADER',
        icon: 'cloud-backup',
        showNewButton: false,
      },
      meta: { permissions: ['administrator'] },
      children: [
        {
          path: '',
          name: 'demo_kits',
          component: DemoKits,
          meta: { permissions: ['administrator'] },
        },
      ],
    },
  ],
};
