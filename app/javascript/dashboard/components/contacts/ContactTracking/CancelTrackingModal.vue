<template>
  <woot-modal :show="show" :on-close="onClose" size="small">
    <div class="flex flex-col h-auto p-6">
      <woot-modal-header
        :header-title="$t('CONTACT_TRACKING.CANCEL_MODAL.TITLE')"
        :header-content="$t('CONTACT_TRACKING.CANCEL_MODAL.DESCRIPTION')"
      />

      <!-- Info del tracking -->
      <div class="bg-red-50 dark:bg-red-900/20 rounded-lg p-4 mb-6 border border-red-100 dark:border-red-800">
        <p class="text-sm font-medium text-red-800 dark:text-red-200">
          {{ tracking.objective }}
        </p>
        <p class="text-xs text-red-600 dark:text-red-400 mt-1">
          {{ $t('CONTACT_TRACKING.CANCEL_MODAL.WARNING') }}
        </p>
      </div>

      <!-- Botones -->
      <div class="flex justify-end gap-3 pt-2">
        <woot-button variant="clear" color-scheme="secondary" @click="onClose">
          {{ $t('CONTACT_TRACKING.CANCEL_MODAL.DISMISS') }}
        </woot-button>
        <woot-button
          color-scheme="alert"
          :is-loading="isLoading"
          @click="handleConfirm"
        >
          {{ $t('CONTACT_TRACKING.CANCEL_MODAL.CONFIRM') }}
        </woot-button>
      </div>
    </div>
  </woot-modal>
</template>

<script>
export default {
  name: 'CancelTrackingModal',

  props: {
    show: {
      type: Boolean,
      default: false,
    },
    tracking: {
      type: Object,
      required: true,
    },
    isLoading: {
      type: Boolean,
      default: false,
    },
  },

  emits: ['close', 'confirm'],

  methods: {
    onClose() {
      this.$emit('close');
    },
    handleConfirm() {
      this.$emit('confirm');
    },
  },
};
</script>
