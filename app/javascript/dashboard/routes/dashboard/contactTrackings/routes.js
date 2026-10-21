// proyecto@contact_tracking — Dashboard de Seguimientos
import { frontendURL } from '../../../helper/URLHelper';
import {
  ROLES,
  CONVERSATION_PERMISSIONS,
} from 'dashboard/constants/permissions.js';

// feat/agentes_ia_unificado: la lista y el espacio del agente reciben a quien antes
// entraba por Ajustes › Agentes IA (también roles personalizados).
const AGENTS_PERMISSIONS = [...ROLES, ...CONVERSATION_PERMISSIONS];

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
    meta: { permissions: AGENTS_PERMISSIONS },
    component: () => import('../settings/trackingTemplates/Index.vue'),
  },
  {
    // feat/agentes_ia_unificado — el espacio de un agente: Entrenamiento (el
    // Asistente), Ficha y Versiones. :templateId es un número o «new».
    path: frontendURL(
      'accounts/:accountId/tracking-dashboard/agents/:templateId(\\d+|new)'
    ),
    name: 'contact_trackings_agent',
    meta: { permissions: AGENTS_PERMISSIONS },
    component: () =>
      import('../../../views/contactTrackings/AgentWorkspace.vue'),
  },
  {
    // proyecto@asistente_agentes_ia — el Asistente ya no es una pantalla aparte: vive
    // dentro del espacio del agente. Los enlaces viejos (?template_id=N, ?nuevo=1)
    // llegan al mismo lugar.
    path: frontendURL('accounts/:accountId/tracking-dashboard/assistant'),
    name: 'contact_trackings_assistant',
    meta: { permissions: ['administrator'] },
    redirect: to => ({
      name: 'contact_trackings_agent',
      params: {
        accountId: to.params.accountId,
        templateId: to.query.template_id ? String(to.query.template_id) : 'new',
      },
      query: { seccion: 'training' },
    }),
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
