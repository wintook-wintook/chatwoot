// Embudo de contactos — «Al soltar una tarjeta aquí, crear la oportunidad» muestra el tipo
// guardado aunque las opciones lleguen después de abrir.
import { shallowMount } from '@vue/test-utils';
import CaseTypesAPI from 'dashboard/api/caseTypes';
import ColumnFunnelFields from '../ColumnFunnelFields.vue';

vi.mock('dashboard/api/caseTypes', () => ({ default: { getAll: vi.fn() } }));
vi.mock('dashboard/helper/caseClasses', () => ({
  creatableTypes: list => list,
}));

const flush = () =>
  new Promise(resolve => {
    setTimeout(resolve);
  });

const mountFields = value =>
  shallowMount(ColumnFunnelFields, {
    propsData: { value },
    mocks: {
      $t: key => key,
      $store: { getters: { 'labels/getLabels': [] }, dispatch: vi.fn() },
    },
  });

describe('ColumnFunnelFields', () => {
  it('con las opciones ya cargadas, el select muestra el tipo guardado', async () => {
    CaseTypesAPI.getAll.mockResolvedValue({
      data: {
        case_types: [{ id: 5, name: 'Oportunidad', case_class: 'commercial' }],
      },
    });
    const wrapper = mountFields({
      stage_kind: 'converted',
      convert_case_type_id: 5,
    });
    await flush();
    await wrapper.vm.$nextTick();
    const select = wrapper.findAll('select').at(1);
    expect(select.element.value).toBe('5');
  });

  it('si el tipo guardado ya no se puede crear, lo conserva en vez de mostrar «Ninguno»', async () => {
    CaseTypesAPI.getAll.mockResolvedValue({ data: { case_types: [] } });
    const wrapper = mountFields({
      stage_kind: 'converted',
      convert_case_type_id: 9,
    });
    await flush();
    await wrapper.vm.$nextTick();
    expect(wrapper.vm.savedTypeMissing).toBe(true);
    expect(wrapper.findAll('select').at(1).element.value).toBe('9');
  });
});
