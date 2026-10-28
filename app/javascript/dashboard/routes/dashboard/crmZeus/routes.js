// CrmZeus — módulo traído de CRMZeus: organizaciones, artículos (lista, alta y edición) y catálogos.
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
  {
    path: frontendURL('accounts/:accountId/crm-zeus/organizations/new'),
    name: 'crmzeus_organization_new',
    meta: AGENT,
    component: () => import('../../../views/crmZeus/OrganizationForm.vue'),
  },
  {
    path: frontendURL(
      'accounts/:accountId/crm-zeus/organizations/:organizationId'
    ),
    name: 'crmzeus_organization_edit',
    meta: AGENT,
    component: () => import('../../../views/crmZeus/OrganizationForm.vue'),
    props: route => ({ organizationId: String(route.params.organizationId) }),
  },
  {
    path: frontendURL('accounts/:accountId/crm-zeus/articles'),
    name: 'crmzeus_articles',
    meta: AGENT,
    component: () => import('../../../views/crmZeus/Articles.vue'),
  },
  {
    path: frontendURL('accounts/:accountId/crm-zeus/articles/new'),
    name: 'crmzeus_article_new',
    meta: AGENT,
    component: () => import('../../../views/crmZeus/ArticleForm.vue'),
  },
  {
    path: frontendURL('accounts/:accountId/crm-zeus/articles/:articleId'),
    name: 'crmzeus_article_edit',
    meta: AGENT,
    component: () => import('../../../views/crmZeus/ArticleForm.vue'),
    props: route => ({ articleId: String(route.params.articleId) }),
  },
  {
    path: frontendURL('accounts/:accountId/crm-zeus/catalogs'),
    name: 'crmzeus_catalogs',
    meta: AGENT,
    component: () => import('../../../views/crmZeus/Catalogs.vue'),
  },
];
