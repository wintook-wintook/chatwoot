import { shallowMount } from '@vue/test-utils';
import RouteCards from './RouteCards.vue';

// proyecto@asistente_agentes_ia — docs/formulario_entrenamiento_plan.md §7 fase 2
const lineas = () => [
  {
    kind: 'route',
    name: 'comercial',
    tag: 'precios',
    description: 'cuanto cuesta',
    source: '{{hoja:Precios}}',
    escalation: '@crear_ticket(tipo=Comercial)',
    raw: '@ruta(comercial #precios: cuanto cuesta): {{hoja:Precios}} -> @crear_ticket(tipo=Comercial)',
  },
  {
    kind: 'route',
    name: 'humano',
    tag: '',
    description: 'quiero un asesor',
    source: '',
    escalation: '',
    raw: '@ruta(humano: quiero un asesor): -',
  },
  {
    kind: 'default',
    name: 'comercial',
    raw: '@ruta_por_defecto: comercial',
  },
];

const opciones = {
  sources: ['{{hoja:Precios}}', '@buscar_articulo'],
  labels: ['precios', 'soporte'],
  caseTypes: ['Comercial'],
  actions: ['@estado_ticket'],
};

const montar = (props = {}) =>
  shallowMount(RouteCards, {
    propsData: { lines: lineas(), options: opciones, ...props },
    global: { mocks: { $t: clave => clave } },
    mocks: { $t: (clave, args) => (args ? `${clave}:${args.value}` : clave) },
    stubs: { 'woot-button': true, 'fluent-icon': true },
  });

describe('RouteCards', () => {
  it('muestra una tarjeta por rama y no una por la rama por defecto', () => {
    const wrapper = montar();

    expect(wrapper.vm.routes.map(r => r.name)).toEqual(['comercial', 'humano']);
    expect(wrapper.findAll('textarea')).toHaveLength(2);
  });

  it('emite la lista completa al cambiar un campo', async () => {
    const wrapper = montar();

    wrapper.vm.update(1, { source: '@buscar_articulo' });

    const emitidas = wrapper.emitted('input')[0][0];
    expect(emitidas).toHaveLength(3);
    expect(emitidas[1].source).toBe('@buscar_articulo');
    // La rama que no se tocó viaja igual, con su línea original.
    expect(emitidas[0]).toEqual(lineas()[0]);
  });

  // Agregar una rama abre el modal: la rama se arma allá, con su línea de alcance.
  it('avisa que se quiere agregar una rama en vez de crearla acá', () => {
    const wrapper = montar();
    const botones = wrapper.findAll('woot-button-stub');

    // El último es el "Agregar rama" del pie.
    botones.at(botones.length - 1).vm.$emit('click');

    expect(wrapper.emitted('add')).toBeTruthy();
    expect(wrapper.emitted('input')).toBeUndefined();
  });

  // Dentro del modal: una sola rama, sin pie ni botones de mover y quitar.
  it('en modo compacto no muestra el pie ni los botones de la tarjeta', () => {
    const compacto = montar({ lines: [lineas()[0]], compact: true });
    const normal = montar({ lines: [lineas()[0]] });

    expect(compacto.find('#route-default').exists()).toBe(false);
    expect(normal.find('#route-default').exists()).toBe(true);
    expect(compacto.findAll('woot-button-stub').length).toBeLessThan(
      normal.findAll('woot-button-stub').length
    );
  });

  it('cambia la rama por defecto sin tocar las demás líneas', () => {
    const wrapper = montar();

    wrapper.vm.setDefault('humano');

    const emitidas = wrapper.emitted('input')[0][0];
    expect(emitidas[2]).toMatchObject({ kind: 'default', name: 'humano' });
  });

  it('quita la línea de rama por defecto cuando se elige ninguna', () => {
    const wrapper = montar();

    wrapper.vm.setDefault('');

    expect(wrapper.emitted('input')[0][0].map(l => l.kind)).toEqual([
      'route',
      'route',
    ]);
  });

  it('agrega la rama por defecto cuando el bloque no la tenía', () => {
    const wrapper = montar({ lines: lineas().slice(0, 2) });

    wrapper.vm.setDefault('humano');

    expect(wrapper.emitted('input')[0][0][2]).toEqual({
      kind: 'default',
      name: 'humano',
      raw: '',
    });
  });

  // Las listas salen del inventario: abrir caso, o una acción disponible. El tipo y
  // la prioridad se eligen aparte, porque son tres decisiones distintas.
  it('ofrece abrir caso y las acciones de la cuenta', () => {
    expect(montar().vm.escalationOptions).toEqual([
      '@crear_ticket',
      '@estado_ticket',
    ]);
  });

  it('muestra tipo y prioridad solo cuando la rama abre un caso', () => {
    const wrapper = montar({
      lines: [
        {
          kind: 'route',
          name: 'admin',
          action: '@crear_ticket',
          case_type: 'Comercial',
          priority: 'alta',
        },
      ],
    });

    expect(wrapper.find('select[id^="route-case-"]').exists()).toBe(true);
    expect(wrapper.find('select[id^="route-prio-"]').exists()).toBe(true);
  });

  it('se lleva el tipo y la prioridad al elegir otra acción', () => {
    const wrapper = montar({
      lines: [
        {
          kind: 'route',
          name: 'admin',
          action: '@crear_ticket',
          case_type: 'Comercial',
          priority: 'alta',
        },
      ],
    });

    wrapper.vm.setAction(0, '@agendar_calendar');

    expect(wrapper.emitted('input')[0][0][0]).toMatchObject({
      action: '@agendar_calendar',
      case_type: '',
      priority: '',
    });
  });

  // Una fuente que ya no existe se sigue ofreciendo, marcada: si desapareciera del
  // selector, abrir el agente le cambiaría la fuente sin avisar.
  it('ofrece marcado un valor guardado que no está en la lista', () => {
    const wrapper = montar();

    expect(wrapper.vm.extraOption('{{hoja:Borrada}}', opciones.sources)).toBe(
      '{{hoja:Borrada}}'
    );
    expect(wrapper.vm.extraOption('{{hoja:Precios}}', opciones.sources)).toBe(
      null
    );
  });

  // Una línea del bloque que el parser no reconoce se muestra tal cual: esconderla
  // la borraría al guardar.
  it('muestra las líneas que no son ramas', () => {
    const wrapper = montar({
      lines: [{ kind: 'other', raw: '# nota suelta' }],
    });

    expect(wrapper.vm.others).toHaveLength(1);
    expect(wrapper.find('input').element.value).toBe('# nota suelta');
  });
});
