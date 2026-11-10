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
    });
  });
});

describe('FichaTicket', () => {
  it('agrega motivos (sin repetir ni paréntesis), quita y cambia prioridad', async () => {
    const { default: FichaTicket } = await import('./FichaTicket.vue');
    const wrapper = shallowMount(FichaTicket, {
      propsData: {
        card: { name: 'Soporte' },
        value: { reasons: ['a'], priority: '' },
      },
      mocks: { $t: clave => clave },
    });
    wrapper.vm.add('reporta (una) falla');
    expect(wrapper.emitted('input')[0][0]).toMatchObject({
      reasons: ['a', 'reporta una falla'],
      priority: '',
    });
    wrapper.vm.add('a');
    expect(wrapper.emitted('input')).toHaveLength(1);
    wrapper.vm.remove('a');
    expect(wrapper.emitted('input')[1][0].reasons).toEqual([]);
    wrapper.vm.emit({ priority: 'alta' });
    expect(wrapper.emitted('input')[2][0].priority).toBe('alta');
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
