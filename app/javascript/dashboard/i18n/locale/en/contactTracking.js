// ================================================================================
// proyecto@contact_tracking
// ================================================================================
// Translations in English
// ================================================================================

export default {
  CONTACT_TRACKING: {
    TITLE: 'Follow-up Management',
    DESCRIPTION: 'Schedule and manage automatic contact follow-ups',
    INTEGRATION_NOT_AVAILABLE: 'The follow-up integration is not available for this inbox',

    TABS: {
      FORM: 'New Follow-up',
      LIST: 'Active Follow-ups',
    },

    FORM: {
      OBJECTIVE: {
        LABEL: 'Follow-up Objective',
        PLACEHOLDER: 'E.g.: Follow up on quote',
        ERROR: 'Objective is required',
      },
      SCHEDULED_FOR: {
        LABEL: 'Date and Time',
        ERROR: 'Date and time are required',
      },
      INBOX: {
        LABEL: 'Channel',
        PLACEHOLDER: 'Select a channel',
        ERROR: 'Channel is required',
      },
      MAX_ATTEMPTS: {
        LABEL: 'No. of Attempts',
      },
      INTERVAL_DAYS: {
        LABEL: 'Days Between Attempts',
        PLACEHOLDER: 'Optional',
      },
      USE_AI: {
        LABEL: 'Use AI to generate messages',
      },
      AI_CONTEXT: {
        LABEL: 'Context for AI',
        PLACEHOLDER: 'Provide additional information for the AI to generate better messages...',
        HELP: 'The AI will use this context to personalize follow-up messages',
      },
      BUTTONS: {
        CANCEL: 'Cancel',
        CREATE: 'Create Follow-up',
        UPDATE: 'Update',
      },
    },

    TABLE: {
      OBJECTIVE: 'Objective',
      SCHEDULED_FOR: 'Scheduled For',
      INBOX: 'Channel',
      ATTEMPTS: 'Reminders',
      STATUS: 'Status',
      ACTIONS: 'Actions',
    },

    STATUS: {
      PENDING: 'Pending',
      SCHEDULED: 'Scheduled',
      ACTIVE: 'Active',
      PAUSED: 'Paused',
      COMPLETED: 'Completed',
      CANCELLED: 'Cancelled',
      FAILED: 'Failed',
    },

    ACTIONS: {
      PAUSE: 'Pause',
      RESUME: 'Resume',
      CANCEL: 'Cancel',
      EDIT: 'Edit',
    },

    FILTERS: {
      STATUS: 'Filter by Status',
      INBOX: 'Filter by Channel',
      SEARCH: 'Search',
      SEARCH_PLACEHOLDER: 'Search by objective...',
      ALL: 'All',
    },

    EMPTY_STATE: 'No follow-ups created for this contact',
    AI_ENABLED: 'This follow-up uses AI to generate messages',

    CONFIRM: {
      CANCEL_MESSAGE: 'Are you sure you want to cancel this follow-up?',
    },

    CANCEL_MODAL: {
      TITLE: 'Cancel Follow-up',
      DESCRIPTION: 'This action cannot be undone.',
      WARNING: 'The follow-up will be cancelled and cannot be reactivated.',
      DISMISS: 'Go Back',
      CONFIRM: 'Yes, cancel',
    },

    RESUME_MODAL: {
      TITLE: 'Resume Follow-up',
      DESCRIPTION: 'Select the date and time for the next contact attempt',
      PAUSED_AT: 'Paused on',
      CURRENT_ATTEMPT: 'Current attempt',
      SCHEDULED_FOR: 'Date and time of next attempt',
      SCHEDULED_FOR_HELP: 'The bot will send the message at the selected date and time',
      CANCEL: 'Cancel',
      SUBMIT: 'Resume',
      SUCCESS: 'Follow-up resumed successfully',
      ERROR: 'Error resuming follow-up',
    },

    API: {
      FETCH_ERROR: 'Error loading follow-ups',
      CREATE_SUCCESS: 'Follow-up created successfully',
      UPDATE_SUCCESS: 'Follow-up updated successfully',
      PAUSE_SUCCESS: 'Follow-up paused successfully',
      RESUME_SUCCESS: 'Follow-up resumed successfully',
      CANCEL_SUCCESS: 'Follow-up cancelled successfully',
      ERROR: 'An error occurred. Please try again',
    },

    // proyecto@contact_tracking: keyword-triggered actions
    KEYWORD_ACTIONS: {
      SECTION_TITLE: 'Action keywords',
      SECTION_DESCRIPTION: 'When a message contains exactly this keyword, the action is executed silently.',
      ADD_BTN: 'Add keyword',
      KEYWORD_PLACEHOLDER: 'e.g. #cancel',
      ACTIONS: {
        LABEL: 'Action',
        CANCEL: 'Cancel follow-up',
        PAUSE: 'Pause follow-up',
      },
      DIRECTIONS: {
        LABEL: 'Direction',
        INCOMING: 'Incoming message',
        OUTGOING: 'Outgoing message',
        BOTH: 'Both',
      },
      EMPTY: 'No keywords configured.',
      REMOVE: 'Remove',
    },
  },
};
