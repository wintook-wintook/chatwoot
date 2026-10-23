import { shallowMount } from '@vue/test-utils';
import CallSimulator from './CallSimulator.vue';
import SimulatorAPI from 'dashboard/api/whatsappCallSimulator';

vi.mock('dashboard/api/whatsappCallSimulator', () => ({
  default: {
    inboxes: vi.fn(),
    signals: vi.fn().mockResolvedValue({ data: [] }),
  },
}));

const esperar = () =>
  new Promise(resolve => {
    setTimeout(resolve);
  });

const montar = () =>
  shallowMount(CallSimulator, {
    mocks: { $t: clave => clave },
    stubs: ['woot-button', 'woot-label', 'BaseSettingsHeader'],
  });

describe('Cliente simulado', () => {
  it('si la Meta simulada está apagada (404), lo dice y no recoge señales', async () => {
    SimulatorAPI.inboxes.mockRejectedValue({ response: { status: 404 } });
    const wrapper = montar();
    await esperar();
    expect(wrapper.vm.disabled).toBe(true);
    expect(wrapper.vm.pollTimer).toBeNull();
    wrapper.destroy();
  });

  it('toma la primera bandeja con llamadas', async () => {
    SimulatorAPI.inboxes.mockResolvedValue({
      data: [{ id: 7, name: 'Ventas', phone_number: '+52' }],
    });
    const wrapper = montar();
    await esperar();
    expect(wrapper.vm.inboxId).toBe(7);
    wrapper.destroy();
  });

  it('cuando el negocio llama, suena; cuando pide permiso, lo muestra', async () => {
    SimulatorAPI.inboxes.mockResolvedValue({ data: [] });
    const wrapper = montar();
    await esperar();

    await wrapper.vm.handle({ type: 'incoming', call_id: 'c1', sdp: 'v=0' });
    expect(wrapper.vm.state).toBe('ringing');
    expect(wrapper.vm.incoming.call_id).toBe('c1');

    await wrapper.vm.handle({
      type: 'permission_request',
      wamid: 'w1',
      text: '¿Te llamamos?',
    });
    expect(wrapper.vm.permission.wamid).toBe('w1');
    wrapper.destroy();
  });

  it('un fin de otra llamada no corta la propia', async () => {
    SimulatorAPI.inboxes.mockResolvedValue({ data: [] });
    const wrapper = montar();
    await esperar();
    wrapper.vm.callId = 'mia';
    wrapper.vm.state = 'in_call';

    await wrapper.vm.handle({ type: 'ended', call_id: 'otra' });
    expect(wrapper.vm.state).toBe('in_call');
    wrapper.destroy();
  });
});
