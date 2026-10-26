import { shallowMount } from '@vue/test-utils';
import ProofreadBar from './ProofreadBar.vue';
import AssistantAPI from 'dashboard/api/assistant';

// proyecto@asistente_agentes_ia — "Mejorar la redacción", en cualquier campo.
vi.mock('dashboard/api/assistant', () => ({
  default: { proofread: vi.fn() },
}));

const montar = (props = {}) =>
  shallowMount(ProofreadBar, {
    propsData: { text: 'no me deja entrar', kind: 'route_phrases', ...props },
    mocks: {
      $t: (clave, args) => (args ? `${clave} ${JSON.stringify(args)}` : clave),
    },
    stubs: ['woot-button'],
  });

describe('ProofreadBar', () => {
  beforeEach(() => AssistantAPI.proofread.mockReset());

  it('le dice al backend qué campo es y entrega el texto corregido', async () => {
    AssistantAPI.proofread.mockResolvedValue({
      data: { text: 'no me deja entrar.', notes: ['punto final'] },
    });
    const wrapper = montar();

    await wrapper.vm.run();

    expect(AssistantAPI.proofread).toHaveBeenCalledWith(
      'no me deja entrar',
      'route_phrases',
      null
    );
    expect(wrapper.emitted('input')[0]).toEqual(['no me deja entrar.']);
    expect(wrapper.vm.notes).toEqual(['punto final']);
  });

  // La corrección se propone, no se impone.
  it('vuelve al original con un clic', async () => {
    AssistantAPI.proofread.mockResolvedValue({ data: { text: 'corregido' } });
    const wrapper = montar();

    await wrapper.vm.run();
    wrapper.vm.undo();

    expect(wrapper.emitted('input')[1]).toEqual(['no me deja entrar']);
    expect(wrapper.vm.previous).toBe(null);
  });

  // Si el backend la descartó por tocar sintaxis del motor o un número, se dice qué.
  it('dice qué intentó cambiar la corrección descartada', async () => {
    const error = new Error('422');
    error.response = {
      data: { error: 'changed_protected', lost: ['@buscar_articulo'] },
    };
    // Una función común y no el espía: en vitest 2.0.1 un vi.fn que devuelve una
    // promesa rechazada deja un rechazo "sin manejar" aunque el componente lo
    // atrape, y la prueba falla por eso y no por el componente.
    const espia = AssistantAPI.proofread;
    AssistantAPI.proofread = () => Promise.reject(error);
    try {
      const wrapper = montar();

      await wrapper.vm.run();

      expect(wrapper.vm.error).toContain('FIX_PROTECTED');
      expect(wrapper.vm.error).toContain('@buscar_articulo');
      expect(wrapper.emitted('input')).toBeUndefined();
    } finally {
      AssistantAPI.proofread = espia;
    }
  });

  it('no llama al modelo con el campo vacío', async () => {
    const wrapper = montar({ text: '   ' });

    await wrapper.vm.run();

    expect(AssistantAPI.proofread).not.toHaveBeenCalled();
  });
});
