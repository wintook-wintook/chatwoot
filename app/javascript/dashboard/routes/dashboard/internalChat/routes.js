// feat/chat_interno (F3) — el chat entre los agentes de la cuenta. Cualquier agente;
// si la cuenta lo tiene apagado, el servidor responde 404 y la pantalla lo dice.
import { frontendURL } from '../../../helper/URLHelper';

const InternalChat = () => import('../../../views/internalChat/Index.vue');

export const routes = [
  {
    path: frontendURL('accounts/:accountId/internal-chat/:roomId?'),
    name: 'internal_chat',
    meta: { permissions: ['administrator', 'agent', 'custom_role'] },
    component: InternalChat,
  },
];
