<!--
  @tickets_cases Fase C
  Modal para crear un ticket INTERNO (agente → agente, sin contacto).
  El solicitante es el usuario actual; se asigna a un agente y/o equipo.
  Incluye naturaleza ITIL y los campos personalizados (2K) del tipo elegido.
-->
<script>
import { mapGetters } from 'vuex';

// Espejo de Cases::PriorityMatrix (backend). impacto × urgencia → prioridad.
const PRIORITY_MATRIX = {
  high: { low: 'high', medium: 'high', high: 'urgent' },
  medium: { low: 'low', medium: 'medium', high: 'high' },
  low: { low: 'low', medium: 'low', high: 'medium' },
};

export default {
  name: 'CaseTicketInternalModal',
  props: {
    show: { type: Boolean, default: false },
  },
  emits: ['close', 'created'],
  data() {
    return {
      activeTab: 'ticket', // 'ticket' | 'assign' | 'custom'
      form: {
        assignee_id: '',
        team_id: '',
        case_type_id: null,
        ticket_kind: 'service_request',
        affected_service_id: null,
        category_id: null,
        title: '',
        impact: null,
        urgency: null,
        priority: 'medium',
        description: '',
      },
      // 2K — valores de los campos personalizados del tipo seleccionado
      customValues: {},
    };
  },
  computed: {
    ...mapGetters({
      uiFlags: 'caseTickets/getUIFlags',
      types: 'caseTickets/getTypes',
      agents: 'agents/getAgents',
      teams: 'teams/getTeams',
      services: 'caseTickets/getServices',
      categories: 'caseTickets/getCategories',
    }),
    tabs() {
      return [
        { key: 'ticket', label: this.$t('CASE_TICKETS.MODAL.TAB_TICKET') },
        { key: 'assign', label: this.$t('CASE_TICKETS.MODAL.TAB_ASSIGN') },
        { key: 'custom', label: this.$t('CASE_TICKETS.MODAL.TAB_CUSTOM') },
      ];
    },
    activeTabIndex() {
      const idx = this.tabs.findIndex(t => t.key === this.activeTab);
      return idx === -1 ? 0 : idx;
    },
    ticketKindOptions() {
      return this.$t('CASE_TICKETS.TICKET_KIND');
    },
    priorityOptions() {
      return this.$t('CASE_TICKETS.PRIORITIES');
    },
    impactOptions() {
      return this.$t('CASE_TICKETS.IMPACT');
    },
    urgencyOptions() {
      return this.$t('CASE_TICKETS.URGENCY');
    },
    // Prioridad derivada por matriz cuando hay impacto y urgencia.
    derivedPriority() {
      if (!this.form.impact || !this.form.urgency) return null;
      return (
        (PRIORITY_MATRIX[this.form.impact] || {})[this.form.urgency] || null
      );
    },
    // Categorías aplanadas (categoría + subcategorías con guion) para el select.
    flatCategories() {
      const out = [];
      (this.categories || []).forEach(c => {
        out.push({ id: c.id, label: c.name });
        (c.subcategories || []).forEach(sub => {
          out.push({ id: sub.id, label: `— ${sub.name}` });
        });
      });
      return out;
    },
    // 2K — campos personalizados del tipo de caso seleccionado.
    selectedTypeFields() {
      const type = (this.types || []).find(
        t => t.id === this.form.case_type_id
      );
      return (type && type.custom_fields) || [];
    },
    // ¿Todos los campos requeridos tienen valor?
    customFieldsValid() {
      return this.selectedTypeFields.every(f => {
        if (!f.required) return true;
        const v = this.customValues[f.key];
        if (f.field_type === 'checkbox') return v === true;
        return v !== undefined && v !== null && String(v).trim() !== '';
      });
    },
    isValid() {
      return this.form.title.trim().length > 0 && this.customFieldsValid;
    },
  },
  watch: {
    // Al cambiar de tipo, inicializa los valores de sus campos (checkbox→false).
    selectedTypeFields: {
      immediate: true,
      handler(fields) {
        const next = {};
        fields.forEach(f => {
          const fallback = f.field_type === 'checkbox' ? false : '';
          next[f.key] =
            f.key in this.customValues ? this.customValues[f.key] : fallback;
        });
        this.customValues = next;
      },
    },
  },
  mounted() {
    this.$store.dispatch('caseTickets/fetchTypes').then(() => {
      if (!this.form.case_type_id && this.types.length) {
        this.form.case_type_id = this.types[0].id;
      }
    });
    this.$store.dispatch('agents/get');
    this.$store.dispatch('teams/get');
    this.$store.dispatch('caseTickets/fetchServices');
    this.$store.dispatch('caseTickets/fetchCategories');
  },
  methods: {
    onTabChange(index) {
      const tab = this.tabs[index];
      if (tab) this.activeTab = tab.key;
    },
    async onSubmit() {
      try {
        const ticket = await this.$store.dispatch('caseTickets/createTicket', {
          internal: true,
          assignee_id: this.form.assignee_id || undefined,
          team_id: this.form.team_id || undefined,
          case_type_id: this.form.case_type_id,
          ticket_kind: this.form.ticket_kind,
          affected_service_id: this.form.affected_service_id || undefined,
          category_id: this.form.category_id || undefined,
          title: this.form.title.trim(),
          impact: this.form.impact || undefined,
          urgency: this.form.urgency || undefined,
          // Si la matriz deriva la prioridad, no se envía la manual (el backend la calcula).
          priority: this.derivedPriority ? undefined : this.form.priority,
          description: this.form.description.trim() || undefined,
          custom_attributes: this.selectedTypeFields.length
            ? this.customValues
            : undefined,
        });
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.INTERNAL.SUCCESS'),
        });
        this.$emit('created', ticket);
        this.$emit('close');
      } catch (e) {
        this.$emitter.emit('newToastMessage', {
          message:
            e.response?.data?.error || this.$t('CASE_TICKETS.INTERNAL.ERROR'),
        });
      }
    },
  },
};
</script>

<template>
  <woot-modal :show="show" :on-close="() => $emit('close')" size="medium">
    <div class="flex flex-col h-auto overflow-auto">
      <woot-modal-header :header-title="$t('CASE_TICKETS.INTERNAL.TITLE')" />
      <form
        class="flex flex-col self-stretch w-full gap-3 p-8 pt-4"
        @submit.prevent="onSubmit"
      >
        <woot-tabs :index="activeTabIndex" @change="onTabChange">
          <woot-tabs-item
            v-for="(t, i) in tabs"
            :key="t.key"
            :index="i"
            :name="t.label"
            :show-badge="false"
          />
        </woot-tabs>

        <!-- Altura fija para que el modal no salte al cambiar de pestaña. -->
        <div class="min-h-[27rem]">
          <!-- Tab: Datos del ticket -->
          <div
            v-show="activeTab === 'ticket'"
            class="grid grid-cols-2 gap-3 [&_.input]:!mb-0"
          >
            <!-- Tipo de caso -->
            <label class="flex flex-col gap-1">
              <span
                class="text-sm font-medium text-slate-700 dark:text-slate-300"
              >
                {{ $t('CASE_TICKETS.MODAL.CASE_TYPE_LABEL') }}
              </span>
              <select v-model="form.case_type_id" class="input">
                <option v-for="t in types" :key="t.id" :value="t.id">
                  {{ t.name }}
                </option>
              </select>
            </label>

            <!-- Naturaleza ITIL -->
            <label class="flex flex-col gap-1">
              <span
                class="text-sm font-medium text-slate-700 dark:text-slate-300"
              >
                {{ $t('CASE_TICKETS.MODAL.TICKET_KIND_LABEL') }}
              </span>
              <select v-model="form.ticket_kind" class="input">
                <option
                  v-for="(label, key) in ticketKindOptions"
                  :key="key"
                  :value="key"
                >
                  {{ label }}
                </option>
              </select>
            </label>

            <!-- Título -->
            <label class="flex flex-col col-span-2 gap-1">
              <span
                class="text-sm font-medium text-slate-700 dark:text-slate-300"
              >
                {{ $t('CASE_TICKETS.MODAL.TITLE_LABEL') }}
              </span>
              <input
                v-model="form.title"
                type="text"
                class="input"
                :placeholder="$t('CASE_TICKETS.INTERNAL.TITLE_PLACEHOLDER')"
                required
              />
            </label>

            <!-- Descripción -->
            <label class="flex flex-col col-span-2 gap-1">
              <span
                class="text-sm font-medium text-slate-700 dark:text-slate-300"
              >
                {{ $t('CASE_TICKETS.MODAL.DESCRIPTION_LABEL') }}
              </span>
              <textarea
                v-model="form.description"
                rows="3"
                class="input"
                :placeholder="$t('CASE_TICKETS.MODAL.DESCRIPTION_PLACEHOLDER')"
              />
            </label>

            <!-- Servicio afectado -->
            <label class="flex flex-col gap-1">
              <span
                class="text-sm font-medium text-slate-700 dark:text-slate-300"
              >
                {{ $t('CASE_TICKETS.MODAL.AFFECTED_SERVICE_LABEL') }}
              </span>
              <select v-model="form.affected_service_id" class="input">
                <option :value="null">
                  {{ $t('CASE_TICKETS.MODAL.UNSPECIFIED') }}
                </option>
                <option v-for="s in services" :key="s.id" :value="s.id">
                  {{ s.name }}
                </option>
              </select>
            </label>

            <!-- Categoría -->
            <label class="flex flex-col gap-1">
              <span
                class="text-sm font-medium text-slate-700 dark:text-slate-300"
              >
                {{ $t('CASE_TICKETS.MODAL.CATEGORY_LABEL') }}
              </span>
              <select v-model="form.category_id" class="input">
                <option :value="null">
                  {{ $t('CASE_TICKETS.MODAL.UNSPECIFIED') }}
                </option>
                <option v-for="c in flatCategories" :key="c.id" :value="c.id">
                  {{ c.label }}
                </option>
              </select>
            </label>

            <!-- Impacto · Urgencia · Prioridad en una sola línea -->
            <div class="grid grid-cols-3 col-span-2 gap-3">
              <!-- Impacto -->
              <label class="flex flex-col gap-1">
                <span
                  class="text-sm font-medium text-slate-700 dark:text-slate-300"
                >
                  {{ $t('CASE_TICKETS.MODAL.IMPACT_LABEL') }}
                </span>
                <select v-model="form.impact" class="input">
                  <option :value="null">
                    {{ $t('CASE_TICKETS.MODAL.UNSPECIFIED') }}
                  </option>
                  <option
                    v-for="(label, key) in impactOptions"
                    :key="key"
                    :value="key"
                  >
                    {{ label }}
                  </option>
                </select>
              </label>

              <!-- Urgencia -->
              <label class="flex flex-col gap-1">
                <span
                  class="text-sm font-medium text-slate-700 dark:text-slate-300"
                >
                  {{ $t('CASE_TICKETS.MODAL.URGENCY_LABEL') }}
                </span>
                <select v-model="form.urgency" class="input">
                  <option :value="null">
                    {{ $t('CASE_TICKETS.MODAL.UNSPECIFIED') }}
                  </option>
                  <option
                    v-for="(label, key) in urgencyOptions"
                    :key="key"
                    :value="key"
                  >
                    {{ label }}
                  </option>
                </select>
              </label>

              <!-- Prioridad -->
              <label class="flex flex-col gap-1">
                <span
                  class="text-sm font-medium text-slate-700 dark:text-slate-300"
                >
                  {{ $t('CASE_TICKETS.MODAL.PRIORITY_LABEL') }}
                </span>
                <select
                  v-model="form.priority"
                  class="input"
                  :disabled="!!derivedPriority"
                >
                  <option value="low">
                    {{ $t('CASE_TICKETS.PRIORITIES.low') }}
                  </option>
                  <option value="medium">
                    {{ $t('CASE_TICKETS.PRIORITIES.medium') }}
                  </option>
                  <option value="high">
                    {{ $t('CASE_TICKETS.PRIORITIES.high') }}
                  </option>
                  <option value="urgent">
                    {{ $t('CASE_TICKETS.PRIORITIES.urgent') }}
                  </option>
                </select>
                <span
                  v-if="derivedPriority"
                  class="text-xs text-slate-500 dark:text-slate-400"
                >
                  {{
                    $t('CASE_TICKETS.MODAL.PRIORITY_DERIVED', {
                      priority: priorityOptions[derivedPriority],
                    })
                  }}
                </span>
              </label>
            </div>
          </div>

          <!-- Tab: Asignación -->
          <div
            v-show="activeTab === 'assign'"
            class="grid grid-cols-2 gap-3 [&_.input]:!mb-0"
          >
            <!-- Equipo -->
            <label class="flex flex-col gap-1">
              <span
                class="text-sm font-medium text-slate-700 dark:text-slate-300"
              >
                {{ $t('CASE_TICKETS.ASSIGN.TEAM_LABEL') }}
              </span>
              <select v-model="form.team_id" class="input">
                <option value="">
                  {{ $t('CASE_TICKETS.INTERNAL.ASSIGNEE_NONE') }}
                </option>
                <option v-for="tm in teams" :key="tm.id" :value="tm.id">
                  {{ tm.name }}
                </option>
              </select>
            </label>

            <!-- Agente -->
            <label class="flex flex-col gap-1">
              <span
                class="text-sm font-medium text-slate-700 dark:text-slate-300"
              >
                {{ $t('CASE_TICKETS.INTERNAL.ASSIGNEE_LABEL') }}
              </span>
              <select v-model="form.assignee_id" class="input">
                <option value="">
                  {{ $t('CASE_TICKETS.INTERNAL.ASSIGNEE_NONE') }}
                </option>
                <option v-for="ag in agents" :key="ag.id" :value="ag.id">
                  {{ ag.name }}
                </option>
              </select>
            </label>
            <p class="col-span-2 text-xs text-slate-400 dark:text-slate-500">
              {{ $t('CASE_TICKETS.MODAL.ASSIGN_HINT') }}
            </p>
          </div>

          <!-- Tab: Campos personalizados (2K) -->
          <div v-show="activeTab === 'custom'">
            <div
              v-if="!selectedTypeFields.length"
              class="py-6 text-sm text-center text-slate-400 dark:text-slate-500"
            >
              {{ $t('CASE_TICKETS.MODAL.NO_CUSTOM_FIELDS') }}
            </div>
            <div v-else class="grid grid-cols-2 gap-3 [&_.input]:!mb-0">
              <label
                v-for="field in selectedTypeFields"
                :key="field.key"
                class="flex"
                :class="
                  field.field_type === 'checkbox'
                    ? 'flex-row items-center col-span-2 gap-2.5 px-3 py-2.5 border rounded-md cursor-pointer border-slate-200 dark:border-slate-600 bg-slate-25 dark:bg-slate-800'
                    : 'flex-col gap-1'
                "
              >
                <input
                  v-if="field.field_type === 'checkbox'"
                  v-model="customValues[field.key]"
                  type="checkbox"
                  class="w-4 h-4 shrink-0"
                />
                <span
                  class="text-sm font-medium text-slate-700 dark:text-slate-300"
                >
                  {{ field.label
                  }}<span v-if="field.required" class="text-red-500"> *</span>
                </span>
                <select
                  v-if="field.field_type === 'list'"
                  v-model="customValues[field.key]"
                  class="input"
                  :required="field.required"
                >
                  <option value="">
                    {{ $t('CASE_TICKETS.MODAL.UNSPECIFIED') }}
                  </option>
                  <option v-for="opt in field.options" :key="opt" :value="opt">
                    {{ opt }}
                  </option>
                </select>
                <input
                  v-else-if="field.field_type === 'number'"
                  v-model="customValues[field.key]"
                  type="number"
                  class="input"
                  :required="field.required"
                />
                <input
                  v-else-if="field.field_type === 'date'"
                  v-model="customValues[field.key]"
                  type="date"
                  class="input"
                  :required="field.required"
                />
                <input
                  v-else-if="field.field_type === 'text'"
                  v-model="customValues[field.key]"
                  type="text"
                  class="input"
                  :required="field.required"
                />
              </label>
            </div>
          </div>
        </div>

        <div class="flex items-center justify-end gap-2">
          <woot-button variant="clear" type="button" @click="$emit('close')">
            {{ $t('CASE_TICKETS.MODAL.CANCEL') }}
          </woot-button>
          <woot-button
            type="submit"
            :is-loading="uiFlags.isCreating"
            :disabled="!isValid"
          >
            {{ $t('CASE_TICKETS.INTERNAL.SUBMIT') }}
          </woot-button>
        </div>
      </form>
    </div>
  </woot-modal>
</template>
