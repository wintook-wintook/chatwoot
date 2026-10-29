// Plan-Contratos R1 — Clientes › Contratos y Clientes › Tipos de contrato.
import { frontendURL } from '../../../helper/URLHelper';

const META = { permissions: ['administrator', 'agent', 'custom_role'] };

export const routes = [
  {
    path: frontendURL('accounts/:accountId/contracts'),
    name: 'contracts_list',
    meta: META,
    component: () => import('../../../views/contracts/ContractsList.vue'),
  },
  {
    path: frontendURL('accounts/:accountId/contracts/types'),
    name: 'contract_types',
    meta: META,
    component: () => import('../../../views/contracts/ContractTypes.vue'),
  },
];
