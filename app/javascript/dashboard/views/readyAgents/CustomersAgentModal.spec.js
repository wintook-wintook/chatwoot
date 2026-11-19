// «Atención a clientes» — el asistente: áreas con sus ejemplos, lo que se manda y la matriz.
import { shallowMount } from '@vue/test-utils';
import ReadyAgentsAPI from 'dashboard/api/readyAgents';
import CustomersAgentModal from './CustomersAgentModal.vue';

const mountModal = props =>
  shallowMount(CustomersAgentModal, {
    propsData: { show: true, ...props },
    mocks: {
      $t: (x, p) => (p ? `${x} ${JSON.stringify(p)}` : x),
      $te: () => false,
      $store: {
        getters: { 'agents/getAgents': [], 'teams/getTeams': [] },
        dispatch: vi.fn(),
      },
    },
    stubs: {
      WootModal: true,
      WootModalHeader: true,
      WootButton: true,
      ReadyAgentChat: true,
      FluentIcon: true,
    },
  });

describe('CustomersAgentModal', () => {
  it('nuevo: Soporte, Comercial y Administrativo prendidos con los ejemplos de la matriz; «Otra» apagada', () => {
    const { vm } = mountModal();
    expect(vm.areasOn).toEqual(['support', 'sales', 'admin']);
    const { areas } = vm.payload().settings;
    expect(areas.support.examples_yes).toContain(
      'No puedo enviar una cotización a pedido'
    );
    expect(areas.sales.examples_no).toContain('La cotización no se genera');
    expect(areas.other.on).toBe(false);
    expect(vm.form.settings).toMatchObject({
      human: 'understand_first',
      not_client: 'serve',
    });
  });

  it('los ejemplos vacíos no se mandan y se pueden quitar', () => {
    const { vm } = mountModal();
    vm.removeExample('admin', 'examples_yes', 0);
    vm.addExample('admin', 'examples_yes');
    vm.area('admin').examples_yes.at(-1).text = '  Quiero mi estado de cuenta ';
    vm.addExample('admin', 'examples_yes');
    const { examples_yes: yes } = vm.payload().settings.areas.admin;
    expect(yes).not.toContain('Mi factura tiene mal el RFC');
    expect(yes.at(-1)).toBe('Quiero mi estado de cuenta');
  });

  it('un agente guardado: sus ejemplos mandan (aunque haya quitado todos) y no se puede guardar sin áreas', () => {
    const { vm } = mountModal({
      agent: {
        id: 3,
        name: 'Clientes',
        inbox_ids: [1],
        settings: {
          areas: {
            support: { on: true, examples_yes: [], examples_no: ['Hola'] },
            sales: { on: false },
            admin: { on: false },
          },
        },
      },
    });
    expect(vm.area('support').examples_yes).toEqual([]);
    expect(vm.area('support').examples_no.map(e => e.text)).toEqual(['Hola']);
    expect(vm.canSave).toBeTruthy();
    vm.area('support').on = false;
    expect(vm.canSave).toBeFalsy();
  });

  it('«Probar la matriz» manda lo del asistente y cuenta los aciertos', async () => {
    const spy = vi.spyOn(ReadyAgentsAPI, 'matrix').mockResolvedValue({
      data: {
        rows: [
          {
            example: 'No abre',
            area: 'support',
            kind: 'yes',
            got: 'support',
            ok: true,
          },
          {
            example: 'Una demo',
            area: 'support',
            kind: 'no',
            got: 'support',
            ok: false,
          },
        ],
      },
    });
    const { vm } = mountModal();
    vm.form.name = 'Clientes';
    await vm.runMatrix();
    expect(spy.mock.calls[0][0].settings.areas.support.on).toBe(true);
    expect(vm.matrixOk).toBe(1);
    expect(vm.matrixRow(vm.matrix[1])).toContain('❌');
  });
});
