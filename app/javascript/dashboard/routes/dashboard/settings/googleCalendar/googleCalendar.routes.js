import { frontendURL } from '../../../../helper/URLHelper';

const SettingsContent = () => import('../Wrapper.vue');
const GoogleCalendarView = () => import('./GoogleCalendarView.vue');

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/google-calendar'),
      component: SettingsContent,
      props: {
        headerTitle: 'GOOGLE_CALENDAR.HEADER',
        icon: 'calendar',
        keepAlive: false,
      },
      children: [
        {
          path: '',
          name: 'google_calendar',
          component: GoogleCalendarView,
          meta: { permissions: ['administrator', 'agent'] },
        },
      ],
    },
  ],
};
