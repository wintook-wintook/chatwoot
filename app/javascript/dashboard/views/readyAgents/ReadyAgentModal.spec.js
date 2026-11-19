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
  it('nuevo: trae unas preguntas de ejemplo que se pueden quitar, cambiar y agregar', () => {
    const { vm } = mountModal();
    expect(vm.form.settings.question_list.map(q => q.text)).toEqual([
      'READY_AGENTS.QUALIFY.need.ASK',
      'READY_AGENTS.QUALIFY.when.ASK',
      'READY_AGENTS.QUALIFY.budget.ASK',
    ]);
    vm.removeQuestion(1);
    vm.form.settings.question_list[0].text = '¿Qué auto buscas?';
    vm.addQuestion();
    vm.form.settings.question_list[2].text = '¿Es para tu familia?';
    vm.addQuestion(); // vacía: no se manda
    expect(vm.payload().settings.question_list).toEqual([
      '¿Qué auto buscas?',
      'READY_AGENTS.QUALIFY.budget.ASK',
      '¿Es para tu familia?',
    ]);
  });

  it('un agente de antes: sus armadas prendidas y sus preguntas propias pasan a la lista', () => {
    const { vm } = mountModal({
      agent: {
        id: 1,
        name: 'Sofi',
        inbox_ids: [1],
        settings: {
          qualify: [
            { key: 'need', on: false, text: '' },
            { key: 'budget', on: true, text: '¿Cuánto pagas?' },
            { key: 'location', on: true, text: '' },
          ],
          questions: 'qué busca',
        },
      },
    });
    expect(vm.form.settings.question_list.map(q => q.text)).toEqual([
      '¿Cuánto pagas?',
      'READY_AGENTS.QUALIFY.location.ASK',
      'qué busca',
    ]);
    const { settings } = vm.payload();
    expect(settings.qualify).toEqual([]);
    expect(settings.questions).toBe('');
  });

  it('respeta lo guardado y no manda objeciones a medias', () => {
    const wrapper = mountModal({
      agent: {
        id: 1,
        name: 'Sofi',
        inbox_ids: [1],
        settings: {
          question_list: ['¿Qué buscas?'],
          objections: [{ objection: 'Está caro', answer: 'Se paga solo' }],
          required_contact: ['email'],
        },
      },
    });
    wrapper.vm.addObjection();
    const { settings } = wrapper.vm.payload();
    expect(settings.question_list).toEqual(['¿Qué buscas?']);
    expect(settings.objections).toEqual([
      { objection: 'Está caro', answer: 'Se paga solo' },
    ]);
    expect(settings.required_contact).toEqual(['email']);
  });
});

describe('ReadyAgentModal · asistente paso a paso', () => {
  it('nuevo: no avanza sin nombre y bandeja; después va paso por paso', () => {
    const wrapper = mountModal({ inboxes: [{ id: 3, name: 'WhatsApp' }] });
    const { vm } = wrapper;
    expect(vm.step).toBe('agent');
    vm.next();
    expect(vm.step).toBe('agent');

    vm.form.name = 'Ana – Facebook';
    vm.toggleInbox(3);
    vm.next();
    expect(vm.step).toBe('business');
    vm.back();
    expect(vm.step).toBe('agent');
    vm.go('test');
    expect(vm.isLast).toBe(true);
  });

  it('al editar se puede saltar a cualquier paso', () => {
    const wrapper = mountModal({
      agent: { id: 1, name: 'Sofi', inbox_ids: [1], settings: {} },
    });
    wrapper.vm.go('objections');
    expect(wrapper.vm.step).toBe('objections');
  });

  it('manda el nombre que ve el cliente y las indicaciones', () => {
    const wrapper = mountModal({
      agent: {
        id: 1,
        name: 'Prospectos FB',
        display_name: 'Sofi',
        inbox_ids: [1],
        settings: { instructions: 'Sé breve' },
      },
    });
    const payload = wrapper.vm.payload();
    expect(payload.display_name).toBe('Sofi');
    expect(payload.settings.instructions).toBe('Sé breve');
  });
});

describe('ReadyAgentModal · cómo platica', () => {
  it('nuevo: vienen las recomendadas y se mandan con las respuestas', () => {
    const { vm } = mountModal();
    expect(vm.steps).toContain('talk');
    const { settings } = vm.payload();
    expect(settings).toMatchObject({
      doubts: 'answer',
      not_found: 'continue',
      off_topic: 'redirect',
    });
  });

  it('si no contesta dudas, «Qué sabe» no aplica', () => {
    const { vm } = mountModal();
    vm.form.settings.doubts = 'defer';
    expect(vm.answersDoubts).toBe(false);
  });
});
