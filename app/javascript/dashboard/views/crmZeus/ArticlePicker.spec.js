import { shallowMount } from '@vue/test-utils';
import ArticlePicker from './ArticlePicker.vue';

vi.mock('dashboard/api/crmArticles', () => ({ default: { list: vi.fn() } }));

const RESULTS = [
  { id: 1, name: 'Tornillo', is_kit: false, is_stockable: true },
  { id: 2, name: 'Kit almacenable', is_kit: true, is_stockable: true },
  { id: 3, name: 'Kit de seguridad', is_kit: true, is_stockable: false },
];

const opciones = props => {
  const wrapper = shallowMount(ArticlePicker, {
    propsData: props,
    mocks: { $t: clave => clave },
  });
  wrapper.vm.results = RESULTS;
  return wrapper.vm.options.map(article => article.id);
};

describe('CrmArticlePicker', () => {
  it('sin opciones no ofrece kits', () => {
    expect(opciones({})).toEqual([1]);
  });

  it('para componentes de una cotización ofrece el kit almacenable (master2)', () => {
    expect(opciones({ allowStockableKits: true, excludeIds: [1] })).toEqual([
      2,
    ]);
  });

  it('para la partida ofrece todos los kits', () => {
    expect(opciones({ allowKits: true })).toEqual([1, 2, 3]);
  });
});
