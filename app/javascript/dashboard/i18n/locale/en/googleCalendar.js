export default {
  GOOGLE_CALENDAR: {
    HEADER: 'Google Calendar',
    CONNECT: {
      TITLE: 'Connect your Google Calendar',
      DESCRIPTION: 'View your events, share availability with teammates, and create appointments directly from conversations.',
      BUTTON: 'Connect Google Account',
      CONNECTING: 'Connecting...',
      MODAL: {
        TITLE: 'Connect Google Calendar',
        DESCRIPTION: 'Chatwoot will request the following permissions on your Google account:',
        PERMISSIONS: [
          'Read your calendar events',
          'Create and edit events on your behalf',
          'View your availability (free/busy)',
        ],
        CONFIRM: 'Connect with Google',
        CANCEL: 'Cancel',
      },
    },
    DISCONNECT: {
      BUTTON: 'Disconnect',
      CONFIRM: 'Are you sure you want to disconnect your Google Calendar?',
    },
    CONNECTED_AS: 'Connected as',
    EVENTS: {
      TITLE: 'My Calendar',
      EMPTY: 'No events for this period',
      NEW_EVENT: 'New Event',
      ALL_DAY: 'All day',
    },
    CALENDAR: {
      WEEK: 'Week',
      MONTH: 'Month',
    },
    AGENDA: {
      TITLE: 'Upcoming',
      EMPTY: 'No upcoming events',
      TODAY: 'Today',
      TOMORROW: 'Tomorrow',
    },
    AVAILABILITY: {
      TITLE: 'Team Availability',
      BUSY: 'Busy',
      FREE: 'Free',
    },
    CREATE_EVENT: {
      TITLE: 'Create Event',
      FIELDS: {
        SUMMARY: 'Title',
        SUMMARY_PLACEHOLDER: 'Event title',
        START: 'Start',
        END: 'End',
        DESCRIPTION: 'Description',
        DESCRIPTION_PLACEHOLDER: 'Event description (optional)',
        ATTENDEES: 'Attendees',
        ATTENDEES_PLACEHOLDER: 'email@example.com',
      },
      SUBMIT: 'Create Event',
      CANCEL: 'Cancel',
      SUCCESS: 'Event created successfully',
      ERROR: 'Could not create event. Please try again.',
    },
    EDIT_EVENT: {
      TITLE: 'Edit Event',
      SUBMIT: 'Save Changes',
      SUCCESS: 'Event updated successfully',
      ERROR: 'Could not update event. Please try again.',
    },
    API: {
      CONNECT_ERROR: 'Could not connect to Google Calendar',
      DISCONNECT_SUCCESS: 'Google Calendar disconnected',
      DISCONNECT_ERROR: 'Could not disconnect Google Calendar',
      FETCH_ERROR: 'Error loading calendar events',
    },
  },
};
