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
    // Agentes listos: puestos empaquetados que la empresa activa en sus bandejas.
    path: frontendURL('accounts/:accountId/tracking-dashboard/ready-agents'),
    name: 'ready_agents',
    meta: { permissions: ['administrator'] },
    component: () => import('../../../views/readyAgents/Index.vue'),
  },
  {
    // «Cómo habla tu empresa»: base común de Seguimiento IA y Agentes listos.
    path: frontendURL('accounts/:accountId/tracking-dashboard/company-voice'),
    name: 'ai_voice',
    meta: { permissions: ['administrator'] },
    component: () => import('../../../views/readyAgents/CompanyVoice.vue'),
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
    // Probador de agentes (Plan-Motor-Agentes.md §11.13): fuera del diseño de los agentes, para
    // probar uno 1.0 o 2.0 como cliente, con lotes y bitácora.
    path: frontendURL('accounts/:accountId/tracking-dashboard/tester'),
    name: 'agent_tester',
    meta: { permissions: AGENTS_PERMISSIONS }, // en Inicio: cualquier usuario
    component: () => import('../../../views/agentTester/AgentTester.vue'),
  },
  {
    // Motor 2.0 (Plan-Motor-Agentes.md §11.11): la ficha de un agente 2.0. Misma lista y
    // tablas que Agentes a medida; la ficha 1.0 sigue en contact_trackings_agent.
    path: frontendURL(
      'accounts/:accountId/tracking-dashboard/agents2/:templateId(\\d+|new)'
    ),
    name: 'motor2_agent',
    meta: { permissions: ['administrator'] },
    component: () => import('../../../views/motor2/AgentPage.vue'),
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
  // Campaña con Vendedor IA (Motor 2.0): pantalla nueva (la 1.0 de arriba no cambia)
  {
    path: frontendURL('accounts/:accountId/tracking-dashboard/campaigns2/new'),
    name: 'campaigns2_new',
    meta: { permissions: ['administrator', 'agent'] },
    component: () => import('../../../views/campaigns2/CampaignWizard.vue'),
  },
  {
    path: frontendURL(
      'accounts/:accountId/tracking-dashboard/campaigns2/:campaignId/edit'
    ),
    name: 'campaigns2_edit',
    meta: { permissions: ['administrator', 'agent'] },
    component: () => import('../../../views/campaigns2/CampaignWizard.vue'),
  },
  {
    path: frontendURL(
      'accounts/:accountId/tracking-dashboard/campaigns2/:campaignId'
    ),
    name: 'campaigns2_detail',
    meta: { permissions: ['administrator', 'agent'] },
    component: () => import('../../../views/campaigns2/CampaignResults.vue'),
  },
];
