// diag/llamadas_whatsapp (F4) — el «cliente simulado». Solo admin; el servidor responde
// 404 si la Meta simulada está apagada, y la página lo dice.
import { frontendURL } from '../../../helper/URLHelper';

export const routes = [
  {
    path: frontendURL('accounts/:accountId/whatsapp-call-simulator'),
    name: 'whatsapp_call_simulator',
    meta: { permissions: ['administrator'] },
    component: () => import('../../../views/whatsappCalls/CallSimulator.vue'),
  },
];
