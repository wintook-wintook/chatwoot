<!--
  ================================================================================
  proyecto@contact_tracking
  ================================================================================
  Componente: ResumeTrackingModal.vue
  Descripcion: Modal para reanudar un seguimiento pausado
               Permite al usuario elegir la fecha/hora del siguiente intento
  ================================================================================
-->

<template>
  <woot-modal :show="show" :on-close="onClose">
    <div class="flex flex-col h-auto p-6">
      <!-- Header -->
      <woot-modal-header
        :header-title="$t('CONTACT_TRACKING.RESUME_MODAL.TITLE')"
        :header-content="$t('CONTACT_TRACKING.RESUME_MODAL.DESCRIPTION')"
      />

      <!-- Info del tracking pausado -->
      <div class="bg-slate-50 dark:bg-slate-800 rounded-lg p-4 mb-4">
        <p class="text-sm text-slate-600 dark:text-slate-400">
          <strong>{{ $t('CONTACT_TRACKING.FORM.OBJECTIVE.LABEL') }}:</strong>
          {{ tracking.objective }}
        </p>
        <p v-if="tracking.paused_at" class="text-sm text-slate-600 dark:text-slate-400 mt-1">
          <strong>{{ $t('CONTACT_TRACKING.RESUME_MODAL.PAUSED_AT') }}:</strong>
          {{ formatDateTime(tracking.paused_at) }}
        </p>
        <p class="text-sm text-slate-600 dark:text-slate-400 mt-1">
          <strong>{{ $t('CONTACT_TRACKING.RESUME_MODAL.CURRENT_ATTEMPT') }}:</strong>
          {{ tracking.attempt_count + 1 }} de {{ tracking.max_attempts }}
        </p>
      </div>

      <!-- Selector de fecha/hora -->
      <label class="block mb-4">
        <span class="text-sm font-medium text-slate-700 dark:text-slate-300">
          {{ $t('CONTACT_TRACKING.RESUME_MODAL.SCHEDULED_FOR') }}
          <span class="text-red-500">*</span>
        </span>
        <input
          v-model="scheduledFor"
          type="datetime-local"
          :min="minDateTime"
          class="mt-1 w-full rounded-md border-slate-300 dark:border-slate-600
                 dark:bg-slate-900 dark:text-slate-100 focus:ring-woot-500
                 focus:border-woot-500"
          required
        />
        <span class="text-xs text-slate-500 dark:text-slate-400 mt-1">
          {{ $t('CONTACT_TRACKING.RESUME_MODAL.SCHEDULED_FOR_HELP') }}
        </span>
      </label>

      <!-- Botones -->
      <div class="flex justify-end gap-3 pt-4 border-t border-slate-200 dark:border-slate-700">
        <woot-button variant="clear" @click="onClose">
          {{ $t('CONTACT_TRACKING.RESUME_MODAL.CANCEL') }}
        </woot-button>
        <woot-button
          :is-loading="isLoading"
          :is-disabled="!scheduledFor"
          @click="handleResume"
        >
          {{ $t('CONTACT_TRACKING.RESUME_MODAL.SUBMIT') }}
        </woot-button>
      </div>
    </div>
  </woot-modal>
</template>

<script>
import { useAlert } from 'dashboard/composables';

export default {
  name: 'ResumeTrackingModal',

  props: {
    show: {
      type: Boolean,
      default: false,
    },
    tracking: {
      type: Object,
      required: true,
    },
    contactId: {
      type: Number,
      required: true,
    },
  },

  emits: ['close', 'resumed'],

  data() {
    return {
      scheduledFor: '',
      isLoading: false,
    };
  },

  computed: {
    minDateTime() {
      // Fecha minima = ahora + 1 minuto
      const now = new Date();
      now.setMinutes(now.getMinutes() + 1);
      return this.toDatetimeLocal(now);
    },
  },

  watch: {
    show(newVal) {
      if (newVal) {
        // Al abrir el modal, sugerir fecha por defecto
        this.suggestDefaultDate();
      }
    },
  },

  methods: {
    onClose() {
      this.scheduledFor = '';
      this.$emit('close');
    },

    suggestDefaultDate() {
      // Sugerir: ahora + intervalo del tracking
      const now = new Date();
      const intervalValue = this.tracking.retry_interval_value || 30;
      const intervalUnit = this.tracking.retry_interval_unit || 'minutes';

      let intervalMs;
      switch (intervalUnit) {
        case 'hours':
          intervalMs = intervalValue * 60 * 60 * 1000;
          break;
        case 'days':
          intervalMs = intervalValue * 24 * 60 * 60 * 1000;
          break;
        default: // minutes
          intervalMs = intervalValue * 60 * 1000;
      }

      const suggestedDate = new Date(now.getTime() + intervalMs);
      this.scheduledFor = this.toDatetimeLocal(suggestedDate);
    },

    toDatetimeLocal(date) {
      const d = new Date(date);
      const offset = d.getTimezoneOffset();
      const localDate = new Date(d.getTime() - offset * 60 * 1000);
      return localDate.toISOString().slice(0, 16);
    },

    formatDateTime(date) {
      if (!date) return '';
      return new Date(date).toLocaleString('es-ES', {
        day: '2-digit',
        month: '2-digit',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
      });
    },

    async handleResume() {
      if (!this.scheduledFor) return;

      this.isLoading = true;
      try {
        await this.$store.dispatch('contactTrackings/resume', {
          contactId: this.contactId,
          trackingId: this.tracking.id,
          scheduledFor: new Date(this.scheduledFor).toISOString(),
        });

        useAlert(this.$t('CONTACT_TRACKING.RESUME_MODAL.SUCCESS'));
        this.$emit('resumed');
        this.onClose();
      } catch (error) {
        console.error('Error resuming tracking:', error);
        const errorMessage = error.response?.data?.error ||
          this.$t('CONTACT_TRACKING.RESUME_MODAL.ERROR');
        useAlert(errorMessage);
      } finally {
        this.isLoading = false;
      }
    },
  },
};
</script>
