<!--
  @tickets_cases — Plan-Casos E1.1
  Filtros finos de Lista y Tablero: botón «Filtros (n)» que abre un panel con
  lo que aplica a la clase (ver FINE_FILTERS_BY_CLASS) y a lo que se ve —estado
  o resultado; ver fineKeyApplies— y, a su lado, lo activo como etiquetas con ✕
  + «Limpiar». Cada cambio se aplica al momento (v-model).
  Plan-Metricas-Comercial — UNA fecha a la vez, arriba: «¿Qué fecha?» (las de la
  clase que aplican a lo que se ve) + «¿Cuándo?» (adelante: vencidas, esta
  semana…; atrás: este mes, últimos 30…; o un rango personalizado).
-->
<script>
import { mapGetters } from 'vuex';
import {
  BILLABLE_OPTIONS,
  FINE_FILTERS_BY_CLASS,
  activeFineKeys,
  availableDateFields,
  datePresetsFor,
  emptyFineFilters,
  fineKeyApplies,
  shownDateField,
} from 'dashboard/helper/caseFilters';
import { formatDay } from 'dashboard/helper/caseCommercial';
import { forType } from 'dashboard/helper/caseClassification';

const PRIORITIES = ['low', 'medium', 'high', 'urgent'];
const ORIGINS = ['whatsapp', 'web', 'email', 'bot', 'manual', 'internal'];

export default {
  name: 'CaseFineFilters',
  props: {
    caseClass: { type: String, required: true },
    value: { type: Object, required: true },
    scope: { type: String, default: 'mine' },
    // Tipo elegido en el encabezado: acota servicios/categorías (F2).
    caseTypeId: { type: [String, Number], default: '' },
    // Naturaleza ITIL solo si el tipo (o algún tipo, sin filtro) usa ITIL.
    itil: { type: Boolean, default: false },
    // Lo que se ve: estado (Soporte) y resultado (Comercial) de la Lista; el
    // Tablero no tiene ninguno de los dos y manda `board`.
    status: { type: String, default: '' },
    outcome: { type: String, default: '' },
    // Etapa de una orden de trabajo (Lista de Órdenes).
    stage: { type: String, default: '' },
    board: { type: Boolean, default: false },
  },
  emits: ['input'],
  data() {
    return { open: false };
  },
  computed: {
    ...mapGetters({
      services: 'caseTickets/getServices',
      categories: 'caseTickets/getCategories',
      agents: 'agents/getAgents',
    }),
    context() {
      return {
        itil: this.itil,
        status: this.status,
        outcome: this.outcome,
        stage: this.stage,
        board: this.board,
      };
    },
    available() {
      return (FINE_FILTERS_BY_CLASS[this.caseClass] || []).filter(key =>
        fineKeyApplies(key, this.caseClass, this.scope, this.context)
      );
    },
    activeKeys() {
      return activeFineKeys(
        this.value,
        this.caseClass,
        this.scope,
        this.context
      );
    },
    priorities() {
      return PRIORITIES;
    },
    origins() {
      return ORIGINS;
    },
    dateFields() {
      return availableDateFields(this.caseClass, this.context);
    },
    dateField() {
      return shownDateField(this.value, this.caseClass, this.context);
    },
    datePresets() {
      return datePresetsFor(this.dateField);
    },
    billableOptions() {
      return BILLABLE_OPTIONS;
    },
    kinds() {
      return Object.keys(this.$t('CASE_TICKETS.TICKET_KIND'));
    },
    typedServices() {
      return this.caseTypeId
        ? forType(this.services, Number(this.caseTypeId))
        : this.services || [];
    },
    flatCategories() {
      const roots = this.caseTypeId
        ? forType(this.categories, Number(this.caseTypeId))
        : this.categories || [];
      const out = [];
      roots.forEach(c => {
        out.push({ id: c.id, label: c.name });
        (c.subcategories || []).forEach(sub =>
          out.push({ id: sub.id, label: `— ${sub.name}` })
        );
      });
      return out;
    },
    chips() {
      return this.activeKeys.map(key => ({ key, label: this.chipLabel(key) }));
    },
  },
  mounted() {
    this.$store.dispatch('caseTickets/fetchServices');
    this.$store.dispatch('caseTickets/fetchCategories');
    this.$store.dispatch('agents/get');
  },
  methods: {
    set(key, val) {
      this.$emit('input', { ...this.value, [key]: val });
    },
    remove(key) {
      if (key === 'date') {
        this.$emit('input', {
          ...this.value,
          date_preset: '',
          date_from: '',
          date_to: '',
        });
        return;
      }
      this.set(key, '');
    },
    // Cambiar de fecha conserva el «¿cuándo?» si también existe para la nueva
    // (este mes, esta semana…); si no (vencidas → alta), lo suelta.
    setDateField(field) {
      const keep = datePresetsFor(field).includes(this.value.date_preset);
      this.$emit('input', {
        ...this.value,
        date_field: field,
        date_preset: keep ? this.value.date_preset : '',
      });
    },
    // Se guarda también la fecha que se ve en el combo (si no se tocó, es la de
    // entrada de la clase).
    setDatePreset(preset) {
      this.$emit('input', {
        ...this.value,
        date_field: this.dateField,
        date_preset: preset,
      });
    },
    setDateBound(key, val) {
      this.$emit('input', {
        ...this.value,
        date_field: this.dateField,
        [key]: val,
      });
    },
    dateFieldLabel(field) {
      const key =
        field === 'closed' && this.caseClass === 'commercial'
          ? 'closed_commercial'
          : field;
      return this.$t(`CASE_TICKETS.FILTERS.DATE_FIELDS.${key}`);
    },
    clear() {
      this.$emit('input', emptyFineFilters());
    },
    fieldLabel(key) {
      return this.$t(`CASE_TICKETS.FILTERS.FIELDS.${key}`);
    },
    findName(list, id, field = 'name') {
      const item = (list || []).find(x => String(x.id) === String(id));
      return item ? item[field] : `#${id}`;
    },
    chipLabel(key) {
      const v = this.value;
      const name = this.fieldLabel(key);
      switch (key) {
        case 'priority':
          return `${name}: ${this.$t(`CASE_TICKETS.PRIORITIES.${v.priority}`)}`;
        case 'origin':
          return `${name}: ${this.$t(`CASE_TICKETS.ORIGINS.${v.origin}`)}`;
        case 'ticket_kind':
          return `${name}: ${this.$t(
            `CASE_TICKETS.TICKET_KIND.${v.ticket_kind}`
          )}`;
        case 'affected_service_id':
          return `${name}: ${this.findName(
            this.services,
            v.affected_service_id
          )}`;
        case 'category_id':
          return `${name}: ${this.findName(
            this.flatCategories,
            v.category_id,
            'label'
          ).replace(/^— /, '')}`;
        case 'assignee_id':
          return `${name}: ${this.findName(this.agents, v.assignee_id)}`;
        case 'date': {
          const when =
            v.date_preset === 'custom'
              ? `${v.date_from ? formatDay(v.date_from) : '…'} – ${
                  v.date_to ? formatDay(v.date_to) : '…'
                }`
              : this.$t(`CASE_TICKETS.FILTERS.DATE_PRESETS.${v.date_preset}`);
          return `${this.dateFieldLabel(
            v.date_field || this.dateField
          )}: ${when}`;
        }
        case 'billable':
          return `${name}: ${this.$t(
            `CASE_TICKETS.FILTERS.BILLABLE.${v.billable}`
          )}`;
        default:
          return name;
      }
    },
  },
};
</script>

<template>
  <div class="flex flex-wrap items-center gap-2">
    <div v-on-clickaway="() => (open = false)" class="relative">
      <woot-button
        size="small"
        variant="smooth"
        :color-scheme="activeKeys.length ? 'primary' : 'secondary'"
        icon="filter"
        @click="open = !open"
      >
        {{ $t('CASE_TICKETS.FILTERS.BUTTON') }}
        <span v-if="activeKeys.length">({{ activeKeys.length }})</span>
      </woot-button>

      <div
        v-if="open"
        class="absolute left-0 z-50 grid w-[34rem] max-w-[90vw] grid-cols-2 gap-3 p-4 mt-1 bg-white border rounded-lg shadow-lg top-full dark:bg-slate-800 border-slate-100 dark:border-slate-700 [&_select]:!mb-0 [&_input]:!mb-0"
      >
        <!-- Fecha: una a la vez («¿Qué fecha?» + «¿Cuándo?») -->
        <div
          v-if="available.includes('date')"
          class="grid grid-cols-2 col-span-2 gap-3 pb-3 border-b border-slate-100 dark:border-slate-700"
        >
          <label class="flex flex-col gap-1">
            <span class="text-xs text-slate-500 dark:text-slate-400">
              {{ $t('CASE_TICKETS.FILTERS.DATE_FIELD') }}
            </span>
            <select
              :value="dateField"
              class="text-sm"
              @change="setDateField($event.target.value)"
            >
              <option v-for="f in dateFields" :key="f" :value="f">
                {{ dateFieldLabel(f) }}
              </option>
            </select>
          </label>
          <label class="flex flex-col gap-1">
            <span class="text-xs text-slate-500 dark:text-slate-400">
              {{ $t('CASE_TICKETS.FILTERS.DATE_WHEN') }}
            </span>
            <select
              :value="value.date_preset"
              class="text-sm"
              @change="setDatePreset($event.target.value)"
            >
              <option value="">{{ $t('CASE_TICKETS.FILTERS.ANY') }}</option>
              <option v-for="p in datePresets" :key="p" :value="p">
                {{ $t(`CASE_TICKETS.FILTERS.DATE_PRESETS.${p}`) }}
              </option>
            </select>
          </label>
          <div
            v-if="value.date_preset === 'custom'"
            class="flex items-center col-span-2 gap-2"
          >
            <input
              type="date"
              class="text-sm"
              :value="value.date_from"
              :max="value.date_to || undefined"
              :aria-label="$t('CASE_TICKETS.FILTERS.CAL_PERIODS.FROM')"
              @change="setDateBound('date_from', $event.target.value)"
            />
            <span class="text-slate-400">–</span>
            <input
              type="date"
              class="text-sm"
              :value="value.date_to"
              :min="value.date_from || undefined"
              :aria-label="$t('CASE_TICKETS.FILTERS.CAL_PERIODS.TO')"
              @change="setDateBound('date_to', $event.target.value)"
            />
          </div>
        </div>

        <label
          v-if="available.includes('billable')"
          class="flex flex-col gap-1"
        >
          <span class="text-xs text-slate-500 dark:text-slate-400">
            {{ fieldLabel('billable') }}
          </span>
          <select
            :value="value.billable"
            class="text-sm"
            @change="set('billable', $event.target.value)"
          >
            <option value="">{{ $t('CASE_TICKETS.FILTERS.ANY') }}</option>
            <option v-for="o in billableOptions" :key="o" :value="o">
              {{ $t(`CASE_TICKETS.FILTERS.BILLABLE.${o}`) }}
            </option>
          </select>
        </label>

        <label
          v-if="available.includes('priority')"
          class="flex flex-col gap-1"
        >
          <span class="text-xs text-slate-500 dark:text-slate-400">
            {{ fieldLabel('priority') }}
          </span>
          <select
            :value="value.priority"
            class="text-sm"
            @change="set('priority', $event.target.value)"
          >
            <option value="">{{ $t('CASE_TICKETS.FILTERS.ANY') }}</option>
            <option v-for="p in priorities" :key="p" :value="p">
              {{ $t(`CASE_TICKETS.PRIORITIES.${p}`) }}
            </option>
          </select>
        </label>

        <label v-if="available.includes('origin')" class="flex flex-col gap-1">
          <span class="text-xs text-slate-500 dark:text-slate-400">
            {{ fieldLabel('origin') }}
          </span>
          <select
            :value="value.origin"
            class="text-sm"
            @change="set('origin', $event.target.value)"
          >
            <option value="">{{ $t('CASE_TICKETS.FILTERS.ANY') }}</option>
            <option v-for="o in origins" :key="o" :value="o">
              {{ $t(`CASE_TICKETS.ORIGINS.${o}`) }}
            </option>
          </select>
        </label>

        <label
          v-if="available.includes('affected_service_id')"
          class="flex flex-col gap-1"
        >
          <span class="text-xs text-slate-500 dark:text-slate-400">
            {{ fieldLabel('affected_service_id') }}
          </span>
          <select
            :value="value.affected_service_id"
            class="text-sm"
            @change="set('affected_service_id', $event.target.value)"
          >
            <option value="">{{ $t('CASE_TICKETS.FILTERS.ANY') }}</option>
            <option v-for="s in typedServices" :key="s.id" :value="s.id">
              {{ s.name }}
            </option>
          </select>
        </label>

        <label
          v-if="available.includes('category_id')"
          class="flex flex-col gap-1"
        >
          <span class="text-xs text-slate-500 dark:text-slate-400">
            {{ fieldLabel('category_id') }}
          </span>
          <select
            :value="value.category_id"
            class="text-sm"
            @change="set('category_id', $event.target.value)"
          >
            <option value="">{{ $t('CASE_TICKETS.FILTERS.ANY') }}</option>
            <option v-for="c in flatCategories" :key="c.id" :value="c.id">
              {{ c.label }}
            </option>
          </select>
        </label>

        <label
          v-if="available.includes('ticket_kind')"
          class="flex flex-col gap-1"
        >
          <span class="text-xs text-slate-500 dark:text-slate-400">
            {{ fieldLabel('ticket_kind') }}
          </span>
          <select
            :value="value.ticket_kind"
            class="text-sm"
            @change="set('ticket_kind', $event.target.value)"
          >
            <option value="">{{ $t('CASE_TICKETS.FILTERS.ANY') }}</option>
            <option v-for="k in kinds" :key="k" :value="k">
              {{ $t(`CASE_TICKETS.TICKET_KIND.${k}`) }}
            </option>
          </select>
        </label>

        <label
          v-if="available.includes('assignee_id')"
          class="flex flex-col gap-1"
        >
          <span class="text-xs text-slate-500 dark:text-slate-400">
            {{ fieldLabel('assignee_id') }}
          </span>
          <select
            :value="value.assignee_id"
            class="text-sm"
            @change="set('assignee_id', $event.target.value)"
          >
            <option value="">{{ $t('CASE_TICKETS.FILTERS.ANY') }}</option>
            <option v-for="a in agents" :key="a.id" :value="a.id">
              {{ a.name }}
            </option>
          </select>
        </label>
      </div>
    </div>

    <span
      v-for="chip in chips"
      :key="chip.key"
      class="flex items-center gap-1 py-0.5 pl-2 pr-1 text-xs rounded-full bg-woot-50 text-woot-700 dark:bg-woot-800/30 dark:text-woot-200"
    >
      {{ chip.label }}
      <button
        type="button"
        class="p-0.5 rounded-full hover:bg-woot-100 dark:hover:bg-woot-800"
        :aria-label="$t('CASE_TICKETS.FILTERS.REMOVE')"
        @click="remove(chip.key)"
      >
        <fluent-icon icon="dismiss" size="10" />
      </button>
    </span>
    <button
      v-if="chips.length"
      type="button"
      class="text-xs text-woot-600 dark:text-woot-400 hover:underline"
      @click="clear"
    >
      {{ $t('CASE_TICKETS.FILTERS.CLEAR') }}
    </button>
  </div>
</template>
