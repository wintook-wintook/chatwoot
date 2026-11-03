// feat/licencias (F2b) — la gestión de licencias. La ruta no filtra por permiso: lo hace el
// servidor (cuenta de Wintook + «Ver licencias») y la pantalla lo dice si responde 401.
// Resumen, Cuentas y Planes son opciones del menú secundario: una ruta cada una, la misma
// pantalla (meta.tab). Crear y editar un plan es una página de captura (plan_form); cada
// cuenta tiene su ficha (account, F6) y asignarle licencia también es una página (issue). `licenses` lleva al Resumen; no es la ruta del Resumen para que el
// menú no la marque activa también en Cuentas y Planes.
import { frontendURL } from '../../../helper/URLHelper';

const page = () => import('../../../views/licenses/Index.vue');
const meta = tab => ({ permissions: ['administrator', 'agent'], tab });

export const routes = [
  {
    path: frontendURL('accounts/:accountId/licenses'),
    name: 'licenses_index',
    meta: meta('summary'),
    redirect: { name: 'licenses_summary' },
  },
  {
    path: frontendURL('accounts/:accountId/licenses/summary'),
    name: 'licenses_summary',
    meta: meta('summary'),
    component: page,
  },
  {
    path: frontendURL('accounts/:accountId/licenses/accounts'),
    name: 'licenses_accounts',
    meta: meta('accounts'),
    component: page,
  },
  {
    path: frontendURL(
      'accounts/:accountId/licenses/accounts/:licensedAccountId'
    ),
    name: 'licenses_accounts_show',
    meta: meta('account'),
    component: page,
  },
  {
    path: frontendURL(
      'accounts/:accountId/licenses/accounts/:licensedAccountId/issue'
    ),
    name: 'licenses_accounts_issue',
    meta: meta('issue'),
    component: page,
  },
  {
    path: frontendURL('accounts/:accountId/licenses/plans'),
    name: 'licenses_plans',
    meta: meta('plans'),
    component: page,
  },
  {
    path: frontendURL('accounts/:accountId/licenses/plans/new'),
    name: 'licenses_plans_new',
    meta: meta('plan_form'),
    component: page,
  },
  {
    path: frontendURL('accounts/:accountId/licenses/plans/:planId/edit'),
    name: 'licenses_plans_edit',
    meta: meta('plan_form'),
    component: page,
  },
];
