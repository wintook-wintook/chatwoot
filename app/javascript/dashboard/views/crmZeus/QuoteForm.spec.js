import { shallowMount } from '@vue/test-utils';
import CrmQuotes from 'dashboard/api/crmQuotes';
import CrmOrganizations from 'dashboard/api/crmOrganizations';
import CrmCatalogs from 'dashboard/api/crmCatalogs';
import QuoteForm from './QuoteForm.vue';
import { addDays } from './crmHelpers';

vi.mock('dashboard/api/crmQuotes', () => ({
  default: {
    show: vi.fn(),
    draft: vi.fn(),
    duplicate: vi.fn(),
    calculate: vi.fn(),
    create: vi.fn(),
    update: vi.fn(),
    changeStatus: vi.fn(),
  },
}));
vi.mock('dashboard/api/crmOrganizations', () => ({
  default: { contacts: vi.fn(), consignees: vi.fn() },
}));
vi.mock('dashboard/api/crmCatalogs', () => ({ default: { fetch: vi.fn() } }));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

const flushPromises = () =>
  new Promise(resolve => {
    setTimeout(resolve);
  });

const ACEROS = { id: 7, name: 'Aceros', organization_type: 'customer' };
const DRAFT = {
  organization_id: 7,
  organization: ACEROS,
  seller_id: 3,
  payment_term_id: 4,
  currency_id: 1,
  cfdi_use: 'G03',
  quote_date: '2026-11-10',
  extra_discount_type: 'percent',
  extra_discount_value: 0,
  freight: 0,
  other_charges: 0,
  items: [],
  tax_summary: [],
  total: 0,
};

const montar = ({ quoteId = '', query = { organization_id: '7' } } = {}) =>
  shallowMount(QuoteForm, {
    propsData: { quoteId },
    mocks: {
      $t: (clave, args) => (args ? `${clave} ${JSON.stringify(args)}` : clave),
      $route: { params: { accountId: '2' }, query, fullPath: '/x' },
      $router: { push: vi.fn(), replace: vi.fn() },
    },
    stubs: ['woot-button', 'woot-confirm-modal'],
  });

describe('CrmZeusQuoteForm', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    CrmCatalogs.fetch.mockResolvedValue({
      data: {
        sellers: [],
        payment_terms: [],
        currencies: [{ id: 1, iso_code: 'MXN', name: 'Peso' }],
        taxes: [{ id: 16, name: 'IVA 16%', tax_type: 'vat', percent: 16 }],
        lookups: { price_list: [] },
      },
    });
    CrmQuotes.draft.mockResolvedValue({
      data: {
        quote: DRAFT,
        series: { series: 'LAU', next_folio: 'LAU000125' },
      },
    });
    CrmOrganizations.contacts.mockResolvedValue({ data: { contacts: [] } });
    CrmOrganizations.consignees.mockResolvedValue({ data: { consignees: [] } });
  });

  it('arranca como «Cotización NUEVA» con los defaults del cliente, sin anunciar folio', async () => {
    const wrapper = montar();
    await flushPromises();

    expect(CrmQuotes.draft).toHaveBeenCalledWith('7');
    expect(wrapper.vm.quote).toMatchObject({ seller_id: 3, cfdi_use: 'G03' });
    expect(wrapper.vm.editable).toBe(true);
    expect(wrapper.text()).toContain('CRM_ZEUS.QUOTE_FORM.NEW_TITLE');
    expect(wrapper.text()).not.toContain('LAU000125');
  });

  it('manda las partidas sin importes y pinta los que calcula el servidor', async () => {
    CrmQuotes.calculate.mockResolvedValue({
      data: {
        quote: {
          ...DRAFT,
          net_amount: 855,
          total: 991.8,
          items: [{ net_amount: 855, tax_amount: 136.8 }],
        },
      },
    });
    const wrapper = montar();
    await flushPromises();
    wrapper.vm.newItem();
    wrapper.vm.saveItem({
      ...wrapper.vm.itemForm,
      description: 'Tornillo',
      quantity: 10,
      unit_price: 100,
      discount_percent: 14.5,
      tax_ids: [16],
      net_amount: 1,
    });

    const [item] = wrapper.vm.payload().items;
    expect(item).toMatchObject({ description: 'Tornillo', tax_ids: [16] });
    expect(item).not.toHaveProperty('net_amount');
    expect(item).not.toHaveProperty('id');

    await wrapper.vm.recalculate();
    expect(wrapper.vm.totals.total).toBe(991.8);
    expect(wrapper.vm.quote.items[0].net_amount).toBe(855);
  });

  it('una cotización ganada, o de otro agente, no se edita', async () => {
    CrmQuotes.show.mockResolvedValue({
      data: {
        quote: {
          ...DRAFT,
          id: 9,
          folio: 'LAU000125',
          status: 'won',
          can_edit: true,
          transitions: ['lost', 'cancelled'],
        },
      },
    });
    const wrapper = montar({ quoteId: '9', query: {} });
    await flushPromises();

    expect(wrapper.vm.title).toBe(
      'CRM_ZEUS.QUOTE_FORM.EDIT_TITLE {"folio":"LAU000125"}'
    );
    expect(wrapper.vm.editable).toBe(false);
    expect(wrapper.vm.statusActions.map(a => a.status)).toEqual([
      'lost',
      'cancelled',
    ]);
  });

  it('los días de entrega ponen la fecha', () => {
    expect(addDays('2026-11-28', 7)).toBe('2026-12-05');
  });
});
