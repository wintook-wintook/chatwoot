import { shallowMount } from '@vue/test-utils';
import SessionCard from './SessionCard.vue';

const montar = props =>
  shallowMount(SessionCard, {
    propsData: props,
    mocks: { $t: clave => clave },
    stubs: ['woot-button'],
    directives: { tooltip: {} },
  });

describe('SessionCard', () => {
  it('con nombre puesto a mano, ese manda sobre el agente', () => {
    const wrapper = montar({
      sessionMeta: { id: 3438, title: 'Universidad — becas', named: true },
      editingTemplate: { id: 1, name: 'Universidad' },
    });

    expect(wrapper.vm.heading).toBe('Universidad — becas');
  });

  it('sin nombre, el agente o el título automático', () => {
    expect(
      montar({
        sessionMeta: { id: 1, title: '🔎 PROMPT X' },
        editingTemplate: { id: 1, name: 'Universidad' },
      }).vm.heading
    ).toBe('Universidad');
    expect(
      montar({ sessionMeta: { id: 1, title: '🔎 PROMPT X' } }).vm.heading
    ).toBe('🔎 PROMPT X');
  });

  it('renombrar emite el nombre escrito', async () => {
    const wrapper = montar({ sessionMeta: { id: 1, title: 'x' } });
    wrapper.vm.startRename();
    wrapper.vm.draftName = '  Revisión becas ';
    wrapper.vm.submitRename();

    expect(wrapper.emitted('rename')[0]).toEqual(['Revisión becas']);
  });
});
