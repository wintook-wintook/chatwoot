// «En prueba» en la lista de agentes: cambia al instante, no se manda dos veces y, si falla,
// regresa a como estaba.
import Index from '../Index.vue';
import AgentTesterAPI from 'dashboard/api/agentTester';
import { useAlert } from 'dashboard/composables';

vi.mock('dashboard/api/agentTester', () => ({
  default: { setTesting: vi.fn() },
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

const contexto = () => ({
  savingTesting: [],
  $set: (obj, key, value) => {
    obj[key] = value;
  },
  $t: clave => clave,
});

describe('trackingTemplates/Index · En prueba', () => {
  beforeEach(() => vi.clearAllMocks());

  it('cambia al instante, antes de que conteste el servidor', async () => {
    let responder;
    AgentTesterAPI.setTesting.mockReturnValue(
      new Promise(resolve => {
        responder = resolve;
      })
    );
    const ctx = contexto();
    const template = { id: 7, testing: false };

    const promesa = Index.methods.toggleTesting.call(ctx, template);
    expect(template.testing).toBe(true);
    expect(ctx.savingTesting).toEqual([7]);

    // Un segundo clic mientras guarda no manda otro.
    await Index.methods.toggleTesting.call(ctx, template);
    expect(AgentTesterAPI.setTesting).toHaveBeenCalledTimes(1);

    responder({ data: { testing: true } });
    await promesa;
    expect(template.testing).toBe(true);
    expect(ctx.savingTesting).toEqual([]);
  });

  it('si el servidor falla, regresa a como estaba y avisa', async () => {
    AgentTesterAPI.setTesting.mockRejectedValue(new Error('x'));
    const ctx = contexto();
    const template = { id: 7, testing: true };

    await Index.methods.toggleTesting.call(ctx, template);

    expect(template.testing).toBe(true);
    expect(useAlert).toHaveBeenCalled();
    expect(ctx.savingTesting).toEqual([]);
  });
});
