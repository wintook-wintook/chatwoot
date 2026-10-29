<!--
  prospeccion P2 (docs/prospeccion_estudio.md §10.9) — modal «Entrega de interesados».
  A qué tablero/columna de Oportunidades entra el prospecto que dice que le interesa,
  en cuántas horas hábiles hay que atenderlo y cuándo se avisa a los administradores.
  Se guarda en cualquier estado de la campaña (PATCH :id/handoff_settings).
  Molde nativo de modal (settings/agents/AddAgent.vue); el padre lo envuelve en <woot-modal>.
-->
<script>
import { useAlert } from 'dashboard/composables';
import WootSubmitButton from 'dashboard/components/buttons/FormSubmitButton.vue';
import TrackingCampaignsAPI from 'dashboard/api/trackingCampaigns';
import KanbanTypeProcessAPI from 'dashboard/api/kanbanTypeProcesses';

export default {
  name: 'CampaignHandoffSettings',
  components: { WootSubmitButton },
  props: {
    campaign: { type: Object, required: true },
  },
  emits: ['saved', 'close'],
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
      if (!this.ready) return;
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
        this.$emit('close');
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
  <div class="flex flex-col h-auto">
    <woot-modal-header
      :header-title="$t('TRACKING_CAMPAIGN_DETAIL.HANDOFF_SETTINGS.TITLE')"
      :header-content="$t('TRACKING_CAMPAIGN_DETAIL.HANDOFF_SETTINGS.DESC')"
    />
    <form class="flex flex-col items-start w-full" @submit.prevent="save">
      <ol
        class="w-full mb-4 ml-4 space-y-1 text-sm list-decimal text-slate-600 dark:text-slate-300"
      >
        <li>{{ $t('TRACKING_CAMPAIGN_DETAIL.HANDOFF_SETTINGS.HOW_1') }}</li>
        <li>{{ $t('TRACKING_CAMPAIGN_DETAIL.HANDOFF_SETTINGS.HOW_2') }}</li>
        <li>{{ $t('TRACKING_CAMPAIGN_DETAIL.HANDOFF_SETTINGS.HOW_3') }}</li>
        <li>{{ $t('TRACKING_CAMPAIGN_DETAIL.HANDOFF_SETTINGS.HOW_4') }}</li>
        <li>{{ $t('TRACKING_CAMPAIGN_DETAIL.HANDOFF_SETTINGS.HOW_5') }}</li>
      </ol>

      <div class="grid w-full grid-cols-2 gap-x-4">
        <div class="w-full">
          <label>
            {{ $t('TRACKING_CAMPAIGN_DETAIL.HANDOFF_SETTINGS.BOARD') }}
            <select v-model="boardId">
              <option value="">
                {{ $t('TRACKING_CAMPAIGN_DETAIL.HANDOFF_SETTINGS.NO_BOARD') }}
              </option>
              <option v-for="b in boards" :key="b.id" :value="b.id">
                {{ b.process_name }}
              </option>
            </select>
          </label>
        </div>
        <div class="w-full">
          <label>
            {{ $t('TRACKING_CAMPAIGN_DETAIL.HANDOFF_SETTINGS.COLUMN') }}
            <select v-model="columnId" :disabled="!boardId">
              <option value="" disabled>
                {{
                  $t(
                    'TRACKING_CAMPAIGN_DETAIL.HANDOFF_SETTINGS.COLUMN_PLACEHOLDER'
                  )
                }}
              </option>
              <option v-for="c in columns" :key="c.id" :value="c.id">
                {{ c.type_process_name }}
              </option>
            </select>
          </label>
        </div>
        <div class="w-full">
          <label>
            {{ $t('TRACKING_CAMPAIGN_DETAIL.HANDOFF_SETTINGS.DUE') }}
            <input
              v-model.number="dueHours"
              type="number"
              min="1"
              max="720"
              :placeholder="
                $t('TRACKING_CAMPAIGN_DETAIL.HANDOFF_SETTINGS.NO_DUE')
              "
            />
          </label>
        </div>
        <div class="w-full">
          <label>
            {{ $t('TRACKING_CAMPAIGN_DETAIL.HANDOFF_SETTINGS.ESCALATE') }}
            <input
              v-model.number="escalateHours"
              type="number"
              min="1"
              max="720"
              :placeholder="
                $t('TRACKING_CAMPAIGN_DETAIL.HANDOFF_SETTINGS.NO_ESCALATE')
              "
            />
          </label>
        </div>
      </div>

      <div class="flex flex-row justify-end w-full gap-2 px-0 py-2">
        <div class="w-full">
          <WootSubmitButton
            :disabled="!ready || saving"
            :button-text="$t('TRACKING_CAMPAIGN_DETAIL.HANDOFF_SETTINGS.SAVE')"
            :loading="saving"
          />
          <button class="button clear" @click.prevent="$emit('close')">
            {{ $t('TRACKING_CAMPAIGN_DETAIL.HANDOFF_SETTINGS.CANCEL') }}
          </button>
        </div>
      </div>
    </form>
  </div>
</template>
