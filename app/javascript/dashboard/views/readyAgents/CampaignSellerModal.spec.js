// «Vendedor de campaña» — el asistente: para qué es, lo que se manda y el mensaje de la prueba.
import { shallowMount } from '@vue/test-utils';
import CampaignSellerModal from './CampaignSellerModal.vue';

const mountModal = props =>
  shallowMount(CampaignSellerModal, {
    propsData: { show: true, ...props },
    mocks: {
      $t: (x, p) => (p ? `${x} ${JSON.stringify(p)}` : x),
      $te: () => false,
      $store: {
        getters: { 'agents/getAgents': [], 'teams/getTeams': [] },
        dispatch: vi.fn(),
      },
    },
    stubs: {
      WootModal: true,
      WootModalHeader: true,
      WootButton: true,
      FichaChannel: true,
      FluentIcon: true,
    },
  });

describe('CampaignSellerModal', () => {
  it('nuevo: ofrecer y relevo al agente de la bandeja; para guardar basta el nombre (la oferta es de cada campaña)', () => {
    const { vm } = mountModal({
      sources: [{ key: 'catalog', kind: 'catalog' }],
    });
    expect(vm.form.settings).toMatchObject({
      purpose: 'offer',
      relay: 'agent',
      price_source: 'catalog',
    });
    expect(vm.canSave).toBeFalsy();
    vm.form.name = 'Ana – campañas';
    expect(vm.canSave).toBeTruthy();
    expect(vm.steps).not.toContain('offer');
    expect(vm.steps).not.toContain('channel');
  });

  it('solo configura cómo vende: sin oferta de ejemplo ni chat; se prueba en la campaña', () => {
    const { vm } = mountModal({ calendarUsers: [{ id: 4, name: 'Ana' }] });
    vm.form.name = 'Ventas';
    expect(vm.$options.components.ReadyAgentChat).toBeUndefined();
    vm.toggleCalendarUser(4);
    expect(vm.payload().settings.appointment_user_ids).toEqual(['4']);
  });

  it('un agente guardado: su canal y toques vuelven al asistente y se mandan con sus nombres', () => {
    const { vm } = mountModal({
      agent: {
        id: 4,
        name: 'Ana',
        settings: {
          purpose: 'renew',
          offer_what: 'Licencia',
          survey_questions: [],
        },
        channel: {
          inbox_id: 3,
          whatsapp_templates: ['renovacion_1'],
          attempts: 1,
          retry_value: 3,
          retry_unit: 'days',
        },
      },
    });
    expect(vm.form.channel).toMatchObject({
      inboxId: 3,
      whatsappTemplates: ['renovacion_1'],
    });
    expect(vm.payload().channel).toMatchObject({
      inbox_id: 3,
      whatsapp_templates: ['renovacion_1'],
      retry_value: 3,
    });
    expect(vm.payload().kind).toBe('campaign_seller');
  });
});
