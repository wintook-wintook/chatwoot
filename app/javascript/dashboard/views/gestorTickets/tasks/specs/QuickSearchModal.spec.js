import QuickSearchModal from '../QuickSearchModal.vue';
import ContactAPI from 'dashboard/api/contacts';
import OrganizationsAPI from 'dashboard/api/organizations';

vi.mock('dashboard/api/contacts', () => ({ default: { search: vi.fn() } }));
vi.mock('dashboard/api/organizations', () => ({ default: { list: vi.fn() } }));

const { methods } = QuickSearchModal;
const context = query => ({
  ...methods,
  ...QuickSearchModal.data(),
  query,
  $emit: vi.fn(),
  $route: { params: { accountId: 1 } },
  $router: { push: vi.fn() },
});

describe('QuickSearchModal', () => {
  beforeEach(() => vi.clearAllMocks());

  it('busca contactos y organizaciones', async () => {
    ContactAPI.search.mockResolvedValue({
      data: { payload: [{ id: 1, name: 'Ana' }] },
    });
    OrganizationsAPI.list.mockResolvedValue({
      data: { organizations: [{ id: 2, name: 'Anáhuac' }] },
    });
    const ctx = context('ana');

    await methods.search.call(ctx);

    expect(OrganizationsAPI.list).toHaveBeenCalledWith({ q: 'ana', stage: '' });
    expect(ctx.contacts[0].name).toBe('Ana');
    expect(ctx.organizations[0].name).toBe('Anáhuac');
  });

  it('con menos de 2 letras no busca', async () => {
    await methods.search.call(context('a'));

    expect(ContactAPI.search).not.toHaveBeenCalled();
  });

  it('si el rol no deja ver contactos, muestra las organizaciones', async () => {
    ContactAPI.search.mockRejectedValue(new Error('403'));
    OrganizationsAPI.list.mockResolvedValue({
      data: { organizations: [{ id: 2, name: 'Acme' }] },
    });
    const ctx = context('acme');

    await methods.search.call(ctx);

    expect(ctx.contacts).toEqual([]);
    expect(ctx.organizations).toHaveLength(1);
  });

  it('abre la ficha y cierra la ventana', () => {
    const ctx = context('acme');

    ctx.openOrganization({ id: 2 });

    expect(ctx.$emit).toHaveBeenCalledWith('close');
    expect(ctx.$router.push).toHaveBeenCalledWith({
      name: 'organization_detail',
      params: { accountId: 1, organizationId: 2 },
    });
  });
});
