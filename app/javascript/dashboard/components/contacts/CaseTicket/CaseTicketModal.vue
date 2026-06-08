<!--
  @tickets_cases
  Modal de tickets desde el panel derecho de conversación.
  Dos vistas: 'list' (tickets en proceso del contacto) y 'create' (alta).
  La vista 'create' usa pestañas: "Datos del ticket" y "Campos personalizados" (2K),
  en rejilla de 2 columnas para evitar scroll vertical.
  2B: clasificación ITIL (tipo, servicio, categoría, impacto/urgencia → prioridad por matriz).
-->
<script>
import { mapGetters } from 'vuex';
import CaseTimeline from './CaseTimeline.vue';

// Espejo de Cases::PriorityMatrix (backend). impacto × urgencia → prioridad.
const PRIORITY_MATRIX = {
  high: { low: 'high', medium: 'high', high: 'urgent' },
  medium: { low: 'low', medium: 'medium', high: 'high' },
  low: { low: 'low', medium: 'low', high: 'medium' },
};

export default {
  name: 'CaseTicketModal',
  components: { CaseTimeline },
  props: {
    show: { type: Boolean, default: false },
    contactId: { type: [Number, String], required: true },
    conversationId: { type: [Number, String], default: null },
  },
  emits: ['close', 'created'],
  data() {
    return {
      view: 'list', // 'list' | 'create'
      activeTab: 'ticket', // 'ticket' | 'custom'
      transitionMenuFor: null, // id del ticket con el menú de estado abierto
      showTimeline: false,
      timelineTicketId: null,
      form: {
        case_type_id: null,
        ticket_kind: 'service_request',
        title: '',
        affected_service_id: null,
        category_id: null,
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
      services: 'caseTickets/getServices',
      categories: 'caseTickets/getCategories',
      getContactTickets: 'caseTickets/getContactTickets',
    }),
    tickets() {
      return this.getContactTickets(this.contactId);
    },
    isFetching() {
      return this.uiFlags.isFetching;
    },
    isCreating() {
      return this.uiFlags.isCreating;
    },
    isTransitioning() {
      return this.uiFlags.isTransitioning;
    },
    headerTitle() {
      return this.view === 'create'
        ? this.$t('CASE_TICKETS.MODAL.TITLE_CREATE')
        : this.$t('CASE_TICKETS.MODAL.TITLE_LIST');
    },
    tabs() {
      return [
        { key: 'ticket', label: this.$t('CASE_TICKETS.MODAL.TAB_TICKET') },
        { key: 'custom', label: this.$t('CASE_TICKETS.MODAL.TAB_CUSTOM') },
      ];
    },
    activeTabIndex() {
      const idx = this.tabs.findIndex(t => t.key === this.activeTab);
      return idx === -1 ? 0 : idx;
    },
    priorityOptions() {
      return this.$t('CASE_TICKETS.PRIORITIES');
    },
    ticketKindOptions() {
      return this.$t('CASE_TICKETS.TICKET_KIND');
    },
    impactOptions() {
      return this.$t('CASE_TICKETS.IMPACT');
    },
    urgencyOptions() {
      return this.$t('CASE_TICKETS.URGENCY');
    },
    // Categorías raíz + subcategorías indentadas para el selector.
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
    // Prioridad derivada por matriz cuando hay impacto y urgencia.
    derivedPriority() {
      if (!this.form.impact || !this.form.urgency) return null;
      return (
        (PRIORITY_MATRIX[this.form.impact] || {})[this.form.urgency] || null
      );
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
  },
  watch: {
    contactId(newId) {
      if (newId) this.fetchTickets();
    },
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
    this.fetchTickets();
    this.$store.dispatch('caseTickets/fetchTypes').then(() => {
      if (!this.form.case_type_id && this.types.length) {
        this.form.case_type_id = this.types[0].id;
      }
    });
    this.$store.dispatch('caseTickets/fetchServices');
    this.$store.dispatch('caseTickets/fetchCategories');
  },
  methods: {
    fetchTickets() {
      if (!this.contactId) return;
      this.$store.dispatch('caseTickets/fetchContactTickets', {
        contactId: this.contactId,
      });
    },
    goCreate() {
      this.activeTab = 'ticket';
      this.view = 'create';
    },
    goList() {
      this.view = 'list';
    },
    onTabChange(index) {
      const tab = this.tabs[index];
      if (tab) this.activeTab = tab.key;
    },
    openDetail(id) {
      this.$emit('close');
      this.$router.push({ name: 'gestorTickets_detail', params: { id } });
    },
    openTimeline(ticket) {
      this.timelineTicketId = ticket.id;
      this.showTimeline = true;
    },
    validTransitions(ticket) {
      return ticket.can_transition_to || [];
    },
    toggleTransitionMenu(id) {
      this.transitionMenuFor = this.transitionMenuFor === id ? null : id;
    },
    async transitionTo(ticket, status) {
      this.transitionMenuFor = null;
      try {
        await this.$store.dispatch('caseTickets/transitionTicket', {
          ticketId: ticket.id,
          contactId: this.contactId,
          status,
        });
        this.fetchTickets();
        this.$emit('created'); // refresca el conteo del panel
      } catch (_e) {
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.MODAL.ERROR'),
          type: 'error',
        });
      }
    },
    async onSubmit() {
      try {
        const ticket = await this.$store.dispatch('caseTickets/createTicket', {
          contact_id: this.contactId,
          conversation_id: this.conversationId || undefined,
          case_type_id: this.form.case_type_id,
          ticket_kind: this.form.ticket_kind,
          title: this.form.title.trim(),
          affected_service_id: this.form.affected_service_id || undefined,
          category_id: this.form.category_id || undefined,
          impact: this.form.impact || undefined,
          urgency: this.form.urgency || undefined,
          // Si la matriz deriva la prioridad, no se envía la manual (el backend la calcula).
          priority: this.derivedPriority ? undefined : this.form.priority,
          description: this.form.description.trim() || undefined,
          // 2K — solo se envían si el tipo define campos personalizados.
          custom_attributes: this.selectedTypeFields.length
            ? this.customValues
            : undefined,
        });
        this.$emit('created', ticket);
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.MODAL.SUCCESS'),
          type: 'success',
        });
        this.resetForm();
        this.fetchTickets();
        this.goList();
      } catch (_e) {
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.MODAL.ERROR'),
          type: 'error',
        });
      }
    },
    resetForm() {
      this.form = {
        case_type_id: this.types.length ? this.types[0].id : null,
        ticket_kind: 'service_request',
        title: '',
        affected_service_id: null,
        category_id: null,
        impact: null,
        urgency: null,
        priority: 'medium',
        description: '',
      };
    },
    statusLabel(key) {
      return this.$t(`CASE_TICKETS.STATUSES.${key}`) || key;
    },
    priorityLabel(key) {
      return this.$t(`CASE_TICKETS.PRIORITIES.${key}`) || key;
    },
    cardClass(ticket) {
      return (
        {
          on_time:
            'bg-white dark:bg-slate-800 border-slate-75 dark:border-slate-700',
          at_risk:
            'bg-yellow-50 dark:bg-yellow-900/20 border-yellow-300 dark:border-yellow-800',
          overdue:
            'bg-red-50 dark:bg-red-900/20 border-red-300 dark:border-red-800',
        }[ticket.sla_status] ||
        'bg-white dark:bg-slate-800 border-slate-75 dark:border-slate-700'
      );
    },
    priorityBadge(p) {
      return (
        {
          low: 'bg-slate-100 text-slate-700 dark:bg-slate-700 dark:text-slate-300',
          medium:
            'bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-300',
          high: 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-300',
          urgent: 'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-300',
        }[p] || 'bg-slate-100 text-slate-700'
      );
    },
    slaBadge(sla) {
      return (
        {
          on_time:
            'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-300',
          at_risk:
            'bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-300',
          overdue: 'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-300',
        }[sla] ||
        'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-300'
      );
    },
    slaText(ticket) {
      if (ticket.sla_status === 'overdue') {
        return this.$t('CASE_TICKETS.SLA_OVERDUE');
      }
      const targetMin = ticket.first_response_at
        ? ticket.resolution_time_target
        : ticket.first_response_time_target;
      if (!targetMin) return '';
      const elapsedMin =
        (Date.now() - new Date(ticket.created_at).getTime()) / 60000;
      const remaining = Math.max(0, targetMin - elapsedMin);
      const h = Math.floor(remaining / 60);
      const m = Math.floor(remaining % 60);
      return h > 0 ? `${h}h ${m}min` : `${m}min`;
    },
    // Prefijo "SLA:" en JS para no dejar texto plano en el template (bare-strings).
    // En 'overdue' el texto ya dice "SLA vencido" → no se duplica el prefijo.
    slaLabel(ticket) {
      const txt = this.slaText(ticket);
      return ticket.sla_status === 'overdue' ? txt : `SLA: ${txt}`;
    },
  },
};
</script>

<template>
  <woot-modal :show="show" :on-close="() => $emit('close')" size="medium">
    <div class="flex flex-col h-auto overflow-auto">
      <woot-modal-header :header-title="headerTitle" />

      <!-- ───────────── Vista LISTA ───────────── -->
      <div
        v-if="view === 'list'"
        class="flex flex-col self-stretch w-full gap-3 pb-8"
      >
        <div v-if="isFetching" class="py-6 text-sm text-center text-slate-400">
          {{ $t('CASE_TICKETS.LIST.LOADING') }}
        </div>

        <div
          v-else-if="!tickets.length"
          class="py-6 text-sm text-center text-slate-400 dark:text-slate-500"
        >
          {{ $t('CASE_TICKETS.MODAL.EMPTY_LIST') }}
        </div>

        <div v-else class="flex flex-col gap-2">
          <div
            v-for="ticket in tickets"
            :key="ticket.id"
            class="flex flex-col gap-2 p-3 border rounded-lg"
            :class="cardClass(ticket)"
          >
            <!-- Badges -->
            <div class="flex flex-wrap gap-1">
              <span
                v-if="ticket.case_type"
                class="px-1.5 py-0.5 text-[11px] font-medium uppercase tracking-wide rounded text-white"
                :style="{ backgroundColor: ticket.case_type.color }"
              >
                {{ ticket.case_type.name }}
              </span>
              <span
                class="px-1.5 py-0.5 text-[11px] font-medium uppercase tracking-wide rounded bg-slate-100 text-slate-800 dark:bg-slate-700 dark:text-slate-300"
              >
                {{ statusLabel(ticket.status) }}
              </span>
              <span
                class="px-1.5 py-0.5 text-[11px] font-medium uppercase tracking-wide rounded"
                :class="priorityBadge(ticket.priority)"
              >
                {{ priorityLabel(ticket.priority) }}
              </span>
              <span
                class="px-1.5 py-0.5 text-[11px] font-medium uppercase tracking-wide rounded"
                :class="slaBadge(ticket.sla_status)"
              >
                {{ slaLabel(ticket) }}
              </span>
            </div>

            <!-- Folio + título -->
            <div class="flex flex-col">
              <span
                v-if="ticket.folio"
                class="font-mono text-xs text-slate-400 dark:text-slate-500"
              >
                {{ ticket.folio }}
              </span>
              <p
                class="m-0 text-sm text-slate-700 dark:text-slate-200 line-clamp-2"
              >
                {{ ticket.title }}
              </p>
            </div>

            <!-- Acciones -->
            <div class="flex items-center gap-1">
              <woot-button
                size="tiny"
                variant="clear"
                color-scheme="secondary"
                @click="openTimeline(ticket)"
              >
                {{ $t('CASE_TICKETS.VIEW_TIMELINE') }}
              </woot-button>

              <div class="relative">
                <woot-button
                  size="tiny"
                  variant="clear"
                  color-scheme="secondary"
                  icon="chevron-down"
                  :is-loading="isTransitioning"
                  :disabled="!validTransitions(ticket).length"
                  @click="toggleTransitionMenu(ticket.id)"
                >
                  {{ $t('CASE_TICKETS.CHANGE_STATUS') }}
                </woot-button>
                <ul
                  v-if="transitionMenuFor === ticket.id"
                  class="absolute left-0 z-50 py-1 mt-1 list-none bg-white border rounded-md shadow-md dark:bg-slate-800 border-slate-100 dark:border-slate-700 min-w-[160px]"
                >
                  <li
                    v-for="s in validTransitions(ticket)"
                    :key="s"
                    class="px-4 py-2 text-sm cursor-pointer text-slate-600 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-slate-700"
                    @click="transitionTo(ticket, s)"
                  >
                    {{ statusLabel(s) }}
                  </li>
                </ul>
              </div>

              <woot-button
                size="tiny"
                variant="clear"
                color-scheme="secondary"
                icon="open"
                @click="openDetail(ticket.id)"
              >
                {{ $t('CASE_TICKETS.MODAL.OPEN_DETAIL') }}
              </woot-button>
            </div>
          </div>
        </div>

        <!-- Crear -->
        <div class="flex justify-end mt-2">
          <woot-button icon="add" @click="goCreate">
            {{ $t('CASE_TICKETS.MODAL.NEW_TICKET') }}
          </woot-button>
        </div>
      </div>

      <!-- ───────────── Vista CREAR ───────────── -->
      <form
        v-else
        class="flex flex-col self-stretch w-full gap-4 pb-8"
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

        <!-- Tab: Datos del ticket -->
        <div v-show="activeTab === 'ticket'" class="grid grid-cols-2 gap-4">
          <!-- Tipo de caso -->
          <label class="flex flex-col gap-1">
            <span
              class="text-sm font-medium text-slate-700 dark:text-slate-300"
            >
              {{ $t('CASE_TICKETS.MODAL.CASE_TYPE_LABEL') }}
            </span>
            <select v-model="form.case_type_id" class="input" required>
              <option v-for="t in types" :key="t.id" :value="t.id">
                {{ t.name }}
              </option>
            </select>
          </label>

          <!-- Tipo ITIL -->
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

          <!-- Título (ancho completo) -->
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
              :placeholder="$t('CASE_TICKETS.MODAL.TITLE_PLACEHOLDER')"
              maxlength="255"
              required
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

          <!-- Prioridad (ancho completo) -->
          <label class="flex flex-col col-span-2 gap-1">
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
              <option
                v-for="(label, key) in priorityOptions"
                :key="key"
                :value="key"
              >
                {{ label }}
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

          <!-- Descripción (ancho completo) -->
          <label class="flex flex-col col-span-2 gap-1">
            <span
              class="text-sm font-medium text-slate-700 dark:text-slate-300"
            >
              {{ $t('CASE_TICKETS.MODAL.DESCRIPTION_LABEL') }}
            </span>
            <textarea
              v-model="form.description"
              class="input"
              rows="2"
              :placeholder="$t('CASE_TICKETS.MODAL.DESCRIPTION_PLACEHOLDER')"
            />
          </label>
        </div>

        <!-- Tab: Campos personalizados (2K) -->
        <div v-show="activeTab === 'custom'">
          <div
            v-if="!selectedTypeFields.length"
            class="py-6 text-sm text-center text-slate-400 dark:text-slate-500"
          >
            {{ $t('CASE_TICKETS.MODAL.NO_CUSTOM_FIELDS') }}
          </div>
          <div v-else class="grid grid-cols-2 gap-4">
            <label
              v-for="field in selectedTypeFields"
              :key="field.id"
              class="flex flex-col gap-1"
              :class="{
                'flex-row items-center gap-2': field.field_type === 'checkbox',
              }"
            >
              <input
                v-if="field.field_type === 'checkbox'"
                v-model="customValues[field.key]"
                type="checkbox"
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

        <!-- Acciones -->
        <div class="flex justify-between gap-2 mt-2">
          <woot-button
            variant="clear"
            color-scheme="secondary"
            icon="chevron-left"
            type="button"
            @click="goList"
          >
            {{ $t('CASE_TICKETS.MODAL.BACK') }}
          </woot-button>
          <woot-button
            type="submit"
            :is-loading="isCreating"
            :disabled="!form.title.trim() || !customFieldsValid"
          >
            {{ $t('CASE_TICKETS.MODAL.SUBMIT') }}
          </woot-button>
        </div>
      </form>
    </div>

    <!-- Timeline del ticket seleccionado -->
    <CaseTimeline
      v-if="showTimeline && timelineTicketId"
      :show="showTimeline"
      :ticket-id="timelineTicketId"
      @close="showTimeline = false"
    />
  </woot-modal>
</template>
