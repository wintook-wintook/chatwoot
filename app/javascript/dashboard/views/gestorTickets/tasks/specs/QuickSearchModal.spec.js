import QuickSearchModal from '../QuickSearchModal.vue';
import GlobalSearchAPI from 'dashboard/api/globalSearch';

// La lupa (Ctrl + K) busca en contactos, organizaciones y casos con una sola
// llamada (GlobalSearchAPI); «ver más» de una pestaña pide ese tipo por páginas.
vi.mock('dashboard/api/globalSearch', () => ({ default: { search: vi.fn() } }));

const group = (items, count = items.length) => ({ count, items });
const response = ({ contacts = [], organizations = [], cases = [] } = {}) => ({
  data: {
    contacts: group(contacts),
    organizations: group(organizations),
    cases: group(cases),
  },
});

const { methods } = QuickSearchModal;
const context = query => {
  const ctx = {
    ...methods,
    ...QuickSearchModal.data(),
    query,
    accountId: 1,
    recent: [],
    $emit: vi.fn(),
    $router: { push: vi.fn() },
  };
  // `flat` es computada: en las pruebas basta con la lista de lo encontrado.
  Object.defineProperty(ctx, 'flat', {
    get: () =>
      ['contacts', 'organizations', 'cases'].flatMap(key =>
        ctx.groups[key].items.map(item => ({ key, item }))
      ),
  });
  return ctx;
};

describe('QuickSearchModal', () => {
  beforeEach(() => vi.clearAllMocks());

  it('busca en todo con una sola llamada', async () => {
    GlobalSearchAPI.search.mockResolvedValue(
      response({
        contacts: [{ id: 1, name: 'Ana' }],
        organizations: [{ id: 2, name: 'Anáhuac' }],
      })
    );
    const ctx = context('ana');

    await methods.search.call(ctx);

    expect(GlobalSearchAPI.search).toHaveBeenCalledWith('ana');
    expect(ctx.groups.contacts.items[0].name).toBe('Ana');
    expect(ctx.groups.organizations.items[0].name).toBe('Anáhuac');
    expect(ctx.groups.cases.count).toBe(0);
    expect(ctx.searched).toBe(true);
    expect(ctx.searching).toBe(false);
  });

  it('con menos de 2 letras no busca', async () => {
    await methods.search.call(context('a'));

    expect(GlobalSearchAPI.search).not.toHaveBeenCalled();
  });

  it('si la búsqueda falla, queda vacía sin tronar', async () => {
    GlobalSearchAPI.search.mockRejectedValue(new Error('403'));
    const ctx = context('acme');

    await methods.search.call(ctx);

    expect(ctx.groups.contacts.items).toEqual([]);
    expect(ctx.searched).toBe(true);
  });

  it('una respuesta vieja no pisa lo que se escribe ahora', async () => {
    const ctx = context('ana');
    GlobalSearchAPI.search.mockImplementation(async () => {
      ctx.query = 'ana lópez';
      return response({ contacts: [{ id: 1, name: 'Ana' }] });
    });

    await methods.search.call(ctx);

    expect(ctx.groups.contacts.items).toEqual([]);
  });

  it('«ver más» de una pestaña pide ese tipo y suma sin repetir', async () => {
    const ctx = context('acme');
    ctx.tab = 'cases';
    ctx.groups.cases = { count: 3, items: [{ id: 1 }], page: 1 };
    GlobalSearchAPI.search.mockResolvedValue(
      response({ cases: [{ id: 1 }, { id: 2 }] })
    );

    await methods.loadMore.call(ctx);

    expect(GlobalSearchAPI.search).toHaveBeenCalledWith('acme', {
      type: 'cases',
      page: 2,
    });
    expect(ctx.groups.cases.items.map(i => i.id)).toEqual([1, 2]);
  });

  it('abre la ficha, la guarda en recientes y cierra la ventana', () => {
    const ctx = context('acme');

    ctx.open('organizations', { id: 2, name: 'Acme', match: 'nombre' });

    expect(ctx.$emit).toHaveBeenCalledWith('close');
    expect(ctx.$router.push).toHaveBeenCalledWith({
      name: 'organization_detail',
      params: { accountId: 1, organizationId: 2 },
    });
    expect(ctx.recent[0]).toEqual({
      key: 'organizations',
      item: { id: 2, name: 'Acme' },
    });
  });
});
