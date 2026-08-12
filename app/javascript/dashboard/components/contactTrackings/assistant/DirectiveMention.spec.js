import { mount } from '@vue/test-utils';
import DirectiveMention from './DirectiveMention.vue';

// proyecto@ai_agent_assistant — la lista que sale al escribir «/» en el chat.
//
// Esta prueba existe porque el componente se subió con dos defectos que ni eslint
// ni la lógica en aislado podían ver: se escuchaba el evento en kebab-case (Vue 2
// no convierte el casing de eventos, así que elegir no hacía nada) y el bloque
// nunca llegó a insertarse en la plantilla del panel. Montar y pulsar lo caza.

const CAPACIDADES = [
  {
    key: 'buscar_articulo',
    available: true,
    swallows_prompt: true,
    renders_prompt: false,
    tokens: [{ token: '@buscar_articulo', label: null }],
  },
  {
    key: 'hoja',
    available: true,
    swallows_prompt: false,
    renders_prompt: false,
    tokens: [{ token: '{{hoja:Precios}}', label: '«Precios»' }],
  },
  {
    key: 'discourse',
    available: false,
    swallows_prompt: true,
    renders_prompt: false,
    tokens: [{ token: '@discourse', label: null }],
  },
];

const montar = (props = {}) =>
  mount(DirectiveMention, {
    propsData: { capabilities: CAPACIDADES, searchKey: '', ...props },
    mocks: { $t: clave => clave },
  });

describe('DirectiveMention.vue', () => {
  it('lista solo las directivas disponibles en la cuenta', () => {
    const textos = montar().findAll('.mention--box button').wrappers;
    const etiquetas = textos.map(w => w.text());

    expect(etiquetas.join(' ')).toContain('@buscar_articulo');
    expect(etiquetas.join(' ')).toContain('{{hoja:Precios}}');
    expect(etiquetas.join(' ')).not.toContain('@discourse');
  });

  // Si vas a equivocarte, que no sea por el orden de la lista.
  it('pone delante lo que NO descarta tu prompt', () => {
    const primero = montar().findAll('.mention--box button').at(0);

    expect(primero.text()).toContain('{{hoja:Precios}}');
  });

  it('filtra por lo que llevas escrito tras la barra', () => {
    const items = montar({ searchKey: 'hoja' }).findAll('.mention--box button');

    expect(items).toHaveLength(1);
    expect(items.at(0).text()).toContain('{{hoja:Precios}}');
  });

  it('no se pinta si no hay nada que ofrecer', () => {
    expect(montar({ searchKey: 'zzz' }).isVisible()).toBe(false);
  });

  // El defecto original: el evento se escuchaba en kebab-case y no llegaba nunca.
  it('al elegir una directiva emite su token exacto', async () => {
    const wrapper = montar();
    await wrapper.findAll('.mention--box button').at(0).trigger('click');

    expect(wrapper.emitted('select')).toBeTruthy();
    expect(wrapper.emitted('select')[0]).toEqual(['{{hoja:Precios}}']);
  });
});
