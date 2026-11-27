import { shallowMount } from '@vue/test-utils';
import CrmOrganizations from 'dashboard/api/crmOrganizations';
import ContactsPanel from './ContactsPanel.vue';

vi.mock('dashboard/api/crmOrganizations', () => ({
  default: {
    contacts: vi.fn(),
    searchContacts: vi.fn(),
    linkContact: vi.fn(),
    unlinkContact: vi.fn(),
  },
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

const flushPromises = () =>
  new Promise(resolve => {
    setTimeout(resolve);
  });

const ANA = { id: 1, name: 'Ana', email: 'ana@aceros.mx', phone_number: '' };

const montar = ({ canEdit = true } = {}) =>
  shallowMount(ContactsPanel, {
    propsData: { organizationId: '5', canEdit },
    mocks: {
      $t: (clave, args) => (args ? `${clave} ${JSON.stringify(args)}` : clave),
      $route: { params: { accountId: '2' } },
    },
    stubs: ['woot-button', 'woot-confirm-modal', 'router-link', 'Thumbnail'],
  });

describe('CrmContactsPanel', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    CrmOrganizations.contacts.mockResolvedValue({ data: { contacts: [ANA] } });
  });

  it('lista los contactos ligados', async () => {
    const wrapper = montar();
    await flushPromises();
    expect(CrmOrganizations.contacts).toHaveBeenCalledWith('5');
    expect(wrapper.text()).toContain('ana@aceros.mx');
  });

  it('sin permiso de escritura no muestra el buscador', async () => {
    const wrapper = montar({ canEdit: false });
    await flushPromises();
    expect(wrapper.find('input[type="search"]').exists()).toBe(false);
  });

  it('liga un contacto libre y no uno que ya está en otra organización', async () => {
    CrmOrganizations.linkContact.mockResolvedValue({});
    const wrapper = montar();
    await flushPromises();
    const libre = { id: 2, name: 'Beto', crm_organization: null };
    const ocupado = {
      id: 3,
      name: 'Carla',
      crm_organization: { id: 9, trade_name: 'Pinturas' },
    };

    expect(wrapper.vm.linkedElsewhere(ocupado)).toEqual(
      ocupado.crm_organization
    );
    await wrapper.vm.link(ocupado);
    expect(CrmOrganizations.linkContact).not.toHaveBeenCalled();

    await wrapper.vm.link(libre);
    expect(CrmOrganizations.linkContact).toHaveBeenCalledWith('5', 2);
    expect(CrmOrganizations.contacts).toHaveBeenCalledTimes(2);
  });

  it('marca como ya ligado al que está en esta organización', () => {
    const wrapper = montar();
    expect(wrapper.vm.alreadyHere({ id: 1, crm_organization: { id: 5 } })).toBe(
      true
    );
  });
});
