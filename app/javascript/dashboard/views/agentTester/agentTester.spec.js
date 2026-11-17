// Probador de agentes — la plática con el motor real (API simulada), el 👎 y las plantillas.
import { shallowMount } from '@vue/test-utils';
import AgentTesterAPI from 'dashboard/api/agentTester';
import TesterChat from './TesterChat.vue';

vi.mock('dashboard/api/agentTester', () => ({
  default: { start: vi.fn(), say: vi.fn(), since: vi.fn(), feedback: vi.fn() },
}));
vi.mock('dashboard/api/agentTestBatches', () => ({
  default: { addCase: vi.fn() },
}));

const mountChat = () =>
  shallowMount(TesterChat, {
    propsData: { agents: [{ id: 3, name: 'Becas', engine: '1' }], batches: [] },
    mocks: {
      $t: (k, a) => (a ? `${k} ${JSON.stringify(a)}` : k),
      $router: { resolve: () => ({ href: '#' }) },
    },
    stubs: { WootButton: true },
  });

describe('TesterChat', () => {
  beforeEach(() => vi.useFakeTimers());
  afterEach(() => vi.useRealTimers());

  it('empieza la plática, manda el mensaje y espera lo que conteste el motor', async () => {
    AgentTesterAPI.start.mockResolvedValue({
      data: { conversation_id: 9, template_id: 3, engine: '1', name: 'Becas' },
    });
    AgentTesterAPI.say.mockResolvedValue({ data: { message_id: 50 } });
    AgentTesterAPI.since
      .mockResolvedValueOnce({
        data: {
          messages: [
            {
              id: 51,
              content: 'Hola, soy Sofi',
              private: false,
              lines: ['Ruta: saludo'],
            },
          ],
          tracking_status: 'active',
        },
      })
      .mockResolvedValue({ data: { messages: [], tracking_status: 'active' } });
    const wrapper = mountChat();
    wrapper.vm.templateId = '3';
    await wrapper.vm.start();
    wrapper.vm.draft = 'Hola';
    const sending = wrapper.vm.send();
    await vi.advanceTimersByTimeAsync(14000);
    await sending;
    expect(AgentTesterAPI.say).toHaveBeenCalledWith(9, 'Hola');
    expect(wrapper.vm.chat.map(m => m.content)).toEqual([
      'Hola',
      'Hola, soy Sofi',
    ]);
    expect(wrapper.vm.chat[1].lines).toEqual(['Ruta: saludo']);
  });

  it('👎 manda la corrección y pinta lo que dice el entrenador', async () => {
    AgentTesterAPI.feedback.mockResolvedValue({
      data: { messages: [{ kind: 'engine', text: 'Es del motor' }] },
    });
    const wrapper = mountChat();
    wrapper.vm.session = { conversation_id: 9 };
    wrapper.vm.chat = [
      { role: 'user', content: 'Hola' },
      { role: 'assistant', id: 51, content: 'Mal' },
    ];
    wrapper.vm.rate(1, 'down');
    wrapper.vm.feedback = 'Debió saludar';
    await wrapper.vm.sendFeedback();
    expect(AgentTesterAPI.feedback).toHaveBeenCalledWith(
      9,
      51,
      'Debió saludar'
    );
    expect(wrapper.vm.chat[2]).toMatchObject({
      role: 'trainer',
      content: '🔧 Es del motor',
    });
  });
});

// El webpack del proyecto no entiende `??` ni `?.` dentro de las plantillas.
describe('plantillas del probador sin operadores que el webpack no lee', () => {
  const files = import.meta.glob('./*.vue', { eager: true, as: 'raw' });
  Object.entries(files).forEach(([path, source]) => {
    it(path, () => {
      expect(source.slice(source.indexOf('<template>'))).not.toMatch(
        /\?\?|\?\./
      );
    });
  });
});
