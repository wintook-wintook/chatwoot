import { mount } from '@vue/test-utils';
import PatternLibraryList from './PatternLibraryList.vue';
import AiAgentAssistantAPI from 'dashboard/api/aiAgentAssistant';

// proyecto@ai_agent_assistant — el cuerpo de la biblioteca de patrones, que ahora
// se lee en dos sitios: el cajón del editor (insertable) y la pestaña Patrones del
// asistente (consulta). Lo que se prueba aquí es justo lo que separa a los dos, que
// es lo que se rompe al extraer un componente para reutilizarlo.

vi.mock('dashboard/api/aiAgentAssistant', () => ({
  default: { patterns: vi.fn() },
}));

const RESPUESTA = {
  data: {
    blocks: [
      {
        key: 'role_identity',
        section: 'rol',
        kind: 'prompt',
        status: 'ready',
        chars: 120,
        body: 'Eres <rol> de <empresa>.',
        source: 'El mejor agente cambia de trato seis veces.',
      },
      {
        key: 'keyword_stop',
        section: 'config',
        kind: 'config',
        status: 'ready',
        chars: 40,
        body: 'baja, no me interesa',
        source: 'Lo determinista va fuera del prompt.',
      },
    ],
    sections: ['rol', 'cierre', 'config'],
    rules: [{ key: 'r1', rule: 'Lo determinista va fuera del prompt.' }],
    skeleton: '[ROL Y LÍMITES]',
    prompt_is_discarded: false,
  },
};

const flushPromises = () =>
  new Promise(resolve => {
    setTimeout(resolve, 0);
  });

const montar = async (props = {}) => {
  AiAgentAssistantAPI.patterns.mockResolvedValue(RESPUESTA);
  const wrapper = mount(PatternLibraryList, {
    propsData: props,
    mocks: { $t: clave => clave },
  });
  await flushPromises();
  return wrapper;
};

describe('PatternLibraryList.vue', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('pinta cada bloque con su texto y su evidencia', async () => {
    const texto = (await montar()).text();

    expect(texto).toContain('Eres <rol> de <empresa>.');
    expect(texto).toContain('cambia de trato seis veces');
  });

  // Sin sitio donde insertar, el botón sería una promesa falsa: en la pestaña de
  // consulta no hay prompt al que llevarse nada.
  it('sin `insertable` no ofrece insertar', async () => {
    const texto = (await montar()).text();

    expect(texto).not.toContain('AI_AGENT_ASSISTANT.PATTERNS.INSERT');
  });

  it('con `insertable` sí, y solo en los bloques que van al prompt', async () => {
    const wrapper = await montar({ insertable: true });
    // `woot-button` no está registrado en el entorno de pruebas y queda como
    // elemento desconocido; se busca por su etiqueta.
    const insertar = wrapper
      .findAll('woot-button')
      .wrappers.filter(w =>
        w.text().includes('AI_AGENT_ASSISTANT.PATTERNS.INSERT')
      );

    // Dos bloques, pero el de `config` no va dentro del prompt: no hay qué insertar.
    expect(insertar).toHaveLength(1);
  });

  // El gesto del chat se aprende viéndolo escrito: quien nunca ha tecleado un «$»
  // en la caja no tiene forma de descubrirlo.
  it('enseña cómo se referencia cada bloque desde el chat', async () => {
    expect((await montar()).text()).toContain('$role_identity');
  });

  // El estado de un bloque depende del canal: @discourse se configura por inbox.
  it('vuelve a consultar al cambiar de canal', async () => {
    const wrapper = await montar({ inboxId: 1 });
    expect(AiAgentAssistantAPI.patterns).toHaveBeenCalledTimes(1);

    await wrapper.setProps({ inboxId: 2 });
    expect(AiAgentAssistantAPI.patterns).toHaveBeenCalledTimes(2);
  });
});
