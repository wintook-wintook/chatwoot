import { shallowMount } from '@vue/test-utils';
import CampaignSettingsMenu from '../CampaignSettingsMenu.vue';

const montar = () =>
  shallowMount(CampaignSettingsMenu, {
    propsData: {
      handoffSummary: 'Solo con el botón «Entregar» · Sin plazo',
      scoringSummary: 'Sin reglas de Perfil: solo cuenta el Interés',
    },
    mocks: { $t: key => key },
    directives: { onClickaway: {} },
    stubs: {
      'woot-button': {
        template:
          '<button class="toggle" @click="$emit(\'click\')"><slot /></button>',
      },
      'fluent-icon': true,
    },
  });

describe('CampaignSettingsMenu', () => {
  it('el tooltip del botón trae los dos resúmenes', () => {
    const title = montar().find('.toggle').attributes('title');
    expect(title).toContain('Sin plazo');
    expect(title).toContain('solo cuenta el Interés');
  });

  it('abre el menú con las dos opciones y su resumen', async () => {
    const wrapper = montar();
    expect(wrapper.findAll('button[type="button"]').length).toBe(0);
    await wrapper.find('.toggle').trigger('click');
    const options = wrapper.findAll('button[type="button"]');
    expect(options.length).toBe(2);
    expect(options.at(0).text()).toContain('Sin plazo');
    expect(options.at(1).text()).toContain('solo cuenta el Interés');
  });

  it('cada opción emite su evento y cierra el menú', async () => {
    const wrapper = montar();
    await wrapper.find('.toggle').trigger('click');
    await wrapper.findAll('button[type="button"]').at(1).trigger('click');
    expect(wrapper.emitted('scoring')).toHaveLength(1);
    expect(wrapper.emitted('handoff')).toBeUndefined();
    expect(wrapper.findAll('button[type="button"]').length).toBe(0);
  });

  it('Esc cierra el menú', async () => {
    const wrapper = montar();
    await wrapper.find('.toggle').trigger('click');
    window.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }));
    await wrapper.vm.$nextTick();
    expect(wrapper.findAll('button[type="button"]').length).toBe(0);
  });
});
