import { shallowMount } from '@vue/test-utils';
import TemplateButtonsEditor from './TemplateButtonsEditor.vue';

// feat/plantillas_whatsapp_mejoras F10.3 — la pestaña Botones del editor
const montar = value =>
  shallowMount(TemplateButtonsEditor, {
    propsData: { value },
    mocks: { $t: clave => clave },
    stubs: ['fluent-icon', 'woot-input', 'woot-button', 'Draggable'],
  });

describe('TemplateButtonsEditor', () => {
  it('separa respuestas rápidas y acciones', () => {
    const wrapper = montar([
      { type: 'URL', text: 'Ver' },
      { type: 'QUICK_REPLY', text: 'Sí' },
    ]);

    expect(wrapper.vm.quickReplies.map(b => b.text)).toEqual(['Sí']);
    expect(wrapper.vm.actions.map(b => b.text)).toEqual(['Ver']);
  });

  it('una respuesta rápida nueva entra en su grupo, antes de las acciones', () => {
    const wrapper = montar([{ type: 'URL', text: 'Ver' }]);

    wrapper.vm.add('QUICK_REPLY');

    expect(wrapper.emitted('input')[0][0].map(b => b.type)).toEqual([
      'QUICK_REPLY',
      'URL',
    ]);
  });

  it('no agrega más del tope de Meta y dice por qué', () => {
    const wrapper = montar([{ type: 'COPY_CODE' }]);

    wrapper.vm.add('COPY_CODE');

    expect(wrapper.emitted('input')).toBeUndefined();
    expect(wrapper.vm.blockerText('COPY_CODE')).toBe(
      'WHATSAPP_TEMPLATE_EDITOR.BUTTONS.LIMIT_TYPE'
    );
  });

  it('cambiar a liga con dato agrega el {{1}} y a fija lo quita', () => {
    const boton = { type: 'URL', text: 'Ver', url: 'https://x.mx/p/' };
    const wrapper = montar([boton]);

    wrapper.vm.setUrlMode(boton, true);
    expect(boton.url).toBe('https://x.mx/p/{{1}}');

    wrapper.vm.setUrlMode(boton, false);
    expect(boton.url).toBe('https://x.mx/p/');
    expect(boton.example).toEqual([]);
  });
});
