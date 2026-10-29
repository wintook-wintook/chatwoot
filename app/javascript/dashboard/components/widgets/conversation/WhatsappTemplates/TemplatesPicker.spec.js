import { shallowMount } from '@vue/test-utils';
import TemplatesPicker from './TemplatesPicker.vue';

// feat/plantillas_whatsapp_mejoras F2: las de archivo solo se ofrecen en WhatsApp Cloud.
const plantillas = [
  {
    name: 'saludo',
    status: 'APPROVED',
    language: 'es_MX',
    category: 'UTILITY',
    components: [{ type: 'BODY', text: 'Hola' }],
  },
  {
    name: 'factura',
    status: 'APPROVED',
    language: 'es_MX',
    category: 'UTILITY',
    components: [
      { type: 'HEADER', format: 'DOCUMENT' },
      { type: 'BODY', text: 'Tu factura' },
      { type: 'BUTTONS', buttons: [{ type: 'URL', text: 'Ver', url: 'x' }] },
    ],
  },
];

const montar = provider =>
  shallowMount(TemplatesPicker, {
    propsData: { inboxId: 1 },
    mocks: {
      $t: clave => clave,
      $store: {
        getters: {
          'inboxes/getWhatsAppTemplates': () => plantillas,
          'inboxes/getInbox': () => ({ id: 1, provider }),
        },
      },
    },
    stubs: ['fluent-icon'],
  });

describe('TemplatesPicker', () => {
  it('en WhatsApp Cloud ofrece también las de archivo, con su encabezado y botones', () => {
    const wrapper = montar('whatsapp_cloud');

    expect(wrapper.vm.filteredTemplateMessages.map(t => t.name)).toEqual([
      'saludo',
      'factura',
    ]);
    expect(wrapper.text()).toContain(
      'WHATSAPP_TEMPLATES.PARSER.MEDIA_DOCUMENT'
    );
    expect(wrapper.text()).toContain('Ver');
  });

  it('en 360dialog o UnoAPI las de archivo siguen ocultas', () => {
    expect(
      montar('default').vm.filteredTemplateMessages.map(t => t.name)
    ).toEqual(['saludo']);
  });
});
