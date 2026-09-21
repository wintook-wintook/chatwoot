import { shallowMount } from '@vue/test-utils';
import Console from '../Console.vue';

// proyecto@erp_productos — F4: "Probar como el agente" en la Consola ERP.
const search = {
  id: 7,
  name: 'buscar_productos',
  params_schema: [
    { key: 'texto', type: 'words' },
    { key: 'con_existencia', type: 'boolean' },
  ],
};
const saldo = { id: 8, name: 'saldo_cliente', params_schema: [{ key: 'rfc' }] };

const mountConsole = dispatch =>
  shallowMount(Console, {
    mocks: {
      $t: key => key,
      $store: { dispatch },
    },
    computed: {
      catalog: () => [{ id: 1, name: 'SAE', queries: [search, saldo] }],
      uiFlags: () => ({ runningQuery: false }),
    },
    stubs: ['woot-button'],
  });

describe('Consola ERP · Probar como el agente', () => {
  it('solo aparece en consultas de búsqueda', async () => {
    const wrapper = mountConsole(vi.fn().mockResolvedValue());
    await wrapper.setData({ connectionId: 1, queryId: 7 });
    expect(wrapper.text()).toContain('ERP.CONSOLE.AGENT_TITLE');

    await wrapper.setData({ queryId: 8 });
    expect(wrapper.text()).not.toContain('ERP.CONSOLE.AGENT_TITLE');
  });

  it('manda el mensaje y muestra lo que llenó la IA y si fue parcial', async () => {
    const dispatch = vi.fn().mockImplementation(action =>
      action === 'externalDb/tryAsked'
        ? Promise.resolve({
            use: true,
            params: { texto: 'toshiba' },
            partial: true,
            columns: ['NOMBRE'],
            rows: [{ NOMBRE: 'AIERE ACONDICIONADO TOSHIBA' }],
          })
        : Promise.resolve()
    );
    const wrapper = mountConsole(dispatch);
    await wrapper.setData({
      connectionId: 1,
      queryId: 7,
      agentMessage: '¿tienen aire toshiba?',
    });

    await wrapper.vm.tryAsAgent();
    await wrapper.vm.$nextTick();

    expect(dispatch).toHaveBeenCalledWith('externalDb/tryAsked', {
      queryId: 7,
      message: '¿tienen aire toshiba?',
    });
    expect(wrapper.text()).toContain('texto = toshiba');
    expect(wrapper.text()).toContain('ERP.CONSOLE.AGENT_PARTIAL');
    expect(wrapper.text()).toContain('AIERE ACONDICIONADO TOSHIBA');
  });

  it('los sí/no se eligen con un selector', async () => {
    const wrapper = mountConsole(vi.fn().mockResolvedValue());
    await wrapper.setData({ connectionId: 1, queryId: 7 });

    const selects = wrapper.findAll('select');
    expect(
      selects.wrappers.some(s => s.text().includes('ERP.CONSOLE.YES'))
    ).toBe(true);
  });
});
