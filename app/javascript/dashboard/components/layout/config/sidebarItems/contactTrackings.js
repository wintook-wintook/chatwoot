// proyecto@contact_tracking — Dashboard de Seguimientos
import { frontendURL } from '../../../../helper/URLHelper';

const contactTrackings = accountId => ({
  parentNav: 'contactTrackingsDashboard',
  routes: ['contact_trackings_dashboard', 'contact_trackings_metrics'],
  menuItems: [
    {
      icon: 'list',
      label: 'TRACKING_LIST',
      hasSubMenu: false,
      toState: frontendURL(`accounts/${accountId}/tracking-dashboard`),
      toStateName: 'contact_trackings_dashboard',
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

export default contactTrackings;
