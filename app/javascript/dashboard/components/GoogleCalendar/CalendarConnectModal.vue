<template>
  <div class="flex flex-1 flex-col items-center justify-center w-full h-full py-16 px-8 text-center">
    <!-- Empty state -->
    <fluent-icon icon="calendar" size="64" class="text-slate-300 dark:text-slate-600 mb-6" />
    <h2 class="text-xl font-semibold text-slate-800 dark:text-slate-100 mb-2">
      {{ $t('GOOGLE_CALENDAR.CONNECT.TITLE') }}
    </h2>
    <p class="text-slate-500 dark:text-slate-400 max-w-md mb-8">
      {{ $t('GOOGLE_CALENDAR.CONNECT.DESCRIPTION') }}
    </p>
    <woot-button icon="brand-google" @click="showModal = true">
      {{ $t('GOOGLE_CALENDAR.CONNECT.BUTTON') }}
    </woot-button>

    <!-- Confirmation modal -->
    <woot-modal :show="showModal" :on-close="() => (showModal = false)">
      <woot-modal-header :header-title="$t('GOOGLE_CALENDAR.CONNECT.MODAL.TITLE')" />
      <div class="p-6">
        <p class="text-sm text-slate-600 dark:text-slate-300 mb-4">
          {{ $t('GOOGLE_CALENDAR.CONNECT.MODAL.DESCRIPTION') }}
        </p>
        <ul class="space-y-2 mb-6">
          <li
            v-for="permission in $t('GOOGLE_CALENDAR.CONNECT.MODAL.PERMISSIONS')"
            :key="permission"
            class="flex items-center gap-2 text-sm text-slate-600 dark:text-slate-300"
          >
            <fluent-icon icon="checkmark-circle" size="16" class="text-green-500 flex-shrink-0" />
            {{ permission }}
          </li>
        </ul>
        <div class="flex justify-end gap-2">
          <woot-button variant="clear" @click="showModal = false">
            {{ $t('GOOGLE_CALENDAR.CONNECT.MODAL.CANCEL') }}
          </woot-button>
          <woot-button
            icon="brand-google"
            :is-loading="uiFlags.isConnecting"
            @click="$emit('connect')"
          >
            {{ uiFlags.isConnecting ? $t('GOOGLE_CALENDAR.CONNECT.CONNECTING') : $t('GOOGLE_CALENDAR.CONNECT.MODAL.CONFIRM') }}
          </woot-button>
        </div>
      </div>
    </woot-modal>
  </div>
</template>

<script>
export default {
  name: 'CalendarConnectModal',
  props: {
    uiFlags: {
      type: Object,
      default: () => ({}),
    },
  },
  emits: ['connect'],
  data() {
    return { showModal: false };
  },
};
</script>
