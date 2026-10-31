import { shallowMount } from '@vue/test-utils';
import WhatsappTemplateHeaderAPI from 'dashboard/api/whatsappTemplateHeader';
import TemplateExtraFields from './TemplateExtraFields.vue';

// feat/plantillas_variables_nombre F4 — lo que comparten conversación y programados
vi.mock('dashboard/api/whatsappTemplateHeader', () => ({
  default: { show: vi.fn(), upload: vi.fn() },
}));

const factura = {
  name: 'factura',
  language: 'es_MX',
  components: [
    { type: 'HEADER', format: 'DOCUMENT' },
    { type: 'BODY', text: 'Tu factura {{1}}.' },
    {
      type: 'BUTTONS',
      buttons: [
        { type: 'QUICK_REPLY', text: 'Sí' },
        { type: 'COPY_CODE', text: 'Copiar' },
      ],
    },
  ],
};

const montar = async (propsData = {}) => {
  const wrapper = shallowMount(TemplateExtraFields, {
    propsData: { template: factura, enabled: true, inboxId: 1, ...propsData },
    mocks: { $t: clave => clave },
    stubs: ['woot-button', 'woot-input'],
  });
  await new Promise(resolve => {
    setTimeout(resolve);
  });
  return wrapper;
};

describe('TemplateExtraFields', () => {
  beforeEach(() => {
    WhatsappTemplateHeaderAPI.show.mockReset();
    WhatsappTemplateHeaderAPI.show.mockResolvedValue({
      data: { available: true, media_name: 'F.pdf', preview_url: 'https://x' },
    });
  });

  it('trae elegido el archivo de la plantilla y avisa los valores', async () => {
    const wrapper = await montar();

    expect(wrapper.vm.mediaSource).toBe('template');
    const ultimo = wrapper.emitted('change').slice(-1)[0][0];
    expect(ultimo.templateFile).toMatchObject({ media_name: 'F.pdf' });
    expect(ultimo.buttons).toEqual({ 1: '' });
  });

  it('al editar respeta lo que ya se había elegido', async () => {
    const wrapper = await montar({
      initial: {
        mediaSource: 'link',
        mediaUrl: 'https://x.mx/f.pdf',
        buttons: { 1: 'PROMO10' },
      },
    });

    expect(wrapper.vm.mediaSource).toBe('link');
    expect(wrapper.vm.mediaUrl).toBe('https://x.mx/f.pdf');
    expect(wrapper.vm.buttonParams).toEqual({ 1: 'PROMO10' });
  });

  it('sin enabled no pide nada ni consulta el archivo', async () => {
    const wrapper = await montar({ enabled: false });

    expect(wrapper.vm.paramButtons).toEqual([]);
    expect(WhatsappTemplateHeaderAPI.show).not.toHaveBeenCalled();
  });
});
