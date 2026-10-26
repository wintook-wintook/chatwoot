import { createLocalVue, shallowMount } from '@vue/test-utils';
import VueI18n from 'vue-i18n';
import i18n from 'dashboard/i18n';
import InboxGroupsOrderModal from '../InboxGroupsOrderModal.vue';
import { DEFAULT_INBOX_GROUP_ORDER } from 'dashboard/helper/inboxGroups';

const localVue = createLocalVue();
localVue.use(VueI18n);

const i18nConfig = new VueI18n({ locale: 'es', messages: i18n });

const mountModal = (order = ['email', 'whatsapp', 'meta']) =>
  shallowMount(InboxGroupsOrderModal, {
    localVue,
    i18n: i18nConfig,
    propsData: { order, counts: { whatsapp: 3 } },
    stubs: ['woot-modal', 'woot-modal-header', 'woot-button', 'fluent-icon'],
  });

describe('InboxGroupsOrderModal', () => {
  it('works on a copy of the order', () => {
    const order = ['email', 'whatsapp'];
    const wrapper = mountModal(order);
    wrapper.vm.move(0, 1);
    expect(order).toEqual(['email', 'whatsapp']);
    expect(wrapper.vm.draft).toEqual(['whatsapp', 'email']);
  });

  it('moves a group up and down, and ignores moves past the edges', () => {
    const wrapper = mountModal();
    wrapper.vm.move(2, -1);
    expect(wrapper.vm.draft).toEqual(['email', 'meta', 'whatsapp']);
    wrapper.vm.move(0, -1);
    wrapper.vm.move(2, 1);
    expect(wrapper.vm.draft).toEqual(['email', 'meta', 'whatsapp']);
  });

  it('resets to the default order', () => {
    const wrapper = mountModal();
    wrapper.vm.reset();
    expect(wrapper.vm.draft).toEqual([...DEFAULT_INBOX_GROUP_ORDER]);
  });

  it('emits the new order on save', () => {
    const wrapper = mountModal();
    wrapper.vm.move(1, -1);
    wrapper.vm.save();
    expect(wrapper.emitted().save[0][0]).toEqual(['whatsapp', 'email', 'meta']);
  });

  it('shows the translated group names with their inbox count', () => {
    const wrapper = mountModal();
    expect(wrapper.vm.groupLabel('meta')).toBe('Meta (Messenger e Instagram)');
    expect(wrapper.vm.countFor('whatsapp')).toBe(3);
    expect(wrapper.vm.countFor('email')).toBe(0);
  });
});
