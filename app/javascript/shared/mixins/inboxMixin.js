export const INBOX_TYPES = {
  WEB: 'Channel::WebWidget',
  FB: 'Channel::FacebookPage',
  TWITTER: 'Channel::TwitterProfile',
  TWILIO: 'Channel::TwilioSms',
  WHATSAPP: 'Channel::Whatsapp',
  API: 'Channel::Api',
  EMAIL: 'Channel::Email',
  TELEGRAM: 'Channel::Telegram',
  LINE: 'Channel::Line',
  SMS: 'Channel::Sms',
  INSTAGRAM: 'Channel::Instagram',
};

export const INBOX_FEATURES = {
  REPLY_TO: 'replyTo',
  REPLY_TO_OUTGOING: 'replyToOutgoing',
};

// This is a single source of truth for inbox features
// This is used to check if a feature is available for a particular inbox or not
export const INBOX_FEATURE_MAP = {
  [INBOX_FEATURES.REPLY_TO]: [
    INBOX_TYPES.FB,
    INBOX_TYPES.INSTAGRAM,
    INBOX_TYPES.WEB,
    INBOX_TYPES.TWITTER,
    INBOX_TYPES.WHATSAPP,
    INBOX_TYPES.TELEGRAM,
    INBOX_TYPES.API,
  ],
  [INBOX_FEATURES.REPLY_TO_OUTGOING]: [
    INBOX_TYPES.WEB,
    INBOX_TYPES.TWITTER,
    INBOX_TYPES.WHATSAPP,
    INBOX_TYPES.TELEGRAM,
    INBOX_TYPES.API,
  ],
};

export default {
  computed: {
    channelType() {
      return this.inbox.channel_type;
    },
    whatsAppAPIProvider() {
      return this.inbox.provider || '';
    },
    isAMicrosoftInbox() {
      return this.isAnEmailChannel && this.inbox.provider === 'microsoft';
    },
    isAGoogleInbox() {
      return this.isAnEmailChannel && this.inbox.provider === 'google';
    },
    isAPIInbox() {
      return this.channelType === INBOX_TYPES.API;
    },
    isATwitterInbox() {
      return this.channelType === INBOX_TYPES.TWITTER;
    },
    isAFacebookInbox() {
      return this.channelType === INBOX_TYPES.FB;
    },
    // Canal nativo de Instagram (Instagram Login), sin Página de Facebook.
    isAnInstagramInbox() {
      return this.channelType === INBOX_TYPES.INSTAGRAM;
    },
    // Cualquier canal de Meta con buzón de mensajes. Instagram vivió siempre dentro de un
    // inbox de Facebook, así que casi todo lo que la interfaz condicionaba a
    // `isAFacebookInbox` quería decir en realidad «es de Meta»: eso es lo que hay que
    // usar, y dejar `isAFacebookInbox` solo donde de verdad se hable de Messenger.
    isAMetaInbox() {
      return this.isAFacebookInbox || this.isAnInstagramInbox;
    },
    isAWebWidgetInbox() {
      return this.channelType === INBOX_TYPES.WEB;
    },
    isATwilioChannel() {
      return this.channelType === INBOX_TYPES.TWILIO;
    },
    isALineChannel() {
      return this.channelType === INBOX_TYPES.LINE;
    },
    isAnEmailChannel() {
      return this.channelType === INBOX_TYPES.EMAIL;
    },
    isATelegramChannel() {
      return this.channelType === INBOX_TYPES.TELEGRAM;
    },
    isATwilioSMSChannel() {
      const { medium: medium = '' } = this.inbox;
      return this.isATwilioChannel && medium === 'sms';
    },
    isASmsInbox() {
      return this.channelType === INBOX_TYPES.SMS || this.isATwilioSMSChannel;
    },
    isATwilioWhatsAppChannel() {
      const { medium: medium = '' } = this.inbox;
      return this.isATwilioChannel && medium === 'whatsapp';
    },
    isAWhatsAppCloudChannel() {
      return (
        this.channelType === INBOX_TYPES.WHATSAPP &&
        this.whatsAppAPIProvider === 'whatsapp_cloud'
      );
    },
    isAUnoapiChannel() {
      return (
        this.channelType === INBOX_TYPES.WHATSAPP &&
        this.whatsAppAPIProvider === 'unoapi'
      );
    },
    is360DialogWhatsAppChannel() {
      return (
        this.channelType === INBOX_TYPES.WHATSAPP &&
        this.whatsAppAPIProvider === 'default'
      );
    },
    chatAdditionalAttributes() {
      const { additional_attributes: additionalAttributes } = this.chat || {};
      return additionalAttributes || {};
    },
    isTwitterInboxTweet() {
      return this.chatAdditionalAttributes.type === 'tweet';
    },
    twilioBadge() {
      return `${this.isATwilioSMSChannel ? 'sms' : 'whatsapp'}`;
    },
    twitterBadge() {
      return `${this.isTwitterInboxTweet ? 'twitter-tweet' : 'twitter-dm'}`;
    },
    facebookBadge() {
      return this.chatAdditionalAttributes.type || 'facebook';
    },
    inboxBadge() {
      let badgeKey = '';
      if (this.isATwitterInbox) {
        badgeKey = this.twitterBadge;
      } else if (this.isAnInstagramInbox) {
        // Sin esto caería al channelType y Thumbnail no encontraría icono
        badgeKey = 'instagram_direct_message';
      } else if (this.isAFacebookInbox) {
        badgeKey = this.facebookBadge;
      } else if (this.isATwilioChannel) {
        badgeKey = this.twilioBadge;
      } else if (this.isAWhatsAppChannel) {
        badgeKey = 'whatsapp';
      }
      return badgeKey || this.channelType;
    },
    isAWhatsAppChannel() {
      return (
        this.channelType === INBOX_TYPES.WHATSAPP ||
        this.isATwilioWhatsAppChannel
      );
    },
  },
  methods: {
    inboxHasFeature(feature) {
      return INBOX_FEATURE_MAP[feature]?.includes(this.channelType) ?? false;
    },
  },
};
