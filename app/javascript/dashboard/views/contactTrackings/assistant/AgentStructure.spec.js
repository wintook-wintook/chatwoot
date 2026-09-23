import { shallowMount } from '@vue/test-utils';
import AgentStructure from './AgentStructure.vue';

// proyecto@asistente_agentes_ia — docs/estructura_agente_arbol_plan.md
const estructura = () => ({
  blocks: [
    {
      type: 'routes',
      text: '',
      gap: 1,
      lines: [
        { kind: 'route', name: 'soporte', description: 'no puedo entrar' },
        { kind: 'route', name: 'comercial', description: 'cuanto cuesta' },
        { kind: 'default', name: 'comercial' },
      ],
    },
    { type: 'section', title: 'ROL', body: 'Sos amable.', gap: 1 },
    {
      type: 'section',
      title: 'ALCANCE POR RAMA',
      body: 'soporte: atiende fallas.\ncomercial: atiende precios.',
      gap: 0,
    },
  ],
});

const montar = (props = {}) =>
  shallowMount(AgentStructure, {
    propsData: { value: estructura(), ...props },
    mocks: { $t: clave => clave },
    stubs: ['woot-button', 'fluent-icon', 'woot-modal'],
  });

const ultimo = wrapper => {
  const eventos = wrapper.emitted('input');
  return eventos[eventos.length - 1][0].blocks;
};

describe('AgentStructure', () => {
  describe('editar una rama', () => {
    it('abre el modal con la rama, su alcance y si es la por defecto', () => {
      const wrapper = montar();

      wrapper.vm.openEditRoute(1);

      expect(wrapper.vm.editingRoute.name).toBe('comercial');
      expect(wrapper.vm.editingRouteScope).toBe('atiende precios.');
      expect(wrapper.vm.editingRouteIsDefault).toBe(true);
      // Su propio nombre no cuenta como "ya en uso".
      expect(wrapper.vm.takenRouteNames).toEqual(['soporte']);
    });

    it('guarda el nombre nuevo y renombra su línea de alcance', () => {
      const wrapper = montar();
      wrapper.vm.openEditRoute(0);

      wrapper.vm.saveRoute({
        route: {
          kind: 'route',
          name: 'soporte_tecnico',
          description: 'no abre',
        },
        previousName: 'soporte',
        scope: 'atiende fallas y errores',
        isDefault: false,
      });

      const blocks = ultimo(wrapper);
      expect(blocks[0].lines.map(l => l.name)).toEqual([
        'soporte_tecnico',
        'comercial',
        'comercial',
      ]);
      expect(blocks[2].body).toBe(
        'comercial: atiende precios.\nsoporte_tecnico: atiende fallas y errores'
      );
    });

    it('pone y saca la rama por defecto desde el modal', () => {
      const wrapper = montar();
      wrapper.vm.openEditRoute(0);
      wrapper.vm.saveRoute({
        route: { kind: 'route', name: 'soporte' },
        previousName: 'soporte',
        scope: '',
        isDefault: true,
      });

      expect(
        ultimo(wrapper)[0].lines.find(l => l.kind === 'default').name
      ).toBe('soporte');

      const otro = montar();
      otro.vm.openEditRoute(1);
      otro.vm.saveRoute({
        route: { kind: 'route', name: 'comercial' },
        previousName: 'comercial',
        scope: '',
        isDefault: false,
      });

      expect(ultimo(otro)[0].lines.some(l => l.kind === 'default')).toBe(false);
    });

    it('quita la rama con su línea de alcance y cierra el modal', () => {
      const wrapper = montar();
      wrapper.vm.openEditRoute(0);

      wrapper.vm.deleteRoute();

      const blocks = ultimo(wrapper);
      expect(blocks[0].lines.filter(l => l.kind === 'route')).toHaveLength(1);
      expect(blocks[2].body).toBe('comercial: atiende precios.');
      expect(wrapper.vm.routeModal.show).toBe(false);
    });

    it('agrega la rama nueva con su alcance', () => {
      const wrapper = montar();
      wrapper.vm.openAddRoute();

      expect(wrapper.vm.editingRoute).toBe(null);
      wrapper.vm.saveRoute({
        route: { kind: 'route', name: 'admin' },
        previousName: '',
        scope: 'atiende facturas',
        isDefault: false,
      });

      expect(ultimo(wrapper)[2].body).toContain('admin: atiende facturas');
    });
  });

  describe('editar una sección', () => {
    it('guarda el nombre y el cuerpo', () => {
      const wrapper = montar();
      wrapper.vm.openEditSection(1);

      wrapper.vm.saveSection({ title: 'ROL', body: 'Sos formal.' });

      expect(ultimo(wrapper)[1]).toMatchObject({
        title: 'ROL',
        body: 'Sos formal.',
      });
    });

    // El texto inicial no lleva rótulo: su contenido va en `text`, no en `body`.
    it('el texto inicial se guarda en su propio campo', () => {
      const wrapper = montar({
        value: { blocks: [{ type: 'preamble', text: 'AGENTE v1', gap: 1 }] },
      });
      wrapper.vm.openEditSection(0);

      wrapper.vm.saveSection({ title: '', body: 'AGENTE v2' });

      expect(ultimo(wrapper)[0]).toMatchObject({
        type: 'preamble',
        text: 'AGENTE v2',
      });
    });

    it('agrega la sección con su contenido', () => {
      const wrapper = montar();
      wrapper.vm.openAddSection();

      wrapper.vm.saveSection({
        title: 'PROHIBIDO',
        body: 'No prometer plazos.',
      });

      const blocks = ultimo(wrapper);
      expect(blocks[blocks.length - 1]).toMatchObject({
        type: 'section',
        title: 'PROHIBIDO',
        body: 'No prometer plazos.',
      });
    });

    it('quita la sección', () => {
      const wrapper = montar();
      wrapper.vm.openEditSection(1);

      wrapper.vm.deleteSection();

      expect(ultimo(wrapper).map(b => b.title)).toEqual([
        undefined,
        'ALCANCE POR RAMA',
      ]);
    });

    // El agente lee las secciones en el orden en que están escritas.
    // Arrastrar la primera sección debajo de la segunda.
    it('cambia una sección de lugar arrastrándola', () => {
      const wrapper = montar();

      wrapper.vm.reorderSection({ from: 0, to: 1 });

      expect(ultimo(wrapper).map(b => b.title)).toEqual([
        undefined,
        'ALCANCE POR RAMA',
        'ROL',
      ]);
    });

    // Soltarla donde estaba no es un cambio.
    it('no avisa ningún cambio si se suelta en el mismo lugar', () => {
      const wrapper = montar();

      wrapper.vm.reorderSection({ from: 0, to: 0 });

      expect(wrapper.emitted('input')).toBeUndefined();
    });

    it('los nombres en uso son los que no se pueden repetir', () => {
      expect(montar().vm.takenTitles).toEqual(['ROL', 'ALCANCE POR RAMA']);
    });
  });

  // El objetivo y el contexto NO son parte del texto: salen aparte.
  it('la definición no toca los bloques', () => {
    const wrapper = montar();

    wrapper.vm.openDefinition('ai_context');
    wrapper.vm.saveDefinition({ objective: 'Atender', ai_context: 'Horario' });

    expect(wrapper.emitted('updateDefinition')[0][0]).toEqual({
      objective: 'Atender',
      ai_context: 'Horario',
    });
    expect(wrapper.emitted('input')).toBeUndefined();
  });

  it('usa el nombre que la cuenta le da a la sección de alcance', () => {
    const wrapper = montar({
      titles: { suggested: ['ROL', 'ALCANCE POR TEMA'] },
    });

    expect(wrapper.vm.scopeTitle).toBe('ALCANCE POR TEMA');
  });
});
