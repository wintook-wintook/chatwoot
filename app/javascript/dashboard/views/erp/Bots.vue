<!--
  @query_databases — Bots cobradores (admin). Modo A (recordatorio programado) +
  toggle Modo B (consulta IA por chat). Tailwind + dark mode.
-->
<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import ErpBotCard from './BotCard.vue';

const emptyForm = () => ({
  name: '',
  external_db_connection_id: null,
  external_db_query_id: null,
  inbox_id: null,
  message_template: '',
  phone_column: 'TELEFONO',
  run_hour: 8,
  mode_b_enabled: false,
  active: true,
});

export default {
  components: { ErpBotCard },
  data() {
    return {
      showForm: false,
      editingId: null,
      form: emptyForm(),
      previewMessages: [],
      deletePopup: false,
      deleteTarget: null,
    };
  },
  computed: {
    ...mapGetters({
      bots: 'externalDb/getBots',
      connections: 'externalDb/getConnections',
      getQueries: 'externalDb/getQueries',
      uiFlags: 'externalDb/getUIFlags',
      inboxes: 'inboxes/getInboxes',
    }),
    connectionQueries() {
      return this.form.external_db_connection_id
        ? this.getQueries(this.form.external_db_connection_id)
        : [];
    },
    isValid() {
      return this.form.name && this.form.external_db_connection_id;
    },
    connectionsById() {
      return Object.fromEntries(this.connections.map(c => [c.id, c.name]));
    },
    inboxesById() {
      return Object.fromEntries(this.inboxes.map(i => [i.id, i.name]));
    },
    modalTitle() {
      return this.editingId
        ? this.$t('ERP.BOTS.EDIT_TITLE')
        : this.$t('ERP.BOTS.NEW');
    },
  },
  mounted() {
    this.$store.dispatch('externalDb/fetchBots');
    this.$store.dispatch('externalDb/fetchConnections');
    this.$store.dispatch('inboxes/get');
  },
  methods: {
    openCreate() {
      this.editingId = null;
      this.form = emptyForm();
      this.previewMessages = [];
      this.showForm = true;
    },
    openEdit(bot) {
      this.editingId = bot.id;
      this.form = { ...bot };
      this.previewMessages = [];
      this.showForm = true;
      if (bot.external_db_connection_id) this.onConnectionChange();
    },
    onConnectionChange() {
      if (this.form.external_db_connection_id) {
        this.$store.dispatch(
          'externalDb/fetchQueries',
          this.form.external_db_connection_id
        );
      }
    },
    closeForm() {
      this.showForm = false;
      this.editingId = null;
      this.previewMessages = [];
    },
    async save() {
      try {
        if (this.editingId) {
          await this.$store.dispatch('externalDb/updateBot', {
            id: this.editingId,
            ...this.form,
          });
        } else {
          const bot = await this.$store.dispatch(
            'externalDb/createBot',
            this.form
          );
          this.editingId = bot.id;
        }
        useAlert(this.$t('ERP.BOTS.SAVE'));
      } catch (e) {
        useAlert(e.response?.data?.error || e.message);
      }
    },
    async preview() {
      this.previewMessages = [];
      try {
        const res = await this.$store.dispatch(
          'externalDb/previewBot',
          this.editingId
        );
        this.previewMessages = res.messages || [];
      } catch (e) {
        useAlert(e.response?.data?.error || e.message);
      }
    },
    remove(bot) {
      this.deleteTarget = bot;
      this.deletePopup = true;
    },
    closeDeletePopup() {
      this.deletePopup = false;
      this.deleteTarget = null;
    },
    async confirmRemove() {
      const id = this.deleteTarget?.id;
      this.closeDeletePopup();
      if (id) await this.$store.dispatch('externalDb/deleteBot', id);
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col flex-1 w-full h-full overflow-hidden bg-slate-25 dark:bg-slate-900"
  >
    <div
      class="flex items-center justify-between flex-shrink-0 px-6 py-4 bg-white border-b dark:bg-slate-900 border-slate-50 dark:border-slate-800/50"
    >
      <div class="flex flex-col">
        <h1 class="m-0 text-xl font-bold text-slate-800 dark:text-slate-100">
          {{ $t('ERP.BOTS.TITLE') }}
        </h1>
        <span class="text-sm text-slate-400 dark:text-slate-500">{{
          $t('ERP.BOTS.SUBTITLE')
        }}</span>
      </div>
      <woot-button icon="add" @click="openCreate">
        {{ $t('ERP.BOTS.NEW') }}
      </woot-button>
    </div>

    <div class="flex flex-col flex-1 gap-4 p-6 overflow-y-auto">
      <!-- Modal de bot (alta/edición) -->
      <woot-modal :show="showForm" :on-close="closeForm" size="medium">
        <div class="flex flex-col overflow-auto">
          <woot-modal-header
            :header-title="modalTitle"
            :header-content="$t('ERP.BOTS.MODAL_DESC')"
          />
          <div class="flex flex-col gap-4 px-8 pt-4 pb-8">
            <div class="grid grid-cols-1 gap-4 md:grid-cols-2">
              <label class="flex flex-col gap-1">
                <span
                  class="text-sm font-medium text-slate-700 dark:text-slate-200"
                  >{{ $t('ERP.BOTS.NAME') }}</span
                >
                <input v-model="form.name" type="text" class="w-full" />
              </label>
              <label class="flex flex-col gap-1">
                <span
                  class="text-sm font-medium text-slate-700 dark:text-slate-200"
                  >{{ $t('ERP.BOTS.CONNECTION') }}</span
                >
                <select
                  v-model="form.external_db_connection_id"
                  class="w-full"
                  @change="onConnectionChange"
                >
                  <option v-for="c in connections" :key="c.id" :value="c.id">
                    {{ c.name }}
                  </option>
                </select>
              </label>
              <label class="flex flex-col gap-1">
                <span
                  class="text-sm font-medium text-slate-700 dark:text-slate-200"
                  >{{ $t('ERP.BOTS.QUERY') }}</span
                >
                <select v-model="form.external_db_query_id" class="w-full">
                  <option :value="null">{{ $t('ERP.BOTS.NONE') }}</option>
                  <option
                    v-for="q in connectionQueries"
                    :key="q.id"
                    :value="q.id"
                  >
                    {{ q.name }}
                  </option>
                </select>
              </label>
              <label class="flex flex-col gap-1">
                <span
                  class="text-sm font-medium text-slate-700 dark:text-slate-200"
                  >{{ $t('ERP.BOTS.INBOX') }}</span
                >
                <select v-model="form.inbox_id" class="w-full">
                  <option :value="null">{{ $t('ERP.BOTS.NONE') }}</option>
                  <option v-for="i in inboxes" :key="i.id" :value="i.id">
                    {{ i.name }}
                  </option>
                </select>
              </label>
              <label class="flex flex-col gap-1">
                <span
                  class="text-sm font-medium text-slate-700 dark:text-slate-200"
                  >{{ $t('ERP.BOTS.PHONE_COLUMN') }}</span
                >
                <input
                  v-model="form.phone_column"
                  type="text"
                  class="w-full font-mono"
                />
              </label>
              <label class="flex flex-col gap-1">
                <span
                  class="text-sm font-medium text-slate-700 dark:text-slate-200"
                  >{{ $t('ERP.BOTS.RUN_HOUR') }}</span
                >
                <input
                  v-model.number="form.run_hour"
                  type="number"
                  min="0"
                  max="23"
                  class="w-full"
                />
              </label>
              <label class="flex flex-col gap-1 md:col-span-2">
                <span
                  class="text-sm font-medium text-slate-700 dark:text-slate-200"
                  >{{ $t('ERP.BOTS.TEMPLATE') }}</span
                >
                <textarea
                  v-model="form.message_template"
                  rows="3"
                  class="w-full font-mono text-sm"
                />
              </label>
            </div>

            <div class="flex flex-col gap-2 mt-4">
              <label class="flex items-center gap-2">
                <input v-model="form.mode_b_enabled" type="checkbox" />
                <span class="text-sm text-slate-700 dark:text-slate-200">{{
                  $t('ERP.BOTS.MODE_B')
                }}</span>
              </label>
              <label class="flex items-center gap-2">
                <input v-model="form.active" type="checkbox" />
                <span class="text-sm text-slate-700 dark:text-slate-200">{{
                  $t('ERP.BOTS.ACTIVE')
                }}</span>
              </label>
            </div>

            <div class="flex gap-2 mt-4">
              <woot-button
                :is-loading="uiFlags.savingBot"
                :disabled="!isValid"
                @click="save"
              >
                {{ $t('ERP.BOTS.SAVE') }}
              </woot-button>
              <woot-button
                v-if="editingId"
                variant="smooth"
                icon="play-circle"
                @click="preview"
              >
                {{ $t('ERP.BOTS.PREVIEW') }}
              </woot-button>
              <woot-button
                variant="clear"
                color-scheme="secondary"
                @click="closeForm"
              >
                {{ $t('ERP.CONNECTIONS.FORM.CANCEL') }}
              </woot-button>
            </div>

            <!-- Preview dry-run -->
            <div
              v-if="previewMessages.length"
              class="p-3 mt-4 text-sm border rounded-lg bg-slate-50 dark:bg-slate-900/40 border-slate-100 dark:border-slate-700"
            >
              <p
                class="m-0 mb-2 text-xs font-semibold uppercase text-slate-500 dark:text-slate-400"
              >
                {{ $t('ERP.BOTS.PREVIEW_TITLE') }}
              </p>
              <p
                v-for="(m, i) in previewMessages"
                :key="i"
                class="m-0 mb-1 text-slate-700 dark:text-slate-200"
              >
                <span class="font-mono text-xs text-slate-400"
                  >({{ m.phone }})</span
                >
                {{ m.message }}
              </p>
            </div>
          </div>
        </div>
      </woot-modal>

      <p
        v-if="!bots.length && !showForm"
        class="text-sm text-slate-400 dark:text-slate-500"
      >
        {{ $t('ERP.BOTS.EMPTY') }}
      </p>

      <!-- Grilla de tarjetas (mismo estilo que Fuentes) -->
      <div
        v-if="bots.length"
        class="grid gap-4 grid-cols-[repeat(auto-fill,minmax(280px,1fr))]"
      >
        <ErpBotCard
          v-for="bot in bots"
          :key="bot.id"
          :bot="bot"
          :connection-name="
            connectionsById[bot.external_db_connection_id] || ''
          "
          :inbox-name="inboxesById[bot.inbox_id] || ''"
          @edit="openEdit"
          @delete="remove"
        />
      </div>

      <woot-delete-modal
        :show.sync="deletePopup"
        :on-close="closeDeletePopup"
        :on-confirm="confirmRemove"
        :title="$t('ERP.BOTS.DELETE_TITLE')"
        :message="
          $t('ERP.BOTS.DELETE_CONFIRM', {
            name: deleteTarget && deleteTarget.name,
          })
        "
        :confirm-text="$t('ERP.COMMON.DELETE')"
        :reject-text="$t('ERP.COMMON.CANCEL')"
      />
    </div>
  </div>
</template>
