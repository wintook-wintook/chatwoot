<!--
  @tickets_cases — Plan-Casos E1.1
  Filas 2 y 3 de Lista y Tablero:
    · fila 2: pestañas «¿de quién?» (Mías · No asignadas · Todas/Todos);
    · fila 3, todos los controles a 32 px de alto y alineados:
      slot `before` (el Tipo) · combo de estado (Pendientes · Cerrados · Todos,
      solo en la Lista de Soporte) o de resultado (En curso · Ganadas · Perdidas ·
      Pospuestas · Canceladas · Todas, Comercial; ver statusForResult) · slot por
      defecto (búsqueda y filtros finos) · en Comercial, la casilla «Solo
      comprometidas» (Plan-Metricas-Comercial: se suma a todo lo demás, también
      al aviso «Cierre vencido», que entonces cuenta las comprometidas vencidas)
      · el aviso «SLA vencido (n)» al final: es una alerta, no un «¿de quién?».
-->
<script>
import {
  COMMERCIAL_RESULTS,
  SCOPES,
  alertApplies,
  hasStages,
  stageKeys,
} from 'dashboard/helper/caseFilters';

// Texto del aviso rojo por clase (SLA / visitas / cierre vencido).
const ALERT_LABELS = {
  support: 'CASE_TICKETS.FILTERS.SLA_OVERDUE',
  work_order: 'CASE_TICKETS.FILTERS.VISIT_OVERDUE_ALERT',
  commercial: 'CASE_TICKETS.FILTERS.CLOSE_OVERDUE_ALERT',
  project: 'CASE_TICKETS.FILTERS.PROJECT_OVERDUE_ALERT',
};
// Textos de las etapas por clase (Órdenes / Proyectos).
const STAGE_LABELS = {
  work_order: 'CASE_TICKETS.FILTERS.WO_STAGES',
  project: 'CASE_TICKETS.FILTERS.PROJECT_STAGES',
};
import { classI18nBase } from 'dashboard/helper/caseClasses';
import {
  allowedAssigneeTabs,
  getUserAccess,
} from 'dashboard/helper/accessHelper';

const STATUSES = ['pending', 'closed', ''];

export default {
  name: 'CaseScopeBar',
  props: {
    caseClass: { type: String, required: true },
    scope: { type: String, default: 'mine' },
    // null = no se ofrece estado (el Tablero: las columnas ya lo muestran).
    status: { type: String, default: null },
    outcome: { type: String, default: '' },
    // Plan-Clase-Orden-de-Trabajo F2b — etapa de una orden (combo de Órdenes).
    stage: { type: String, default: '' },
    slaOnly: { type: Boolean, default: false },
    slaCount: { type: Number, default: 0 },
    committedOnly: { type: Boolean, default: false },
  },
  emits: ['scope', 'status', 'outcome', 'stage', 'sla', 'committed'],
  computed: {
    i18nBase() {
      return classI18nBase(this.caseClass);
    },
    // Plan-Roles-Permisos — con el área (Ventas o Servicio) en «solo lo suyo» no
    // hay «Todas» (y «No asignadas» solo si el rol puede tomarlas).
    scopes() {
      const access = getUserAccess(
        this.$store.getters.getCurrentUser,
        this.$route.params.accountId
      );
      const area = this.caseClass === 'commercial' ? 'sales' : 'service';
      return allowedAssigneeTabs(access, area, SCOPES);
    },
    statuses() {
      return STATUSES;
    },
    outcomes() {
      return COMMERCIAL_RESULTS;
    },
    scopeIndex() {
      const i = this.scopes.indexOf(this.scope);
      return i < 0 ? 0 : i;
    },
    showStatus() {
      return (
        this.status !== null &&
        this.caseClass !== 'commercial' &&
        !hasStages(this.caseClass)
      );
    },
    showStages() {
      return hasStages(this.caseClass) && this.status !== null;
    },
    stages() {
      return stageKeys(this.caseClass);
    },
    stageLabelBase() {
      return STAGE_LABELS[this.caseClass];
    },
    showOutcomes() {
      return this.caseClass === 'commercial' && this.status !== null;
    },
    // Aviso rojo de la clase, con algo vencido o ya activo (para poder quitarlo):
    // SLA vencido (Soporte), visitas vencidas (Órdenes), cierre vencido
    // (Comercial). Cuenta abiertos: donde solo hay cerrados no aplica.
    showSla() {
      return (
        alertApplies({
          caseClass: this.caseClass,
          status: this.status,
          outcome: this.outcome,
          stage: this.stage,
        }) &&
        (this.slaCount > 0 || this.slaOnly)
      );
    },
    alertLabel() {
      return ALERT_LABELS[this.caseClass] || ALERT_LABELS.support;
    },
    showCommitted() {
      return this.caseClass === 'commercial';
    },
  },
  methods: {
    scopeLabel(key) {
      return this.$t(`${this.i18nBase}.SCOPES.${key}`);
    },
    statusLabel(key) {
      return this.$t(`${this.i18nBase}.STATUS.${key || 'all'}`);
    },
    outcomeLabel(key) {
      return this.$t(`CASE_TICKETS.FILTERS.OUTCOMES_PLURAL.${key}`);
    },
  },
};
</script>

<template>
  <div class="flex flex-col">
    <woot-tabs :index="scopeIndex" @change="i => $emit('scope', scopes[i])">
      <woot-tabs-item
        v-for="(key, i) in scopes"
        :key="key"
        :index="i"
        :name="scopeLabel(key)"
        :show-badge="false"
      />
    </woot-tabs>

    <!-- Fila de filtros: todo a h-8 (32 px) para que combos, buscador y botones
         queden a la misma altura. -->
    <div
      class="flex flex-wrap items-center gap-2 py-3 [&_select]:!h-8 [&_select]:!py-0 [&_select]:!mb-0"
    >
      <slot name="before" />

      <select
        v-if="showOutcomes"
        :value="outcome"
        class="text-sm w-40"
        :aria-label="$t('CASE_TICKETS.FILTERS.RESULT')"
        @change="$emit('outcome', $event.target.value)"
      >
        <option v-for="o in outcomes" :key="o" :value="o">
          {{ outcomeLabel(o) }}
        </option>
        <option value="">{{ statusLabel('') }}</option>
      </select>

      <select
        v-if="showStages"
        :value="stage"
        class="text-sm w-40"
        :aria-label="$t('CASE_TICKETS.FILTERS.STAGE_LABEL')"
        @change="$emit('stage', $event.target.value)"
      >
        <option v-for="st in stages" :key="st" :value="st">
          {{ $t(`${stageLabelBase}.${st}`) }}
        </option>
        <option value="">{{ statusLabel('') }}</option>
      </select>

      <select
        v-if="showStatus"
        :value="status"
        class="text-sm w-36"
        :aria-label="$t('CASE_TICKETS.FILTERS.STATUS_LABEL')"
        @change="$emit('status', $event.target.value)"
      >
        <option v-for="st in statuses" :key="st || 'all'" :value="st">
          {{ statusLabel(st) }}
        </option>
      </select>

      <slot />

      <label
        v-if="showCommitted"
        class="flex items-center h-8 gap-2 px-3 ml-auto text-xs font-medium border rounded-full cursor-pointer"
        :class="
          committedOnly
            ? 'bg-teal-100 text-teal-800 border-teal-200 dark:bg-teal-900/40 dark:text-teal-200 dark:border-teal-800'
            : 'text-slate-600 border-slate-200 hover:bg-slate-50 dark:text-slate-300 dark:border-slate-600 dark:hover:bg-slate-800'
        "
        :title="$t('CASE_TICKETS.FILTERS.COMMITTED_ONLY_HINT')"
      >
        <input
          type="checkbox"
          class="!mb-0"
          :checked="committedOnly"
          @change="$emit('committed', $event.target.checked)"
        />
        {{ $t('CASE_TICKETS.FILTERS.COMMITTED_ONLY') }}
      </label>

      <button
        v-if="showSla"
        type="button"
        class="flex items-center h-8 gap-1 px-3 text-xs font-medium border rounded-full"
        :class="[
          showCommitted ? '' : 'ml-auto',
          slaOnly
            ? 'bg-red-100 text-red-800 border-red-200 dark:bg-red-900/40 dark:text-red-300 dark:border-red-800'
            : 'text-red-700 border-red-200 hover:bg-red-50 dark:text-red-300 dark:border-red-800 dark:hover:bg-red-900/20',
        ]"
        :aria-pressed="slaOnly"
        @click="$emit('sla', !slaOnly)"
      >
        <fluent-icon icon="warning" size="12" />
        {{ $t(alertLabel, { count: slaCount }) }}
      </button>
    </div>
  </div>
</template>
