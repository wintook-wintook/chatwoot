import { validateAuthenticateRoutePermission, landingRoute } from './index';

describe('#validateAuthenticateRoutePermission', () => {
  describe(`when route is protected`, () => {
    describe(`when user not logged in`, () => {
      it(`should redirect to login`, () => {
        const to = { name: 'some-protected-route', params: { accountId: 1 } };
        const next = vi.fn();
        const getters = {
          isLoggedIn: false,
          getCurrentUser: {
            account_id: null,
            id: null,
            accounts: [],
          },
        };

        expect(validateAuthenticateRoutePermission(to, next, { getters })).toBe(
          '/app/login'
        );
      });
    });
    describe(`when user is logged in`, () => {
      describe(`when route is not accessible to current user`, () => {
        it(`should redirect to dashboard`, () => {
          const to = {
            name: 'general_settings_index',
            params: { accountId: 1 },
            meta: { permissions: ['administrator'] },
          };
          const next = vi.fn();
          const getters = {
            isLoggedIn: true,
            getCurrentUser: {
              account_id: 1,
              id: 1,
              accounts: [
                {
                  permissions: ['agent'],
                  id: 1,
                  role: 'agent',
                  status: 'active',
                },
              ],
            },
          };
          validateAuthenticateRoutePermission(to, next, { getters });
          expect(next).toHaveBeenCalledWith('/app/accounts/1/dashboard');
        });
      });
      describe(`when route is accessible to current user`, () => {
        it(`should go there`, () => {
          const to = {
            name: 'general_settings_index',
            params: { accountId: 1 },
            meta: { permissions: ['administrator'] },
          };
          const next = vi.fn();
          const getters = {
            isLoggedIn: true,
            getCurrentUser: {
              account_id: 1,
              id: 1,
              accounts: [
                {
                  id: 1,
                  role: 'administrator',
                  permissions: ['administrator'],
                  status: 'active',
                },
              ],
            },
          };
          validateAuthenticateRoutePermission(to, next, { getters });
          expect(next).toHaveBeenCalledWith();
        });
      });
    });
  });
});

// @tickets_cases — dónde aterriza el usuario al entrar a la app.
describe('#landingRoute', () => {
  const home = { name: 'home', params: { accountId: 1 } };
  const start = { name: null };
  const user = landing => ({
    ui_settings: landing ? { landing_page: landing } : {},
  });

  it('al entrar sin preferencia va a «Mi resumen»', () => {
    expect(landingRoute(home, start, user())).toEqual({
      name: 'my_summary',
      params: { accountId: 1 },
    });
  });

  it('respeta la preferencia: Mi día abre la pestaña, Conversaciones no redirige', () => {
    expect(landingRoute(home, start, user('my_day'))).toEqual({
      name: 'gestorTickets_tasks',
      query: { tab: 'my_day' },
      params: { accountId: 1 },
    });
    expect(landingRoute(home, start, user('conversations'))).toBeNull();
  });

  it('dentro de la app, ir a Conversaciones no redirige', () => {
    expect(landingRoute(home, { name: 'my_summary' }, user())).toBeNull();
  });

  it('solo actúa sobre la entrada a Conversaciones', () => {
    expect(
      landingRoute({ name: 'contacts_dashboard', params: {} }, start, user())
    ).toBeNull();
  });
});
