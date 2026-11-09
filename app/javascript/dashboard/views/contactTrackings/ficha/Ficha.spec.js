import { shallowMount } from '@vue/test-utils';
import FichaCards from './FichaCards.vue';
import FichaWizard from './FichaWizard.vue';
import AgentFicha from './AgentFicha.vue';
import FichaAPI from 'dashboard/api/fichaAgente';

vi.mock('dashboard/api/fichaAgente', () => ({
  default: {
    catalog: vi.fn(),
    preview: vi.fn(),
    create: vi.fn(),
    get: vi.fn(),
    save: vi.fn(),
    apply: vi.fn(),
  },
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

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
  const montar = value =>
    shallowMount(FichaCards, { propsData: { cards: CARDS, value }, mocks });

  it('marca y desmarca un recurso', () => {
    const wrapper = montar([]);
    wrapper.vm.toggle(CARDS[0]);
    expect(wrapper.emitted('input')[0][0]).toEqual([{ key: 'google_sheet:1' }]);
    const marcado = montar([{ key: 'google_sheet:1' }]);
    marcado.vm.toggle(CARDS[0]);
    expect(marcado.emitted('input')[0][0]).toEqual([]);
  });

  it('«Marcar las listas» solo agrega las que están listas', () => {
    const wrapper = montar([]);
    const fuentes = wrapper.vm.groups.find(g => g.id === 'sources');
    wrapper.vm.selectReady(fuentes);
    expect(wrapper.emitted('input')[0][0].map(i => i.key)).toEqual([
      'google_sheet:1',
      'canned_response',
    ]);
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
  });

  it('agrupa por tipo y siempre muestra Archivos', () => {
    const wrapper = montar([]);
    expect(wrapper.vm.groups.map(g => g.id)).toEqual([
      'sources',
      'calendar',
      'files',
    ]);
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
  });

  const montar = () =>
    shallowMount(FichaWizard, {
      mocks: {
        ...mocks,
        $store: {
          getters: { 'inboxes/getInboxes': [{ id: 5, name: 'WA' }] },
          dispatch: vi.fn(),
        },
      },
    });

  it('pide nombre y al menos un recurso antes de seguir', async () => {
    const wrapper = montar();
    await esperar();
    expect(wrapper.vm.cards).toHaveLength(4);
    expect(wrapper.vm.canContinue).toBe(false);
    wrapper.setData({ name: 'Ventas', items: [{ key: 'google_sheet:1' }] });
    expect(wrapper.vm.canContinue).toBe(true);
  });

  it('en tres clics: recursos → qué hará → crear', async () => {
    const wrapper = montar();
    await esperar();
    wrapper.setData({ name: 'Ventas', items: [{ key: 'google_sheet:1' }] });
    await wrapper.vm.next();
    expect(FichaAPI.preview).toHaveBeenCalled();
    expect(wrapper.vm.step).toBe('offers');
    expect(wrapper.vm.activeOffers).toHaveLength(2);

    wrapper.vm.toggleOffer(PREVIEW.offers[1]);
    expect(wrapper.vm.payload.skip).toEqual(['calendar:3']);

    await wrapper.vm.next();
    expect(wrapper.vm.step).toBe('review');
    await wrapper.vm.next();
    await esperar();
    expect(FichaAPI.create).toHaveBeenCalledWith(
      expect.objectContaining({ name: 'Ventas', skip: ['calendar:3'] })
    );
    expect(wrapper.emitted('created')[0]).toEqual([77]);
  });

  it('no deja crear si el comprobador encuentra errores', async () => {
    const wrapper = montar();
    await esperar();
    wrapper.setData({
      step: 'review',
      preview: { ...PREVIEW, validation: { valid: false, blocking: [{}] } },
    });
    expect(wrapper.vm.canContinue).toBe(false);
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
    expect(FichaAPI.save).toHaveBeenCalledWith(7, [
      { key: 'google_sheet:1' },
      { key: 'calendar:3' },
    ]);
  });

  it('«Aplicar todos» agrega y quita cada ruta una sola vez', async () => {
    const wrapper = montar();
    await esperar();
    wrapper.vm.applyAll();
    await esperar();
    expect(FichaAPI.apply).toHaveBeenCalledWith(7, {
      add: ['google_sheet:1'],
      remove: ['agendar'],
    });
    expect(wrapper.emitted('applied')).toBeTruthy();
  });
});
