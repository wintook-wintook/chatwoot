<!--
  @query_databases — Conexiones a ERPs (admin). CRUD de conexiones + "Probar
  conexión" + panel de consultas predefinidas por conexión. Tailwind + dark mode.
-->
<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import ErpQueriesPanel from './QueriesPanel.vue';
import ErpConnectionCard from './ConnectionCard.vue';

const emptyForm = () => ({
  name: '',
  engine: 'firebird',
  erp_type: 'generic',
  company_suffix: '',
  host: '',
  port: null,
  database: '',
  username: '',
  password: '',
});

export default {
  components: { ErpQueriesPanel, ErpConnectionCard },
  data() {
    return {
      showForm: false,
      editingId: null,
      expandedId: null,
      testingId: null,
      form: emptyForm(),
      tdsVersion: '7.0',
      tdsPlaceholder: '7.0',
      seedingId: null,
      erpTypes: ['generic', 'sae', 'microsip', 'contpaq'],
      deletePopup: false,
      deleteTarget: null,
    };
  },
  computed: {
    ...mapGetters({
      connections: 'externalDb/getConnections',
      uiFlags: 'externalDb/getUIFlags',
    }),
    isFormValid() {
      return (
        this.form.name && this.form.host && this.form.port && this.form.database
      );
    },
    expandedConnection() {
      return this.connections.find(c => c.id === this.expandedId) || null;
    },
    modalTitle() {
      return this.editingId
        ? this.$t('ERP.CONNECTIONS.FORM.TITLE_EDIT')
        : this.$t('ERP.CONNECTIONS.FORM.TITLE_NEW');
    },
  },
  mounted() {
    this.$store.dispatch('externalDb/fetchConnections');
  },
  methods: {
    openCreate() {
      this.editingId = null;
      this.form = emptyForm();
      this.tdsVersion = '7.0';
      this.showForm = true;
    },
    openEdit(conn) {
      this.editingId = conn.id;
      this.form = {
        name: conn.name,
        engine: conn.engine,
        erp_type: conn.erp_type || 'generic',
        company_suffix: conn.company_suffix || '',
        host: conn.host,
        port: conn.port,
        database: conn.database,
        username: conn.username,
        password: '',
      };
      this.tdsVersion = (conn.options && conn.options.tds_version) || '7.0';
      this.showForm = true;
    },
    closeForm() {
      this.showForm = false;
      this.editingId = null;
    },
    buildPayload() {
      const payload = { ...this.form };
      if (this.editingId && !payload.password) delete payload.password;
      payload.options =
        this.form.engine === 'mssql' ? { tds_version: this.tdsVersion } : {};
      return payload;
    },
    async save() {
      try {
        const payload = this.buildPayload();
        if (this.editingId) {
          await this.$store.dispatch('externalDb/updateConnection', {
            id: this.editingId,
            ...payload,
          });
        } else {
          await this.$store.dispatch('externalDb/createConnection', payload);
        }
        this.closeForm();
        useAlert(this.$t('ERP.CONNECTIONS.FORM.SAVE'));
      } catch (e) {
        useAlert(e.response?.data?.error || e.message);
      }
    },
    async seed(conn) {
      this.seedingId = conn.id;
      try {
        const res = await this.$store.dispatch(
          'externalDb/seedQueries',
          conn.id
        );
        useAlert(
          res.count
            ? this.$t('ERP.CONNECTIONS.SEED_OK', { count: res.count })
            : this.$t('ERP.CONNECTIONS.SEED_NONE')
        );
        await this.$store.dispatch('externalDb/fetchConnections');
        this.$store.dispatch('externalDb/fetchQueries', conn.id);
      } catch (e) {
        useAlert(e.response?.data?.error || e.message);
      } finally {
        this.seedingId = null;
      }
    },
    async test(conn) {
      this.testingId = conn.id;
      try {
        const res = await this.$store.dispatch(
          'externalDb/testConnection',
          conn.id
        );
        if (res.ok)
          useAlert(this.$t('ERP.CONNECTIONS.TEST_OK', { info: res.info }));
        else
          useAlert(this.$t('ERP.CONNECTIONS.TEST_FAIL', { error: res.error }));
      } finally {
        this.testingId = null;
      }
    },
    toggleQueries(conn) {
      this.expandedId = this.expandedId === conn.id ? null : conn.id;
    },
    remove(conn) {
      this.deleteTarget = conn;
      this.deletePopup = true;
    },
    closeDeletePopup() {
      this.deletePopup = false;
      this.deleteTarget = null;
    },
    async confirmRemove() {
      const id = this.deleteTarget?.id;
      this.closeDeletePopup();
      if (id) await this.$store.dispatch('externalDb/deleteConnection', id);
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col flex-1 w-full h-full overflow-hidden bg-slate-25 dark:bg-slate-900"
  >
    <!-- Header -->
    <div
      class="flex items-center justify-between flex-shrink-0 px-6 py-4 bg-white border-b dark:bg-slate-900 border-slate-50 dark:border-slate-800/50"
    >
      <div class="flex flex-col">
        <h1 class="m-0 text-xl font-bold text-slate-800 dark:text-slate-100">
          {{ $t('ERP.CONNECTIONS.TITLE') }}
        </h1>
        <span class="text-sm text-slate-400 dark:text-slate-500">{{
          $t('ERP.CONNECTIONS.SUBTITLE')
        }}</span>
      </div>
      <woot-button icon="add" @click="openCreate">
        {{ $t('ERP.CONNECTIONS.NEW') }}
      </woot-button>
    </div>

    <div class="flex flex-col flex-1 gap-4 p-6 overflow-y-auto">
      <!-- Modal de conexión (alta/edición) -->
      <woot-modal :show="showForm" :on-close="closeForm">
        <div class="flex flex-col overflow-auto">
          <woot-modal-header
            :header-title="modalTitle"
            :header-content="$t('ERP.CONNECTIONS.FORM.MODAL_DESC')"
          />
          <div class="flex flex-col gap-4 px-8 pt-4 pb-8">
            <div class="grid grid-cols-1 gap-4 md:grid-cols-2">
              <label class="flex flex-col gap-1">
                <span
                  class="text-sm font-medium text-slate-700 dark:text-slate-200"
                  >{{ $t('ERP.CONNECTIONS.FORM.NAME') }}</span
                >
                <input v-model="form.name" type="text" class="w-full" />
              </label>
              <label class="flex flex-col gap-1">
                <span
                  class="text-sm font-medium text-slate-700 dark:text-slate-200"
                  >{{ $t('ERP.CONNECTIONS.FORM.ENGINE') }}</span
                >
                <select v-model="form.engine" class="w-full">
                  <option value="firebird">
                    {{ $t('ERP.ENGINE.FIREBIRD') }}
                  </option>
                  <option value="mssql">{{ $t('ERP.ENGINE.MSSQL') }}</option>
                </select>
              </label>
              <label class="flex flex-col gap-1">
                <span
                  class="text-sm font-medium text-slate-700 dark:text-slate-200"
                  >{{ $t('ERP.CONNECTIONS.FORM.ERP_TYPE') }}</span
                >
                <select v-model="form.erp_type" class="w-full">
                  <option v-for="t in erpTypes" :key="t" :value="t">
                    {{ t }}
                  </option>
                </select>
              </label>
              <label v-if="form.erp_type === 'sae'" class="flex flex-col gap-1">
                <span
                  class="text-sm font-medium text-slate-700 dark:text-slate-200"
                  >{{ $t('ERP.CONNECTIONS.FORM.COMPANY_SUFFIX') }}</span
                >
                <input
                  v-model="form.company_suffix"
                  type="text"
                  class="w-full font-mono"
                />
              </label>
              <label class="flex flex-col gap-1">
                <span
                  class="text-sm font-medium text-slate-700 dark:text-slate-200"
                  >{{ $t('ERP.CONNECTIONS.FORM.HOST') }}</span
                >
                <input v-model="form.host" type="text" class="w-full" />
              </label>
              <label class="flex flex-col gap-1">
                <span
                  class="text-sm font-medium text-slate-700 dark:text-slate-200"
                  >{{ $t('ERP.CONNECTIONS.FORM.PORT') }}</span
                >
                <input
                  v-model.number="form.port"
                  type="number"
                  class="w-full"
                  :placeholder="form.engine === 'mssql' ? '6072' : '3050'"
                />
              </label>
              <label class="flex flex-col gap-1 md:col-span-2">
                <span
                  class="text-sm font-medium text-slate-700 dark:text-slate-200"
                  >{{ $t('ERP.CONNECTIONS.FORM.DATABASE') }}</span
                >
                <input
                  v-model="form.database"
                  type="text"
                  class="w-full font-mono"
                />
                <span class="text-xs text-slate-400 dark:text-slate-500">{{
                  $t('ERP.CONNECTIONS.FORM.DATABASE_HINT')
                }}</span>
              </label>
              <label class="flex flex-col gap-1">
                <span
                  class="text-sm font-medium text-slate-700 dark:text-slate-200"
                  >{{ $t('ERP.CONNECTIONS.FORM.USERNAME') }}</span
                >
                <input
                  v-model="form.username"
                  type="text"
                  class="w-full"
                  autocomplete="off"
                />
              </label>
              <label class="flex flex-col gap-1">
                <span
                  class="text-sm font-medium text-slate-700 dark:text-slate-200"
                  >{{ $t('ERP.CONNECTIONS.FORM.PASSWORD') }}</span
                >
                <input
                  v-model="form.password"
                  type="password"
                  class="w-full"
                  autocomplete="new-password"
                />
                <span
                  v-if="editingId"
                  class="text-xs text-slate-400 dark:text-slate-500"
                  >{{ $t('ERP.CONNECTIONS.FORM.PASSWORD_KEEP') }}</span
                >
              </label>
              <label v-if="form.engine === 'mssql'" class="flex flex-col gap-1">
                <span
                  class="text-sm font-medium text-slate-700 dark:text-slate-200"
                  >{{ $t('ERP.CONNECTIONS.FORM.TDS_VERSION') }}</span
                >
                <input
                  v-model="tdsVersion"
                  type="text"
                  class="w-full"
                  :placeholder="tdsPlaceholder"
                />
              </label>
            </div>
            <div class="flex gap-2 mt-4">
              <woot-button
                :is-loading="uiFlags.savingConnection"
                :disabled="!isFormValid"
                @click="save"
              >
                {{ $t('ERP.CONNECTIONS.FORM.SAVE') }}
              </woot-button>
              <woot-button
                variant="clear"
                color-scheme="secondary"
                @click="closeForm"
              >
                {{ $t('ERP.CONNECTIONS.FORM.CANCEL') }}
              </woot-button>
            </div>
          </div>
        </div>
      </woot-modal>

      <!-- Listado -->
      <p
        v-if="!connections.length && !showForm"
        class="text-sm text-slate-400 dark:text-slate-500"
      >
        {{ $t('ERP.CONNECTIONS.EMPTY') }}
      </p>

      <!-- Grilla de tarjetas (mismo estilo que Fuentes) -->
      <div
        v-if="connections.length && !expandedConnection"
        class="grid gap-4 grid-cols-[repeat(auto-fill,minmax(280px,1fr))]"
      >
        <ErpConnectionCard
          v-for="conn in connections"
          :key="conn.id"
          :connection="conn"
          :testing="testingId === conn.id"
          :seeding="seedingId === conn.id"
          :active="expandedId === conn.id"
          @test="test"
          @queries="toggleQueries"
          @seed="seed"
          @edit="openEdit"
          @delete="remove"
        />
      </div>

      <!-- Panel de consultas de la conexión seleccionada (full-width) -->
      <div
        v-if="expandedConnection"
        class="bg-white border rounded-lg dark:bg-slate-800 border-slate-100 dark:border-slate-700"
      >
        <div
          class="flex items-center gap-3 px-4 py-3 border-b border-slate-100 dark:border-slate-700"
        >
          <woot-button
            size="small"
            variant="clear"
            color-scheme="secondary"
            icon="chevron-left"
            @click="expandedId = null"
          >
            {{ $t('ERP.CONNECTIONS.BACK') }}
          </woot-button>
          <h3 class="text-sm font-semibold text-slate-700 dark:text-slate-200">
            {{ $t('ERP.QUERIES.TITLE', { name: expandedConnection.name }) }}
          </h3>
        </div>
        <ErpQueriesPanel :connection="expandedConnection" />
      </div>

      <woot-delete-modal
        :show.sync="deletePopup"
        :on-close="closeDeletePopup"
        :on-confirm="confirmRemove"
        :title="$t('ERP.CONNECTIONS.DELETE_TITLE')"
        :message="
          $t('ERP.CONNECTIONS.DELETE_CONFIRM', {
            name: deleteTarget && deleteTarget.name,
          })
        "
        :confirm-text="$t('ERP.COMMON.DELETE')"
        :reject-text="$t('ERP.COMMON.CANCEL')"
      />
    </div>
  </div>
</template>
