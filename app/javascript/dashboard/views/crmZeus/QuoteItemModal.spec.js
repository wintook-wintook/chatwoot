import { shallowMount } from '@vue/test-utils';
import CrmArticles from 'dashboard/api/crmArticles';
import QuoteItemModal from './QuoteItemModal.vue';

vi.mock('dashboard/api/crmArticles', () => ({
  default: { show: vi.fn(), list: vi.fn() },
}));

const flushPromises = () =>
  new Promise(resolve => {
    setTimeout(resolve);
  });

const KIT = {
  id: 9,
  key: 'KIT-1',
  name: 'Kit de seguridad',
  unit: null,
  is_kit: true,
  is_stockable: false,
  tax_ids: [1],
  prices: [],
  components: [
    {
      component_id: 20,
      key: 'CAS-1',
      name: 'Casco',
      unit: 'PZA',
      quantity: 1,
      replaceable: true,
      units_editable: false,
    },
    {
      component_id: 21,
      key: 'GUA-1',
      name: 'Guantes',
      unit: 'PAR',
      quantity: 2,
      replaceable: false,
      units_editable: true,
    },
  ],
};

const blankItem = () => ({
  role: 'normal',
  article_id: null,
  description: '',
  quantity: 3,
  unit_price: 0,
  discount_percent: 0,
  tax_ids: [],
});

const montar = item =>
  shallowMount(QuoteItemModal, {
    propsData: { item },
    mocks: { $t: clave => clave },
    stubs: ['woot-modal', 'woot-modal-header', 'woot-submit-button'],
  });

describe('CrmQuoteItemModal (kits)', () => {
  beforeEach(() => {
    CrmArticles.show.mockResolvedValue({ data: { article: KIT } });
  });

  it('al elegir un kit no almacenable trae sus componentes por la cantidad', async () => {
    const wrapper = montar(blankItem());
    await wrapper.vm.pickArticle({ id: 9 });

    expect(wrapper.vm.form.role).toBe('kit');
    expect(
      wrapper.vm.form.components.map(c => [c.key, c.units_per_kit, c.quantity])
    ).toEqual([
      ['CAS-1', 1, 3],
      ['GUA-1', 2, 6],
    ]);
  });

  it('un kit almacenable se cotiza como artículo normal', async () => {
    CrmArticles.show.mockResolvedValue({
      data: { article: { ...KIT, is_stockable: true } },
    });
    const wrapper = montar(blankItem());
    await wrapper.vm.pickArticle({ id: 9 });

    expect(wrapper.vm.form.role).toBe('normal');
    expect(wrapper.vm.form.components).toEqual([]);
  });

  it('recalcula las unidades al cambiar la cantidad o las unidades por kit', async () => {
    const wrapper = montar(blankItem());
    await wrapper.vm.pickArticle({ id: 9 });
    wrapper.vm.form.quantity = 5;
    await wrapper.vm.$nextTick();
    wrapper.vm.setUnitsPerKit(1, '3');

    expect(wrapper.vm.form.components.map(c => c.quantity)).toEqual([5, 15]);
  });

  it('reemplaza un componente por otro artículo', async () => {
    const wrapper = montar(blankItem());
    await wrapper.vm.pickArticle({ id: 9 });
    wrapper.vm.replaceComponent(0, {
      id: 30,
      key: 'CAS-2',
      name: 'Casco rojo',
    });

    expect(wrapper.vm.form.components[0]).toMatchObject({
      article_id: 30,
      description: 'Casco rojo',
      quantity: 3,
    });
    expect(wrapper.vm.componentExcludeIds(0)).toEqual([9, 21]);
  });

  it('un kit sin componentes no se puede elegir', async () => {
    CrmArticles.show.mockResolvedValue({
      data: { article: { ...KIT, components: [] } },
    });
    const wrapper = montar(blankItem());
    await wrapper.vm.pickArticle({ id: 9 });

    expect(wrapper.vm.form.article_id).toBeNull();
    expect(wrapper.vm.error).toBe('CRM_ZEUS.QUOTE_FORM.KIT_WITHOUT_COMPONENTS');
  });

  it('una partida guardada deduce las unidades por kit y toma las reglas del catálogo', async () => {
    const wrapper = montar({
      ...blankItem(),
      id: 5,
      uid: 1,
      role: 'kit',
      article_id: 9,
      description: 'Kit de seguridad',
      quantity: 2,
      components: [
        { id: 6, article_id: 20, description: 'Casco', quantity: 2 },
        { id: 7, article_id: 21, description: 'Guantes', quantity: 8 },
      ],
    });
    await flushPromises();

    expect(
      wrapper.vm.form.components.map(c => [
        c.units_per_kit,
        c.replaceable,
        c.units_editable,
      ])
    ).toEqual([
      [1, true, false],
      [4, false, true],
    ]);
    wrapper.vm.save();
    expect(wrapper.emitted('save')[0][0].components).toHaveLength(2);
  });
});
