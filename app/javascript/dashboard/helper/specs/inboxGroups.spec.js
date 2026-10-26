import {
  DEFAULT_INBOX_GROUP_ORDER,
  INBOX_GROUPS,
  groupInboxes,
  groupOrderFromUISettings,
  inboxGroupFor,
  normalizeGroupOrder,
  resolveOpenGroup,
  toggleOpenGroup,
} from '../inboxGroups';

const inbox = (id, name, channelType, extra = {}) => ({
  id,
  name,
  channel_type: channelType,
  ...extra,
});

describe('inboxGroupFor', () => {
  it.each([
    ['Channel::Whatsapp', INBOX_GROUPS.WHATSAPP],
    ['Channel::Telegram', INBOX_GROUPS.TELEGRAM],
    ['Channel::Email', INBOX_GROUPS.EMAIL],
    ['Channel::FacebookPage', INBOX_GROUPS.META],
    ['Channel::Instagram', INBOX_GROUPS.META],
    ['Channel::WebWidget', INBOX_GROUPS.WEB],
    ['Channel::Tiktok', INBOX_GROUPS.TIKTOK],
    ['Channel::Api', INBOX_GROUPS.OTHERS],
    ['Channel::Line', INBOX_GROUPS.OTHERS],
    ['Channel::Sms', INBOX_GROUPS.OTHERS],
    ['Channel::TwitterProfile', INBOX_GROUPS.OTHERS],
    ['Channel::Algo_nuevo', INBOX_GROUPS.OTHERS],
  ])('%s → %s', (type, group) => {
    expect(inboxGroupFor(inbox(1, 'x', type))).toBe(group);
  });

  it('puts Twilio WhatsApp with WhatsApp and Twilio SMS with the others', () => {
    expect(
      inboxGroupFor(
        inbox(1, 'x', 'Channel::TwilioSms', { phone_number: 'whatsapp:+52' })
      )
    ).toBe(INBOX_GROUPS.WHATSAPP);
    expect(
      inboxGroupFor(inbox(1, 'x', 'Channel::TwilioSms', { medium: 'whatsapp' }))
    ).toBe(INBOX_GROUPS.WHATSAPP);
    expect(
      inboxGroupFor(
        inbox(1, 'x', 'Channel::TwilioSms', { phone_number: '+5255' })
      )
    ).toBe(INBOX_GROUPS.OTHERS);
  });
});

describe('normalizeGroupOrder', () => {
  it('returns the default order when nothing is saved', () => {
    expect(normalizeGroupOrder(undefined)).toEqual([
      ...DEFAULT_INBOX_GROUP_ORDER,
    ]);
  });

  it('keeps the saved order and appends missing groups', () => {
    expect(normalizeGroupOrder(['email', 'whatsapp'])).toEqual([
      'internal',
      'email',
      'whatsapp',
      'telegram',
      'meta',
      'web',
      'tiktok',
      'others',
    ]);
  });

  it('drops unknown and duplicated groups', () => {
    expect(normalizeGroupOrder(['meta', 'fax', 'meta'])[1]).toBe('meta');
    expect(normalizeGroupOrder(['meta', 'fax', 'meta'])).not.toContain('fax');
    expect(normalizeGroupOrder(['meta', 'meta'])).toHaveLength(8);
  });

  it('puts Internal first when an old saved order does not have it, and respects it when it does', () => {
    expect(normalizeGroupOrder(['email'])[0]).toBe('internal');
    expect(normalizeGroupOrder(['email', 'internal'])).toEqual([
      'email',
      'internal',
      'whatsapp',
      'telegram',
      'meta',
      'web',
      'tiktok',
      'others',
    ]);
  });
});

describe('groupOrderFromUISettings', () => {
  it('reads the order saved for that account only', () => {
    const settings = { inbox_group_order: { 2: ['tiktok'], 3: ['email'] } };
    expect(groupOrderFromUISettings(settings, 2)[1]).toBe('tiktok');
    expect(groupOrderFromUISettings(settings, 3)[1]).toBe('email');
    expect(groupOrderFromUISettings(settings, 9)[0]).toBe('internal');
    expect(groupOrderFromUISettings(undefined, 2)[1]).toBe('whatsapp');
  });
});

describe('groupInboxes', () => {
  const inboxes = [
    inbox(1, 'Widget', 'Channel::WebWidget'),
    inbox(2, 'zeta ventas', 'Channel::Whatsapp'),
    inbox(3, 'Alfa soporte', 'Channel::Whatsapp'),
    inbox(4, 'Correo', 'Channel::Email'),
    inbox(5, 'Página', 'Channel::FacebookPage'),
    inbox(6, 'IG', 'Channel::Instagram'),
    inbox(7, 'API', 'Channel::Api'),
  ];

  it('groups in the default order and skips empty groups', () => {
    const groups = groupInboxes(inboxes);
    expect(groups.map(g => g.key)).toEqual([
      'whatsapp',
      'email',
      'meta',
      'web',
      'others',
    ]);
  });

  it('sorts inboxes by name inside each group', () => {
    const whatsapp = groupInboxes(inboxes)[0];
    expect(whatsapp.inboxes.map(i => i.name)).toEqual([
      'Alfa soporte',
      'zeta ventas',
    ]);
  });

  it('follows a custom order', () => {
    const groups = groupInboxes(inboxes, ['others', 'meta']);
    expect(groups.map(g => g.key)).toEqual([
      'others',
      'meta',
      'whatsapp',
      'email',
      'web',
    ]);
  });

  it('returns nothing without inboxes', () => {
    expect(groupInboxes([])).toEqual([]);
  });
});

describe('accordion', () => {
  const groups = [{ key: 'whatsapp' }, { key: 'email' }];

  it('opens the first group until the agent chooses one', () => {
    expect(resolveOpenGroup('', groups)).toBe('whatsapp');
    expect(resolveOpenGroup('', [])).toBeNull();
    expect(resolveOpenGroup('email', groups)).toBe('email');
    expect(resolveOpenGroup(null, groups)).toBeNull();
  });

  it('opening one closes the rest, and clicking the open one closes it', () => {
    expect(toggleOpenGroup('whatsapp', 'email')).toBe('email');
    expect(toggleOpenGroup('email', 'email')).toBeNull();
    expect(toggleOpenGroup(null, 'meta')).toBe('meta');
  });
});
