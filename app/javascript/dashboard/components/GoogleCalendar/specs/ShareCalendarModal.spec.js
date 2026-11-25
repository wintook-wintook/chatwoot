import ShareCalendarModal from '../ShareCalendarModal.vue';
import GoogleCalendarAPI from '../../../api/googleCalendar';

// fix/calendario_google — «Compartir mi calendario» con otras personas (cualquier correo).
vi.mock('../../../api/googleCalendar', () => ({
  default: { shareCalendarWithEmail: vi.fn(), updateSharingRule: vi.fn() },
}));

const { methods } = ShareCalendarModal;

const ctx = overrides => {
  const c = {
    others: [],
    rules: [],
    rowState: {},
    newEmail: '',
    newLevel: 'details',
    adding: false,
    addError: '',
    $t: key => key,
    ...overrides,
  };
  Object.keys(methods).forEach(name => {
    c[name] = (...args) => methods[name].apply(c, args);
  });
  return c;
};

describe('ShareCalendarModal · otras personas', () => {
  beforeEach(() => vi.clearAllMocks());

  it('agrega un correo (en minúsculas), lo ordena y limpia el campo', async () => {
    GoogleCalendarAPI.shareCalendarWithEmail.mockResolvedValue({
      data: { email: 'b@x.com', level: 'free_busy', status: 'editable' },
    });
    const c = ctx({
      newEmail: ' B@X.com ',
      newLevel: 'free_busy',
      others: [{ email: 'z@x.com', level: 'details', status: 'editable' }],
    });
    await c.addEmail();
    expect(GoogleCalendarAPI.shareCalendarWithEmail).toHaveBeenCalledWith(
      'b@x.com',
      'free_busy'
    );
    expect(c.others.map(o => o.email)).toEqual(['b@x.com', 'z@x.com']);
    expect(c.newEmail).toBe('');
    expect(c.rowState['email:b@x.com']).toBe('saved');
  });

  it('si Google o el servidor rechaza, muestra el motivo y no agrega', async () => {
    GoogleCalendarAPI.shareCalendarWithEmail.mockRejectedValue({
      response: { data: { error: 'invalid_email' } },
    });
    const c = ctx({ newEmail: 'nope' });
    await c.addEmail();
    expect(c.addError).toBe(
      'GOOGLE_CALENDAR.SHARE_CALENDAR.ERRORS.INVALID_EMAIL'
    );
    expect(c.others).toEqual([]);
  });

  it('dejar de compartir quita la fila', async () => {
    GoogleCalendarAPI.shareCalendarWithEmail.mockResolvedValue({
      data: { email: 'a@x.com', level: 'none', status: 'editable' },
    });
    const c = ctx({
      others: [{ email: 'a@x.com', level: 'details', status: 'editable' }],
    });
    await c.changeOther('a@x.com', 'none');
    expect(c.others).toEqual([]);
  });

  it('si falla un cambio, la fila vuelve a como estaba', async () => {
    GoogleCalendarAPI.updateSharingRule.mockRejectedValue({
      response: { data: { error: 'Cannot share outside the domain' } },
    });
    const c = ctx({
      rules: [{ agent_id: 4, level: 'none', status: 'editable' }],
    });
    await c.changeCoworker(4, 'details');
    expect(c.rules[0].level).toBe('none');
    expect(c.rowState['agent:4']).toBe('Cannot share outside the domain');
  });
});
