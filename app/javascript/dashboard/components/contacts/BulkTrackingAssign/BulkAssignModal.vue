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
// Tipo de filtro de "contactos" para customViews (segmentos), igual que ContactsView.
const FILTER_TYPE_CONTACT = 1;

export default {
  components: { ReviewContactsModal },
  props: {
    show: { type: Boolean, default: false },
    filterPayload: { type: Array, default: () => [] },
    // Cuando es true, el modal muestra un selector de audiencia (segmento o
    // etiqueta) en lugar de recibir el filtro ya resuelto desde Contactos.
    allowAudienceSelection: { type: Boolean, default: false },
  },
  emits: ['close', 'success'],
  data() {
    return {
      campaignName: '',
      selectedTemplateId: '',
      scheduledFor: '',
      skipActive: true,
      excludedContactIds: [],
      totalCount: 0,
      isLoadingCount: false,
      isSubmitting: false,
      showReviewModal: false,
      result: null,
      audienceType: 'segment',
      selectedSegmentId: '',
      selectedLabel: '',
    };
  },
  computed: {
    ...mapGetters({
      templates: 'trackingTemplates/getTemplates',
      labels: 'labels/getLabels',
    }),
    // Solo segmentos de contactos (no de conversaciones).
    segments() {
      return this.$store.getters['customViews/getCustomViewsByFilterType'](
        FILTER_TYPE_CONTACT
      );
    },
    minDateTime() {
      return getMinDateTime();
    },
    // Filtro efectivo: el seleccionado en el modal (dashboard) o el recibido
    // por prop (Contactos).
    effectiveFilterPayload() {
      if (!this.allowAudienceSelection) return this.filterPayload;
      if (this.audienceType === 'segment' && this.selectedSegmentId) {
        const segment = this.segments.find(
          s => s.id === Number(this.selectedSegmentId)
        );
        return segment?.query?.payload || [];
      }
      if (this.audienceType === 'label' && this.selectedLabel) {
        return [
          {
            attribute_key: 'labels',
            filter_operator: 'equal_to',
            values: [this.selectedLabel],
            query_operator: null,
          },
        ];
      }
      return [];
    },
    hasAudienceSelected() {
      if (!this.allowAudienceSelection) return true;
      return this.audienceType === 'segment'
        ? !!this.selectedSegmentId
        : !!this.selectedLabel;
    },
    selectedCount() {
      return Math.max(this.totalCount - this.excludedContactIds.length, 0);
    },
    exceedsLimit() {
      return this.selectedCount > MAX_BULK_ASSIGN;
    },
    canConfirm() {
      return (
        !!this.campaignName.trim() &&
        this.hasAudienceSelected &&
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
        this.loadAudienceData();
        this.fetchCount();
      }
    },
    // Al cambiar la audiencia, recalcular el conteo y limpiar exclusiones.
    audienceType() {
      this.onAudienceChange();
    },
    selectedSegmentId() {
      this.onAudienceChange();
    },
    selectedLabel() {
      this.onAudienceChange();
    },
  },
  methods: {
    resetState() {
      this.campaignName = '';
      this.selectedTemplateId = '';
      this.scheduledFor = '';
      this.skipActive = true;
      this.excludedContactIds = [];
      this.totalCount = 0;
      this.result = null;
      this.showReviewModal = false;
      this.audienceType = 'segment';
      this.selectedSegmentId = '';
      this.selectedLabel = '';
    },
    async loadTemplates() {
      if (this.templates.length) return;
      try {
        await this.$store.dispatch('trackingTemplates/get');
      } catch (error) {
        // silencioso
      }
    },
    async loadAudienceData() {
      if (!this.allowAudienceSelection) return;
      try {
        if (!this.segments.length) {
          await this.$store.dispatch('customViews/get', FILTER_TYPE_CONTACT);
        }
        if (!this.labels.length) {
          await this.$store.dispatch('labels/get');
        }
      } catch (error) {
        // silencioso
      }
    },
    onAudienceChange() {
      this.excludedContactIds = [];
      this.fetchCount();
    },
    async fetchCount() {
      if (!this.hasAudienceSelected) {
        this.totalCount = 0;
        return;
      }
      this.isLoadingCount = true;
      try {
        const { data } = await contactAPI.filter(1, 'name', {
          payload: this.effectiveFilterPayload,
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
          payload: this.effectiveFilterPayload,
          campaignName: this.campaignName.trim(),
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
  <woot-modal :show="show" :on-close="onClose">
    <div class="p-6 w-full">
      <h2 class="text-xl font-bold text-slate-800 dark:text-slate-100 mb-1">
        {{ $t('BULK_TRACKING_ASSIGN.MODAL.TITLE') }}
      </h2>
      <p class="text-sm text-slate-500 dark:text-slate-400 mb-4">
        {{ $t('BULK_TRACKING_ASSIGN.MODAL.DESCRIPTION') }}
      </p>

      <template v-if="!result">
        <!-- Nombre de la campaña -->
        <label class="block mb-4">
          <span
            class="text-sm font-semibold text-slate-700 dark:text-slate-300"
          >
            {{ $t('BULK_TRACKING_ASSIGN.MODAL.CAMPAIGN_NAME_LABEL') }}
          </span>
          <input
            v-model="campaignName"
            type="text"
            maxlength="120"
            :placeholder="
              $t('BULK_TRACKING_ASSIGN.MODAL.CAMPAIGN_NAME_PLACEHOLDER')
            "
            class="w-full bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 border border-slate-200 dark:border-slate-600 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-1 focus:ring-woot-200 focus:border-woot-200"
          />
        </label>

        <!-- Audiencia (solo al crear desde el dashboard) -->
        <div v-if="allowAudienceSelection" class="mb-4">
          <span
            class="text-sm font-semibold text-slate-700 dark:text-slate-300"
          >
            {{ $t('BULK_TRACKING_ASSIGN.MODAL.AUDIENCE_LABEL') }}
          </span>
          <div class="flex gap-4 mt-1 mb-2">
            <label
              class="flex items-center gap-1.5 text-sm text-slate-700 dark:text-slate-300"
            >
              <input v-model="audienceType" type="radio" value="segment" />
              {{ $t('BULK_TRACKING_ASSIGN.MODAL.AUDIENCE_SEGMENT') }}
            </label>
            <label
              class="flex items-center gap-1.5 text-sm text-slate-700 dark:text-slate-300"
            >
              <input v-model="audienceType" type="radio" value="label" />
              {{ $t('BULK_TRACKING_ASSIGN.MODAL.AUDIENCE_LABEL_OPTION') }}
            </label>
          </div>
          <select
            v-if="audienceType === 'segment'"
            v-model="selectedSegmentId"
            class="w-full bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 border border-slate-200 dark:border-slate-600 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-1 focus:ring-woot-200 focus:border-woot-200"
          >
            <option value="" disabled>
              {{
                $t('BULK_TRACKING_ASSIGN.MODAL.AUDIENCE_SEGMENT_PLACEHOLDER')
              }}
            </option>
            <option v-for="s in segments" :key="s.id" :value="s.id">
              {{ s.name }}
            </option>
          </select>
          <select
            v-else
            v-model="selectedLabel"
            class="w-full bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 border border-slate-200 dark:border-slate-600 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-1 focus:ring-woot-200 focus:border-woot-200"
          >
            <option value="" disabled>
              {{ $t('BULK_TRACKING_ASSIGN.MODAL.AUDIENCE_LABEL_PLACEHOLDER') }}
            </option>
            <option v-for="l in labels" :key="l.id" :value="l.title">
              {{ l.title }}
            </option>
          </select>
        </div>

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
          {{
            $t('BULK_TRACKING_ASSIGN.MODAL.LIMIT_EXCEEDED', {
              max: MAX_BULK_ASSIGN,
            })
          }}
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
      :filter-payload="effectiveFilterPayload"
      :excluded-contact-ids="excludedContactIds"
      @close="showReviewModal = false"
      @update:excludedContactIds="onUpdateExcluded"
    />
  </woot-modal>
</template>
