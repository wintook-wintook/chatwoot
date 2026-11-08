import { getLoginRedirectURL } from '../AuthHelper';

describe('#URL Helpers', () => {
  describe('getLoginRedirectURL', () => {
    it('should return correct Account URL if account id is present', () => {
      expect(
        getLoginRedirectURL({
          ssoAccountId: '7500',
          user: {
            accounts: [{ id: 7500, name: 'Test Account 7500' }],
          },
        })
      ).toBe('/app/accounts/7500/dashboard');
    });

    it('should return correct conversation URL if account id and conversationId is present', () => {
      expect(
        getLoginRedirectURL({
          ssoAccountId: '7500',
          ssoConversationId: '752',
          user: {
            accounts: [{ id: 7500, name: 'Test Account 7500' }],
          },
        })
      ).toBe('/app/accounts/7500/conversations/752');
    });

    // Portal de Dali: entrar desde /dali o con el QR del perfil regresa a Dali.
    it('should return the Dali portal URL when redirect is dali', () => {
      expect(
        getLoginRedirectURL({
          ssoAccountId: '7500',
          redirect: 'dali',
          user: {
            accounts: [{ id: 7500, name: 'Test Account 7500' }],
          },
        })
      ).toBe('/app/accounts/7500/dali');
    });

    it('should ignore unknown redirect values', () => {
      expect(
        getLoginRedirectURL({
          ssoAccountId: '7500',
          redirect: 'https://evil.example',
          user: {
            accounts: [{ id: 7500, name: 'Test Account 7500' }],
          },
        })
      ).toBe('/app/accounts/7500/dashboard');
    });

    it('should return default URL if account id is not present', () => {
      expect(getLoginRedirectURL({ ssoAccountId: '7500', user: {} })).toBe(
        '/app/'
      );
      expect(
        getLoginRedirectURL({
          ssoAccountId: '7500',
          user: {
            accounts: [{ id: '7501', name: 'Test Account 7501' }],
          },
        })
      ).toBe('/app/accounts/7501/dashboard');
      expect(getLoginRedirectURL('7500', null)).toBe('/app/');
    });
  });
});
