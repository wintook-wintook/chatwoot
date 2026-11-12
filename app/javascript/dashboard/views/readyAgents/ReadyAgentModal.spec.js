// Agentes listos — la configuración: preguntas armadas, objeciones y datos antes de pasarlo.
import { shallowMount } from '@vue/test-utils';
import ReadyAgentModal from './ReadyAgentModal.vue';

const mountModal = props =>
  shallowMount(ReadyAgentModal, {
    propsData: { show: true, ...props },
    mocks: {
      $t: x => x,
      $te: () => false,
      $store: {
        getters: { 'agents/getAgents': [], 'teams/getTeams': [] },
        dispatch: vi.fn(),
      },
    },
    stubs: { WootModal: true, WootModalHeader: true, WootButton: true },
  });

describe('ReadyAgentModal', () => {
  it('nuevo: trae las 7 preguntas armadas con «qué necesita» prendida', () => {
    const { qualify } = mountModal().vm.form.settings;
    expect(qualify.map(q => q.key)).toEqual([
      'need',
      'when',
      'budget',
      'decides',
      'location',
      'quantity',
      'source',
    ]);
    expect(qualify.filter(q => q.on).map(q => q.key)).toEqual(['need']);
  });

  it('un agente de antes conserva sus preguntas propias y recibe las armadas', () => {
    const wrapper = mountModal({
      agent: {
        id: 1,
        name: 'Sofi',
        inbox_ids: [1],
        settings: { objective: 'handoff', questions: 'qué busca' },
      },
    });
    const { settings } = wrapper.vm.form;
    expect(settings.questions).toBe('qué busca');
    expect(settings.qualify).toHaveLength(7);
    expect(settings.objections).toEqual([]);
  });

  it('respeta lo guardado y no manda objeciones a medias', () => {
    const wrapper = mountModal({
      agent: {
        id: 1,
        name: 'Sofi',
        inbox_ids: [1],
        settings: {
          qualify: [
            { key: 'need', on: false, text: '' },
            { key: 'budget', on: true, text: '¿Cuánto pagas?' },
          ],
          objections: [{ objection: 'Está caro', answer: 'Se paga solo' }],
          required_contact: ['email'],
        },
      },
    });
    wrapper.vm.addObjection();
    const { settings } = wrapper.vm.payload();
    expect(settings.qualify.find(q => q.key === 'need').on).toBe(false);
    expect(settings.qualify.find(q => q.key === 'budget')).toMatchObject({
      on: true,
      text: '¿Cuánto pagas?',
    });
    expect(settings.objections).toEqual([
      { objection: 'Está caro', answer: 'Se paga solo' },
    ]);
    expect(settings.required_contact).toEqual(['email']);
  });
});
