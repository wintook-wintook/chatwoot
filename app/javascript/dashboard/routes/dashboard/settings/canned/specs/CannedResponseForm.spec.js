import { shallowMount } from '@vue/test-utils';
import CannedResponseForm from '../CannedResponseForm.vue';

// proyecto@predefinidas_prompt — docs/predefinidas_prompt_plan.md §3.4
const montar = (
  props = {},
  etiquetas = [{ title: 'demo' }, { title: 'tracking' }]
) =>
  shallowMount(CannedResponseForm, {
    propsData: {
      shortCode: 'COTIZACION',
      content: 'Cotización de equipo.',
      ...props,
    },
    mocks: {
      $t: (clave, args) => (args ? `${clave} ${JSON.stringify(args)}` : clave),
      $store: { getters: { 'labels/getLabels': etiquetas }, dispatch: vi.fn() },
    },
    computed: { labels: () => etiquetas },
    stubs: [
      'woot-tabs',
      'woot-tabs-item',
      'WootMessageEditor',
      'WootSubmitButton',
    ],
  });

describe('CannedResponseForm', () => {
  it('entrega el nombre, el mensaje y el prompt al guardar', () => {
    const wrapper = montar({ contentPrompts: '1. Pedí la cantidad.' });

    wrapper.vm.submit();

    expect(wrapper.emitted('submit')[0][0]).toEqual({
      short_code: 'COTIZACION',
      content: 'Cotización de equipo.',
      content_prompts: '1. Pedí la cantidad.',
      content_is_prompt: false,
    });
  });

  // La casilla "El mensaje es el prompt" viaja aparte del Prompt de Contenido.
  it('entrega la casilla "El mensaje es el prompt" marcada y desmarcada', async () => {
    const wrapper = montar({ contentIsPrompt: true });
    wrapper.vm.submit();
    expect(wrapper.emitted('submit')[0][0].content_is_prompt).toBe(true);

    await wrapper.find('#canned-content-is-prompt').setChecked(false);
    wrapper.vm.submit();
    expect(wrapper.emitted('submit')[1][0]).toMatchObject({
      content_is_prompt: false,
      content_prompts: '',
    });
  });

  // La pestaña del prompt avisa que tiene algo sin tener que abrirla.
  it('marca la pestaña del prompt cuando tiene texto', () => {
    expect(montar().vm.promptTabName).toBe(
      'CANNED_MGMT.FORM_PROMPT.TAB_PROMPT'
    );
    expect(montar({ contentPrompts: 'algo' }).vm.promptTabName).toBe(
      'CANNED_MGMT.FORM_PROMPT.TAB_PROMPT_ACTIVE'
    );
    expect(montar({ contentPrompts: '   ' }).vm.promptTabName).toBe(
      'CANNED_MGMT.FORM_PROMPT.TAB_PROMPT'
    );
  });

  // El error no se esconde en la otra pestaña.
  it('vuelve a "Mensaje" si se guarda sin mensaje desde el prompt', () => {
    const wrapper = montar({ content: '' });
    wrapper.vm.showTab(1);

    wrapper.vm.submit();

    expect(wrapper.vm.activeTab).toBe(0);
    expect(wrapper.emitted('submit')).toBeUndefined();
  });

  it('no guarda sin nombre', () => {
    const wrapper = montar({ shortCode: '' });

    wrapper.vm.submit();

    expect(wrapper.emitted('submit')).toBeUndefined();
  });

  describe('el aviso de etiquetas', () => {
    // El caso real de #1330: con tilde, el motor lee otra cosa.
    it('avisa la etiqueta que el motor no puede leer y dice qué lee', () => {
      const avisos = montar({
        contentPrompts: '8. Utiliza la etiqueta: #SolicitaCotización',
      }).vm.tagWarnings;

      expect(avisos).toHaveLength(1);
      expect(avisos[0]).toContain('TAG_UNREADABLE');
      expect(avisos[0]).toContain('#SolicitaCotizaci');
    });

    it('avisa la etiqueta que no existe en la cuenta', () => {
      const avisos = montar({ contentPrompts: 'Cerrá con #cotizacion' }).vm
        .tagWarnings;

      expect(avisos).toEqual([
        'CANNED_MGMT.FORM_PROMPT.TAG_MISSING {"tag":"#cotizacion"}',
      ]);
    });

    it('no avisa las etiquetas que existen, sin importar mayúsculas', () => {
      expect(
        montar({ contentPrompts: 'Cerrá con #Demo o #tracking.' }).vm
          .tagWarnings
      ).toEqual([]);
    });

    // "#1" es un paso numerado, y "# Título" es un encabezado: ninguno es etiqueta.
    it('no confunde pasos numerados ni encabezados con etiquetas', () => {
      expect(
        montar({
          contentPrompts: '# Pasos\nPaso #1: saludá. Paso #2: pedí datos.',
        }).vm.tagWarnings
      ).toEqual([]);
    });
  });
});
