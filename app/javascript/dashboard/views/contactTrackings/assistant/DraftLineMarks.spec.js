import { mount } from '@vue/test-utils';
import DraftLineMarks from './DraftLineMarks.vue';

// En jsdom nada tiene tamaño: cada línea mide 16px y el marco 400×300.
const caja = (top, alto, ancho = 400) => ({
  top,
  bottom: top + alto,
  left: 0,
  right: ancho,
  width: ancho,
  height: alto,
});

const montar = async () => {
  const marco = document.createElement('div');
  const editor = document.createElement('textarea');
  // Vue 2 REEMPLAZA el elemento donde monta: va uno de relleno dentro del marco.
  const lugar = document.createElement('div');
  marco.append(lugar, editor);
  document.body.appendChild(marco);
  marco.getBoundingClientRect = () => caja(0, 300);
  const wrapper = mount(DraftLineMarks, {
    attachTo: lugar,
    propsData: {
      text: 'uno\n@ruta(x #x: algo)\ntres',
      marks: { 2: 'blocking' },
      messages: { 2: [{ level: 'blocking', message: 'La ruta no cierra.' }] },
      target: editor,
    },
  });
  wrapper.vm.$refs.lines.forEach((fila, i) => {
    fila.getBoundingClientRect = () => caja(8 + i * 16, 16);
  });
  return { wrapper, editor };
};

const mover = (editor, clientY) =>
  editor.dispatchEvent(new MouseEvent('mousemove', { clientX: 100, clientY }));

describe('DraftLineMarks — aviso al pasar el mouse', () => {
  it('sobre la línea marcada muestra lo que dice el comprobador', async () => {
    const { wrapper, editor } = await montar();
    mover(editor, 30); // línea 2: de 24 a 40
    await wrapper.vm.$nextTick();

    expect(wrapper.text()).toContain('🔴 La ruta no cierra.');
    expect(wrapper.vm.hover.position).toEqual({ top: '44px' });
  });

  it('sobre una línea sin marca, o al salir del editor, no muestra nada', async () => {
    const { wrapper, editor } = await montar();
    mover(editor, 12); // línea 1
    await wrapper.vm.$nextTick();
    expect(wrapper.text()).not.toContain('La ruta no cierra.');

    mover(editor, 30);
    editor.dispatchEvent(new MouseEvent('mouseleave'));
    await wrapper.vm.$nextTick();
    expect(wrapper.vm.hover).toBeNull();
  });
});
