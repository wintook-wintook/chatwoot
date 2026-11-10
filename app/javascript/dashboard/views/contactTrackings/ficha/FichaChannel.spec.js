import { shallowMount } from '@vue/test-utils';
import FichaChannel, {
  channelKind,
  trackingChannels,
} from './FichaChannel.vue';
import FileRule from './FileRule.vue';

const INTEGRATIONS = [
  {
    id: 'tracking_bot',
    enabled: true,
    hooks: [
      { status: true, inbox: { id: 1 } },
      { status: true, inbox: { id: 2 } },
      { status: false, inbox: { id: 3 } },
    ],
  },
];
const INBOXES = [
  { id: 1, name: 'WA Ventas', channel_type: 'Channel::Whatsapp' },
  { id: 2, name: 'Correo', channel_type: 'Channel::Email' },
  { id: 3, name: 'Apagada', channel_type: 'Channel::Api' },
];

describe('FichaChannel', () => {
  const montar = value =>
    shallowMount(FichaChannel, {
      propsData: { value },
      mocks: {
        $t: clave => clave,
        $store: {
          dispatch: vi.fn(),
          getters: {
            'integrations/getAppIntegrations': INTEGRATIONS,
            'inboxes/getInboxes': INBOXES,
            'inboxes/getWhatsAppTemplates': () => [
              { name: 'seguimiento_1', language: 'es_MX' },
            ],
          },
        },
      },
    });

  it('solo ofrece canales con el bot de seguimiento activo', () => {
    expect(trackingChannels(INTEGRATIONS, INBOXES).map(c => c.id)).toEqual([
      1, 2,
    ]);
    expect(channelKind({ channelType: 'Channel::Whatsapp' })).toBe('whatsapp');
    expect(channelKind({ channelType: 'Channel::Email' })).toBe('email');
  });

  it('con WhatsApp pide una plantilla por intento', () => {
    const wrapper = montar({
      inboxId: 1,
      attempts: 2,
      whatsappTemplates: ['seguimiento_1'],
    });
    expect(wrapper.vm.kind).toBe('whatsapp');
    expect(wrapper.vm.missingTemplates).toBe(true);
    wrapper.vm.setTemplate(1, 'seguimiento_1');
    expect(wrapper.emitted('input')[0][0].whatsappTemplates).toEqual([
      'seguimiento_1',
      'seguimiento_1',
    ]);
  });

  it('bajar los intentos recorta las plantillas', () => {
    const wrapper = montar({
      inboxId: 1,
      attempts: 3,
      whatsappTemplates: ['a', 'b', 'c'],
    });
    wrapper.vm.setAttempts(2);
    expect(wrapper.emitted('input')[0][0]).toMatchObject({
      attempts: 2,
      whatsappTemplates: ['a', 'b'],
    });
  });
});

describe('FileRule', () => {
  it('marca cuándo se manda un archivo y avisa si nunca', async () => {
    const wrapper = shallowMount(FileRule, {
      propsData: {
        value: { ask: true, welcome: false, attempts: [] },
        attempts: 3,
      },
      mocks: { $t: clave => clave },
    });
    wrapper.vm.toggleAttempt(2);
    expect(wrapper.emitted('input')[0][0]).toMatchObject({
      ask: true,
      welcome: false,
      attempts: [2],
    });
    await wrapper.setProps({
      value: { ask: false, welcome: false, attempts: [] },
    });
    expect(wrapper.vm.nothing).toBe(true);
  });
});

describe('FichaSheet', () => {
  it('carga la hoja y cambia «busca por» sin dejarla en «contesta con»', async () => {
    const { default: FichaSheet } = await import('./FichaSheet.vue');
    const { default: FichaAPI } = await import('dashboard/api/fichaAgente');
    FichaAPI.sheet = vi.fn().mockResolvedValue({
      data: { columns: ['Servicio', 'Zona', 'Precio'], rows: [], total: 3 },
    });
    const wrapper = shallowMount(FichaSheet, {
      propsData: {
        card: { id: 1, search_by: 'Servicio', answer_with: ['Precio', 'Zona'] },
      },
      mocks: { $t: clave => clave },
    });
    await new Promise(resolve => {
      setTimeout(resolve);
    });
    expect(FichaAPI.sheet).toHaveBeenCalledWith(1);
    expect(wrapper.vm.answerOptions).toEqual(['Zona', 'Precio']);
    wrapper.vm.set('search_by', 'Zona');
    expect(wrapper.emitted('input')[0][0]).toEqual({
      purpose: '',
      search_by: 'Zona',
      answer_with: ['Precio'],
      remember: false,
    });
  });
});

describe('FichaTicket', () => {
  it('escribe motivos (por renglón o coma, sin paréntesis), los sugeridos se marcan y solo cuentan los marcados', async () => {
    const { default: FichaTicket } = await import('./FichaTicket.vue');
    const wrapper = shallowMount(FichaTicket, {
      propsData: {
        card: { name: 'Soporte' },
        value: { reasons: ['a'], priority: '' },
      },
      mocks: { $t: clave => clave },
    });
    wrapper.setData({ draft: 'reporta (una) falla\nquiere un asesor, a' });
    wrapper.vm.addDraft();
    expect(wrapper.emitted('input')[0][0]).toMatchObject({
      reasons: ['a', 'reporta una falla', 'quiere un asesor'],
      priority: '',
    });
    expect(wrapper.vm.draft).toBe('');
    // Un sugerido sin marcar se ve pero no cuenta; al tocarlo se marca.
    expect(wrapper.vm.chips).toContain('TRACKING_TEMPLATES.FICHA.SUG_PERSON');
    expect(wrapper.vm.isOn('TRACKING_TEMPLATES.FICHA.SUG_PERSON')).toBe(false);
    wrapper.vm.toggle('TRACKING_TEMPLATES.FICHA.SUG_PERSON');
    expect(wrapper.emitted('input')[1][0].reasons).toEqual([
      'a',
      'TRACKING_TEMPLATES.FICHA.SUG_PERSON',
    ]);
    // Desmarcar quita el motivo, pero el chip sigue a la vista.
    wrapper.vm.toggle('a');
    expect(wrapper.emitted('input')[2][0].reasons).toEqual([]);
    wrapper.vm.emit({ priority: 'alta' });
    expect(wrapper.emitted('input')[3][0].priority).toBe('alta');
  });
});

describe('FileRule: agendar, ticket y ruta', () => {
  it('marca rutas y tickets y cuenta «nunca» solo si no hay nada', async () => {
    const wrapper = shallowMount(FileRule, {
      propsData: {
        value: { ask: false, welcome: false, attempts: [] },
        routeOptions: [{ value: 'precios', label: 'Precios' }],
        ticketOptions: [{ value: '*', label: 'Cualquiera' }],
        showBooking: true,
      },
      mocks: { $t: clave => clave },
    });
    expect(wrapper.vm.nothing).toBe(true);
    wrapper.vm.toggleIn('routes', 'precios');
    expect(wrapper.emitted('input')[0][0]).toMatchObject({
      routes: ['precios'],
      booking: false,
    });
    await wrapper.setProps({ value: { ask: false, tickets: ['*'] } });
    expect(wrapper.vm.nothing).toBe(false);
  });
});

describe('FichaQuestions', () => {
  it('agrega, nombra la variable, mueve y quita preguntas', async () => {
    const { default: FichaQuestions } = await import('./FichaQuestions.vue');
    const wrapper = shallowMount(FichaQuestions, {
      propsData: {
        value: {
          questions: [{ text: '¿En qué ciudad estás?', var: '', options: [] }],
          when: 'start',
        },
      },
      mocks: { $t: clave => clave },
    });
    wrapper.vm.autoVar(0);
    expect(wrapper.emitted('input')[0][0].questions[0].var).toBe('CIUDAD');
    wrapper.vm.setOptions(0, 'Monterrey, CDMX , ');
    expect(wrapper.emitted('input')[1][0].questions[0].options).toEqual([
      'Monterrey',
      'CDMX',
    ]);
    wrapper.vm.add();
    expect(wrapper.emitted('input')[2][0].questions).toHaveLength(2);
    await wrapper.setProps({
      value: {
        questions: [
          { text: 'a', var: 'A', options: [] },
          { text: 'b', var: 'B', options: [] },
        ],
        when: 'start',
      },
    });
    wrapper.vm.move(1, -1);
    expect(wrapper.emitted('input')[3][0].questions.map(q => q.text)).toEqual([
      'b',
      'a',
    ]);
    wrapper.vm.remove(0);
    expect(wrapper.emitted('input')[4][0].questions).toHaveLength(1);
  });
});

describe('FichaIdentity', () => {
  it('«Te conviene agregar» suma la línea al contexto y quita el chip', async () => {
    const { default: FichaIdentity } = await import('./FichaIdentity.vue');
    const wrapper = shallowMount(FichaIdentity, {
      propsData: {
        value: {
          name: 'Ventas',
          displayName: '',
          tone: 'cercano',
          objective: '',
          business: 'Renta de grúas',
        },
        missing: ['horario de atención', 'dirección'],
        canSuggest: true,
      },
      mocks: { $t: clave => clave },
    });
    wrapper.vm.addMissing('horario de atención');
    expect(wrapper.emitted('input')[0][0].business).toBe(
      'Renta de grúas\nhorario de atención: '
    );
    expect(wrapper.emitted('update:missing')[0][0]).toEqual(['dirección']);
  });
});

describe('FichaQuestions › ¿Cuándo pregunta?', () => {
  it('ofrece «con la bienvenida» o «al iniciar» según haya bienvenida', async () => {
    const { default: FichaQuestions } = await import('./FichaQuestions.vue');
    const montar = hasWelcome =>
      shallowMount(FichaQuestions, {
        propsData: {
          value: {
            questions: [{ text: '¿Ciudad?', var: 'CIUDAD' }],
            when: 'welcome',
          },
          hasWelcome,
        },
        mocks: { $t: clave => clave },
      });
    expect(montar(true).find('option[value="welcome"]').text()).toBe(
      'TRACKING_TEMPLATES.FICHA.QUESTIONS_WITH_WELCOME'
    );
    expect(montar(false).find('option[value="welcome"]').text()).toBe(
      'TRACKING_TEMPLATES.FICHA.QUESTIONS_FIRST_MESSAGE'
    );
  });
});

describe('Variables y datos del negocio', () => {
  it('la variable de una columna sale de su nombre (o ninguna si no da uno válido)', async () => {
    const { sheetVar } = await import('./FichaSheet.vue');
    expect(sheetVar('Carrera')).toBe('CARRERA');
    expect(sheetVar('Nombre carrera')).toBe('NOMBRE_CARRERA');
    expect(sheetVar('Precio $')).toBe('');
  });

  it('valores, inicial y «pasa a … cuando» por cada valor; libre = «se guarda cuando»', async () => {
    const { default: FichaVariables } = await import('./FichaVariables.vue');
    const variable = {
      name: 'LIGA',
      values: ['NO', 'SÍ'],
      free: false,
      initial: 'NO',
      rules: [],
    };
    const wrapper = shallowMount(FichaVariables, {
      propsData: {
        value: [variable],
        sheetVars: [{ name: 'CARRERA', column: 'Carrera', sheet: 'Precios' }],
      },
      mocks: { $t: clave => clave },
    });
    expect(wrapper.vm.targets(variable)).toEqual(['SÍ']);
    expect(wrapper.vm.derived.map(d => d.name)).toEqual(['CARRERA']);
    wrapper.vm.setRule(0, 'SÍ', ' le mande la liga ');
    expect(wrapper.emitted('input')[0][0][0].rules).toEqual([
      { to: 'SÍ', when: 'le mande la liga' },
    ]);
    wrapper.vm.setValues(0, 'PENDIENTE, ENVIADA');
    expect(wrapper.emitted('input')[1][0][0]).toMatchObject({
      values: ['PENDIENTE', 'ENVIADA'],
      initial: 'PENDIENTE',
      rules: [],
    });
    wrapper.vm.setFree(0, true);
    expect(wrapper.emitted('input')[2][0][0]).toMatchObject({
      free: true,
      values: ['VACÍO'],
    });
    expect(wrapper.vm.targets({ free: true })).toEqual(['*']);
  });

  it('datos del negocio: «Nombre del agente» se llena con el nombre que ve el cliente', async () => {
    const { default: FichaBusiness } = await import('./FichaBusiness.vue');
    const wrapper = shallowMount(FichaBusiness, {
      propsData: { value: [], agentName: 'Ana' },
      mocks: { $t: clave => clave },
    });
    const preset = wrapper.vm.presets.find(p => p.key === 'AGENT_NAME');
    wrapper.vm.add(preset);
    expect(wrapper.emitted('input')[0][0]).toEqual([
      { label: 'TRACKING_TEMPLATES.FICHA.BUSINESS_AGENT_NAME', value: 'Ana' },
    ]);
  });
});

describe('Tono', () => {
  it('cada tono arranca con sus ajustes y el ejemplo cambia con ellos', async () => {
    const { toneDefaults, toneExample, TONES } = await import(
      './FichaIdentity.vue'
    );
    expect(TONES).toEqual([
      'cercano',
      'profesional',
      'entusiasta',
      'empatico',
      'directo',
    ]);
    expect(toneDefaults('entusiasta')).toEqual({
      emojis: true,
      short: false,
      question: true,
    });
    expect(toneDefaults('profesional')).toEqual({
      emojis: false,
      short: false,
      question: false,
    });
    expect(
      toneExample('empatico', { emojis: false, short: true, question: false })
    ).toBe('Entiendo que necesitas resolverlo pronto.');
    expect(
      toneExample('directo', { emojis: true, short: false, question: true })
    ).toBe('Grúa de 30 t: $1,800 por día. ¿Para qué fecha la necesitas? 🚚');
  });

  it('al cambiar de tono, los ajustes vuelven a los de ese tono', async () => {
    const { default: FichaIdentity } = await import('./FichaIdentity.vue');
    const wrapper = shallowMount(FichaIdentity, {
      propsData: {
        value: { name: '', tone: 'cercano', objective: '', business: '' },
        showTone: true,
      },
      mocks: { $t: clave => clave },
    });
    wrapper.vm.setTone('directo');
    expect(wrapper.emitted('input')[0][0]).toMatchObject({
      tone: 'directo',
      toneAdjust: { emojis: false, short: true, question: false },
    });
  });
});
