import { FEATURE_FLAGS } from '../../../../featureFlags';
import { frontendURL } from '../../../../helper/URLHelper';

const primaryMenuItems = accountId => [
  {
    icon: 'mail-inbox',
    key: 'inboxView',
    label: 'INBOX_VIEW',
    featureFlag: FEATURE_FLAGS.INBOX_VIEW,
    toState: frontendURL(`accounts/${accountId}/inbox-view`),
    toStateName: 'inbox_view',
  },
  {
    icon: 'chat',
    key: 'conversations',
    label: 'CONVERSATIONS',
    toState: frontendURL(`accounts/${accountId}/dashboard`),
    toStateName: 'home',
  },
  // KANBAN0725
  {
    icon: 'kanban', // Asegúrate que este icono existe en tu biblioteca
    key: 'kanban',
    label: 'KANBAN',
    // featureFlag: FEATURE_FLAGS.KANBAN,
    toState: frontendURL(`accounts/${accountId}/kanban`),
    toStateName: 'kanban_dashboard',
    // toStateName: 'kanban_wrapper',
  },
  // KANBAN0725
  {
    icon: 'captain',
    key: 'captain',
    label: 'CAPTAIN',
    featureFlag: FEATURE_FLAGS.CAPTAIN,
    toState: frontendURL(`accounts/${accountId}/captain`),
    toStateName: 'captain',
  },
  {
    icon: 'book-contacts',
    key: 'contacts',
    label: 'CONTACTS',
    featureFlag: FEATURE_FLAGS.CRM,
    toState: frontendURL(`accounts/${accountId}/contacts`),
    toStateName: 'contacts_dashboard',
  },
  {
    icon: 'arrow-trending-lines',
    key: 'reports',
    label: 'REPORTS',
    featureFlag: FEATURE_FLAGS.REPORTS,
    toState: frontendURL(`accounts/${accountId}/reports`),
    toStateName: 'account_overview_reports',
  },
  {
    icon: 'megaphone',
    key: 'campaigns',
    label: 'CAMPAIGNS',
    featureFlag: FEATURE_FLAGS.CAMPAIGNS,
    // Al abrir la sección cae primero en el listado de seguimientos
    // (/tracking-dashboard), primer ítem del submenú.
    toState: frontendURL(`accounts/${accountId}/tracking-dashboard`),
    toStateName: 'contact_trackings_dashboard',
  },
  {
    icon: 'library',
    key: 'helpcenter',
    label: 'HELP_CENTER.TITLE',
    featureFlag: FEATURE_FLAGS.HELP_CENTER,
    alwaysVisibleOnChatwootInstances: true,
    toState: frontendURL(`accounts/${accountId}/portals`),
    toStateName: 'default_portal_articles',
  },
  {
    icon: 'calendar',
    key: 'google_calendar',
    label: 'GOOGLE_CALENDAR',
    featureFlag: FEATURE_FLAGS.GOOGLE_CALENDAR,
    toState: frontendURL(`accounts/${accountId}/google-calendar`),
    toStateName: 'google_calendar',
    roles: ['administrator', 'agent'],
  },
  // @tickets_cases
  {
    icon: 'clipboard',
    key: 'gestorTickets',
    label: 'TICKETS',
    featureFlag: FEATURE_FLAGS.CASE_MANAGEMENT,
    toState: frontendURL(`accounts/${accountId}/tickets`),
    toStateName: 'gestorTickets_index',
  },
  // proyecto@contact_tracking — Dashboard de Seguimientos fusionado dentro de
  // la sección Campañas (ver sidebarItems/campaigns.js). Se elimina el ícono
  // top-level propio para evitar duplicar la navegación.
  {
    icon: 'settings',
    key: 'settings',
    label: 'SETTINGS',
    toState: frontendURL(`accounts/${accountId}/settings`),
    toStateName: 'settings_home',
  },
];

export default primaryMenuItems;
