import { mount } from '@vue/test-utils';
import CampaignKnowledge from './CampaignKnowledge.vue';
import CampaignReplies from './CampaignReplies.vue';
import { fillCampaignText, guessSource } from './campaignFlow';

const mocks = { $t: key => key, $te: () => false };
const stubs = { CampaignFiles: true, 'fluent-icon': true };

describe('La ficha y las respuestas de la campaña', () => {
  it('la ficha enseña los campos del tipo y agrega una liga «con la información»', async () => {
    const wrapper = mount(CampaignKnowledge, {
      propsData: {
        brief: { facts: {}, links: [], objections: [] },
        kind: 'invite',
        kit: { facts: ['when', 'place', 'more'] },
        save: () => true,
      },
      mocks,
      stubs,
    });
    expect(wrapper.findAll('textarea')).toHaveLength(3);
    const add = wrapper
      .findAll('button')
      .filter(b => b.text() === 'CAMPAIGNS2.KNOWLEDGE.LINKS.ADD')
      .at(0);
    await add.trigger('click');
    const brief = wrapper.emitted('update:brief')[0][0];
    expect(brief.links[0]).toMatchObject({ use: 'package', url: '' });
  });

  it('las etiquetas quedan como las de la cuenta (minúsculas, sin espacios)', async () => {
    const wrapper = mount(CampaignReplies, {
      propsData: {
        brief: { offer_goal: 'external', replies: {}, labels: {} },
        kind: 'invite',
        kit: { asks_future: true, replies: { achieved: '¡Gracias!' } },
      },
      mocks,
    });
    expect(wrapper.find('textarea').attributes('placeholder')).toBe(
      '¡Gracias!'
    );
    await wrapper.find('input').setValue('Ya Registrado!');
    expect(wrapper.emitted('update:brief')[0][0].labels.achieved).toBe(
      'ya-registrado'
    );
  });

  it('el paquete llena los datos de cada contacto', () => {
    expect(
      fillCampaignText('Te vence {{vence}} por {{monto}}', {
        due_date: '30 de noviembre',
        due_amount: '$1,800 MXN',
      })
    ).toBe('Te vence 30 de noviembre por $1,800 MXN');
    expect(guessSource('monto', 2)).toBe('due_amount');
  });
});
