// Plan-Organizaciones O1 — Clientes › Organizaciones (prospectos y clientes).
import { frontendURL } from '../../../helper/URLHelper';

const META = { permissions: ['administrator', 'agent', 'custom_role'] };

export const routes = [
  // Antes que :organizationId para que no la tome como id.
  {
    path: frontendURL('accounts/:accountId/organizations-dashboard'),
    name: 'organizations_dashboard',
    meta: META,
    component: () =>
      import('../../../views/organizations/OrganizationsDashboard.vue'),
  },
  {
    path: frontendURL('accounts/:accountId/organizations'),
    name: 'organizations_list',
    meta: META,
    component: () =>
      import('../../../views/organizations/OrganizationsList.vue'),
  },
  {
    path: frontendURL('accounts/:accountId/organizations/:organizationId'),
    name: 'organization_detail',
    meta: META,
    component: () =>
      import('../../../views/organizations/OrganizationDetail.vue'),
  },
];
