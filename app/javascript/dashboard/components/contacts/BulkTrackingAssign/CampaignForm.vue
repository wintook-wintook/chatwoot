<!--
  ================================================================================
  @campanas_vendedor / proyecto@bulk_tracking_assign
  ================================================================================
  Componente: CampaignForm.vue
  Descripción: Formulario para configurar y lanzar una campaña (asignación masiva de
               un Agente IA). Antes vivía en un modal; ahora es inline, dentro del tab
               "Nueva campaña" de Campañas de seguimiento. Debajo embebe AudiencePreview
               (los buckets). Hace UN solo /preview y recalcula los conteos en cliente.

  proyecto@automatizacion_campanas — el formulario en tres preguntas (plan §7.1):
    1 · ¿Qué?      nombre y Agente IA.
    2 · ¿A quién?  un segmento, una etiqueta o "los que agreguen mis automatizaciones".
                   Las dos primeras son una campaña POR LOTE (vista previa + asignación
                   masiva); la tercera, una CONTINUA (POST tracking_campaigns). No se le
                   pregunta a la persona "por lote o continua": se deduce de a quién.
    3 · ¿Cuándo?   desde / hasta (la ventana); las opciones de envío (espera, tope diario,
                   horario del inbox) van plegadas: con sus valores por defecto casi nadie
                   las toca.
  Junto al botón, un resumen de lo que va a pasar.

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
      showSendOptions: false,
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
    // Sin "tipo de campaña" en pantalla: sale de a quién va dirigida.
    mode() {
      return this.audienceType === 'automation' ? 'continuous' : 'batch';
    },
    isContinuous() {
      return this.mode === 'continuous';
    },
    summaryText() {
      const base = 'BULK_TRACKING_ASSIGN.MODAL';
      if (this.isContinuous) {
        return this.$t(`${base}.SUMMARY_CONTINUOUS`, {
          from: this.scheduledFor
            ? this.shortDate(this.scheduledFor)
            : this.$t(`${base}.NOW`),
          to: this.endsAt
            ? this.shortDate(this.endsAt)
            : this.$t(`${base}.NO_END`),
        });
      }
      if (!this.scheduledFor) {
        return this.$t(`${base}.SUMMARY_BATCH_NO_DATE`, {
          count: this.displayCount,
        });
      }
      return this.$t(`${base}.SUMMARY_BATCH`, {
        count: this.displayCount,
        date: this.shortDate(this.scheduledFor),
      });
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
    shortDate(value) {
      return new Date(value).toLocaleString('es-MX', {
        day: '2-digit',
        month: '2-digit',
        hour: '2-digit',
        minute: '2-digit',
      });
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
        this.$emit('created', { ...data, mode: this.mode });
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
      this.showSendOptions = false;
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
    <div
      class="bg-white dark:bg-slate-900 border border-slate-100 dark:border-slate-700 rounded-md p-4"
    >
      <!-- 1 · ¿Qué? -->
      <section>
        <h3 class="section-title">
          {{ $t('BULK_TRACKING_ASSIGN.MODAL.SECTION_WHAT') }}
        </h3>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-x-4 gap-y-3">
          <label class="block">
            <span class="field-label">
              {{ $t('BULK_TRACKING_ASSIGN.MODAL.CAMPAIGN_NAME_LABEL') }}
            </span>
            <input
              v-model="campaignName"
              type="text"
              maxlength="120"
              :placeholder="
                $t('BULK_TRACKING_ASSIGN.MODAL.CAMPAIGN_NAME_PLACEHOLDER')
              "
              class="field-input"
            />
          </label>
          <label class="block">
            <span class="field-label">
              {{ $t('BULK_TRACKING_ASSIGN.MODAL.TEMPLATE_LABEL') }}
            </span>
            <select v-model="selectedTemplateId" class="field-input">
              <option value="" disabled>
                {{ $t('BULK_TRACKING_ASSIGN.MODAL.TEMPLATE_PLACEHOLDER') }}
              </option>
              <option v-for="t in templates" :key="t.id" :value="t.id">
                {{ t.name }}
              </option>
            </select>
          </label>
        </div>
      </section>

      <!-- 2 · ¿A quién? Segmento o etiqueta = por lote; automatizaciones = continua.
           Tres fichas del mismo alto; los selectores siempre se ven y solo se habilita
           el de la opción elegida. -->
      <section class="mt-5">
        <h3 class="section-title">
          {{ $t('BULK_TRACKING_ASSIGN.MODAL.SECTION_WHO') }}
        </h3>
        <div
          v-if="allowAudienceSelection"
          class="grid grid-cols-1 md:grid-cols-3 gap-3"
        >
          <label
            class="audience-card"
            :class="{ 'audience-card--active': audienceType === 'segment' }"
          >
            <span class="audience-radio">
              <input v-model="audienceType" type="radio" value="segment" />
              {{ $t('BULK_TRACKING_ASSIGN.MODAL.WHO_SEGMENT') }}
            </span>
            <select
              v-model="selectedSegmentId"
              :disabled="audienceType !== 'segment'"
              class="field-input"
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
          </label>
          <label
            class="audience-card"
            :class="{ 'audience-card--active': audienceType === 'label' }"
          >
            <span class="audience-radio">
              <input v-model="audienceType" type="radio" value="label" />
              {{ $t('BULK_TRACKING_ASSIGN.MODAL.WHO_LABEL') }}
            </span>
            <select
              v-model="selectedLabel"
              :disabled="audienceType !== 'label'"
              class="field-input"
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
          </label>
          <label
            class="audience-card"
            :class="{ 'audience-card--active': audienceType === 'automation' }"
          >
            <span class="audience-radio">
              <input v-model="audienceType" type="radio" value="automation" />
              {{ $t('BULK_TRACKING_ASSIGN.MODAL.WHO_AUTOMATION') }}
            </span>
          </label>
        </div>
        <p v-else class="m-0 text-sm text-slate-500 dark:text-slate-400 italic">
          {{ $t('BULK_TRACKING_ASSIGN.MODAL.AUDIENCE_FROM_CONTACTS') }}
        </p>
      </section>

      <!-- 3 · ¿Cuándo? La ventana; las opciones de envío, plegadas. -->
      <section class="mt-5">
        <h3 class="section-title">
          {{ $t('BULK_TRACKING_ASSIGN.MODAL.SECTION_WHEN') }}
        </h3>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-x-4 gap-y-3">
          <label class="block">
            <span class="field-label">
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
              class="field-input"
            />
          </label>
          <label class="block">
            <span class="field-label">
              {{ $t('BULK_TRACKING_ASSIGN.MODAL.ENDS_AT_LABEL') }}
            </span>
            <input
              v-model="endsAt"
              type="datetime-local"
              :min="endsAtMin"
              class="field-input"
            />
          </label>
        </div>
        <p v-if="windowError" class="m-0 mt-2 text-sm text-red-600">
          {{ windowError }}
        </p>

        <button
          type="button"
          class="flex items-center gap-1 mt-3 text-sm text-woot-600 dark:text-woot-400"
          @click="showSendOptions = !showSendOptions"
        >
          <fluent-icon
            :icon="showSendOptions ? 'chevron-down' : 'chevron-right'"
            size="14"
          />
          {{ $t('BULK_TRACKING_ASSIGN.MODAL.SEND_OPTIONS') }}
        </button>
        <div
          v-if="showSendOptions"
          class="grid grid-cols-1 md:grid-cols-3 gap-x-4 gap-y-3 mt-2"
        >
          <label class="block">
            <span class="field-label">
              {{ $t('BULK_TRACKING_ASSIGN.MODAL.ENTRY_DELAY_LABEL') }}
            </span>
            <input
              v-model.number="entryDelayMinutes"
              type="number"
              min="0"
              step="5"
              class="field-input"
            />
          </label>
          <label v-if="isContinuous" class="block">
            <span class="field-label">
              {{ $t('BULK_TRACKING_ASSIGN.MODAL.DAILY_CAP_LABEL') }}
            </span>
            <input
              v-model.number="dailyCap"
              type="number"
              min="1"
              :placeholder="
                $t('BULK_TRACKING_ASSIGN.MODAL.DAILY_CAP_PLACEHOLDER')
              "
              class="field-input"
            />
          </label>
          <!-- Mismo molde que los otros campos (título + caja del alto de un input)
               para que las tres columnas queden alineadas. -->
          <div class="block">
            <span class="field-label">
              {{ $t('BULK_TRACKING_ASSIGN.MODAL.WORKING_HOURS_LABEL') }}
            </span>
            <label
              class="field-input flex items-center gap-2 !h-10 !py-0 cursor-pointer"
            >
              <input
                v-model="respectWorkingHours"
                type="checkbox"
                class="m-0"
              />
              {{ $t('BULK_TRACKING_ASSIGN.MODAL.RESPECT_WORKING_HOURS') }}
            </label>
          </div>
        </div>
      </section>

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

      <!-- Lo que va a pasar, junto al botón -->
      <div
        class="flex items-center justify-between gap-3 mt-5 pt-4 border-t border-slate-100 dark:border-slate-700"
      >
        <span class="text-sm text-slate-600 dark:text-slate-300">
          {{ summaryText }}
        </span>
        <woot-button
          :is-loading="isSubmitting"
          :disabled="!canConfirm"
          @click="onConfirm"
        >
          {{
            $t(
              isContinuous
                ? 'BULK_TRACKING_ASSIGN.MODAL.CREATE'
                : 'BULK_TRACKING_ASSIGN.MODAL.LAUNCH'
            )
          }}
        </woot-button>
      </div>
    </div>

    <!-- Revisar audiencia (solo segmento o etiqueta: la continua no tiene lista) -->
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

<style scoped>
.section-title {
  @apply m-0 mb-3 text-base font-semibold text-slate-800 dark:text-slate-100;
}

.field-label {
  @apply text-sm font-semibold text-slate-700 dark:text-slate-300;
}

.field-input {
  @apply w-full mt-1 bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 border border-slate-200 dark:border-slate-600 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-1 focus:ring-woot-200 focus:border-woot-200;
}

.field-input:disabled {
  @apply bg-slate-50 dark:bg-slate-800 text-slate-400 dark:text-slate-500 cursor-not-allowed;
}

.audience-card {
  @apply flex flex-col gap-2 m-0 p-3 rounded-md border border-slate-200 dark:border-slate-600 cursor-pointer;
}

/* El selector gris de una ficha no elegida deja pasar el clic a la ficha: así un clic
   ahí la elige (un <select> deshabilitado se traga el clic). */
.audience-card select:disabled {
  @apply pointer-events-none;
}

.audience-card--active {
  @apply border-woot-300 dark:border-woot-600 bg-woot-25 dark:bg-woot-900/20;
}

.audience-radio {
  @apply flex items-center gap-2 text-sm font-semibold text-slate-700 dark:text-slate-300;
}

.audience-radio input {
  @apply m-0;
}
</style>
