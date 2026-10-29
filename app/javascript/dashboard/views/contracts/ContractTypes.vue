<!--
  Plan-Contratos R1 — Clientes › Tipos de contrato (solo el Administrador los cambia):
  nombre, color, cada cuánto se cobra, plazo y renovación por omisión, y los datos
  propios que pide cada tipo («Número de cuenta», «Usuarios»…). No se borran: se
  desactivan.
-->
<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import ContractTypesAPI from 'dashboard/api/contractTypes';
import Spinner from 'shared/components/Spinner.vue';
import { UNITS, contractAccess, everyLabel } from './contractHelpers';

const FIELD_TYPES = ['text', 'number', 'date'];

const blank = () => ({
  name: '',
  color: '#2781F6',
  default_every: 1,
  default_unit: 'month',
  default_term_months: '',
  default_auto_renew: true,
  custom_fields: [],
  active: true,
});

export default {
  name: 'ContractTypes',
  components: { Spinner },
  data() {
    return { types: [], loading: true, form: null, saving: false };
  },
  computed: {
    ...mapGetters({ currentUser: 'getCurrentUser' }),
    isAdmin() {
      return contractAccess(this.currentUser, this.$route.params.accountId)
        .isAdmin;
    },
    units() {
      return UNITS;
    },
    fieldTypes() {
      return FIELD_TYPES;
    },
    isEdit() {
      return !!(this.form && this.form.id);
    },
  },
  mounted() {
    this.fetch();
  },
  methods: {
    everyLabel(type) {
      return everyLabel(
        this.$t.bind(this),
        type.default_every,
        type.default_unit
      );
    },
    async fetch() {
      this.loading = true;
      try {
        const { data } = await ContractTypesAPI.list();
        this.types = data.contract_types || [];
      } catch {
        this.types = [];
      } finally {
        this.loading = false;
      }
    },
    openNew() {
      this.form = blank();
    },
    openEdit(type) {
      if (!this.isAdmin) return;
      this.form = {
        ...blank(),
        ...type,
        default_term_months: type.default_term_months || '',
        custom_fields: (type.custom_fields || []).map(field => ({ ...field })),
      };
    },
    addField() {
      this.form.custom_fields.push({ key: '', label: '', type: 'text' });
    },
    removeField(index) {
      this.form.custom_fields.splice(index, 1);
    },
    async save() {
      if (!this.form.name.trim()) return;
      this.saving = true;
      const { id, contracts_count: count, position, ...payload } = this.form;
      payload.default_term_months = payload.default_term_months || null;
      payload.custom_fields = payload.custom_fields.filter(field =>
        field.label.trim()
      );
      try {
        if (id) await ContractTypesAPI.update(id, payload);
        else await ContractTypesAPI.create(payload);
        useAlert(this.$t('CONTRACTS.TYPES.SAVED'));
        this.form = null;
        this.fetch();
      } catch (error) {
        useAlert(
          error?.response?.data?.error || this.$t('CONTRACTS.TYPES.ERROR')
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
    class="flex flex-col flex-1 w-full h-full overflow-hidden bg-white dark:bg-slate-900"
  >
    <header
      class="flex flex-wrap items-start justify-between gap-3 px-6 pt-5 pb-3"
    >
      <div class="max-w-2xl">
        <h1 class="m-0 text-xl font-bold text-slate-800 dark:text-slate-100">
          {{ $t('CONTRACTS.TYPES.TITLE') }}
        </h1>
        <p class="m-0 text-sm text-slate-600 dark:text-slate-300">
          {{ $t('CONTRACTS.TYPES.DESCRIPTION') }}
        </p>
      </div>
      <woot-button v-if="isAdmin" size="small" icon="add" @click="openNew">
        {{ $t('CONTRACTS.TYPES.NEW') }}
      </woot-button>
    </header>

    <div class="flex-1 px-6 pb-4 overflow-auto">
      <Spinner v-if="loading" />
      <p
        v-else-if="!types.length"
        class="py-12 text-sm text-center text-slate-500 dark:text-slate-400"
      >
        {{ $t('CONTRACTS.TYPES.EMPTY') }}
      </p>
      <table v-else class="w-full text-sm">
        <thead>
          <tr
            class="text-left border-b text-slate-500 dark:text-slate-400 border-slate-50 dark:border-slate-800"
          >
            <th class="px-3 py-2 font-medium">
              {{ $t('CONTRACTS.TYPES.COLUMNS.NAME') }}
            </th>
            <th class="px-3 py-2 font-medium">
              {{ $t('CONTRACTS.TYPES.COLUMNS.BILLING') }}
            </th>
            <th class="px-3 py-2 font-medium">
              {{ $t('CONTRACTS.TYPES.COLUMNS.TERM') }}
            </th>
            <th class="px-3 py-2 font-medium">
              {{ $t('CONTRACTS.TYPES.COLUMNS.FIELDS') }}
            </th>
            <th class="px-3 py-2 font-medium text-right">
              {{ $t('CONTRACTS.TYPES.COLUMNS.CONTRACTS') }}
            </th>
            <th class="px-3 py-2 font-medium">
              {{ $t('CONTRACTS.TYPES.COLUMNS.ACTIVE') }}
            </th>
          </tr>
        </thead>
        <tbody class="divide-y divide-slate-50 dark:divide-slate-800">
          <tr
            v-for="type in types"
            :key="type.id"
            :class="{
              'cursor-pointer hover:bg-slate-25 dark:hover:bg-slate-800':
                isAdmin,
              'opacity-60': !type.active,
            }"
            @click="openEdit(type)"
          >
            <td class="px-3 py-2">
              <span class="flex items-center gap-2">
                <span
                  class="w-2.5 h-2.5 rounded-full"
                  :style="{ backgroundColor: type.color }"
                />
                <span class="font-medium text-slate-800 dark:text-slate-100">
                  {{ type.name }}
                </span>
              </span>
            </td>
            <td class="px-3 py-2">{{ everyLabel(type) }}</td>
            <td class="px-3 py-2">
              {{
                type.default_term_months
                  ? $t('CONTRACTS.TYPES.MONTHS', {
                      n: type.default_term_months,
                    })
                  : $t('CONTRACTS.TYPES.NO_TERM')
              }}
            </td>
            <td class="px-3 py-2 text-slate-600 dark:text-slate-300">
              {{ type.custom_fields.map(field => field.label).join(', ') || '—' }}
            </td>
            <td class="px-3 py-2 text-right">{{ type.contracts_count }}</td>
            <td class="px-3 py-2">
              <fluent-icon
                v-if="type.active"
                icon="checkmark"
                size="16"
                class="text-green-600"
              />
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <woot-modal
      :show="!!form"
      :on-close="() => (form = null)"
      modal-type="right-aligned"
      size="wide"
    >
      <div v-if="form" class="flex flex-col h-auto">
        <woot-modal-header
          :header-title="
            isEdit
              ? $t('CONTRACTS.TYPES.FORM.EDIT_TITLE')
              : $t('CONTRACTS.TYPES.FORM.NEW_TITLE')
          "
        />
        <form
          class="flex flex-col self-stretch w-full gap-1 px-8 pt-4 pb-0"
          @submit.prevent="save"
        >
          <div class="grid grid-cols-1 gap-x-4 sm:grid-cols-[3fr_1fr]">
            <label>
              {{ $t('CONTRACTS.TYPES.FORM.NAME') }}
              <input
                v-model="form.name"
                type="text"
                required
                :placeholder="$t('CONTRACTS.TYPES.FORM.NAME_PLACEHOLDER')"
              />
            </label>
            <label>
              {{ $t('CONTRACTS.TYPES.FORM.COLOR') }}
              <input v-model="form.color" type="color" class="!h-10 !p-1" />
            </label>
          </div>
          <div class="grid grid-cols-1 gap-x-4 sm:grid-cols-2">
            <label>
              {{ $t('CONTRACTS.TYPES.FORM.EVERY') }}
              <span class="flex gap-2">
                <input
                  v-model.number="form.default_every"
                  type="number"
                  min="1"
                  class="!w-20"
                />
                <select v-model="form.default_unit">
                  <option v-for="unit in units" :key="unit" :value="unit">
                    {{ $t(`CONTRACTS.UNITS.${unit}`) }}
                  </option>
                </select>
              </span>
            </label>
            <label>
              {{ $t('CONTRACTS.TYPES.FORM.TERM') }}
              <input
                v-model="form.default_term_months"
                type="number"
                min="1"
              />
              <span class="text-xs text-slate-500 dark:text-slate-400">{{
                $t('CONTRACTS.TYPES.FORM.TERM_HINT')
              }}</span>
            </label>
          </div>
          <label class="flex items-center gap-2">
            <input
              v-model="form.default_auto_renew"
              type="checkbox"
              class="!m-0"
            />
            {{ $t('CONTRACTS.TYPES.FORM.AUTO_RENEW') }}
          </label>

          <!-- Datos propios del tipo -->
          <div class="mt-3">
            <p class="m-0 text-sm font-medium text-slate-800 dark:text-slate-100">
              {{ $t('CONTRACTS.TYPES.FORM.FIELDS') }}
            </p>
            <p class="mb-2 text-xs text-slate-500 dark:text-slate-400">
              {{ $t('CONTRACTS.TYPES.FORM.FIELDS_HINT') }}
            </p>
            <div
              v-for="(field, index) in form.custom_fields"
              :key="index"
              class="flex items-center gap-2 mb-2"
            >
              <input
                v-model="field.label"
                type="text"
                class="!mb-0 flex-1"
                :placeholder="$t('CONTRACTS.TYPES.FORM.FIELD_LABEL')"
              />
              <select v-model="field.type" class="!mb-0 !w-32">
                <option
                  v-for="fieldType in fieldTypes"
                  :key="fieldType"
                  :value="fieldType"
                >
                  {{ $t(`CONTRACTS.TYPES.FORM.FIELD_TYPES.${fieldType}`) }}
                </option>
              </select>
              <woot-button
                type="button"
                size="tiny"
                variant="clear"
                color-scheme="alert"
                icon="dismiss"
                :title="$t('CONTRACTS.TYPES.FORM.REMOVE')"
                @click="removeField(index)"
              />
            </div>
            <woot-button
              type="button"
              size="small"
              variant="smooth"
              color-scheme="secondary"
              icon="add"
              @click="addField"
            >
              {{ $t('CONTRACTS.TYPES.FORM.ADD_FIELD') }}
            </woot-button>
          </div>

          <label class="flex items-center gap-2 mt-3">
            <input v-model="form.active" type="checkbox" class="!m-0" />
            {{ $t('CONTRACTS.TYPES.FORM.ACTIVE') }}
          </label>

          <div
            class="sticky bottom-0 z-10 flex justify-end gap-2 px-8 py-3 mt-4 -mx-8 bg-white border-t dark:bg-slate-800 border-slate-50 dark:border-slate-700"
          >
            <button type="button" class="button clear" @click="form = null">
              {{ $t('CONTRACTS.TYPES.FORM.CANCEL') }}
            </button>
            <woot-submit-button
              :loading="saving"
              :button-text="$t('CONTRACTS.TYPES.FORM.SAVE')"
            />
          </div>
        </form>
      </div>
    </woot-modal>
  </div>
</template>
