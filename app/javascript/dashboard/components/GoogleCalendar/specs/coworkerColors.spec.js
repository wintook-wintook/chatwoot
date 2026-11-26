import { shallowMount } from '@vue/test-utils';
import {
  agentColor,
  agentTextColor,
  autoTextColor,
  coworkerColorsFrom,
  defaultAgentColor,
  TEXT_COLORS,
} from '../agentColor';
import CoworkerColorModal from '../CoworkerColorModal.vue';
import AgendaWidget from '../AgendaWidget.vue';
import CalendarView from '../CalendarView.vue';

// fix/calendario_eliminar F4 — colores de compañeros (solo los ve quien los escoge).
describe('colores de compañeros', () => {
  it('sin elección: el color de siempre', () => {
    expect(agentColor(4, {})).toBe(defaultAgentColor(4));
    expect(coworkerColorsFrom(null)).toEqual({});
    expect(coworkerColorsFrom({ calendar_coworker_colors: { 4: {} } })).toEqual(
      { 4: {} }
    );
  });

  it('con elección: mi fondo y mi letra', () => {
    const custom = { 4: { bg: '#0ea5e9', text: 'white' } };
    expect(agentColor(4, custom)).toBe('#0ea5e9');
    expect(agentTextColor(4, custom)).toBe(TEXT_COLORS.white);
    expect(agentColor(5, custom)).toBe(defaultAgentColor(5));
  });

  it('letra automática: negra sobre claros (verde limón, cian), blanca sobre oscuros', () => {
    expect(autoTextColor('#a3e635')).toBe(TEXT_COLORS.black);
    expect(autoTextColor('#22d3ee')).toBe(TEXT_COLORS.black);
    expect(autoTextColor('#1e3a8a')).toBe(TEXT_COLORS.white);
    expect(autoTextColor('#64748b')).toBe(TEXT_COLORS.white);
    expect(agentTextColor(4, { 4: { bg: '#a3e635', text: 'auto' } })).toBe(
      TEXT_COLORS.black
    );
  });
});

describe('CoworkerColorModal', () => {
  const mountModal = props =>
    shallowMount(CoworkerColorModal, {
      propsData: {
        show: true,
        name: 'Andres',
        bg: '#a3e635',
        text: 'auto',
        ...props,
      },
      mocks: { $t: (k, v) => (v ? `${k}:${v.name}` : k) },
      stubs: {
        'woot-modal': { template: '<div><slot /></div>' },
        'woot-modal-header': true,
        WootSubmitButton: true,
      },
    });

  it('escoger no guarda; «Guardar» manda fondo y letra', async () => {
    const wrapper = mountModal();
    await wrapper.find('[data-test="swatch-#0ea5e9"]').trigger('click');
    await wrapper.findAll('input[type="radio"]').at(1).setChecked();
    expect(wrapper.emitted('save')).toBeUndefined();

    await wrapper.find('form').trigger('submit');
    expect(wrapper.emitted('save')[0]).toEqual([
      { bg: '#0ea5e9', text: 'white' },
    ]);
  });

  it('la vista previa usa el fondo y la letra que se leen', () => {
    const style = mountModal()
      .find('[data-test="color-sample"]')
      .attributes('style');
    expect(style).toContain('background-color: rgb(163, 230, 53)');
    expect(style).toContain('color: rgb(31, 41, 55)');
  });

  it('«Restablecer» solo sale si ya escogí un color', async () => {
    expect(mountModal().find('[data-test="color-reset"]').exists()).toBe(false);
    const wrapper = mountModal({ custom: true });
    await wrapper.find('[data-test="color-reset"]').trigger('click');
    expect(wrapper.emitted('reset')).toHaveLength(1);
  });
});

describe('AgendaWidget · guardar colores en mis preferencias', () => {
  const ctxWith = uiSettings => {
    const ctx = {
      $store: { getters: { getUISettings: uiSettings }, dispatch: vi.fn() },
    };
    ctx.coworkerColors = AgendaWidget.computed.coworkerColors.call(ctx);
    ctx.saveCoworkerColors = AgendaWidget.methods.saveCoworkerColors.bind(ctx);
    return ctx;
  };

  it('guarda sin borrar las demás preferencias', () => {
    const ctx = ctxWith({ show_sidebar: true });
    AgendaWidget.methods.setCoworkerColor.call(ctx, 4, {
      bg: '#0ea5e9',
      text: 'auto',
    });
    expect(ctx.$store.dispatch).toHaveBeenCalledWith('updateUISettings', {
      uiSettings: {
        show_sidebar: true,
        calendar_coworker_colors: { 4: { bg: '#0ea5e9', text: 'auto' } },
      },
    });
  });

  it('Guardar y Restablecer cierran la ventana', () => {
    const ctx = ctxWith({});
    ctx.colorMenuFor = 4;
    ctx.setCoworkerColor = vi.fn();
    ctx.resetCoworkerColor = vi.fn();
    AgendaWidget.methods.saveColor.call(ctx, { bg: '#0ea5e9', text: 'auto' });
    expect(ctx.setCoworkerColor).toHaveBeenCalledWith(4, {
      bg: '#0ea5e9',
      text: 'auto',
    });
    expect(ctx.colorMenuFor).toBeNull();

    ctx.colorMenuFor = 4;
    AgendaWidget.methods.resetColor.call(ctx);
    expect(ctx.resetCoworkerColor).toHaveBeenCalledWith(4);
    expect(ctx.colorMenuFor).toBeNull();
  });

  it('Restablecer quita solo a ese compañero', () => {
    const ctx = ctxWith({
      calendar_coworker_colors: { 4: { bg: '#0ea5e9' }, 9: { bg: '#ef4444' } },
    });
    AgendaWidget.methods.resetCoworkerColor.call(ctx, 4);
    expect(
      ctx.$store.dispatch.mock.calls[0][1].uiSettings.calendar_coworker_colors
    ).toEqual({
      9: { bg: '#ef4444' },
    });
  });
});

describe('CalendarView · eventos del compañero con mi color', () => {
  it('pinta fondo, borde y letra', () => {
    const added = [];
    const ctx = {
      coworkerEvents: [
        {
          agent_id: 4,
          name: 'Andres',
          events: [{ id: 'e1', summary: 'Junta', start: 'a', end: 'b' }],
        },
      ],
      coworkerColors: { 4: { bg: '#a3e635', text: 'auto' } },
      $t: k => k,
    };
    CalendarView.methods.addCoworkerEvents.call(ctx, {
      addEvent: e => added.push(e),
    });
    expect(added[0]).toMatchObject({
      backgroundColor: '#a3e635',
      borderColor: '#a3e635',
      textColor: TEXT_COLORS.black,
      title: 'Andres · Junta',
    });
  });
});
