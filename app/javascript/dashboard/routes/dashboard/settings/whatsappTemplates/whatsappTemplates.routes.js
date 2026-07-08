// @waba_templates — sección de Configuración: plantillas de WhatsApp (todos los canales).
import { frontendURL } from '../../../../helper/URLHelper';

const SettingsWrapper = () => import('../SettingsWrapper.vue');
const Index = () => import('./Index.vue');

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/whatsapp-templates'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          name: 'whatsapp_templates_wrapper',
          meta: {
            permissions: ['administrator'],
          },
          redirect: 'list',
        },
        {
          path: 'list',
          name: 'whatsapp_templates_index',
          meta: {
            permissions: ['administrator'],
          },
          component: Index,
        },
      ],
    },
  ],
};
