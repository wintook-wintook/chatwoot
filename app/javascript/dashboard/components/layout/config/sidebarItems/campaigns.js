import { frontendURL } from '../../../../helper/URLHelper';

const campaigns = accountId => ({
  parentNav: 'campaigns',
  routes: [
    'ongoing_campaigns',
    'one_off',
    // proyecto@contact_tracking — Dashboard de Seguimientos fusionado en Campañas
    'contact_trackings_dashboard',
    'contact_trackings_agents',
    'contact_trackings_assistant',
    'contact_trackings_campaigns',
    'contact_trackings_campaign_detail',
    'contact_trackings_metrics',
  ],
  menuItems: [
    // proyecto@contact_tracking — antes en la sección "Agente de Seguimientos"
    {
      icon: 'list',
      label: 'TRACKING_LIST',
      hasSubMenu: false,
      toState: frontendURL(`accounts/${accountId}/tracking-dashboard`),
      toStateName: 'contact_trackings_dashboard',
    },
    {
      icon: 'megaphone',
      label: 'TRACKING_CAMPAIGNS',
      hasSubMenu: false,
      toState: frontendURL(
        `accounts/${accountId}/tracking-dashboard/campaigns`
      ),
      toStateName: 'contact_trackings_campaigns',
    },
    {
      icon: 'bot',
      label: 'TRACKING_AGENTS',
      hasSubMenu: false,
      toState: frontendURL(`accounts/${accountId}/tracking-dashboard/agents`),
      toStateName: 'contact_trackings_agents',
    },
    {
      // proyecto@ai_agent_assistant — va pegado a Agentes IA, porque les sirve a ellos
      icon: 'wand',
      label: 'TRACKING_ASSISTANT',
      hasSubMenu: false,
      toState: frontendURL(
        `accounts/${accountId}/tracking-dashboard/assistant`
      ),
      toStateName: 'contact_trackings_assistant',
    },
    {
      icon: 'arrow-swap',
      label: 'ONGOING',
      key: 'ongoingCampaigns',
      hasSubMenu: false,
      toState: frontendURL(`accounts/${accountId}/campaigns/ongoing`),
      toStateName: 'ongoing_campaigns',
    },
    {
      key: 'oneOffCampaigns',
      icon: 'sound-source',
      label: 'ONE_OFF',
      hasSubMenu: false,
      toState: frontendURL(`accounts/${accountId}/campaigns/one_off`),
      toStateName: 'one_off',
    },
    {
      icon: 'arrow-trending-lines',
      label: 'TRACKING_SUMMARY',
      hasSubMenu: false,
      toState: frontendURL(`accounts/${accountId}/tracking-dashboard/metrics`),
      toStateName: 'contact_trackings_metrics',
    },
  ],
});

export default campaigns;
