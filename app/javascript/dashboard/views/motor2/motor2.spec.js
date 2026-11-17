// Motor 2.0 — la ficha en la pantalla ↔ la API, y el probador con lo que hizo el agente.
import { shallowMount } from '@vue/test-utils';
import Motor2AgentsAPI from 'dashboard/api/motor2Agents';
import { fromAgent, toPayload, missingFields, emptyForm } from './agentForm';
import Tester from './Tester.vue';

vi.mock('dashboard/api/motor2Agents', () => ({
  default: { test: vi.fn() },
}));

const agent = {
  id: 7,
  name: 'Becas',
  customer_display_name: 'Sofi',
  objective: 'Inscribir alumnos',
  inbox_id: 3,
  attempts: 2,
  whatsapp_templates: ['hola'],
  calendar_integration_ids: [5],
  file_rules: { brochure: { ask: true } },
  motor2: {
    tone: 'usted',
    instructions: 'Habla de carreras',
    sources: ['canned_response'],
    skills: { offers: { on: true, steps: [{ text: 'Beca 20%' }] } },
  },
};

describe('agentForm', () => {
  it('lo de la API llega a la pantalla con todas las habilidades y regresa igual', () => {
    const form = fromAgent(agent);
    expect(form.channel).toMatchObject({ inboxId: 3, attempts: 2 });
    expect(form.motor2.skills.offers.steps[0].text).toBe('Beca 20%');
    expect(form.motor2.skills.handoff.on).toBe(true);
    const payload = toPayload(form);
    expect(payload).toMatchObject({
      inbox_id: 3,
      attempts: 2,
      calendar_integration_ids: [5],
      file_rules: { brochure: { ask: true } },
    });
    expect(payload.motor2.instructions).toBe('Habla de carreras');
  });

  it('pide nombre y objetivo', () => {
    expect(missingFields(emptyForm())).toEqual(['name', 'objective']);
  });
});

describe('Tester', () => {
  const mountTester = () =>
    shallowMount(Tester, {
      propsData: { templateId: 7, payload: () => ({}) },
      mocks: {
        $t: (key, args) => (args ? `${key} ${JSON.stringify(args)}` : key),
      },
      stubs: { WootButton: true },
    });

  it('manda la plática y la memoria, y enseña qué fuente consultó', async () => {
    Motor2AgentsAPI.test.mockResolvedValue({
      data: {
        reply: 'La colegiatura es de $4,200',
        state: { offer_step: 1 },
        trace: {
          sources: [{ name: 'Precios', found: ['Derecho: $4,200'] }],
          events: [{ kind: 'oferta', text: 'escalón 1 de 2' }],
        },
        files: [],
      },
    });
    const wrapper = mountTester();
    wrapper.vm.draft = '¿Cuánto cuesta?';
    await wrapper.vm.send();

    expect(Motor2AgentsAPI.test).toHaveBeenCalledWith(
      expect.objectContaining({
        id: 7,
        messages: [{ role: 'user', content: '¿Cuánto cuesta?' }],
        state: {},
      })
    );
    expect(wrapper.vm.state).toEqual({ offer_step: 1 });
    const lines = wrapper.vm.lines(wrapper.vm.chat[1]);
    expect(lines.map(l => l.icon)).toEqual(['📚', '🧩']);
    expect(lines[0].detail).toEqual(['Derecho: $4,200']);
  });

  it('«Probar de nuevo» vuelve a contestar el mismo mensaje del cliente', async () => {
    Motor2AgentsAPI.test.mockResolvedValue({
      data: { reply: 'Otra', trace: {} },
    });
    const wrapper = mountTester();
    wrapper.vm.chat = [
      { role: 'user', content: 'Hola' },
      { role: 'assistant', content: 'Mala' },
      { role: 'trainer', content: 'Ya lo corregí' },
    ];
    await wrapper.vm.retryLast();
    expect(Motor2AgentsAPI.test).toHaveBeenLastCalledWith(
      expect.objectContaining({ messages: [{ role: 'user', content: 'Hola' }] })
    );
    expect(wrapper.vm.chat[3]).toMatchObject({ content: 'Otra', again: true });
  });
});
