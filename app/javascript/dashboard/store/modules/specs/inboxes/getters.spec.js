import { getters } from '../../inboxes';
import inboxList from './fixtures';

describe('#getters', () => {
  it('getInboxes', () => {
    const state = {
      records: inboxList,
    };
    expect(getters.getInboxes(state)).toEqual(inboxList);
  });

  // feat/plantillas_whatsapp_mejoras: ya no se quitan las de imagen o video.
  it('getWhatsAppTemplates devuelve todas, también las de imagen o video', () => {
    const plantillas = [
      { name: 'texto', components: [{ type: 'BODY', text: 'Hola' }] },
      {
        name: 'video',
        components: [{ type: 'HEADER', format: 'VIDEO' }, { type: 'BODY' }],
      },
      {
        name: 'imagen',
        components: [{ type: 'HEADER', format: 'IMAGE' }, { type: 'BODY' }],
      },
    ];
    const state = { records: [{ id: 9, message_templates: plantillas }] };

    expect(getters.getWhatsAppTemplates(state)(9)).toEqual(plantillas);
    expect(getters.getWhatsAppTemplates(state)(1)).toEqual([]);
  });

  it('getWebsiteInboxes', () => {
    const state = { records: inboxList };
    expect(getters.getWebsiteInboxes(state).length).toEqual(3);
  });

  it('getTwilioInboxes', () => {
    const state = { records: inboxList };
    expect(getters.getTwilioInboxes(state).length).toEqual(1);
  });

  it('getSMSInboxes', () => {
    const state = { records: inboxList };
    expect(getters.getSMSInboxes(state).length).toEqual(2);
  });

  it('dialogFlowEnabledInboxes', () => {
    const state = { records: inboxList };
    expect(getters.dialogFlowEnabledInboxes(state).length).toEqual(6);
  });

  it('getInbox', () => {
    const state = {
      records: inboxList,
    };
    expect(getters.getInbox(state)(1)).toEqual({
      id: 1,
      channel_id: 1,
      name: 'Test FacebookPage 1',
      channel_type: 'Channel::FacebookPage',
      avatar_url: 'random_image.png',
      page_id: '12345',
      widget_color: null,
      website_token: null,
      enable_auto_assignment: true,
    });
  });

  it('getUIFlags', () => {
    const state = {
      uiFlags: {
        isFetching: true,
        isFetchingItem: false,
        isCreating: false,
        isUpdating: false,
        isDeleting: false,
      },
    };
    expect(getters.getUIFlags(state)).toEqual({
      isFetching: true,
      isFetchingItem: false,
      isCreating: false,
      isUpdating: false,
      isDeleting: false,
    });
  });
});
