<!--
  ================================================================================
  proyecto@bulk_tracking_assign
  ================================================================================
  Componente: BulkAssignModal.vue
  Descripción: Modal principal para asignar una TrackingTemplate a un conjunto
               de contactos resuelto por filtro (mismo formato que
               Contacts::FilterService). Permite elegir plantilla, fecha/hora
               de inicio, omitir contactos con seguimiento activo y revisar/
               excluir contactos antes de confirmar.
  ================================================================================
-->

<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import contactAPI from 'dashboard/api/contacts';
import contactTrackingBulkAssignsAPI from 'dashboard/api/contactTrackingBulkAssigns';
import { getMinDateTime } from '../../../helper/trackingHelpers';
import ReviewContactsModal from './ReviewContactsModal.vue';

const MAX_BULK_ASSIGN = 100;

export default {
  components: { ReviewContactsModal },
  props: {
    show: { type: Boolean, default: false },
    filterPayload: { type: Array, default: () => [] },
  },
  emits: ['close', 'success'],
  data() {
    return {
      selectedTemplateId: '',
      scheduledFor: '',
      skipActive: true,
      excludedContactIds: [],
      totalCount: 0,
      isLoadingCount: false,
      isSubmitting: false,
      showReviewModal: false,
      result: null,
    };
  },
  computed: {
    ...mapGetters({
      templates: 'trackingTemplates/getTemplates',
    }),
    minDateTime() {
      return getMinDateTime();
    },
    selectedCount() {
      return Math.max(this.totalCount - this.excludedContactIds.length, 0);
    },
    exceedsLimit() {
      return this.selectedCount > MAX_BULK_ASSIGN;
    },
    canConfirm() {
      return (
        !!this.selectedTemplateId &&
        !!this.scheduledFor &&
        this.selectedCount > 0 &&
        !this.exceedsLimit &&
        !this.isLoadingCount &&
        !this.isSubmitting
      );
    },
  },
  watch: {
    show(val) {
      if (val) {
        this.resetState();
        this.loadTemplates();
        this.fetchCount();
      }
    },
  },
  methods: {
    resetState() {
      this.selectedTemplateId = '';
      this.scheduledFor = '';
      this.skipActive = true;
      this.excludedContactIds = [];
      this.totalCount = 0;
      this.result = null;
      this.showReviewModal = false;
    },
    async loadTemplates() {
      if (this.templates.length) return;
      try {
        await this.$store.dispatch('trackingTemplates/get');
      } catch (error) {
        // silencioso
      }
    },
    async fetchCount() {
      this.isLoadingCount = true;
      try {
        const { data } = await contactAPI.filter(1, 'name', {
          payload: this.filterPayload,
        });
        this.totalCount = data.meta.count;
      } catch (error) {
        this.totalCount = 0;
      } finally {
        this.isLoadingCount = false;
      }
    },
    openReview() {
      this.showReviewModal = true;
    },
    onUpdateExcluded(ids) {
      this.excludedContactIds = ids;
    },
    async onConfirm() {
      this.isSubmitting = true;
      try {
        const { data } = await contactTrackingBulkAssignsAPI.create({
          payload: this.filterPayload,
          templateId: this.selectedTemplateId,
          scheduledFor: new Date(this.scheduledFor).toISOString(),
          excludedContactIds: this.excludedContactIds,
          skipActive: this.skipActive,
        });
        this.result = data;
      } catch (error) {
        useAlert(
          error.response?.data?.error ||
            error.message ||
            this.$t('BULK_TRACKING_ASSIGN.MODAL.ERROR_GENERIC')
        );
      } finally {
        this.isSubmitting = false;
      }
    },
    onClose() {
      if (this.result) {
        this.$emit('success', this.result);
      }
      this.$emit('close');
    },
  },
};
</script>

<template>
  <woot-modal :show="show" :on-close="onClose" size="medium">
    <div class="p-6 w-full max-w-2xl">
      <h2 class="text-xl font-bold text-slate-800 dark:text-slate-100 mb-1">
        {{ $t('BULK_TRACKING_ASSIGN.MODAL.TITLE') }}
      </h2>
      <p class="text-sm text-slate-500 dark:text-slate-400 mb-4">
        {{ $t('BULK_TRACKING_ASSIGN.MODAL.DESCRIPTION') }}
      </p>

      <template v-if="!result">
        <!-- Plantilla -->
        <label class="block mb-4">
          <span
            class="text-sm font-semibold text-slate-700 dark:text-slate-300"
          >
            {{ $t('BULK_TRACKING_ASSIGN.MODAL.TEMPLATE_LABEL') }}
          </span>
          <select
            v-model="selectedTemplateId"
            class="w-full bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 border border-slate-200 dark:border-slate-600 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-1 focus:ring-woot-200 focus:border-woot-200"
          >
            <option value="" disabled>
              {{ $t('BULK_TRACKING_ASSIGN.MODAL.TEMPLATE_PLACEHOLDER') }}
            </option>
            <option v-for="t in templates" :key="t.id" :value="t.id">
              {{ t.name }}
            </option>
          </select>
        </label>

        <!-- Fecha y hora -->
        <label class="block mb-4">
          <span
            class="text-sm font-semibold text-slate-700 dark:text-slate-300"
          >
            {{ $t('BULK_TRACKING_ASSIGN.MODAL.SCHEDULED_FOR_LABEL') }}
          </span>
          <input
            v-model="scheduledFor"
            type="datetime-local"
            :min="minDateTime"
            class="w-full bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 border border-slate-200 dark:border-slate-600 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-1 focus:ring-woot-200 focus:border-woot-200"
          />
        </label>

        <!-- Omitir activos -->
        <label
          class="flex items-center gap-2 mb-4 text-sm text-slate-700 dark:text-slate-300"
        >
          <input v-model="skipActive" type="checkbox" />
          {{ $t('BULK_TRACKING_ASSIGN.MODAL.SKIP_ACTIVE') }}
        </label>

        <!-- Conteo de contactos -->
        <div class="mb-4 text-sm text-slate-600 dark:text-slate-300">
          {{ $t('BULK_TRACKING_ASSIGN.MODAL.CONTACTS_COUNT_PREFIX') }}
          <button
            type="button"
            class="font-semibold text-woot-500 hover:text-woot-600 underline"
            :disabled="isLoadingCount"
            @click="openReview"
          >
            {{ selectedCount }}
          </button>
          {{ $t('BULK_TRACKING_ASSIGN.MODAL.CONTACTS_COUNT_SUFFIX') }}
        </div>

        <!-- Aviso de límite -->
        <div
          v-if="exceedsLimit"
          class="mb-4 p-3 bg-yellow-50 dark:bg-yellow-900/20 border border-yellow-200 dark:border-yellow-800 rounded-md text-sm text-yellow-800 dark:text-yellow-200"
        >
          {{ $t('BULK_TRACKING_ASSIGN.MODAL.LIMIT_EXCEEDED', { max: MAX_BULK_ASSIGN }) }}
        </div>

        <div class="flex justify-end gap-2 mt-6">
          <woot-button variant="clear" @click="onClose">
            {{ $t('BULK_TRACKING_ASSIGN.MODAL.CANCEL') }}
          </woot-button>
          <woot-button
            :is-loading="isSubmitting"
            :disabled="!canConfirm"
            @click="onConfirm"
          >
            {{ $t('BULK_TRACKING_ASSIGN.MODAL.CONFIRM') }}
          </woot-button>
        </div>
      </template>

      <!-- Resultado -->
      <template v-else>
        <div class="space-y-2 text-sm text-slate-700 dark:text-slate-300">
          <p>
            {{ $t('BULK_TRACKING_ASSIGN.MODAL.RESULT_INSERTED') }}:
            <strong>{{ result.inserted }}</strong>
          </p>
          <p>
            {{ $t('BULK_TRACKING_ASSIGN.MODAL.RESULT_SKIPPED') }}:
            <strong>{{ result.skipped }}</strong>
          </p>
          <div v-if="result.errors && result.errors.length">
            <p class="font-semibold text-red-500">
              {{ $t('BULK_TRACKING_ASSIGN.MODAL.RESULT_ERRORS') }}:
            </p>
            <ul class="list-disc list-inside text-red-500">
              <li v-for="(err, idx) in result.errors" :key="idx">
                {{ err.contact_name || err.contact_id || '—' }}:
                {{ err.message }}
              </li>
            </ul>
          </div>
        </div>

        <div class="flex justify-end mt-6">
          <woot-button color-scheme="primary" @click="onClose">
            {{ $t('BULK_TRACKING_ASSIGN.MODAL.CLOSE') }}
          </woot-button>
        </div>
      </template>
    </div>

    <ReviewContactsModal
      :show="showReviewModal"
      :filter-payload="filterPayload"
      :excluded-contact-ids="excludedContactIds"
      @close="showReviewModal = false"
      @update:excludedContactIds="onUpdateExcluded"
    />
  </woot-modal>
</template>
