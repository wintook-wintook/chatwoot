import Motor2CampaignsAPI from './motor2Campaigns';

// Sin simular la API: un método llamado igual que una propiedad de ApiClient (this.options) quedaba tapado.
describe('Motor2CampaignsAPI', () => {
  beforeEach(() => {
    window.axios = { get: vi.fn(() => Promise.resolve({ data: {} })) };
  });

  it('pide las opciones y la campaña (sin caché)', async () => {
    await Motor2CampaignsAPI.formOptions();
    await Motor2CampaignsAPI.show(5);
    const [[optionsUrl, optionsConfig], [showUrl]] =
      window.axios.get.mock.calls;
    expect(optionsUrl).toMatch(/motor2_campaigns\/options$/);
    expect(optionsConfig.params._).toBeDefined();
    expect(showUrl).toMatch(/motor2_campaigns\/5$/);
  });
});
