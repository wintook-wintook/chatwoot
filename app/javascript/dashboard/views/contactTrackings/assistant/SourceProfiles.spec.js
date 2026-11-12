import { shallowMount } from '@vue/test-utils';
import SourceProfiles from './SourceProfiles.vue';

const montar = props =>
  shallowMount(SourceProfiles, {
    propsData: props,
    mocks: { $t: c => c },
    stubs: ['CopyChip'],
  });

describe('SourceProfiles', () => {
  it('dibuja una tarjeta por fuente con sus ejemplos', () => {
    const wrapper = montar({
      profiles: [
        {
          tipo: 'hoja',
          nombre: 'Precios',
          que_tiene: 'Producto · Precio (2 filas)',
          ejemplo: ['Grúa | $1,800'],
          se_le_puede_preguntar: 'busca por Producto',
          como_se_usa: '{{hoja_buscar: …}}',
          ruta_sugerida: '@ruta(…)',
        },
        {
          tipo: 'predefinidas',
          nombre: 'Respuestas predefinidas',
          que_tiene: '3 respuestas',
          ejemplo: { VEN: ['VEN-precio', 'VEN-promo'] },
          como_se_usa: '@buscar_predefinidas(VEN)',
        },
      ],
    });
    expect(wrapper.findAll('article')).toHaveLength(2);
    expect(wrapper.text()).toContain('Grúa | $1,800');
    expect(wrapper.vm.examples(wrapper.vm.profiles[1])).toEqual([
      'VEN: VEN-precio, VEN-promo',
    ]);
  });

  it('sin fuentes lo dice, con lo que falta', () => {
    const wrapper = montar({
      profiles: [],
      missing: ['google_sheet', 'case_type'],
    });
    expect(wrapper.text()).toContain('PROFILES_EMPTY');
    expect(wrapper.vm.missingText).toBe(
      'TRACKING_ASSISTANT_VIEW.PROFILES_MISSING_google_sheet · TRACKING_ASSISTANT_VIEW.PROFILES_MISSING_case_type'
    );
  });
});
