// Pestaña «Casos relacionados»: crear de cualquier tipo y ligar como «Relacionado».
import { shallowMount } from '@vue/test-utils';
import CaseTicketsAPI from 'dashboard/api/caseTickets';
import CaseRelations from '../CaseRelations.vue';

vi.mock('dashboard/api/caseTickets', () => ({
  default: {
    createRelation: vi.fn(),
    getAll: vi.fn(),
    deleteRelation: vi.fn(),
  },
}));

const TYPES = [
  { id: 1, name: 'Venta', case_class: 'commercial' },
  { id: 2, name: 'Soporte', case_class: 'support' },
  { id: 3, name: 'Viejo', case_class: 'support', retired: true },
];

const mountTab = () =>
  shallowMount(CaseRelations, {
    propsData: { ticket: { id: 9, title: 'Licencias' }, relations: [] },
    mocks: {
      $t: key => key,
      $store: { getters: { 'caseTickets/getTypes': TYPES }, dispatch: vi.fn() },
      $emitter: { emit: vi.fn() },
    },
  });

describe('CaseRelations', () => {
  it('ofrece crear cualquier tipo activo, no solo los de Servicio', () => {
    const wrapper = mountTab();
    expect(wrapper.vm.createTypes.map(t => t.id)).toEqual([1, 2]);
  });

  it('crear manda el tipo y el título; ligar manda «related» por omisión', async () => {
    CaseTicketsAPI.createRelation.mockResolvedValue({});
    const wrapper = mountTab();
    wrapper.vm.openCreate();
    wrapper.vm.form.case_type_id = 2;
    await wrapper.vm.submitCreate();
    expect(CaseTicketsAPI.createRelation).toHaveBeenCalledWith(9, {
      case_type_id: 2,
      title: 'Licencias',
    });
    wrapper.vm.openLink();
    await wrapper.vm.link({ id: 15 });
    expect(CaseTicketsAPI.createRelation).toHaveBeenLastCalledWith(9, {
      related_ticket_id: 15,
      relation_type: 'related',
    });
    expect(wrapper.emitted().changed).toHaveLength(2);
  });
});
