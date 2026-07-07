// proyecto@contact_tracking — Dashboard de Seguimientos
import { frontendURL } from '../../../../helper/URLHelper';

const contactTrackings = accountId => ({
  parentNav: 'contactTrackingsDashboard',
  routes: [
    'contact_trackings_dashboard',
    'contact_trackings_agents',
    'contact_trackings_campaigns',
    'contact_trackings_campaign_detail',
    'contact_trackings_metrics',
  ],
  menuItems: [
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
      icon: 'arrow-trending-lines',
      label: 'TRACKING_SUMMARY',
      hasSubMenu: false,
      toState: frontendURL(`accounts/${accountId}/tracking-dashboard/metrics`),
      toStateName: 'contact_trackings_metrics',
    },
    {
      icon: 'bot',
      label: 'TRACKING_AGENTS',
      hasSubMenu: false,
      toState: frontendURL(`accounts/${accountId}/tracking-dashboard/agents`),
      toStateName: 'contact_trackings_agents',
    },
  ],
});

export default contactTrackings;
