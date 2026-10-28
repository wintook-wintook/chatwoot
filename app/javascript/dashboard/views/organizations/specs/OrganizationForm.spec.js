// Plan-Organizaciones O1 — el formulario llena desde el contacto y Público en general no factura.
import { shallowMount } from '@vue/test-utils';
import OrganizationForm from '../OrganizationForm.vue';

const mountForm = props =>
  shallowMount(OrganizationForm, {
    propsData: { show: true, ...props },
    mocks: {
      $t: x => x,
      $store: { getters: { 'agents/getAgents': [] }, dispatch: vi.fn() },
    },
    stubs: { WootModal: true, WootModalHeader: true, WootSubmitButton: true },
  });

describe('OrganizationForm', () => {
  it('desde un contacto con empresa escrita propone Empresa con su dominio', () => {
    const wrapper = mountForm({
      contact: {
        id: 1,
        name: 'Luis',
        email: 'luis@acme.mx',
        additional_attributes: { company_name: 'Acme SA' },
      },
    });
    expect(wrapper.vm.form).toMatchObject({
      name: 'Acme SA',
      kind: 'company',
      email_domain: 'acme.mx',
    });
  });

  it('sin empresa escrita propone Público en general con su nombre', () => {
    const wrapper = mountForm({
      contact: { id: 2, name: 'Ana López', phone_number: '+5255' },
    });
    expect(wrapper.vm.form).toMatchObject({
      name: 'Ana López',
      kind: 'general_public',
      phone_number: '+5255',
    });
  });

  it('Público en general no manda RFC ni datos de empresa', () => {
    const wrapper = mountForm();
    Object.assign(wrapper.vm.form, {
      name: 'Ana',
      kind: 'general_public',
      tax_id: 'XAXX010101000',
      industry: 'Comercio',
    });
    expect(wrapper.vm.payload()).toMatchObject({
      kind: 'general_public',
      tax_id: null,
      industry: null,
    });
  });
});
