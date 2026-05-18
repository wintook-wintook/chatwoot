import { frontendURL } from '../../../../helper/URLHelper';

const googleCalendar = accountId => ({
  parentNav: 'google_calendar',
  routes: ['google_calendar'],
  menuItems: [
    {
      icon: 'calendar',
      label: 'GOOGLE_CALENDAR_VIEW',
      hasSubMenu: false,
      toState: frontendURL(`accounts/${accountId}/google-calendar`),
      toStateName: 'google_calendar',
    },
  ],
});

export default googleCalendar;
