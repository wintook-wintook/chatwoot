import ApiClient from '../ApiClient';
import tiktokClient from '../channel/tiktokClient';

// Portado de Chatwoot 4.19. Nuestro generateAuthorization() no manda cuerpo: el servidor
// arma el `state` firmado con la cuenta.
describe('#TiktokClient', () => {
  it('creates correct instance', () => {
    expect(tiktokClient).toBeInstanceOf(ApiClient);
    expect(tiktokClient).toHaveProperty('generateAuthorization');
  });

  describe('#generateAuthorization', () => {
    const originalAxios = window.axios;
    const originalPathname = window.location.pathname;
    const axiosMock = {
      post: vi.fn(() => Promise.resolve()),
    };

    beforeEach(() => {
      window.axios = axiosMock;
      window.history.pushState({}, '', '/app/accounts/1/settings');
    });

    afterEach(() => {
      window.axios = originalAxios;
      window.history.pushState({}, '', originalPathname);
    });

    it('posts to the authorization endpoint', () => {
      tiktokClient.generateAuthorization();
      expect(axiosMock.post).toHaveBeenCalledWith(
        '/api/v1/accounts/1/tiktok/authorization'
      );
    });
  });
});
