<!--
  prospeccion P2 (docs/prospeccion_estudio.md §10.9) — entrega de interesados.
  A qué tablero/columna de Oportunidades entra el prospecto que dice que le interesa,
  en cuántas horas hábiles hay que atenderlo y cuándo se avisa a los administradores.
  Se guarda en cualquier estado de la campaña (PATCH :id/handoff_settings).
-->
<script>
import { useAlert } from 'dashboard/composables';
import TrackingCampaignsAPI from 'dashboard/api/trackingCampaigns';
import KanbanTypeProcessAPI from 'dashboard/api/kanbanTypeProcesses';

export default {
  name: 'CampaignHandoffSettings',
  props: {
    campaign: { type: Object, required: true },
  },
  emits: ['saved'],
  data() {
    return {
      boards: [],
      boardId: this.campaign.handoff_board_id || '',
      columnId: this.campaign.handoff_column_id || '',
      dueHours: this.campaign.handoff_due_hours || '',
      escalateHours: this.campaign.handoff_escalate_hours || '',
      saving: false,
    };
  },
  computed: {
    columns() {
      const board = this.boards.find(b => b.id === Number(this.boardId));
      const columns = board ? board.kanban_processes || [] : [];
      return [...columns].sort((a, b) => a.position - b.position);
    },
    // Sin tablero: entrega solo con el botón. Con tablero hace falta la columna.
    ready() {
      return !this.boardId || !!this.columnId;
    },
  },
  watch: {
    boardId(value, old) {
      if (old !== '' && value !== old) this.columnId = '';
    },
  },
  async mounted() {
    try {
      const { data } = await KanbanTypeProcessAPI.get();
      this.boards = data;
    } catch {
      this.boards = [];
    }
  },
  methods: {
    async save() {
      this.saving = true;
      try {
        const { data } = await TrackingCampaignsAPI.updateHandoffSettings(
          this.campaign.id,
          {
            handoff_board_id: this.boardId || null,
            handoff_column_id: this.boardId ? this.columnId || null : null,
            handoff_due_hours: this.dueHours || null,
            handoff_escalate_hours: this.escalateHours || null,
          }
        );
        this.$emit('saved', data);
        useAlert(this.$t('TRACKING_CAMPAIGN_DETAIL.HANDOFF_SETTINGS.SAVED'));
      } catch (error) {
        const message = error.response && error.response.data;
        useAlert(
          (message && message.error) ||
            this.$t('TRACKING_CAMPAIGN_DETAIL.HANDOFF_SETTINGS.ERROR')
        );
      } finally {
        this.saving = false;
      }
    },
  },
};
</script>

<template>
  <div
    class="p-3 mb-3 rounded-lg bg-white dark:bg-slate-800 border border-slate-75 dark:border-slate-700 shadow-sm"
  >
    <span class="text-sm font-medium text-slate-700 dark:text-slate-200">
      {{ $t('TRACKING_CAMPAIGN_DETAIL.HANDOFF_SETTINGS.TITLE') }}
    </span>
    <ol
      class="mt-2 mb-3 ml-4 space-y-0.5 text-xs list-decimal text-slate-500 dark:text-slate-400"
    >
      <li>{{ $t('TRACKING_CAMPAIGN_DETAIL.HANDOFF_SETTINGS.HOW_1') }}</li>
      <li>{{ $t('TRACKING_CAMPAIGN_DETAIL.HANDOFF_SETTINGS.HOW_2') }}</li>
      <li>{{ $t('TRACKING_CAMPAIGN_DETAIL.HANDOFF_SETTINGS.HOW_3') }}</li>
      <li>{{ $t('TRACKING_CAMPAIGN_DETAIL.HANDOFF_SETTINGS.HOW_4') }}</li>
    </ol>
    <div class="grid grid-cols-1 gap-3 md:grid-cols-4">
      <label class="block">
        <span class="field-label">
          {{ $t('TRACKING_CAMPAIGN_DETAIL.HANDOFF_SETTINGS.BOARD') }}
        </span>
        <select v-model="boardId" class="field-input">
          <option value="">
            {{ $t('TRACKING_CAMPAIGN_DETAIL.HANDOFF_SETTINGS.NO_BOARD') }}
          </option>
          <option v-for="b in boards" :key="b.id" :value="b.id">
            {{ b.process_name }}
          </option>
        </select>
      </label>
      <label class="block">
        <span class="field-label">
          {{ $t('TRACKING_CAMPAIGN_DETAIL.HANDOFF_SETTINGS.COLUMN') }}
        </span>
        <select v-model="columnId" class="field-input" :disabled="!boardId">
          <option value="" disabled>
            {{
              $t('TRACKING_CAMPAIGN_DETAIL.HANDOFF_SETTINGS.COLUMN_PLACEHOLDER')
            }}
          </option>
          <option v-for="c in columns" :key="c.id" :value="c.id">
            {{ c.type_process_name }}
          </option>
        </select>
      </label>
      <label class="block">
        <span class="field-label">
          {{ $t('TRACKING_CAMPAIGN_DETAIL.HANDOFF_SETTINGS.DUE') }}
        </span>
        <input
          v-model.number="dueHours"
          type="number"
          min="1"
          max="720"
          :placeholder="$t('TRACKING_CAMPAIGN_DETAIL.HANDOFF_SETTINGS.NO_DUE')"
          class="field-input"
        />
      </label>
      <label class="block">
        <span class="field-label">
          {{ $t('TRACKING_CAMPAIGN_DETAIL.HANDOFF_SETTINGS.ESCALATE') }}
        </span>
        <input
          v-model.number="escalateHours"
          type="number"
          min="1"
          max="720"
          :placeholder="
            $t('TRACKING_CAMPAIGN_DETAIL.HANDOFF_SETTINGS.NO_ESCALATE')
          "
          class="field-input"
        />
      </label>
    </div>
    <div class="flex justify-end mt-3">
      <woot-button
        size="small"
        :is-loading="saving"
        :is-disabled="!ready"
        @click="save"
      >
        {{ $t('TRACKING_CAMPAIGN_DETAIL.HANDOFF_SETTINGS.SAVE') }}
      </woot-button>
    </div>
  </div>
</template>

<style scoped>
.field-label {
  @apply text-sm font-semibold text-slate-700 dark:text-slate-300;
}

.field-input {
  @apply w-full mt-1 bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 border border-slate-200 dark:border-slate-600 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-1 focus:ring-woot-200 focus:border-woot-200;
}

.field-input:disabled {
  @apply bg-slate-50 dark:bg-slate-800 text-slate-400 dark:text-slate-500 cursor-not-allowed;
}
</style>
