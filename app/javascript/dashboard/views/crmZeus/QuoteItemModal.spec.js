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

  it('quita solo componentes reemplazables y no acepta el kit vacío', async () => {
    const wrapper = montar(blankItem());
    await wrapper.vm.pickArticle({ id: 9 });
    wrapper.vm.removeComponent(1);
    expect(wrapper.vm.form.components).toHaveLength(2);

    wrapper.vm.removeComponent(0);
    expect(wrapper.vm.form.components.map(c => c.key)).toEqual(['GUA-1']);

    wrapper.vm.form.components = [];
    wrapper.vm.save();
    expect(wrapper.emitted('save')).toBeUndefined();
    expect(wrapper.vm.error).toBe('CRM_ZEUS.QUOTE_FORM.KIT_WITHOUT_COMPONENTS');
  });

  it('agrega un componente con 1 unidad por kit, editable y que se puede quitar', async () => {
    const wrapper = montar(blankItem());
    await wrapper.vm.pickArticle({ id: 9 });
    wrapper.vm.addComponent({ id: 40, key: 'LEN-1', name: 'Lentes' });

    expect(wrapper.vm.form.components[2]).toMatchObject({
      article_id: 40,
      description: 'Lentes',
      units_per_kit: 1,
      quantity: 3,
      replaceable: true,
      units_editable: true,
    });
    expect(wrapper.vm.componentExcludeIds(-1)).toEqual([9, 20, 21, 40]);
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
        { id: 8, article_id: 40, description: 'Lentes', quantity: 2 },
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
      [1, true, true],
    ]);
    wrapper.vm.save();
    expect(wrapper.emitted('save')[0][0].components).toHaveLength(3);
  });
});

describe('CrmQuoteItemModal (impuestos según el cliente)', () => {
  const TAXES = [
    { id: 1, name: 'IVA 16%', tax_type: 'vat', percent: 16 },
    { id: 2, name: 'Ret. IVA', tax_type: 'vat_withholding', percent: 10.67 },
    { id: 3, name: 'Ret. ISR', tax_type: 'isr_withholding', percent: 10 },
  ];
  const SERVICE = {
    id: 5,
    key: 'SRV-1',
    name: 'Servicio',
    unit: null,
    tax_ids: [1, 2, 3],
    prices: [],
    components: [],
  };
  const elegir = async organization => {
    const wrapper = shallowMount(QuoteItemModal, {
      propsData: { item: blankItem(), taxes: TAXES, organization },
      mocks: { $t: clave => clave },
      stubs: ['woot-modal', 'woot-modal-header', 'woot-submit-button'],
    });
    await wrapper.vm.pickArticle({ id: 5 });
    return wrapper.vm.form.tax_ids;
  };

  beforeEach(() => {
    CrmArticles.show.mockResolvedValue({ data: { article: SERVICE } });
  });

  it('cobra y no retiene: solo los trasladados', async () => {
    expect(
      await elegir({ id: 7, charge_taxes: true, withholds_taxes: false })
    ).toEqual([1]);
  });

  it('con artículo no se eligen; en la partida libre solo los que aplican', () => {
    const wrapper = shallowMount(QuoteItemModal, {
      propsData: {
        item: blankItem(),
        taxes: TAXES,
        organization: { id: 7, charge_taxes: true, withholds_taxes: false },
      },
      mocks: { $t: clave => clave },
      stubs: ['woot-modal', 'woot-modal-header', 'woot-submit-button'],
    });
    expect(TAXES.map(wrapper.vm.taxSelectable)).toEqual([true, false, false]);

    wrapper.vm.form.article_id = 5;
    expect(TAXES.map(wrapper.vm.taxSelectable)).toEqual([false, false, false]);
  });

  it('retiene y no cobra: solo las retenciones', async () => {
    expect(
      await elegir({ id: 7, charge_taxes: false, withholds_taxes: true })
    ).toEqual([2, 3]);
  });

  describe('precio con impuesto', () => {
    const precio = (unitPrice, taxIds) => {
      const wrapper = shallowMount(QuoteItemModal, {
        propsData: {
          item: { ...blankItem(), unit_price: unitPrice, tax_ids: taxIds },
          taxes: TAXES,
        },
        mocks: { $t: clave => clave },
        stubs: ['woot-modal', 'woot-modal-header', 'woot-submit-button'],
      });
      return wrapper.vm.priceWithTaxes;
    };

    it('solo suma los trasladados, sin restar retenciones', () => {
      expect(precio(100, [1, 2, 3])).toBe('116.00');
      expect(precio(100, [2, 3])).toBe('100.00');
    });

    it('redondea el precio y el impuesto por separado', () => {
      // 10.555 → 10.56; 10.56 × 16 % = 1.6896 → 1.69; total 12.25
      // (redondeando una sola vez daría 10.555 × 1.16 = 12.2438 → 12.24).
      expect(precio(10.555, [1])).toBe('12.25');
    });

    it('sin precio enseña cero', () => {
      expect(precio('', [1])).toBe('0.00');
    });
  });

  describe('importe y con impuesto', () => {
    const importes = item =>
      shallowMount(QuoteItemModal, {
        propsData: { item: { ...blankItem(), ...item }, taxes: TAXES },
        mocks: { $t: clave => clave },
        stubs: ['woot-modal', 'woot-modal-header', 'woot-submit-button'],
      }).vm.amounts;

    it('cantidad × precio menos descuento; solo suma los trasladados', () => {
      expect(
        importes({
          quantity: 3,
          unit_price: 100,
          discount_percent: 10,
          tax_ids: [1, 2, 3],
        })
      ).toEqual({ amount: '270.00', amountWithTaxes: '313.20' });
    });

    it('redondea el bruto, el descuento y el impuesto por separado', () => {
      // 1 × 10.125 → 10.13; descuento 10.13 × 10 % = 1.013 → 1.01; neto 9.12;
      // IVA 9.12 × 16 % = 1.4592 → 1.46; con impuesto 10.58.
      expect(
        importes({
          quantity: 1,
          unit_price: 10.125,
          discount_percent: 10,
          tax_ids: [1],
        })
      ).toEqual({ amount: '9.12', amountWithTaxes: '10.58' });
    });

    it('sin cantidad ni precio enseña cero', () => {
      expect(importes({ quantity: '', unit_price: '', tax_ids: [1] })).toEqual({
        amount: '0.00',
        amountWithTaxes: '0.00',
      });
    });
  });
});
