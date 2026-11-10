import { shallowMount } from '@vue/test-utils';
import FichaCards from './FichaCards.vue';
import FichaWizard from './FichaWizard.vue';
import AgentFicha from './AgentFicha.vue';
import FichaFiles, { nameFromFile, uniqueName } from './FichaFiles.vue';
import AiAgentAttachmentsAPI from 'dashboard/api/aiAgentAttachments';
import FichaAPI from 'dashboard/api/fichaAgente';

vi.mock('dashboard/api/fichaAgente', () => ({
  default: {
    catalog: vi.fn(),
    preview: vi.fn(),
    create: vi.fn(),
    suggest: vi.fn(),
    activate: vi.fn(),
    get: vi.fn(),
    save: vi.fn(),
    apply: vi.fn(),
  },
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/api/aiAgentAttachments', () => ({
  default: { upload: vi.fn() },
}));

const CARDS = [
  { key: 'google_sheet:1', kind: 'sheet', name: 'Precios', status: 'ready' },
  { key: 'google_doc:2', kind: 'doc', name: 'Políticas', status: 'warn' },
  {
    key: 'canned_response',
    kind: 'canned',
    name: 'Predefinidas',
    status: 'ready',
    parts: [
      { key: 'PATITAS', label: 'PATITAS', count: 14, not_ready: 0 },
      { key: 'SSUSA', label: 'SSUSA', count: 6, not_ready: 2 },
    ],
  },
  { key: 'calendar:3', kind: 'calendar', name: 'Agenda', status: 'ready' },
];

const esperar = () =>
  new Promise(resolve => {
    setTimeout(resolve);
  });

const mocks = { $t: (clave, args) => (args ? `${clave}` : clave) };

describe('FichaCards', () => {
  const montar = (value, extra = {}) =>
    shallowMount(FichaCards, {
      propsData: { cards: CARDS, value, ...extra },
      mocks,
      directives: { tooltip: {} },
    });

  it('marca y desmarca un recurso', () => {
    const wrapper = montar([]);
    wrapper.vm.toggle(CARDS[0]);
    expect(wrapper.emitted('input')[0][0]).toEqual([{ key: 'google_sheet:1' }]);
    const marcado = montar([{ key: 'google_sheet:1' }]);
    marcado.vm.toggle(CARDS[0]);
    expect(marcado.emitted('input')[0][0]).toEqual([]);
  });

  it('«Marcar las listas» solo agrega las que están listas; «Quitar todas» las quita', () => {
    const wrapper = montar([]);
    const fuentes = wrapper.vm.groups.find(g => g.id === 'sources');
    wrapper.vm.selectReady(fuentes);
    expect(wrapper.emitted('input')[0][0].map(i => i.key)).toEqual([
      'google_sheet:1',
      'canned_response',
    ]);
    const marcadas = montar([{ key: 'google_sheet:1' }, { key: 'calendar:3' }]);
    marcadas.vm.clearGroup(marcadas.vm.groups.find(g => g.id === 'sources'));
    expect(marcadas.emitted('input')[0][0]).toEqual([{ key: 'calendar:3' }]);
  });

  it('elige grupos de predefinidas; sin grupos = todos; sin ninguno se desmarca', () => {
    const wrapper = montar([{ key: 'canned_response' }]);
    expect(wrapper.vm.isPartOn(CARDS[2], CARDS[2].parts[1])).toBe(true);
    wrapper.vm.togglePart(CARDS[2], CARDS[2].parts[1]);
    expect(wrapper.emitted('input')[0][0]).toEqual([
      { key: 'canned_response', parts: ['PATITAS'] },
    ]);
    const uno = montar([{ key: 'canned_response', parts: ['PATITAS'] }]);
    uno.vm.togglePart(CARDS[2], CARDS[2].parts[0]);
    expect(uno.emitted('input')[0][0]).toEqual([]);
    const nada = montar([]);
    nada.vm.togglePart(CARDS[2], CARDS[2].parts[1]);
    expect(nada.emitted('input')[0][0]).toEqual([
      { key: 'canned_response', parts: ['SSUSA'] },
    ]);
  });

  it('muestra solo el grupo pedido y filtra por texto y por tipo', () => {
    expect(montar([], { only: ['calendar'] }).vm.groups.map(g => g.id)).toEqual(
      ['calendar']
    );
    const buscar = montar([], { only: ['sources'], query: 'ssusa' });
    expect(buscar.vm.groups[0].cards.map(c => c.key)).toEqual([
      'canned_response',
    ]);
    const tipo = montar([], { only: ['sources'], kind: 'doc' });
    expect(tipo.vm.groups[0].cards.map(c => c.key)).toEqual(['google_doc:2']);
  });
});

describe('FichaWizard', () => {
  const PREVIEW = {
    prompt: '@ruta(x #xxx: y): {{hoja:Precios}}',
    objective: 'Atender a los clientes',
    routes: [{ name: 'x', label: 'Contestar', description: 'pregunta' }],
    offers: [
      { key: 'google_sheet:1', label: 'Contestar datos', on: true },
      { key: 'calendar:3', label: 'Agendar', on: true },
    ],
    validation: { valid: true, blocking: [], degrading: [] },
  };

  beforeEach(() => {
    FichaAPI.catalog.mockResolvedValue({ data: { cards: CARDS } });
    FichaAPI.preview.mockResolvedValue({ data: PREVIEW });
    FichaAPI.create.mockResolvedValue({ data: { ...PREVIEW, id: 77 } });
    FichaAPI.save.mockResolvedValue({ data: {} });
    AiAgentAttachmentsAPI.upload.mockResolvedValue({ data: { id: 5 } });
  });

  const montar = () =>
    shallowMount(FichaWizard, {
      mocks: {
        ...mocks,
        $store: {
          getters: {
            'inboxes/getInboxes': [
              { id: 5, name: 'Web', channel_type: 'Channel::WebWidget' },
            ],
            'integrations/getAppIntegrations': [
              {
                id: 'tracking_bot',
                enabled: true,
                hooks: [{ status: true, inbox: { id: 5, name: 'Web' } }],
              },
            ],
          },
          dispatch: vi.fn(),
        },
      },
    });

  it('empieza en Canal y seguimiento y cuenta lo marcado por sección', async () => {
    const wrapper = montar();
    await esperar();
    expect(wrapper.vm.section).toBe('channel');
    wrapper.setData({
      items: [{ key: 'google_sheet:1' }, { key: 'calendar:3' }],
    });
    const menu = Object.fromEntries(wrapper.vm.navItems.map(i => [i.id, i]));
    expect(menu.sources).toMatchObject({ count: 1, total: 3 });
    expect(menu.calendar).toMatchObject({ count: 1, total: 1 });
    expect(wrapper.vm.navItems.map(i => i.id)).toEqual([
      'channel',
      'sources',
      'calendar',
      'tickets',
      'files',
      'rules',
    ]);
    expect(menu.channel.state).toBe('todo');
    expect(wrapper.vm.nextSection).toBe('sources');
  });

  it('Continuar pide canal y al menos una ruta', async () => {
    const wrapper = montar();
    await esperar();
    expect(wrapper.vm.canContinue).toBe(false);
    wrapper.setData({ items: [{ key: 'google_sheet:1' }] });
    await wrapper.vm.loadPreview();
    expect(wrapper.vm.canContinue).toBe(false);
    wrapper.setData({ follow: { ...wrapper.vm.follow, inboxId: 5 } });
    expect(wrapper.vm.channelOk).toBe(true);
    expect(wrapper.vm.canContinue).toBe(true);
    expect(wrapper.vm.canCreate).toBe(false);
  });

  it('✨ bienvenida: propone o mejora el texto', async () => {
    FichaAPI.suggest.mockResolvedValue({
      data: { welcome: '¡Hola! Soy Sofía' },
    });
    const wrapper = montar();
    await esperar();
    await wrapper.vm.suggest('welcome');
    expect(FichaAPI.suggest).toHaveBeenLastCalledWith(
      expect.objectContaining({ field: 'welcome' })
    );
    expect(wrapper.vm.welcome).toBe('¡Hola! Soy Sofía');
  });

  it('✨ Proponer con IA llena el objetivo o el contexto y lo que falta', async () => {
    FichaAPI.suggest.mockResolvedValue({
      data: {
        objective: 'Atender a los clientes',
        ai_context: 'Renta de grúas',
        missing: ['horario de atención'],
      },
    });
    const wrapper = montar();
    await esperar();
    await wrapper.vm.suggest('context');
    expect(wrapper.vm.business).toBe('Renta de grúas');
    expect(wrapper.vm.objective).toBe('');
    expect(wrapper.vm.missing).toEqual(['horario de atención']);
    wrapper.vm.addMissing('horario de atención');
    expect(wrapper.vm.business).toBe('Renta de grúas\nhorario de atención: ');
    expect(wrapper.vm.missing).toEqual([]);
    await wrapper.vm.suggest('objective');
    expect(wrapper.vm.objective).toBe('Atender a los clientes');
  });

  it('nombre + un recurso → Crear agente (sube los archivos y los marca)', async () => {
    const wrapper = montar();
    await esperar();
    expect(wrapper.vm.canCreate).toBe(false);
    wrapper.setData({
      name: 'Ventas',
      items: [{ key: 'google_sheet:1' }],
      follow: { ...wrapper.vm.follow, inboxId: 5 },
      files: [
        {
          key: 1,
          name: 'catalogo',
          file: { name: 'Catálogo.pdf' },
          ask: false,
          welcome: true,
          attempts: [2],
        },
      ],
    });
    await wrapper.vm.loadPreview();
    expect(wrapper.vm.canCreate).toBe(true);
    wrapper.vm.toggleOffer(PREVIEW.offers[1]);
    wrapper.setData({
      keywordActions: [{ keyword: 'asesor' }],
      welcome: 'Hola ',
    });
    expect(wrapper.vm.payload).toMatchObject({
      skip: ['calendar:3'],
      files: [{ name: 'catalogo', ask: false, welcome: true, attempts: [2] }],
      keyword_actions: [{ keyword: 'asesor' }],
      inbox_id: 5,
      retry_interval_value: 1,
      retry_interval_unit: 'days',
      attempts: 3,
      whatsapp_templates: [],
      welcome: 'Hola',
    });
    expect(wrapper.vm.welcomeFiles.map(f => f.name)).toEqual(['catalogo']);

    await wrapper.vm.create();
    expect(FichaAPI.create).toHaveBeenCalledWith(
      expect.objectContaining({ name: 'Ventas' })
    );
    expect(AiAgentAttachmentsAPI.upload).toHaveBeenCalledWith(77, {
      name: 'catalogo',
      file: { name: 'Catálogo.pdf' },
    });
    expect(FichaAPI.save).toHaveBeenCalledWith(
      77,
      [{ key: 'google_sheet:1' }, { key: 'file:5' }],
      { keyword_actions: [{ keyword: 'asesor' }] }
    );
    expect(wrapper.emitted('created')[0]).toEqual([77]);
  });

  it('una frase agregada desde la prueba viaja con la ficha; activar solo con canal', async () => {
    const wrapper = montar();
    await esperar();
    wrapper.vm.addPhrase({ key: 'calendar:3', phrase: '¿hay lugar?' });
    wrapper.vm.addPhrase({ key: 'calendar:3', phrase: '¿hay lugar?' });
    expect(wrapper.vm.payload.phrases).toEqual({
      'calendar:3': ['¿hay lugar?'],
    });
    wrapper.setData({ activateOnCreate: true });
    expect(wrapper.vm.payload.activate).toBe(false);
    wrapper.setData({ follow: { ...wrapper.vm.follow, inboxId: 5 } });
    expect(wrapper.vm.payload.activate).toBe(true);
    expect(wrapper.vm.testPayload.activate).toBeUndefined();
    expect(wrapper.vm.payload.agenda).toBeNull();
    wrapper.setData({ items: [{ key: 'calendar:3' }] });
    expect(wrapper.vm.calendarIds).toEqual([3]);
    expect(wrapper.vm.payload.agenda).toMatchObject({
      calendar_event_duration: 30,
    });
  });

  it('no deja crear si el comprobador encuentra errores', async () => {
    const wrapper = montar();
    await esperar();
    wrapper.setData({
      name: 'Ventas',
      preview: { ...PREVIEW, validation: { valid: false, blocking: [{}] } },
    });
    expect(wrapper.vm.canCreate).toBe(false);
  });
});

describe('FichaFiles', () => {
  it('nombra cada archivo desde su nombre y no repite', () => {
    expect(nameFromFile('Catálogo 2026.pdf')).toBe('catalogo-2026');
    expect(uniqueName('catalogo', ['Catalogo'])).toBe('catalogo-2');
    const wrapper = shallowMount(FichaFiles, {
      propsData: { value: [], existingNames: ['garantia'] },
      mocks,
    });
    wrapper.vm.add([
      { name: 'Garantía.pdf', size: 10 },
      { name: 'garantia.doc', size: 10 },
    ]);
    expect(wrapper.emitted('input')[0][0].map(i => i.name)).toEqual([
      'garantia-2',
      'garantia-3',
    ]);
  });
});

describe('AgentFicha', () => {
  const DATA = {
    cards: CARDS,
    items: [{ key: 'google_sheet:1' }],
    changes: {
      added: [{ key: 'google_sheet:1', name: 'Precios', label: 'Contestar' }],
      removed: [
        { key: 'calendar:3', name: 'Agenda', route: 'agendar' },
        { key: 'calendar:9', name: 'Otra', route: 'agendar' },
      ],
      not_ready: [],
      confirmed: true,
    },
  };

  beforeEach(() => {
    FichaAPI.get.mockResolvedValue({ data: DATA });
    FichaAPI.save.mockResolvedValue({ data: DATA });
    FichaAPI.apply.mockResolvedValue({ data: DATA });
  });

  const montar = () =>
    shallowMount(AgentFicha, { propsData: { templateId: 7 }, mocks });

  it('un archivo subido se marca y se guarda solo', async () => {
    const wrapper = montar();
    await esperar();
    wrapper.vm.onUploaded({ id: 9 });
    expect(FichaAPI.save).toHaveBeenCalledWith(
      7,
      [{ key: 'google_sheet:1' }, { key: 'file:9' }],
      { keyword_actions: [], agenda: {}, file_rules: {} }
    );
  });

  it('una frase de la prueba se suma a esa ruta del Entrenamiento', async () => {
    const wrapper = montar();
    await esperar();
    wrapper.vm.addPhrase({ route: 'agendar', phrase: '¿hay lugar?' });
    expect(FichaAPI.apply).toHaveBeenLastCalledWith(7, {
      add: [],
      remove: [],
      phrases: { agendar: ['¿hay lugar?'] },
    });
  });

  it('activar pide confirmación y, con OK, crea la automatización', async () => {
    FichaAPI.activate.mockResolvedValue({ data: DATA });
    const wrapper = montar();
    await esperar();
    const showConfirmation = vi.fn().mockResolvedValueOnce(false);
    wrapper.vm.$refs.activateDialog = { showConfirmation };
    await wrapper.vm.activate();
    expect(FichaAPI.activate).not.toHaveBeenCalled();
    showConfirmation.mockResolvedValueOnce(true);
    await wrapper.vm.activate();
    expect(FichaAPI.activate).toHaveBeenCalledWith(7);
  });

  it('las Reglas se cargan, cuentan como cambio y se guardan con la ficha', async () => {
    const regla = {
      keyword: 'asesor',
      action: 'handoff',
      direction: 'incoming',
    };
    FichaAPI.get.mockResolvedValue({
      data: { ...DATA, keyword_actions: [regla] },
    });
    const wrapper = montar();
    await esperar();
    expect(wrapper.vm.rules).toEqual([regla]);
    expect(wrapper.vm.navItems.find(i => i.id === 'rules').count).toBe(1);
    wrapper.setData({ rules: [] });
    expect(wrapper.vm.dirty).toBe(true);
    await wrapper.vm.save();
    expect(FichaAPI.save).toHaveBeenLastCalledWith(7, DATA.items, {
      keyword_actions: [],
      agenda: {},
      file_rules: {},
    });
  });

  it('carga la ficha, cuenta los cambios y avisa al espacio del agente', async () => {
    const wrapper = montar();
    await esperar();
    expect(wrapper.vm.pending).toBe(3);
    expect(wrapper.emitted('changes')[0]).toEqual([3]);
    expect(wrapper.vm.dirty).toBe(false);
  });

  it('marcar algo deja cambios sin guardar; guardar los manda', async () => {
    const wrapper = montar();
    await esperar();
    wrapper.setData({
      items: [{ key: 'google_sheet:1' }, { key: 'calendar:3' }],
    });
    expect(wrapper.vm.dirty).toBe(true);
    await wrapper.vm.save();
    expect(FichaAPI.save).toHaveBeenCalledWith(
      7,
      [{ key: 'google_sheet:1' }, { key: 'calendar:3' }],
      { keyword_actions: [], agenda: {}, file_rules: {} }
    );
  });

  it('«Aplicar todos» agrega y quita cada ruta una sola vez', async () => {
    const wrapper = montar();
    await esperar();
    wrapper.vm.applyAll();
    await esperar();
    expect(FichaAPI.apply).toHaveBeenCalledWith(7, {
      add: ['google_sheet:1'],
      remove: ['agendar'],
      phrases: {},
    });
    expect(wrapper.emitted('applied')).toBeTruthy();
  });
});
