import { shallowMount } from '@vue/test-utils';
import ExportMenu from './ExportMenu.vue';
import { downloadEngineCatalog } from './engineCatalogMarkdown';

vi.mock('./engineCatalogMarkdown', () => ({
  downloadEngineCatalog: vi.fn(),
}));

const montar = props =>
  shallowMount(ExportMenu, {
    propsData: props,
    mocks: {
      $t: c => c,
      $i18n: { locale: 'es' },
      $store: {
        getters: {
          getCurrentAccountId: 2,
          'accounts/getAccount': () => ({ name: 'Kontrolya' }),
        },
      },
    },
    directives: { onClickaway: {} },
    stubs: {
      'woot-button': {
        template: '<button @click="$emit(\'click\')"><slot /></button>',
      },
      WootDropdownMenu: { template: '<div><slot /></div>' },
      WootDropdownItem: { template: '<div><slot /></div>' },
    },
  });

const abrir = async wrapper => {
  await wrapper.find('button').trigger('click');
};

describe('ExportMenu', () => {
  it('ofrece los dos archivos y pide las instrucciones al de arriba', async () => {
    const wrapper = montar({ catalog: [{ key: 'hoja' }], hasAgent: true });
    await abrir(wrapper);

    const opciones = wrapper.findAll('button').wrappers.slice(1);
    expect(opciones.map(b => b.text())).toEqual([
      'TRACKING_ASSISTANT_VIEW.EXPORT_INSTRUCTIONS',
      'TRACKING_ASSISTANT_VIEW.EXPORT_RESOURCES',
    ]);
    await opciones[0].trigger('click');
    expect(wrapper.emitted('instructions')).toHaveLength(1);
  });

  it('los recursos se descargan con el nombre de la cuenta', async () => {
    const wrapper = montar({ catalog: [{ key: 'hoja' }] });
    await abrir(wrapper);

    const opciones = wrapper.findAll('button').wrappers.slice(1);
    expect(opciones).toHaveLength(1);
    await opciones[0].trigger('click');
    expect(downloadEngineCatalog).toHaveBeenCalledWith(
      [{ key: 'hoja' }],
      expect.any(Function),
      { accountName: 'Kontrolya', locale: 'es' }
    );
  });
});
