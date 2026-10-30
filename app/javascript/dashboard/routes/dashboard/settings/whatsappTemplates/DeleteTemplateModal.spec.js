import { shallowMount } from '@vue/test-utils';
import WhatsappTemplatesAPI from 'dashboard/api/whatsapp/templates';
import DeleteTemplateModal from './DeleteTemplateModal.vue';

// feat/plantillas_whatsapp_mejoras — borrar sabiendo qué se rompe
vi.mock('dashboard/api/whatsapp/templates', () => ({
  default: { usage: vi.fn() },
}));

const sinUso = {
  agents: [],
  trackings_count: 0,
  campaigns: [],
  portals: [],
};
const enMeta = { id: 7, name: 'pago', status: 'APPROVED', local_only: false };

const montar = async (template = enMeta) => {
  const wrapper = shallowMount(DeleteTemplateModal, {
    propsData: { template },
    mocks: { $t: clave => clave },
    stubs: ['woot-modal-header', 'woot-button', 'router-link'],
  });
  await new Promise(resolve => {
    setTimeout(resolve);
  });
  return wrapper;
};

describe('DeleteTemplateModal', () => {
  it('sin uso se borra directo; el mensaje depende de si llegó a Meta', async () => {
    WhatsappTemplatesAPI.usage.mockResolvedValue({ data: sinUso });

    const wrapper = await montar();
    expect(wrapper.vm.canDelete).toBe(true);
    expect(wrapper.vm.description).toBe('WHATSAPP_TEMPLATE_DELETE.IN_META');

    const borrador = await montar({
      ...enMeta,
      status: 'DRAFT',
      local_only: true,
    });
    expect(borrador.vm.description).toBe('WHATSAPP_TEMPLATE_DELETE.DRAFT');
  });

  it('en uso pide marcar la casilla', async () => {
    WhatsappTemplatesAPI.usage.mockResolvedValue({
      data: { ...sinUso, trackings_count: 14 },
    });

    const wrapper = await montar();
    expect(wrapper.vm.canDelete).toBe(false);

    await wrapper.setData({ acknowledged: true });
    expect(wrapper.vm.canDelete).toBe(true);
    expect(wrapper.vm.confirmLabel).toBe(
      'WHATSAPP_TEMPLATE_DELETE.CONFIRM_ANYWAY'
    );
  });

  it('si no se pudo revisar el uso también pide la casilla', async () => {
    WhatsappTemplatesAPI.usage.mockRejectedValue(new Error('500'));

    const wrapper = await montar();

    expect(wrapper.vm.usageFailed).toBe(true);
    expect(wrapper.vm.canDelete).toBe(false);
  });
});
