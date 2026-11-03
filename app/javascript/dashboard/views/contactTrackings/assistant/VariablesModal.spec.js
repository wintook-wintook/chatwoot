import { shallowMount } from '@vue/test-utils';
import VariablesModal from './VariablesModal.vue';

// proyecto@crear_agente_conversando — F1 (docs/creacion_conversacional_agentes_plan.md §3)
const montar = (props = {}) =>
  shallowMount(VariablesModal, {
    propsData: { show: false, ...props },
    mocks: { $t: c => c, $tc: c => c },
    stubs: ['woot-modal', 'woot-button'],
  });

const abrir = async (props = {}) => {
  const wrapper = montar(props);
  await wrapper.setProps({ show: true });
  return wrapper;
};

const BECAS = {
  variables: [
    { name: 'CARRERA', options: [], free: true, initial: '' },
    {
      name: 'LIGA_ENTREGADA',
      options: ['NO', 'SÍ'],
      free: false,
      initial: 'NO',
    },
  ],
  extra: ['Nota de la sección'],
};

describe('VariablesModal', () => {
  it('carga las variables como filas al abrir', async () => {
    const wrapper = await abrir({ value: BECAS });
    expect(wrapper.vm.rows).toEqual([
      { name: 'CARRERA', values: '', free: true, initial: '' },
      { name: 'LIGA_ENTREGADA', values: 'NO | SÍ', free: false, initial: 'NO' },
    ]);
    expect(wrapper.vm.hasNotes).toBe(true);
  });

  it('sin variables abre con una fila vacía', async () => {
    expect((await abrir()).vm.rows).toHaveLength(1);
  });

  it('guarda la lista con el nombre limpio y conserva las notas', async () => {
    const wrapper = await abrir({ value: BECAS });
    wrapper.vm.rows.push({
      name: 'nivel interes',
      values: 'ALTO|BAJO',
      free: false,
      initial: 'BAJO',
    });
    wrapper.vm.save();
    const [[guardado]] = wrapper.emitted('save');
    expect(guardado.variables[2]).toEqual({
      name: 'NIVEL_INTERES',
      options: ['ALTO', 'BAJO'],
      free: false,
      initial: 'BAJO',
    });
    expect(guardado.extra).toEqual(['Nota de la sección']);
  });

  it('no guarda con un nombre repetido o sin valores', async () => {
    const wrapper = await abrir({ value: BECAS });
    wrapper.vm.rows.push({
      name: 'carrera',
      values: 'A',
      free: false,
      initial: '',
    });
    wrapper.vm.rows.push({
      name: 'OTRA',
      values: '',
      free: false,
      initial: '',
    });
    wrapper.vm.save();
    expect(wrapper.emitted('save')).toBeUndefined();
    expect(wrapper.vm.errors.slice(2)).toEqual([
      'VARIABLES_ERROR_DUPLICATE',
      'VARIABLES_ERROR_NO_VALUES',
    ]);
  });

  it('un inicial que ya no está en la lista se descarta', async () => {
    const wrapper = await abrir({ value: BECAS });
    wrapper.vm.rows[1].values = 'NO | TAL_VEZ | SÍ';
    wrapper.vm.rows[1].initial = 'QUIZÁ';
    wrapper.vm.save();
    expect(wrapper.emitted('save')[0][0].variables[1].initial).toBe('');
  });

  it('ofrece pasar las sueltas y recarga al volver la lista', async () => {
    const wrapper = await abrir({
      value: { variables: [], extra: [] },
      strayCount: 2,
    });
    expect(wrapper.text()).toContain('VARIABLES_STRAY_MOVE');
    await wrapper.setProps({ value: BECAS, strayCount: 0 });
    expect(wrapper.vm.rows.map(r => r.name)).toEqual([
      'CARRERA',
      'LIGA_ENTREGADA',
    ]);
    expect(wrapper.text()).not.toContain('VARIABLES_STRAY_MOVE');
  });
});
