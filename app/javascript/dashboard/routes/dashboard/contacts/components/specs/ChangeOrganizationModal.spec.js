// Plan-Organizaciones — «Cambiar de organización»: sin sustituto no se puede quedar todo.
import { shallowMount } from '@vue/test-utils';
import OrganizationsAPI from 'dashboard/api/organizations';
import ChangeOrganizationModal from '../ChangeOrganizationModal.vue';

vi.mock('dashboard/api/organizations', () => ({
  default: { changePreview: vi.fn(), changeContact: vi.fn() },
}));

const PREVIEW = {
  organization: { id: 1, name: 'Acme' },
  counts: { all: { contracts: 1 }, live: { contracts: 1 } },
  candidates: [{ id: 7, name: 'Ana' }],
};

const mountModal = async () => {
  OrganizationsAPI.changePreview.mockResolvedValue({ data: PREVIEW });
  const wrapper = shallowMount(ChangeOrganizationModal, {
    propsData: { show: true, contact: { id: 3, name: 'Luis' } },
    mocks: { $t: key => key },
    stubs: { WootModal: true, WootModalHeader: true, WootButton: true },
  });
  await new Promise(resolve => {
    setTimeout(resolve);
  });
  return wrapper;
};

describe('ChangeOrganizationModal', () => {
  it('pasar todo: basta con la nueva organización', async () => {
    const wrapper = await mountModal();
    wrapper.vm.chooseTarget({ id: 2, name: 'Globex' });
    wrapper.vm.move = true;
    expect(wrapper.vm.canSave).toBe(true);
    expect(wrapper.vm.payload()).toEqual({
      contact_id: 3,
      to_organization_id: 2,
      move: true,
    });
  });

  it('dejar todo: hasta elegir quién queda en su lugar', async () => {
    const wrapper = await mountModal();
    wrapper.vm.chooseTarget({ id: 2, name: 'Globex' });
    wrapper.vm.move = false;
    expect(wrapper.vm.canSave).toBe(false);
    wrapper.vm.replacementId = 7;
    expect(wrapper.vm.canSave).toBe(true);
    expect(wrapper.vm.payload()).toMatchObject({ replacement_contact_id: 7 });
  });

  it('no deja elegir la misma organización', async () => {
    const wrapper = await mountModal();
    wrapper.vm.chooseTarget({ id: 1, name: 'Acme' });
    wrapper.vm.move = true;
    expect(wrapper.vm.canSave).toBe(false);
  });
});
