<!--
  ================================================================================
  @campanas_vendedor / proyecto@bulk_tracking_assign
  ================================================================================
  Componente: CampaignForm.vue
  Descripción: Formulario para configurar y lanzar una campaña (asignación masiva de
               un Agente IA). Antes vivía en un modal; ahora es inline, dentro del tab
               "Nueva campaña" de Campañas de seguimiento. Debajo embebe AudiencePreview
               (los buckets). Hace UN solo /preview y recalcula los conteos en cliente.

  proyecto@automatizacion_campanas — tipo y VENTANA (docs/automatizacion_campanas_plan.md §7.1):
    - Por lote: la audiencia de siempre (segmento o etiqueta + vista previa) y se crea por
      contact_tracking_bulk_assigns.
    - Continua: sin audiencia; se crea sola (POST tracking_campaigns) y la llenan las
      automatizaciones con "Agregar a campaña". El inicio es opcional (vacío = ahora).
    En las dos: fin opcional, espera tras la inscripción y horario de atención del inbox;
    la continua además tiene tope diario.

  Props:
    - presetFilterPayload: si viene (p. ej. desde Contactos), la audiencia es ese
      filtro y se oculta el selector de segmento/etiqueta (y el tipo: es por lote).
  Emits:
    - created(result): tras lanzar la campaña ({ queued, campaign_id, campaign_name }).
  ================================================================================
-->

<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import contactAPI from 'dashboard/api/contacts';
import contactTrackingBulkAssignsAPI from 'dashboard/api/contactTrackingBulkAssigns';
import TrackingCampaignsAPI from 'dashboard/api/trackingCampaigns';
import { getMinDateTime } from '../../../helper/trackingHelpers';
import AudiencePreview from './AudiencePreview.vue';

const MAX_BULK_ASSIGN = 100;
// Nombre del enum filter_type de customViews para "contactos" (el backend lo serializa
// como string "contact"; el getter getCustomViewsByFilterType compara por ese string).
const FILTER_TYPE_CONTACT = 'contact';

export default {
  components: { AudiencePreview },
  props: {
    presetFilterPayload: { type: Array, default: null },
  },
  emits: ['created'],
  data() {
    return {
      campaignName: '',
      selectedTemplateId: '',
      mode: 'batch',
      scheduledFor: '',
      endsAt: '',
      entryDelayMinutes: 0,
      respectWorkingHours: true,
      dailyCap: '',
      skipActive: true,
      excludedContactIds: [],
      audienceType: 'segment',
      selectedSegmentId: '',
      selectedLabel: '',
      totalCount: 0,
      previewData: null,
      isLoadingPreview: false,
      isSubmitting: false,
    };
  },
  computed: {
    ...mapGetters({
      templates: 'trackingTemplates/getTemplates',
      labels: 'labels/getLabels',
    }),
    segments() {
      return this.$store.getters['customViews/getCustomViewsByFilterType'](
        FILTER_TYPE_CONTACT
      );
    },
    minDateTime() {
      return getMinDateTime();
    },
    // Cuando llega un filtro preestablecido (desde Contactos) no se elige audiencia.
    allowAudienceSelection() {
      return !this.presetFilterPayload;
    },
    isContinuous() {
      return this.mode === 'continuous';
    },
    // El fin, si lo hay, después del inicio (o de ahora, si la continua no tiene inicio).
    windowError() {
      if (!this.endsAt) return '';
      const start = this.scheduledFor
        ? new Date(this.scheduledFor)
        : new Date();
      return new Date(this.endsAt) <= start
        ? this.$t('BULK_TRACKING_ASSIGN.MODAL.ENDS_BEFORE_START')
        : '';
    },
    endsAtMin() {
      return this.scheduledFor || this.minDateTime;
    },
    effectiveFilterPayload() {
      if (!this.allowAudienceSelection) return this.presetFilterPayload;
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
    total() {
      return this.previewData ? this.previewData.counts.total : this.totalCount;
    },
    selectedCount() {
      return Math.max(this.total - this.excludedContactIds.length, 0);
    },
    // "Listos" recalculados en cliente desde el preview + las exclusiones actuales.
    readyCount() {
      if (!this.previewData || this.previewData.counts_only) return null;
      const excluded = new Set(this.excludedContactIds);
      return this.previewData.contacts.reduce(
        (n, c) => (!excluded.has(c.id) && c.bucket === 'ready' ? n + 1 : n),
        0
      );
    },
    displayCount() {
      return this.readyCount !== null ? this.readyCount : this.selectedCount;
    },
    exceedsLimit() {
      return this.selectedCount > MAX_BULK_ASSIGN;
    },
    canConfirm() {
      if (this.isContinuous) {
        return (
          !!this.campaignName.trim() &&
          !!this.selectedTemplateId &&
          !this.windowError &&
          !this.isSubmitting
        );
      }
      const hasTargets =
        this.readyCount !== null ? this.readyCount > 0 : this.selectedCount > 0;
      return (
        !!this.campaignName.trim() &&
        this.hasAudienceSelected &&
        !!this.selectedTemplateId &&
        !!this.scheduledFor &&
        !this.windowError &&
        hasTargets &&
        !this.exceedsLimit &&
        !this.isLoadingPreview &&
        !this.isSubmitting
      );
    },
  },
  watch: {
    audienceType() {
      this.onAudienceChange();
    },
    selectedSegmentId() {
      this.onAudienceChange();
    },
    selectedLabel() {
      this.onAudienceChange();
    },
    selectedTemplateId() {
      if (!this.isContinuous) this.fetchPreview();
    },
    mode() {
      if (!this.isContinuous) this.fetchPreview();
    },
  },
  mounted() {
    this.loadTemplates();
    this.loadAudienceData();
    this.fetchPreview();
  },
  methods: {
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
      this.previewData = null;
      this.fetchPreview();
    },
    async fetchPreview() {
      if (!this.hasAudienceSelected) {
        this.totalCount = 0;
        this.previewData = null;
        return;
      }
      this.isLoadingPreview = true;
      try {
        if (this.selectedTemplateId) {
          await this.fetchClassifiedPreview();
        } else {
          await this.fetchAudienceCount();
        }
      } catch (error) {
        this.totalCount = 0;
        this.previewData = null;
      } finally {
        this.isLoadingPreview = false;
      }
    },
    // Sin agente aún: solo el tamaño bruto de la audiencia (no hay canal todavía).
    async fetchAudienceCount() {
      const { data } = await contactAPI.filter(1, 'name', {
        payload: this.effectiveFilterPayload,
      });
      this.totalCount = data.meta.count;
      this.previewData = null;
    },
    // Con agente: el preview da el desglose por bucket + la lista clasificada.
    async fetchClassifiedPreview() {
      const { data } = await contactTrackingBulkAssignsAPI.preview({
        payload: this.effectiveFilterPayload,
        templateId: this.selectedTemplateId,
        skipActive: this.skipActive,
        excludedContactIds: this.excludedContactIds,
      });
      this.previewData = data;
    },
    onToggleExclude(contactId) {
      this.excludedContactIds = this.excludedContactIds.includes(contactId)
        ? this.excludedContactIds.filter(id => id !== contactId)
        : [...this.excludedContactIds, contactId];
    },
    toIso(value) {
      return value ? new Date(value).toISOString() : null;
    },
    windowPayload() {
      return {
        ends_at: this.toIso(this.endsAt),
        entry_delay_minutes: Number(this.entryDelayMinutes) || 0,
        respect_working_hours: this.respectWorkingHours,
      };
    },
    createContinuous() {
      return TrackingCampaignsAPI.create({
        name: this.campaignName.trim(),
        tracking_template_id: this.selectedTemplateId,
        scheduled_for: this.toIso(this.scheduledFor),
        daily_cap: this.dailyCap ? Number(this.dailyCap) : null,
        ...this.windowPayload(),
      });
    },
    createBatch() {
      return contactTrackingBulkAssignsAPI.create({
        payload: this.effectiveFilterPayload,
        campaignName: this.campaignName.trim(),
        templateId: this.selectedTemplateId,
        scheduledFor: this.toIso(this.scheduledFor),
        excludedContactIds: this.excludedContactIds,
        skipActive: this.skipActive,
        window: this.windowPayload(),
      });
    },
    async onConfirm() {
      this.isSubmitting = true;
      try {
        const { data } = this.isContinuous
          ? await this.createContinuous()
          : await this.createBatch();
        if (this.isContinuous) {
          useAlert(
            this.$t('BULK_TRACKING_ASSIGN.MODAL.CONTINUOUS_CREATED', {
              name: data.campaign_name,
            })
          );
        }
        this.$emit('created', data);
        this.resetForm();
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
    resetForm() {
      this.campaignName = '';
      this.selectedTemplateId = '';
      this.mode = 'batch';
      this.scheduledFor = '';
      this.endsAt = '';
      this.entryDelayMinutes = 0;
      this.respectWorkingHours = true;
      this.dailyCap = '';
      this.skipActive = true;
      this.excludedContactIds = [];
      this.audienceType = 'segment';
      this.selectedSegmentId = '';
      this.selectedLabel = '';
      this.totalCount = 0;
      this.previewData = null;
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-4">
    <!-- Configuración -->
    <div
      class="bg-white dark:bg-slate-900 border border-slate-100 dark:border-slate-700 rounded-md p-4"
    >
      <div class="grid grid-cols-1 md:grid-cols-2 gap-x-4 gap-y-3">
        <!-- Nombre de la campaña -->
        <label class="block">
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
            class="w-full mt-1 bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 border border-slate-200 dark:border-slate-600 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-1 focus:ring-woot-200 focus:border-woot-200"
          />
        </label>

        <!-- Agente IA -->
        <label class="block">
          <span
            class="text-sm font-semibold text-slate-700 dark:text-slate-300"
          >
            {{ $t('BULK_TRACKING_ASSIGN.MODAL.TEMPLATE_LABEL') }}
          </span>
          <select
            v-model="selectedTemplateId"
            class="w-full mt-1 bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 border border-slate-200 dark:border-slate-600 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-1 focus:ring-woot-200 focus:border-woot-200"
          >
            <option value="" disabled>
              {{ $t('BULK_TRACKING_ASSIGN.MODAL.TEMPLATE_PLACEHOLDER') }}
            </option>
            <option v-for="t in templates" :key="t.id" :value="t.id">
              {{ t.name }}
            </option>
          </select>
        </label>
      </div>

      <!-- proyecto@automatizacion_campanas: tipo de campaña, debajo de nombre y Agente IA.
           Desde Contactos (audiencia ya elegida) solo cabe "por lote": no se muestra. -->
      <div v-if="allowAudienceSelection" class="mt-4 mb-4">
        <span class="text-sm font-semibold text-slate-700 dark:text-slate-300">
          {{ $t('BULK_TRACKING_ASSIGN.MODAL.TYPE_LABEL') }}
        </span>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-3 mt-1">
          <label
            v-for="option in ['batch', 'continuous']"
            :key="option"
            class="flex items-start gap-2 p-3 border rounded-md cursor-pointer"
            :class="
              mode === option
                ? 'border-woot-300 bg-woot-25 dark:bg-woot-900/20'
                : 'border-slate-200 dark:border-slate-600'
            "
          >
            <input v-model="mode" type="radio" :value="option" class="mt-1" />
            <span>
              <span
                class="block text-sm font-semibold text-slate-800 dark:text-slate-100"
              >
                {{
                  $t(
                    option === 'batch'
                      ? 'BULK_TRACKING_ASSIGN.MODAL.TYPE_BATCH'
                      : 'BULK_TRACKING_ASSIGN.MODAL.TYPE_CONTINUOUS'
                  )
                }}
              </span>
              <span class="block text-xs text-slate-500 dark:text-slate-400">
                {{
                  $t(
                    option === 'batch'
                      ? 'BULK_TRACKING_ASSIGN.MODAL.TYPE_BATCH_HINT'
                      : 'BULK_TRACKING_ASSIGN.MODAL.TYPE_CONTINUOUS_HINT'
                  )
                }}
              </span>
            </span>
          </label>
        </div>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-x-4 gap-y-3">
        <!-- Audiencia: los radios ("Audiencia por Segmento/Etiqueta") hacen de
             encabezado del campo, por eso no hay un título "Audiencia" aparte
             (así la celda queda alineada con la de Fecha en el grid). -->
        <div
          v-if="isContinuous"
          class="p-3 rounded-md bg-slate-25 dark:bg-slate-800 border border-slate-100 dark:border-slate-700"
        >
          <span
            class="text-sm font-semibold text-slate-700 dark:text-slate-300"
          >
            {{ $t('BULK_TRACKING_ASSIGN.MODAL.CONTINUOUS_AUDIENCE_TITLE') }}
          </span>
          <p class="mt-1 mb-0 text-xs text-slate-500 dark:text-slate-400">
            {{ $t('BULK_TRACKING_ASSIGN.MODAL.CONTINUOUS_AUDIENCE_BODY') }}
          </p>
        </div>
        <div v-else>
          <template v-if="allowAudienceSelection">
            <div class="flex items-center gap-4 h-5 mb-1">
              <label
                class="flex items-center gap-1.5 text-sm font-semibold text-slate-700 dark:text-slate-300"
              >
                <input
                  v-model="audienceType"
                  type="radio"
                  value="segment"
                  class="m-0"
                />
                {{ $t('BULK_TRACKING_ASSIGN.MODAL.AUDIENCE_SEGMENT') }}
              </label>
              <label
                class="flex items-center gap-1.5 text-sm font-semibold text-slate-700 dark:text-slate-300"
              >
                <input
                  v-model="audienceType"
                  type="radio"
                  value="label"
                  class="m-0"
                />
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
                {{
                  $t('BULK_TRACKING_ASSIGN.MODAL.AUDIENCE_LABEL_PLACEHOLDER')
                }}
              </option>
              <option v-for="l in labels" :key="l.id" :value="l.title">
                {{ l.title }}
              </option>
            </select>
          </template>
          <template v-else>
            <span
              class="text-sm font-semibold text-slate-700 dark:text-slate-300"
            >
              {{ $t('BULK_TRACKING_ASSIGN.MODAL.AUDIENCE_LABEL') }}
            </span>
            <p class="mt-1 text-sm text-slate-500 dark:text-slate-400 italic">
              {{ $t('BULK_TRACKING_ASSIGN.MODAL.AUDIENCE_FROM_CONTACTS') }}
            </p>
          </template>
        </div>

        <!-- Fecha programada. "Omitir contactos con Agente IA activo" se aplica
             siempre (skipActive fijo en true), por eso ya no se muestra opción. -->
        <div class="flex flex-col gap-3">
          <label class="block">
            <span
              class="flex items-center h-5 text-sm font-semibold text-slate-700 dark:text-slate-300"
            >
              {{
                $t(
                  isContinuous
                    ? 'BULK_TRACKING_ASSIGN.MODAL.STARTS_AT_OPTIONAL'
                    : 'BULK_TRACKING_ASSIGN.MODAL.STARTS_AT_LABEL'
                )
              }}
            </span>
            <input
              v-model="scheduledFor"
              type="datetime-local"
              :min="minDateTime"
              class="w-full mt-1 bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 border border-slate-200 dark:border-slate-600 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-1 focus:ring-woot-200 focus:border-woot-200"
            />
          </label>
        </div>
      </div>

      <!-- proyecto@automatizacion_campanas: el resto de la ventana y cómo se agenda
           a cada inscrito (plan §3.3). -->
      <div
        class="grid grid-cols-1 md:grid-cols-3 gap-x-4 gap-y-3 mt-4 pt-4 border-t border-slate-100 dark:border-slate-700"
      >
        <label class="block">
          <span
            class="text-sm font-semibold text-slate-700 dark:text-slate-300"
          >
            {{ $t('BULK_TRACKING_ASSIGN.MODAL.ENDS_AT_LABEL') }}
          </span>
          <input
            v-model="endsAt"
            type="datetime-local"
            :min="endsAtMin"
            class="w-full mt-1 bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 border border-slate-200 dark:border-slate-600 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-1 focus:ring-woot-200 focus:border-woot-200"
          />
        </label>
        <label class="block">
          <span
            class="text-sm font-semibold text-slate-700 dark:text-slate-300"
          >
            {{ $t('BULK_TRACKING_ASSIGN.MODAL.ENTRY_DELAY_LABEL') }}
          </span>
          <input
            v-model.number="entryDelayMinutes"
            type="number"
            min="0"
            step="5"
            class="w-full mt-1 bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 border border-slate-200 dark:border-slate-600 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-1 focus:ring-woot-200 focus:border-woot-200"
          />
        </label>
        <label v-if="isContinuous" class="block">
          <span
            class="text-sm font-semibold text-slate-700 dark:text-slate-300"
          >
            {{ $t('BULK_TRACKING_ASSIGN.MODAL.DAILY_CAP_LABEL') }}
          </span>
          <input
            v-model.number="dailyCap"
            type="number"
            min="1"
            :placeholder="
              $t('BULK_TRACKING_ASSIGN.MODAL.DAILY_CAP_PLACEHOLDER')
            "
            class="w-full mt-1 bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 border border-slate-200 dark:border-slate-600 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-1 focus:ring-woot-200 focus:border-woot-200"
          />
        </label>
        <label
          class="flex items-center gap-2 text-sm text-slate-700 dark:text-slate-300 md:col-span-3"
        >
          <input v-model="respectWorkingHours" type="checkbox" class="m-0" />
          {{ $t('BULK_TRACKING_ASSIGN.MODAL.RESPECT_WORKING_HOURS') }}
        </label>
        <p
          v-if="windowError"
          class="m-0 text-sm text-red-600 dark:text-red-400 md:col-span-3"
        >
          {{ windowError }}
        </p>
      </div>

      <!-- Aviso de límite -->
      <div
        v-if="!isContinuous && exceedsLimit"
        class="mt-4 p-3 bg-yellow-50 dark:bg-yellow-900/20 border border-yellow-200 dark:border-yellow-800 rounded-md text-sm text-yellow-800 dark:text-yellow-200"
      >
        {{
          $t('BULK_TRACKING_ASSIGN.MODAL.LIMIT_EXCEEDED', {
            max: MAX_BULK_ASSIGN,
          })
        }}
      </div>

      <div
        class="flex items-center justify-between mt-4 pt-4 border-t border-slate-100 dark:border-slate-700"
      >
        <span class="text-sm text-slate-600 dark:text-slate-300">
          <template v-if="!isContinuous">
            {{
              $t('BULK_TRACKING_ASSIGN.PREVIEW.WILL_CREATE', {
                count: displayCount,
              })
            }}
          </template>
        </span>
        <woot-button
          :is-loading="isSubmitting"
          :disabled="!canConfirm"
          @click="onConfirm"
        >
          {{
            $t(
              isContinuous
                ? 'BULK_TRACKING_ASSIGN.MODAL.CREATE_CONTINUOUS'
                : 'BULK_TRACKING_ASSIGN.MODAL.LAUNCH'
            )
          }}
        </woot-button>
      </div>
    </div>

    <!-- Revisar audiencia (solo por lote: la continua no tiene lista) -->
    <div
      v-if="!isContinuous"
      class="bg-white dark:bg-slate-900 border border-slate-100 dark:border-slate-700 rounded-md p-4"
    >
      <h3 class="text-sm font-semibold text-slate-700 dark:text-slate-300 mb-3">
        {{ $t('BULK_TRACKING_ASSIGN.PREVIEW.TITLE') }}
      </h3>

      <p
        v-if="!selectedTemplateId"
        class="text-sm text-slate-400 py-6 text-center"
      >
        {{ $t('BULK_TRACKING_ASSIGN.MODAL.PICK_AGENT_HINT') }}
      </p>

      <AudiencePreview
        v-else
        :preview="previewData"
        :is-loading="isLoadingPreview"
        :skip-active="skipActive"
        :excluded-contact-ids="excludedContactIds"
        @toggle-exclude="onToggleExclude"
      />
    </div>
  </div>
</template>
