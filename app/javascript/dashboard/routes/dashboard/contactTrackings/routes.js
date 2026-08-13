// proyecto@contact_tracking — Dashboard de Seguimientos
import { frontendURL } from '../../../helper/URLHelper';

export const routes = [
  {
    path: frontendURL('accounts/:accountId/tracking-dashboard'),
    name: 'contact_trackings_dashboard',
    meta: { permissions: ['administrator', 'agent'] },
    component: () => import('../../../views/contactTrackings/Dashboard.vue'),
  },
  {
    // proyecto@contact_tracking — Agentes IA dentro del dashboard (reutiliza la vista de Settings)
    path: frontendURL('accounts/:accountId/tracking-dashboard/agents'),
    name: 'contact_trackings_agents',
    meta: { permissions: ['administrator', 'agent'] },
    component: () => import('../settings/trackingTemplates/Index.vue'),
  },
  {
    // proyecto@ai_agent_assistant — Asistente de Agentes IA
    path: frontendURL('accounts/:accountId/tracking-dashboard/assistant'),
    name: 'contact_trackings_assistant',
    meta: { permissions: ['administrator', 'agent'] },
    component: () => import('../../../views/contactTrackings/Assistant.vue'),
  },
  {
    path: frontendURL('accounts/:accountId/tracking-dashboard/metrics'),
    name: 'contact_trackings_metrics',
    meta: { permissions: ['administrator', 'agent'] },
    component: () => import('../../../views/contactTrackings/Dashboard.vue'),
  },
  {
    // @campanas_vendedor — listado de campañas (corridas de asignación masiva)
    path: frontendURL('accounts/:accountId/tracking-dashboard/campaigns'),
    name: 'contact_trackings_campaigns',
    meta: { permissions: ['administrator', 'agent'] },
    component: () => import('../../../views/contactTrackings/Campaigns.vue'),
  },
  {
    // @campanas_vendedor — detalle de una campaña (cola de prospectos + KPIs)
    path: frontendURL(
      'accounts/:accountId/tracking-dashboard/campaigns/:campaignId'
    ),
    name: 'contact_trackings_campaign_detail',
    meta: { permissions: ['administrator', 'agent'] },
    component: () =>
      import('../../../views/contactTrackings/CampaignDetail.vue'),
  },
];
