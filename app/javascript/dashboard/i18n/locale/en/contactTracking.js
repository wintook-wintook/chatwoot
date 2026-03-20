// ================================================================================
// proyecto@contact_tracking
// ================================================================================
// Translations in English
// ================================================================================

export default {
    CONTACT_TRACKING: {
      TITLE: 'Tracking Management',
      DESCRIPTION: 'Schedule and manage automatic contact follow-ups',
      INTEGRATION_NOT_AVAILABLE: 'The tracking integration is not available for this inbox',

      TABS: {
        FORM: 'New Tracking',
        LIST: 'Active Trackings',
      },

      FORM: {
        OBJECTIVE: {
          LABEL: 'Tracking Objective',
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
          LABEL: 'AI Context',
          PLACEHOLDER: 'Provide additional information so the AI generates better messages...',
          HELP: 'The AI will use this context to personalize the follow-up messages',
        },
        BUTTONS: {
          CANCEL: 'Cancel',
          CREATE: 'Create Tracking',
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
        DUPLICATE: 'Duplicate tracking',
      },

      FILTERS: {
        STATUS: 'Filter by Status',
        INBOX: 'Filter by Channel',
        SEARCH: 'Search',
        SEARCH_PLACEHOLDER: 'Search by objective...',
        ALL: 'All',
      },

      EMPTY_STATE: 'No trackings created for this contact',
      AI_ENABLED: 'This tracking uses AI to generate messages',

      CONFIRM: {
        CANCEL_MESSAGE: 'Are you sure you want to cancel this tracking?',
      },

      CANCEL_MODAL: {
        TITLE: 'Cancel Tracking',
        DESCRIPTION: 'This action cannot be undone.',
        WARNING: 'The tracking will be cancelled and cannot be reactivated.',
        DISMISS: 'Go Back',
        CONFIRM: 'Yes, cancel',
      },

      RESUME_MODAL: {
        TITLE: 'Resume Tracking',
        DESCRIPTION: 'Select the date and time for the next contact attempt',
        PAUSED_AT: 'Paused on',
        CURRENT_ATTEMPT: 'Current attempt',
        SCHEDULED_FOR: 'Date and time of next attempt',
        SCHEDULED_FOR_HELP: 'The bot will send the message at the selected date and time',
        CANCEL: 'Cancel',
        SUBMIT: 'Resume',
        SUCCESS: 'Tracking resumed successfully',
        ERROR: 'Error resuming tracking',
      },

      API: {
        FETCH_ERROR: 'Error loading trackings',
        CREATE_SUCCESS: 'Tracking created successfully',
        UPDATE_SUCCESS: 'Tracking updated successfully',
        PAUSE_SUCCESS: 'Tracking paused successfully',
        RESUME_SUCCESS: 'Tracking resumed successfully',
        CANCEL_SUCCESS: 'Tracking cancelled successfully',
        ERROR: 'An error occurred. Please try again',
      },
    },

  };
