<!--
  @tickets_cases
  Reglas de automatización. La lista ahora es una tabla nativa de Chatwoot
  (vue-easytable) + paginado inferior, con el resumen SI/ENTONCES en celdas; el
  builder visual (modal) se conserva. Tailwind + dark mode.
-->
<script>
import { mapGetters } from 'vuex';
import { VeTable } from 'vue-easytable';
import TableFooter from 'dashboard/components/widgets/TableFooter.vue';
import { SIMPLE_FILTER_STATUSES } from 'dashboard/helper/caseSimpleStatus'; // modo simple/ITIL

const PER_PAGE_OPTIONS = [25, 50, 100];

const DEFAULT_FORM = () => ({
  name: '',
  description: '',
  active: true,
  continue_on_match: false,
  position: 0,
  conditions: [],
  actions: [],
});

const CONDITION_FIELDS = [
  { value: 'case_type', label: 'Tipo de caso', type: 'select' },
  { value: 'origin', label: 'Origen', type: 'select' },
  { value: 'priority', label: 'Prioridad', type: 'select' },
  { value: 'status', label: 'Estado', type: 'select' },
  { value: 'sla_status', label: 'Estado SLA', type: 'select' },
  { value: 'message_content', label: 'Contenido del mensaje', type: 'text' },
  {
    value: 'time_without_response_min',
    label: 'Tiempo sin respuesta (min)',
    type: 'number',
  },
];

const OPERATORS_TEXT = [
  { value: 'eq', label: 'es igual a' },
  { value: 'neq', label: 'no es' },
  { value: 'contains', label: 'contiene' },
];
const OPERATORS_SELECT = [
  { value: 'eq', label: 'es' },
  { value: 'neq', label: 'no es' },
  { value: 'in', label: 'está en' },
  { value: 'not_in', label: 'no está en' },
];
const OPERATORS_NUMBER = [
  { value: 'eq', label: '=' },
  { value: 'gte', label: '≥' },
  { value: 'lte', label: '≤' },
];

const VALUE_OPTIONS = {
  // case_type es dinámico (viene de los tipos de la cuenta) — ver valueOptionsFor()
  origin: [
    { value: 'whatsapp', label: 'WhatsApp' },
    { value: 'web', label: 'Web' },
    { value: 'email', label: 'Email' },
    { value: 'bot', label: 'Bot' },
    { value: 'manual', label: 'Manual' },
  ],
  priority: [
    { value: 'low', label: 'Baja' },
    { value: 'medium', label: 'Media' },
    { value: 'high', label: 'Alta' },
    { value: 'urgent', label: 'Urgente' },
  ],
  status: [
    { value: 'open', label: 'Nuevo' },
    { value: 'classified', label: 'Clasificado' },
    { value: 'assigned', label: 'Asignado' },
    { value: 'in_diagnosis', label: 'En diagnóstico' },
    { value: 'in_progress', label: 'En proceso' },
    { value: 'waiting_on_customer', label: 'En espera del cliente' },
    { value: 'waiting_on_third_party', label: 'En espera de tercero' },
    { value: 'waiting_on_internal', label: 'En espera interna' },
    { value: 'escalated', label: 'Escalado' },
    { value: 'resolved', label: 'Resuelto' },
    { value: 'validating', label: 'Validando con cliente' },
    { value: 'closed', label: 'Cerrado' },
    { value: 'cancelled', label: 'Cancelado' },
  ],
  sla_status: [
    { value: 'on_time', label: 'A tiempo' },
    { value: 'at_risk', label: 'En riesgo' },
    { value: 'overdue', label: 'Vencido' },
  ],
};

const ACTION_TYPES = [
  { value: 'assign_agent', label: 'Asignar agente', valueType: 'text' },
  { value: 'assign_team', label: 'Asignar equipo', valueType: 'text' },
  {
    value: 'change_priority',
    label: 'Cambiar prioridad',
    valueType: 'priority',
  },
  { value: 'change_status', label: 'Cambiar estado', valueType: 'status' },
  { value: 'escalate', label: 'Escalar', valueType: 'none' },
  { value: 'notify_agent', label: 'Notificar agente', valueType: 'text' },
  { value: 'add_label', label: 'Agregar etiqueta', valueType: 'text' },
  { value: 'close_ticket', label: 'Cerrar ticket', valueType: 'none' },
  {
    value: 'trigger_tracking',
    label: 'Activar seguimiento',
    valueType: 'text',
  },
];

const ACTION_VALUE_PLACEHOLDERS = {
  assign_agent: 'Nombre del agente',
  assign_team: 'Nombre del equipo',
  notify_agent: 'Email del agente',
  add_label: 'Nombre de la etiqueta',
  trigger_tracking: 'Nombre del tracking',
};

export default {
  name: 'TicketRules',
  components: { VeTable, TableFooter },
  data() {
    return {
      showModal: false,
      editingRule: null,
      form: DEFAULT_FORM(),
      deletingId: null,
      showDeleteModal: false,
      ruleToDelete: null,
      currentPage: 1,
      perPage: 25,
      perPageOptions: PER_PAGE_OPTIONS,
    };
  },
  computed: {
    ...mapGetters({
      rules: 'caseTickets/getRules',
      rulesUiFlags: 'caseTickets/getRulesUIFlags',
      caseTypes: 'caseTickets/getTypes',
      itilEnabled: 'caseTickets/getItilEnabled', // modo simple/ITIL
    }),
    isFetching() {
      return this.rulesUiFlags.isFetching;
    },
    isSaving() {
      return this.rulesUiFlags.isSaving;
    },
    conditionFields() {
      return CONDITION_FIELDS;
    },
    // Modo simple: oculta la acción ITIL "Escalar".
    actionTypes() {
      return this.itilEnabled
        ? ACTION_TYPES
        : ACTION_TYPES.filter(a => a.value !== 'escalate');
    },
    priorityOptions() {
      return VALUE_OPTIONS.priority;
    },
    // Modo simple: solo estados simples como opción.
    statusOptions() {
      return this.itilEnabled
        ? VALUE_OPTIONS.status
        : VALUE_OPTIONS.status.filter(o =>
            SIMPLE_FILTER_STATUSES.includes(o.value)
          );
    },
    // Tipos de la cuenta como opciones {value: id (string), label: name}
    typeOptions() {
      return this.caseTypes.map(t => ({ value: String(t.id), label: t.name }));
    },
    deleteMessageValue() {
      return this.ruleToDelete ? ` "${this.ruleToDelete.name}"?` : '';
    },
    pagedRules() {
      const start = (this.currentPage - 1) * this.perPage;
      return this.rules.slice(start, start + this.perPage);
    },
    columns() {
      return [
        {
          field: 'position',
          key: 'position',
          title: this.$t('CASE_TICKETS.RULES.TABLE_POSITION'),
          align: 'center',
          width: 56,
          renderBodyCell: ({ row }) => (
            <span class="text-xs font-mono text-slate-400 dark:text-slate-500">
              {row.position}
            </span>
          ),
        },
        {
          field: 'name',
          key: 'name',
          title: this.$t('CASE_TICKETS.RULES.TABLE_NAME'),
          align: 'left',
          width: 220,
          renderBodyCell: ({ row }) => (
            <div class="min-w-0">
              <p class="m-0 text-sm font-semibold truncate text-slate-800 dark:text-slate-100">
                {row.name}
              </p>
              {row.description ? (
                <p class="m-0 mt-0.5 text-xs truncate text-slate-500 dark:text-slate-400">
                  {row.description}
                </p>
              ) : null}
            </div>
          ),
        },
        {
          field: 'if',
          key: 'if',
          title: this.$t('CASE_TICKETS.RULES.TABLE_IF'),
          align: 'left',
          renderBodyCell: ({ row }) =>
            (row.conditions || []).length ? (
              <div class="flex flex-wrap gap-1">
                {row.conditions.map((cond, i) => (
                  <span
                    key={i}
                    class="px-1.5 py-0.5 text-[11px] rounded bg-slate-100 text-slate-700 dark:bg-slate-700 dark:text-slate-300"
                  >
                    {this.fieldLabel(cond.field)}{' '}
                    {this.operatorLabel(cond.operator)}{' '}
                    <strong>{this.valueLabel(cond.field, cond.value)}</strong>
                  </span>
                ))}
              </div>
            ) : (
              <span class="text-xs text-slate-400 dark:text-slate-500">
                {this.$t('CASE_TICKETS.RULES.NO_CONDITIONS')}
              </span>
            ),
        },
        {
          field: 'then',
          key: 'then',
          title: this.$t('CASE_TICKETS.RULES.TABLE_THEN'),
          align: 'left',
          renderBodyCell: ({ row }) =>
            (row.actions || []).length ? (
              <div class="flex flex-wrap gap-1">
                {row.actions.map((action, i) => (
                  <span
                    key={i}
                    class="px-1.5 py-0.5 text-[11px] rounded bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-300"
                  >
                    {this.actionTypeLabel(action.type)}
                    {action.value ? ` · ${action.value}` : ''}
                  </span>
                ))}
              </div>
            ) : (
              <span class="text-xs text-slate-400 dark:text-slate-500">
                {this.$t('CASE_TICKETS.RULES.NO_ACTIONS')}
              </span>
            ),
        },
        {
          field: 'status',
          key: 'status',
          title: this.$t('CASE_TICKETS.RULES.TABLE_STATUS'),
          align: 'left',
          width: 120,
          renderBodyCell: ({ row }) => (
            <woot-button
              size="tiny"
              variant={row.active ? 'smooth' : 'clear'}
              color-scheme={row.active ? 'success' : 'secondary'}
              icon={row.active ? 'checkmark-circle' : 'dismiss-circle'}
              onClick={() => this.toggleActive(row)}
            >
              {row.active
                ? this.$t('CASE_TICKETS.RULES.ACTIVE_BADGE')
                : this.$t('CASE_TICKETS.RULES.INACTIVE_BADGE')}
            </woot-button>
          ),
        },
        {
          field: 'actions',
          key: 'actions',
          title: '',
          align: 'right',
          width: 100,
          renderBodyCell: ({ row }) => (
            <div class="flex items-center justify-end gap-1">
              <woot-button
                size="tiny"
                variant="clear"
                color-scheme="secondary"
                icon="edit"
                onClick={() => this.openEditModal(row)}
              />
              <woot-button
                size="tiny"
                variant="clear"
                color-scheme="alert"
                icon="delete"
                isLoading={this.deletingId === row.id}
                onClick={() => this.openDelete(row)}
              />
            </div>
          ),
        },
      ];
    },
  },
  mounted() {
    this.$store.dispatch('caseTickets/fetchRules');
    this.$store.dispatch('caseTickets/fetchTypes');
    this.$store.dispatch('caseTickets/fetchSettings'); // modo simple/ITIL
  },
  methods: {
    changePage(page) {
      this.currentPage = page;
    },
    changePerPage() {
      this.currentPage = 1;
    },
    openCreateModal() {
      this.editingRule = null;
      this.form = DEFAULT_FORM();
      this.showModal = true;
    },
    openEditModal(rule) {
      this.editingRule = rule;
      this.form = {
        name: rule.name,
        description: rule.description || '',
        active: rule.active,
        continue_on_match: rule.continue_on_match,
        position: rule.position,
        conditions: JSON.parse(JSON.stringify(rule.conditions || [])),
        actions: JSON.parse(JSON.stringify(rule.actions || [])),
      };
      this.showModal = true;
    },
    addCondition() {
      const firstType = this.typeOptions[0]?.value || '';
      this.form.conditions.push({
        field: 'case_type',
        operator: 'eq',
        value: firstType,
      });
    },
    removeCondition(i) {
      this.form.conditions.splice(i, 1);
    },
    onFieldChange(cond) {
      const fieldDef = CONDITION_FIELDS.find(f => f.value === cond.field);
      cond.operator = fieldDef?.type === 'number' ? 'gte' : 'eq';
      const opts = this.valueOptionsFor(cond.field);
      cond.value = opts.length ? opts[0].value : '';
    },
    operatorsFor(field) {
      const fieldDef = CONDITION_FIELDS.find(f => f.value === field);
      if (!fieldDef) return OPERATORS_SELECT;
      if (fieldDef.type === 'number') return OPERATORS_NUMBER;
      if (fieldDef.type === 'text') return OPERATORS_TEXT;
      return OPERATORS_SELECT;
    },
    valueTypeFor(field) {
      return CONDITION_FIELDS.find(f => f.value === field)?.type || 'text';
    },
    valueOptionsFor(field) {
      if (field === 'case_type') return this.typeOptions;
      if (field === 'status') return this.statusOptions;
      return VALUE_OPTIONS[field] || [];
    },
    addAction() {
      this.form.actions.push({ type: 'assign_team', value: '' });
    },
    removeAction(i) {
      this.form.actions.splice(i, 1);
    },
    onActionTypeChange(action) {
      action.value = '';
    },
    actionValueType(type) {
      return ACTION_TYPES.find(a => a.value === type)?.valueType || 'text';
    },
    actionValuePlaceholder(type) {
      return (
        ACTION_VALUE_PLACEHOLDERS[type] ||
        this.$t('CASE_TICKETS.RULES.VALUE_PLACEHOLDER')
      );
    },
    async saveRule() {
      try {
        const payload = { ...this.form };
        if (this.editingRule) {
          await this.$store.dispatch('caseTickets/updateRule', {
            id: this.editingRule.id,
            ...payload,
          });
        } else {
          await this.$store.dispatch('caseTickets/createRule', payload);
        }
        this.showModal = false;
      } catch (_e) {
        /* silent */
      }
    },
    async toggleActive(rule) {
      await this.$store.dispatch('caseTickets/updateRule', {
        id: rule.id,
        active: !rule.active,
        name: rule.name,
        conditions: rule.conditions,
        actions: rule.actions,
      });
    },
    openDelete(rule) {
      this.ruleToDelete = rule;
      this.showDeleteModal = true;
    },
    closeDelete() {
      this.showDeleteModal = false;
      this.ruleToDelete = null;
    },
    async confirmDelete() {
      const rule = this.ruleToDelete;
      if (!rule) return;
      this.showDeleteModal = false;
      this.deletingId = rule.id;
      try {
        await this.$store.dispatch('caseTickets/deleteRule', rule.id);
      } finally {
        this.deletingId = null;
        this.ruleToDelete = null;
      }
    },
    fieldLabel(field) {
      return CONDITION_FIELDS.find(f => f.value === field)?.label || field;
    },
    operatorLabel(op) {
      return (
        [...OPERATORS_SELECT, ...OPERATORS_TEXT, ...OPERATORS_NUMBER].find(
          o => o.value === op
        )?.label || op
      );
    },
    actionTypeLabel(type) {
      return ACTION_TYPES.find(a => a.value === type)?.label || type;
    },
    valueLabel(field, value) {
      const opts =
        field === 'case_type' ? this.typeOptions : VALUE_OPTIONS[field];
      if (!opts) return value;
      return opts.find(o => String(o.value) === String(value))?.label || value;
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
      <div class="flex items-center gap-4">
        <woot-button
          size="small"
          variant="clear"
          color-scheme="secondary"
          icon="chevron-left"
          @click="$router.push({ name: 'gestorTickets_index' })"
        >
          {{ $t('CASE_TICKETS.RULES.BACK') }}
        </woot-button>
        <h1 class="m-0 text-xl font-bold text-slate-800 dark:text-slate-100">
          {{ $t('CASE_TICKETS.SIDEBAR.RULES') }}
        </h1>
      </div>
      <woot-button size="small" icon="add-circle" @click="openCreateModal">
        {{ $t('CASE_TICKETS.RULES.CREATE_BUTTON') }}
      </woot-button>
    </div>

    <!-- Loading -->
    <div
      v-if="isFetching && !rules.length"
      class="flex items-center justify-center flex-1 text-slate-400 dark:text-slate-500"
    >
      <span>{{ $t('CASE_TICKETS.RULES.LOADING') }}</span>
    </div>

    <!-- Empty -->
    <div
      v-else-if="!rules.length"
      class="flex flex-col items-center justify-center flex-1 gap-4 text-slate-400 dark:text-slate-500"
    >
      <fluent-icon icon="automation" size="36" />
      <p>{{ $t('CASE_TICKETS.RULES.EMPTY') }}</p>
      <woot-button size="small" icon="add-circle" @click="openCreateModal">
        {{ $t('CASE_TICKETS.RULES.CREATE_BUTTON') }}
      </woot-button>
    </div>

    <!-- Tabla + paginado -->
    <template v-else>
      <div class="flex-1 min-h-0 px-6 py-4 rules-table-wrap">
        <VeTable
          fixed-header
          max-height="100%"
          row-key-field-name="id"
          :columns="columns"
          :table-data="pagedRules"
          :border-around="false"
        />
      </div>
      <div
        class="flex items-center justify-between flex-shrink-0 bg-white border-t dark:bg-slate-900 border-slate-50 dark:border-slate-800/50"
      >
        <label
          class="flex items-center gap-1 pl-6 text-xs text-slate-500 dark:text-slate-400"
        >
          {{ $t('CASE_TICKETS.RULES.PER_PAGE') }}
          <select
            v-model.number="perPage"
            class="!mb-0 w-20 text-sm"
            @change="changePerPage"
          >
            <option v-for="n in perPageOptions" :key="n" :value="n">
              {{ n }}
            </option>
          </select>
        </label>
        <TableFooter
          :current-page="currentPage"
          :total-count="rules.length"
          :page-size="perPage"
          @pageChange="changePage"
        />
      </div>
    </template>

    <!-- ═══ Modal crear/editar — builder visual ═══ -->
    <woot-modal
      v-if="showModal"
      :show="showModal"
      :on-close="() => (showModal = false)"
      size="medium"
    >
      <div class="flex flex-col overflow-hidden rules-modal-body">
        <woot-modal-header
          :header-title="
            editingRule
              ? $t('CASE_TICKETS.RULES.EDIT_TITLE')
              : $t('CASE_TICKETS.RULES.CREATE_TITLE')
          "
        />

        <form
          class="flex flex-col self-stretch w-full gap-4 overflow-y-auto"
          @submit.prevent="saveRule"
        >
          <!-- Datos básicos -->
          <div class="flex items-start gap-4">
            <label class="flex flex-col flex-[2] gap-1">
              <span
                class="text-sm font-medium text-slate-700 dark:text-slate-200"
                >{{ $t('CASE_TICKETS.RULES.NAME_LABEL') }} *</span
              >
              <input
                v-model="form.name"
                type="text"
                class="w-full"
                required
                :placeholder="$t('CASE_TICKETS.RULES.NAME_PLACEHOLDER')"
              />
            </label>
            <label class="flex flex-col gap-1">
              <span
                class="text-sm font-medium text-slate-700 dark:text-slate-200"
                >{{ $t('CASE_TICKETS.RULES.POSITION_LABEL') }}</span
              >
              <input
                v-model.number="form.position"
                type="number"
                min="0"
                class="w-20"
              />
            </label>
          </div>

          <div class="flex items-start gap-4">
            <label class="flex flex-col flex-[2] gap-1">
              <span
                class="text-sm font-medium text-slate-700 dark:text-slate-200"
                >{{ $t('CASE_TICKETS.RULES.DESCRIPTION_LABEL') }}</span
              >
              <input
                v-model="form.description"
                type="text"
                class="w-full"
                :placeholder="$t('CASE_TICKETS.RULES.DESCRIPTION_PLACEHOLDER')"
              />
            </label>
            <div class="flex flex-col flex-shrink-0 gap-2 pt-6">
              <label
                class="flex items-center gap-2 text-sm cursor-pointer text-slate-600 dark:text-slate-300"
              >
                <input v-model="form.active" type="checkbox" />
                <span>{{ $t('CASE_TICKETS.RULES.ACTIVE_LABEL') }}</span>
              </label>
              <label
                class="flex items-center gap-2 text-sm cursor-pointer text-slate-600 dark:text-slate-300"
              >
                <input v-model="form.continue_on_match" type="checkbox" />
                <span>{{ $t('CASE_TICKETS.RULES.CONTINUE_LABEL') }}</span>
              </label>
            </div>
          </div>

          <!-- Condiciones -->
          <div
            class="flex flex-col gap-2 p-4 border rounded-lg bg-slate-25 dark:bg-slate-800/50 border-slate-100 dark:border-slate-700"
          >
            <div class="flex items-center justify-between">
              <span
                class="flex items-center gap-2 text-sm font-semibold text-slate-800 dark:text-slate-100"
              >
                <span
                  class="px-2 py-0.5 text-xs font-bold rounded bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-300"
                  >{{ $t('CASE_TICKETS.RULES.IF_BADGE') }}</span
                >
                {{ $t('CASE_TICKETS.RULES.IF_SECTION_TITLE') }}
              </span>
              <woot-button
                size="tiny"
                variant="clear"
                icon="add-circle"
                type="button"
                @click="addCondition"
                >{{ $t('CASE_TICKETS.RULES.ADD_CONDITION') }}</woot-button
              >
            </div>

            <div
              v-if="!form.conditions.length"
              class="p-2 text-sm text-center text-slate-400 dark:text-slate-500"
            >
              {{ $t('CASE_TICKETS.RULES.NO_CONDITIONS_HINT') }}
            </div>

            <div
              v-for="(cond, i) in form.conditions"
              :key="i"
              class="grid items-center gap-2 px-3 py-2 bg-white border rounded-lg cond-grid dark:bg-slate-800 border-slate-100 dark:border-slate-700"
            >
              <select
                v-model="cond.field"
                class="w-full"
                @change="onFieldChange(cond)"
              >
                <option
                  v-for="f in conditionFields"
                  :key="f.value"
                  :value="f.value"
                >
                  {{ f.label }}
                </option>
              </select>
              <select v-model="cond.operator" class="w-full">
                <option
                  v-for="op in operatorsFor(cond.field)"
                  :key="op.value"
                  :value="op.value"
                >
                  {{ op.label }}
                </option>
              </select>
              <template v-if="valueTypeFor(cond.field) === 'select'">
                <select v-model="cond.value" class="w-full">
                  <option
                    v-for="opt in valueOptionsFor(cond.field)"
                    :key="opt.value"
                    :value="opt.value"
                  >
                    {{ opt.label }}
                  </option>
                </select>
              </template>
              <template v-else-if="valueTypeFor(cond.field) === 'number'">
                <input
                  v-model.number="cond.value"
                  type="number"
                  min="0"
                  class="w-full"
                  :placeholder="$t('CASE_TICKETS.RULES.MINUTES_PLACEHOLDER')"
                />
              </template>
              <template v-else>
                <input
                  v-model="cond.value"
                  type="text"
                  class="w-full"
                  :placeholder="$t('CASE_TICKETS.RULES.VALUE_PLACEHOLDER')"
                />
              </template>
              <button
                type="button"
                class="flex items-center justify-center w-6 h-6 rounded-full text-slate-400 hover:bg-red-100 hover:text-red-600 dark:hover:bg-red-900/40"
                @click="removeCondition(i)"
              >
                <fluent-icon icon="dismiss" size="12" />
              </button>
            </div>
          </div>

          <!-- Acciones -->
          <div
            class="flex flex-col gap-2 p-4 border rounded-lg bg-slate-25 dark:bg-slate-800/50 border-slate-100 dark:border-slate-700"
          >
            <div class="flex items-center justify-between">
              <span
                class="flex items-center gap-2 text-sm font-semibold text-slate-800 dark:text-slate-100"
              >
                <span
                  class="px-2 py-0.5 text-xs font-bold rounded bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-300"
                  >{{ $t('CASE_TICKETS.RULES.THEN_BADGE') }}</span
                >
                {{ $t('CASE_TICKETS.RULES.THEN_SECTION_TITLE') }}
              </span>
              <woot-button
                size="tiny"
                variant="clear"
                icon="add-circle"
                type="button"
                @click="addAction"
                >{{ $t('CASE_TICKETS.RULES.ADD_ACTION') }}</woot-button
              >
            </div>

            <div
              v-if="!form.actions.length"
              class="p-2 text-sm text-center text-yellow-600 dark:text-yellow-400"
            >
              {{ $t('CASE_TICKETS.RULES.NEED_ACTION') }}
            </div>

            <div
              v-for="(action, i) in form.actions"
              :key="i"
              class="grid items-center gap-2 px-3 py-2 bg-white border rounded-lg action-grid dark:bg-slate-800 border-slate-100 dark:border-slate-700"
            >
              <select
                v-model="action.type"
                class="w-full"
                @change="onActionTypeChange(action)"
              >
                <option
                  v-for="a in actionTypes"
                  :key="a.value"
                  :value="a.value"
                >
                  {{ a.label }}
                </option>
              </select>
              <template v-if="actionValueType(action.type) === 'priority'">
                <select v-model="action.value" class="w-full">
                  <option
                    v-for="p in priorityOptions"
                    :key="p.value"
                    :value="p.value"
                  >
                    {{ p.label }}
                  </option>
                </select>
              </template>
              <template v-else-if="actionValueType(action.type) === 'status'">
                <select v-model="action.value" class="w-full">
                  <option
                    v-for="s in statusOptions"
                    :key="s.value"
                    :value="s.value"
                  >
                    {{ s.label }}
                  </option>
                </select>
              </template>
              <template v-else-if="actionValueType(action.type) === 'text'">
                <input
                  v-model="action.value"
                  type="text"
                  class="w-full"
                  :placeholder="actionValuePlaceholder(action.type)"
                />
              </template>
              <template v-else>
                <span
                  class="text-xs italic text-slate-400 dark:text-slate-500"
                  >{{ $t('CASE_TICKETS.RULES.NO_PARAM') }}</span
                >
              </template>
              <button
                type="button"
                class="flex items-center justify-center w-6 h-6 rounded-full text-slate-400 hover:bg-red-100 hover:text-red-600 dark:hover:bg-red-900/40"
                @click="removeAction(i)"
              >
                <fluent-icon icon="dismiss" size="12" />
              </button>
            </div>
          </div>

          <!-- Footer -->
          <div
            class="flex justify-end flex-shrink-0 gap-4 pt-4 border-t border-slate-100 dark:border-slate-700"
          >
            <woot-button
              variant="clear"
              color-scheme="secondary"
              type="button"
              @click="showModal = false"
              >{{ $t('CASE_TICKETS.RULES.CANCEL') }}</woot-button
            >
            <woot-button
              type="submit"
              :is-loading="isSaving"
              :disabled="!form.actions.length"
            >
              {{
                editingRule
                  ? $t('CASE_TICKETS.RULES.SAVE_EDIT')
                  : $t('CASE_TICKETS.RULES.CREATE')
              }}
            </woot-button>
          </div>
        </form>
      </div>
    </woot-modal>

    <!-- Confirmación de borrado -->
    <woot-delete-modal
      :show.sync="showDeleteModal"
      :on-close="closeDelete"
      :on-confirm="confirmDelete"
      :title="$t('CASE_TICKETS.RULES.DELETE.TITLE')"
      :message="$t('CASE_TICKETS.RULES.DELETE.MESSAGE')"
      :message-value="deleteMessageValue"
      :confirm-text="$t('CASE_TICKETS.RULES.DELETE.YES')"
      :reject-text="$t('CASE_TICKETS.RULES.DELETE.NO')"
    />
  </div>
</template>

<style lang="scss" scoped>
.rules-modal-body {
  max-height: 90vh;
}

// Rejillas del builder: condición (campo · operador · valor · quitar) y acción
// (tipo · valor · quitar).
.cond-grid {
  grid-template-columns: 1fr 160px 1fr 28px;
}
.action-grid {
  grid-template-columns: 1fr 1fr 28px;
}

.rules-table-wrap {
  overflow: hidden;
}

.rules-table-wrap::v-deep {
  .ve-table {
    height: 100%;
  }
  .ve-table-header-th {
    padding: var(--space-small) var(--space-one) !important;
    font-size: var(--font-size-mini) !important;
  }
  .ve-table-body-td {
    padding: var(--space-small) var(--space-one) !important;
    vertical-align: middle;
  }
}
</style>
