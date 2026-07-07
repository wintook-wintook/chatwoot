<!--
  @query_databases — panel de consultas predefinidas de una conexión (admin).
  Embebido en Connections.vue. Consultas en tabla; alta/edición en modal.
  params_schema se edita como JSON (pragmático para v1).
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
    modalTitle() {
      return this.editingId
        ? this.$t('ERP.QUERIES.EDIT_TITLE')
        : this.$t('ERP.QUERIES.NEW');
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
    <!-- Encabezado: conteo + botón nueva -->
    <div class="flex items-center justify-between mb-3">
      <span class="text-xs font-medium text-slate-400 dark:text-slate-500">
        {{ $t('ERP.QUERIES.COUNT', { n: queries.length }) }}
      </span>
      <woot-button size="small" variant="smooth" icon="add" @click="openCreate">
        {{ $t('ERP.QUERIES.NEW') }}
      </woot-button>
    </div>

    <!-- Vacío -->
    <p
      v-if="!queries.length"
      class="py-4 text-sm text-center text-slate-400 dark:text-slate-500"
    >
      {{ $t('ERP.QUERIES.EMPTY') }}
    </p>

    <!-- Tabla de consultas -->
    <div
      v-else
      class="overflow-x-auto bg-white border rounded-lg dark:bg-slate-800 border-slate-100 dark:border-slate-700"
    >
      <table class="w-full min-w-[640px] text-base">
        <thead>
          <tr
            class="border-b bg-slate-50 dark:bg-slate-900/40 border-slate-100 dark:border-slate-700"
          >
            <th
              class="px-3 py-2 font-semibold text-left text-slate-500 dark:text-slate-400"
            >
              {{ $t('ERP.QUERIES.NAME') }}
            </th>
            <th
              class="px-3 py-2 font-semibold text-left text-slate-500 dark:text-slate-400"
            >
              {{ $t('ERP.QUERIES.DESCRIPTION') }}
            </th>
            <th
              class="px-3 py-2 font-semibold text-left w-28 text-slate-500 dark:text-slate-400"
            >
              {{ $t('ERP.QUERIES.RESULT_FORMAT') }}
            </th>
            <th
              class="w-12 px-3 py-2 font-semibold text-center text-slate-500 dark:text-slate-400"
            >
              {{ $t('ERP.QUERIES.AI_COL') }}
            </th>
            <th
              class="px-3 py-2 font-semibold text-right w-16 text-slate-500 dark:text-slate-400"
            >
              {{ $t('ERP.QUERIES.ROW_LIMIT') }}
            </th>
            <th
              class="w-20 px-3 py-2 font-semibold text-right text-slate-500 dark:text-slate-400"
            >
              {{ $t('ERP.QUERIES.ACTIONS') }}
            </th>
          </tr>
        </thead>
        <tbody class="divide-y divide-slate-100 dark:divide-slate-700">
          <tr
            v-for="q in queries"
            :key="q.id"
            class="transition-colors cursor-pointer hover:bg-slate-50 dark:hover:bg-slate-900/40"
            @click="openEdit(q)"
          >
            <td
              class="px-3 py-2 font-mono text-slate-700 dark:text-slate-200 max-w-[200px] truncate"
            >
              {{ q.name }}
            </td>
            <td
              class="px-3 py-2 text-slate-500 dark:text-slate-400 max-w-[240px] truncate"
            >
              {{ q.description || '—' }}
            </td>
            <td class="px-3 py-2">
              <span
                class="inline-flex items-center px-2 py-0.5 text-sm font-medium rounded bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-200"
              >
                {{ q.result_format }}
              </span>
            </td>
            <td class="px-3 py-2 text-center">
              <span
                v-if="q.ai_enabled"
                class="inline-flex items-center px-1.5 py-0.5 text-xs font-semibold rounded bg-green-100 text-green-700 dark:bg-green-800 dark:text-green-100"
              >
                {{ $t('ERP.QUERIES.AI_COL') }}
              </span>
              <span v-else class="text-slate-300 dark:text-slate-600">—</span>
            </td>
            <td
              class="px-3 py-2 font-mono text-right text-slate-500 dark:text-slate-400"
            >
              {{ q.row_limit }}
            </td>
            <td class="px-3 py-2" @click.stop>
              <div class="flex items-center justify-end gap-1">
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
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Modal de consulta (alta/edición) -->
    <woot-modal :show="showForm" :on-close="closeForm" size="medium">
      <div class="flex flex-col overflow-auto">
        <woot-modal-header
          :header-title="modalTitle"
          :header-content="$t('ERP.QUERIES.MODAL_DESC')"
        />
        <div class="flex flex-col gap-4 px-8 pt-4 pb-8">
          <div class="grid grid-cols-1 gap-3 md:grid-cols-2">
            <label class="flex flex-col gap-1">
              <span
                class="text-sm font-medium text-slate-600 dark:text-slate-300"
              >
                {{ $t('ERP.QUERIES.NAME') }}
              </span>
              <input
                v-model="form.name"
                type="text"
                class="w-full font-mono"
                :placeholder="nameExample"
              />
            </label>
            <label class="flex flex-col gap-1">
              <span
                class="text-sm font-medium text-slate-600 dark:text-slate-300"
              >
                {{ $t('ERP.QUERIES.DESCRIPTION') }}
              </span>
              <input v-model="form.description" type="text" class="w-full" />
            </label>
          </div>
          <label class="flex flex-col gap-1">
            <span
              class="text-sm font-medium text-slate-600 dark:text-slate-300"
            >
              {{ $t('ERP.QUERIES.SQL') }}
            </span>
            <textarea
              v-model="form.sql_template"
              rows="12"
              class="w-full font-mono text-sm !h-60"
              placeholder="SELECT ... WHERE RFC = :rfc"
            />
          </label>
          <label class="flex flex-col gap-1">
            <span
              class="text-sm font-medium text-slate-600 dark:text-slate-300"
            >
              {{ $t('ERP.QUERIES.PARAMS') }} {{ '(JSON)' }}
            </span>
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
                class="text-sm font-medium text-slate-600 dark:text-slate-300"
              >
                {{ $t('ERP.QUERIES.ROW_LIMIT') }}
              </span>
              <input
                v-model.number="form.row_limit"
                type="number"
                class="w-full"
              />
            </label>
            <label class="flex flex-col gap-1">
              <span
                class="text-sm font-medium text-slate-600 dark:text-slate-300"
              >
                {{ $t('ERP.QUERIES.RESULT_FORMAT') }}
              </span>
              <select v-model="form.result_format" class="w-full">
                <option v-for="f in resultFormats" :key="f" :value="f">
                  {{ f }}
                </option>
              </select>
            </label>
            <label class="flex items-end gap-2 pb-1.5">
              <input v-model="form.ai_enabled" type="checkbox" />
              <span class="text-sm text-slate-600 dark:text-slate-300">
                {{ $t('ERP.QUERIES.AI_ENABLED') }}
              </span>
            </label>
          </div>
          <div class="flex gap-2 mt-2">
            <woot-button
              :is-loading="uiFlags.savingQuery"
              :disabled="!isValid"
              @click="save"
            >
              {{ $t('ERP.QUERIES.SAVE') }}
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
  </div>
</template>
