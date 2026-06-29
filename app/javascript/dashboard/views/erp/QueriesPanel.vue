<!--
  @query_databases — panel de consultas predefinidas de una conexión (admin).
  Embebido en Connections.vue. params_schema se edita como JSON (pragmático para v1).
-->
<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';

const emptyForm = () => ({
  name: '',
  description: '',
  sql_template: '',
  row_limit: 200,
  result_format: 'table',
  ai_enabled: false,
});

export default {
  props: {
    connection: { type: Object, required: true },
  },
  data() {
    return {
      showForm: false,
      editingId: null,
      form: emptyForm(),
      paramsJson: '[]',
      resultFormats: ['table', 'summary', 'template'],
      nameExample: 'facturas_vencidas',
      paramsExample:
        '[{"key":"rfc","label":"RFC","type":"string","required":true}]',
    };
  },
  computed: {
    ...mapGetters({
      getQueries: 'externalDb/getQueries',
      uiFlags: 'externalDb/getUIFlags',
    }),
    queries() {
      return this.getQueries(this.connection.id);
    },
    isValid() {
      return this.form.name && this.form.sql_template;
    },
  },
  mounted() {
    this.$store.dispatch('externalDb/fetchQueries', this.connection.id);
  },
  methods: {
    openCreate() {
      this.editingId = null;
      this.form = emptyForm();
      this.paramsJson = '[]';
      this.showForm = true;
    },
    openEdit(q) {
      this.editingId = q.id;
      this.form = {
        name: q.name,
        description: q.description,
        sql_template: q.sql_template,
        row_limit: q.row_limit,
        result_format: q.result_format,
        ai_enabled: q.ai_enabled,
      };
      this.paramsJson = JSON.stringify(q.params_schema || [], null, 0);
      this.showForm = true;
    },
    closeForm() {
      this.showForm = false;
      this.editingId = null;
    },
    async save() {
      let paramsSchema;
      try {
        paramsSchema = JSON.parse(this.paramsJson || '[]');
      } catch (e) {
        useAlert('JSON de parámetros inválido');
        return;
      }
      const query = { ...this.form, params_schema: paramsSchema };
      try {
        if (this.editingId) {
          await this.$store.dispatch('externalDb/updateQuery', {
            connectionId: this.connection.id,
            id: this.editingId,
            query,
          });
        } else {
          await this.$store.dispatch('externalDb/createQuery', {
            connectionId: this.connection.id,
            query,
          });
        }
        this.closeForm();
      } catch (e) {
        useAlert(e.response?.data?.error || e.message);
      }
    },
    async remove(q) {
      // eslint-disable-next-line no-alert
      if (
        !window.confirm(this.$t('ERP.QUERIES.DELETE_CONFIRM', { name: q.name }))
      )
        return;
      await this.$store.dispatch('externalDb/deleteQuery', {
        connectionId: this.connection.id,
        id: q.id,
      });
    },
  },
};
</script>

<template>
  <div
    class="px-4 py-3 border-t bg-slate-25 dark:bg-slate-900/40 border-slate-100 dark:border-slate-700"
  >
    <!-- Listado de consultas -->
    <p
      v-if="!queries.length && !showForm"
      class="text-sm text-slate-400 dark:text-slate-500"
    >
      {{ $t('ERP.QUERIES.EMPTY') }}
    </p>
    <ul v-else class="flex flex-col gap-1 mb-3">
      <li
        v-for="q in queries"
        :key="q.id"
        class="flex items-center justify-between gap-2 px-2 py-1.5 rounded hover:bg-slate-50 dark:hover:bg-slate-800"
      >
        <div class="flex flex-col min-w-0">
          <div class="flex items-center gap-2">
            <span
              class="font-mono text-sm text-slate-700 dark:text-slate-200"
              >{{ q.name }}</span
            >
            <span
              v-if="q.ai_enabled"
              class="px-1 py-0.5 text-[10px] rounded bg-green-100 text-green-700 dark:bg-green-800 dark:text-green-100"
              >{{ 'IA' }}</span
            >
          </div>
          <span class="text-xs truncate text-slate-400 dark:text-slate-500">{{
            q.description
          }}</span>
        </div>
        <div class="flex items-center gap-1 shrink-0">
          <woot-button
            size="tiny"
            variant="clear"
            icon="edit"
            @click="openEdit(q)"
          />
          <woot-button
            size="tiny"
            variant="clear"
            color-scheme="alert"
            icon="delete"
            @click="remove(q)"
          />
        </div>
      </li>
    </ul>

    <!-- Form de consulta -->
    <div
      v-if="showForm"
      class="flex flex-col gap-3 p-4 mb-3 bg-white border rounded-lg dark:bg-slate-800 border-slate-100 dark:border-slate-700"
    >
      <div class="grid grid-cols-1 gap-3 md:grid-cols-2">
        <label class="flex flex-col gap-1">
          <span
            class="text-xs font-medium text-slate-600 dark:text-slate-300"
            >{{ $t('ERP.QUERIES.NAME') }}</span
          >
          <input
            v-model="form.name"
            type="text"
            class="w-full font-mono"
            :placeholder="nameExample"
          />
        </label>
        <label class="flex flex-col gap-1">
          <span
            class="text-xs font-medium text-slate-600 dark:text-slate-300"
            >{{ $t('ERP.QUERIES.DESCRIPTION') }}</span
          >
          <input v-model="form.description" type="text" class="w-full" />
        </label>
      </div>
      <label class="flex flex-col gap-1">
        <span class="text-xs font-medium text-slate-600 dark:text-slate-300">{{
          $t('ERP.QUERIES.SQL')
        }}</span>
        <textarea
          v-model="form.sql_template"
          rows="4"
          class="w-full font-mono text-sm"
          placeholder="SELECT ... WHERE RFC = :rfc"
        />
      </label>
      <label class="flex flex-col gap-1">
        <span class="text-xs font-medium text-slate-600 dark:text-slate-300"
          >{{ $t('ERP.QUERIES.PARAMS') }} {{ '(JSON)' }}</span
        >
        <textarea
          v-model="paramsJson"
          rows="3"
          class="w-full font-mono text-xs"
          :placeholder="paramsExample"
        />
      </label>
      <div class="grid grid-cols-1 gap-3 md:grid-cols-3">
        <label class="flex flex-col gap-1">
          <span
            class="text-xs font-medium text-slate-600 dark:text-slate-300"
            >{{ $t('ERP.QUERIES.ROW_LIMIT') }}</span
          >
          <input v-model.number="form.row_limit" type="number" class="w-full" />
        </label>
        <label class="flex flex-col gap-1">
          <span
            class="text-xs font-medium text-slate-600 dark:text-slate-300"
            >{{ $t('ERP.QUERIES.RESULT_FORMAT') }}</span
          >
          <select v-model="form.result_format" class="w-full">
            <option v-for="f in resultFormats" :key="f" :value="f">
              {{ f }}
            </option>
          </select>
        </label>
        <label class="flex items-end gap-2 pb-1.5">
          <input v-model="form.ai_enabled" type="checkbox" />
          <span class="text-xs text-slate-600 dark:text-slate-300">{{
            $t('ERP.QUERIES.AI_ENABLED')
          }}</span>
        </label>
      </div>
      <div class="flex gap-2">
        <woot-button
          size="small"
          :is-loading="uiFlags.savingQuery"
          :disabled="!isValid"
          @click="save"
        >
          {{ $t('ERP.QUERIES.SAVE') }}
        </woot-button>
        <woot-button
          size="small"
          variant="clear"
          color-scheme="secondary"
          @click="closeForm"
        >
          {{ $t('ERP.CONNECTIONS.FORM.CANCEL') }}
        </woot-button>
      </div>
    </div>

    <woot-button
      v-if="!showForm"
      size="small"
      variant="smooth"
      icon="add"
      @click="openCreate"
    >
      {{ $t('ERP.QUERIES.NEW') }}
    </woot-button>
  </div>
</template>
