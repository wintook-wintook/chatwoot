// feat/licencias (F2b) — la gestión de licencias. La ruta no filtra por permiso: lo hace el
// servidor (cuenta de Wintook + «Ver licencias») y la pantalla lo dice si responde 401.
import { frontendURL } from '../../../helper/URLHelper';

export const routes = [
  {
    path: frontendURL('accounts/:accountId/licenses'),
    name: 'licenses_index',
    meta: { permissions: ['administrator', 'agent'] },
    component: () => import('../../../views/licenses/Index.vue'),
  },
];
