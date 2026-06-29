<!--
  @query_databases — Conexiones a ERPs (admin). CRUD de conexiones + "Probar
  conexión" + panel de consultas predefinidas por conexión. Tailwind + dark mode.
-->
<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import ErpQueriesPanel from './QueriesPanel.vue';

const emptyForm = () => ({
  name: '',
  engine: 'firebird',
  host: '',
  port: null,
  database: '',
  username: '',
  password: '',
});

export default {
  components: { ErpQueriesPanel },
  data() {
    return {
      showForm: false,
      editingId: null,
      expandedId: null,
      testingId: null,
      form: emptyForm(),
      tdsVersion: '7.0',
      tdsPlaceholder: '7.0',
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
    async remove(conn) {
      // eslint-disable-next-line no-alert
      if (
        !window.confirm(
          this.$t('ERP.CONNECTIONS.DELETE_CONFIRM', { name: conn.name })
        )
      )
        return;
      await this.$store.dispatch('externalDb/deleteConnection', conn.id);
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
      <!-- Form de conexión (alta/edición) -->
      <div
        v-if="showForm"
        class="max-w-3xl p-5 bg-white border rounded-lg dark:bg-slate-800 border-slate-100 dark:border-slate-700"
      >
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
              <option value="firebird">{{ $t('ERP.ENGINE.FIREBIRD') }}</option>
              <option value="mssql">{{ $t('ERP.ENGINE.MSSQL') }}</option>
            </select>
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

      <!-- Listado -->
      <p
        v-if="!connections.length && !showForm"
        class="text-sm text-slate-400 dark:text-slate-500"
      >
        {{ $t('ERP.CONNECTIONS.EMPTY') }}
      </p>

      <div
        v-for="conn in connections"
        :key="conn.id"
        class="max-w-3xl bg-white border rounded-lg dark:bg-slate-800 border-slate-100 dark:border-slate-700"
      >
        <div class="flex items-center justify-between gap-3 px-4 py-3">
          <div class="flex flex-col">
            <div class="flex items-center gap-2">
              <span class="font-semibold text-slate-800 dark:text-slate-100">{{
                conn.name
              }}</span>
              <span
                class="px-1.5 py-0.5 text-xs rounded bg-woot-100 text-woot-700 dark:bg-woot-700 dark:text-woot-100"
                >{{ conn.engine }}</span
              >
            </div>
            <span class="font-mono text-xs text-slate-400 dark:text-slate-500"
              >{{ conn.host }}:{{ conn.port }}</span
            >
          </div>
          <div class="flex items-center gap-1">
            <woot-button
              size="small"
              variant="smooth"
              color-scheme="success"
              :is-loading="testingId === conn.id"
              @click="test(conn)"
            >
              {{ $t('ERP.CONNECTIONS.TEST') }}
            </woot-button>
            <woot-button
              size="small"
              variant="clear"
              icon="code"
              @click="toggleQueries(conn)"
            >
              {{ $t('ERP.CONNECTIONS.QUERIES') }} ({{ conn.queries_count }})
            </woot-button>
            <woot-button
              size="small"
              variant="clear"
              icon="edit"
              @click="openEdit(conn)"
            />
            <woot-button
              size="small"
              variant="clear"
              color-scheme="alert"
              icon="delete"
              @click="remove(conn)"
            />
          </div>
        </div>

        <!-- Panel de consultas -->
        <ErpQueriesPanel v-if="expandedId === conn.id" :connection="conn" />
      </div>
    </div>
  </div>
</template>
