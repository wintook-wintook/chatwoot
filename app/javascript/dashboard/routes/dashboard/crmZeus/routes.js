// CrmZeus — módulo traído de CRMZeus (O1: lista de organizaciones).
import { frontendURL } from '../../../helper/URLHelper';

const AGENT = { permissions: ['administrator', 'agent'] };

export const routes = [
  {
    path: frontendURL('accounts/:accountId/crm-zeus'),
    redirect: to => ({
      name: 'crmzeus_organizations',
      params: { accountId: to.params.accountId },
    }),
  },
  {
    path: frontendURL('accounts/:accountId/crm-zeus/organizations'),
    name: 'crmzeus_organizations',
    meta: AGENT,
    component: () => import('../../../views/crmZeus/Organizations.vue'),
  },
];
