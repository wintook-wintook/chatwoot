import { shallowMount } from '@vue/test-utils';
import ConstantsModal from './ConstantsModal.vue';

const montar = props =>
  shallowMount(ConstantsModal, {
    propsData: { show: false, ...props },
    mocks: { $t: (c, a) => (a ? `${c} ${JSON.stringify(a)}` : c) },
    stubs: ['woot-modal', 'woot-button', 'CopyChip'],
  });

const abrir = async props => {
  const wrapper = montar(props);
  await wrapper.setProps({ show: true });
  return wrapper;
};

const VALUE = {
  constants: [
    { name: 'EMPRESA', type: 'texto', value: 'Kontrolya', savesTo: '' },
    {
      name: 'Q1',
      type: 'pregunta',
      value: '¿Qué sistema usas?',
      savesTo: 'SISTEMA',
    },
  ],
  extra: [],
};

describe('ConstantsModal', () => {
  it('carga los datos fijos al abrir', async () => {
    const wrapper = await abrir({ value: VALUE });
    expect(wrapper.vm.rows.map(r => r.name)).toEqual(['EMPRESA', 'Q1']);
  });

  it('guarda con el nombre limpio y quita «guarda en» si ya no es pregunta', async () => {
    const wrapper = await abrir({ value: VALUE });
    wrapper.vm.rows[1].type = 'texto';
    wrapper.vm.rows.push({
      name: 'liga agenda',
      type: 'liga',
      value: ' https://x.mx ',
      savesTo: '',
    });
    wrapper.vm.save();
    const [[guardado]] = wrapper.emitted('save');
    expect(guardado.constants[1].savesTo).toBe('');
    expect(guardado.constants[2]).toEqual({
      name: 'LIGA_AGENDA',
      type: 'liga',
      value: 'https://x.mx',
      savesTo: '',
    });
  });

  it('no guarda con nombre repetido o sin contenido', async () => {
    const wrapper = await abrir({ value: VALUE });
    wrapper.vm.rows.push({
      name: 'empresa',
      type: 'texto',
      value: 'Otra',
      savesTo: '',
    });
    wrapper.vm.rows.push({
      name: 'VACIO',
      type: 'texto',
      value: ' ',
      savesTo: '',
    });
    wrapper.vm.save();
    expect(wrapper.emitted('save')).toBeUndefined();
    expect(wrapper.vm.errors.slice(2)).toEqual([
      'CONSTANTS_ERROR_DUPLICATE',
      'CONSTANTS_ERROR_NO_VALUE',
    ]);
  });

  it('dice dónde se usa y avisa los que no se usan', async () => {
    const wrapper = await abrir({
      value: VALUE,
      usage: { EMPRESA: { count: 2, places: ['', '@demo'] } },
    });
    expect(wrapper.vm.usageText(wrapper.vm.rows[0])).toContain('@demo');
    expect(wrapper.vm.isUsed(wrapper.vm.rows[1])).toBe(false);
    expect(wrapper.vm.refOf(wrapper.vm.rows[1])).toBe('%Q1%');
  });

  it("con focus 'new' agrega uno y con un índice edita solo ese", async () => {
    const nuevo = await abrir({ value: VALUE, focus: 'new' });
    expect(nuevo.vm.title).toBe('TRACKING_ASSISTANT_VIEW.CONSTANTS_TITLE_ADD');
    Object.assign(nuevo.vm.rows[2], {
      name: 'LIGA',
      type: 'liga',
      value: 'https://k.mx',
    });
    nuevo.vm.save();
    expect(nuevo.emitted('save')[0][0].constants.map(c => c.name)).toEqual([
      'EMPRESA',
      'Q1',
      'LIGA',
    ]);

    const uno = await abrir({ value: VALUE, focus: 0 });
    expect([0, 1].map(i => uno.vm.isShown(i))).toEqual([true, false]);
  });
});
