// @waba_templates — sección de Configuración: plantillas de WhatsApp (todos los canales).
// feat/plantillas_whatsapp_mejoras F10: crear y editar a página completa (ya no en un modal
// de la lista), con el mismo encabezado nativo que la lista (SettingsLayout +
// BaseSettingsHeader con «← Plantillas de WhatsApp»).
import { frontendURL } from '../../../../helper/URLHelper';

const SettingsWrapper = () => import('../SettingsWrapper.vue');
const Index = () => import('./Index.vue');
const TemplateEditor = () => import('./TemplateEditor.vue');
const TemplateDetail = () => import('./TemplateDetail.vue');

const meta = { permissions: ['administrator'] };

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/whatsapp-templates'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          name: 'whatsapp_templates_wrapper',
          meta,
          redirect: 'list',
        },
        {
          path: 'list',
          name: 'whatsapp_templates_index',
          meta,
          component: Index,
        },
        {
          path: 'new',
          name: 'whatsapp_templates_new',
          meta,
          component: TemplateEditor,
        },
        // Después de 'list' y 'new': si no, ':templateId' también las atraparía.
        {
          path: ':templateId',
          name: 'whatsapp_templates_show',
          meta,
          component: TemplateDetail,
        },
        {
          path: ':templateId/edit',
          name: 'whatsapp_templates_edit',
          meta,
          component: TemplateEditor,
        },
      ],
    },
  ],
};
