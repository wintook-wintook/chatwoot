<!--
  @tickets_cases
  Modal de creación de ticket desde el panel derecho de conversación.
  2B: incluye clasificación ITIL (tipo, servicio afectado, categoría, impacto/urgencia
  con previsualización de prioridad derivada por matriz).
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
  name: 'CaseTicketModal',
  props: {
    show: { type: Boolean, default: false },
    contactId: { type: [Number, String], required: true },
    conversationId: { type: [Number, String], default: null },
  },
  emits: ['close', 'created'],
  data() {
    return {
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
    };
  },
  computed: {
    ...mapGetters({
      uiFlags: 'caseTickets/getUIFlags',
      types: 'caseTickets/getTypes',
      services: 'caseTickets/getServices',
      categories: 'caseTickets/getCategories',
    }),
    isCreating() {
      return this.uiFlags.isCreating;
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
  },
  mounted() {
    this.$store.dispatch('caseTickets/fetchTypes').then(() => {
      if (!this.form.case_type_id && this.types.length) {
        this.form.case_type_id = this.types[0].id;
      }
    });
    this.$store.dispatch('caseTickets/fetchServices');
    this.$store.dispatch('caseTickets/fetchCategories');
  },
  methods: {
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
        });
        this.$emit('created', ticket);
        this.$emit('close');
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.MODAL.SUCCESS'),
          type: 'success',
        });
      } catch (_e) {
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.MODAL.ERROR'),
          type: 'error',
        });
      }
    },
  },
};
</script>

<template>
  <woot-modal :show="show" :on-close="() => $emit('close')" size="small">
    <div class="flex flex-col h-auto overflow-auto">
      <woot-modal-header
        :header-title="$t('CASE_TICKETS.MODAL.TITLE_CREATE')"
      />

      <form
        class="flex flex-col self-stretch w-full gap-4 pb-8"
        @submit.prevent="onSubmit"
      >
        <!-- Tipo de caso (área de negocio) -->
        <label class="flex flex-col gap-1">
          <span class="text-sm font-medium text-slate-700 dark:text-slate-300">
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
          <span class="text-sm font-medium text-slate-700 dark:text-slate-300">
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
        <label class="flex flex-col gap-1">
          <span class="text-sm font-medium text-slate-700 dark:text-slate-300">
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

        <!-- Servicio afectado + Categoría -->
        <div class="flex gap-3">
          <label class="flex flex-col flex-1 gap-1">
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
          <label class="flex flex-col flex-1 gap-1">
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
        </div>

        <!-- Impacto + Urgencia -->
        <div class="flex gap-3">
          <label class="flex flex-col flex-1 gap-1">
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
          <label class="flex flex-col flex-1 gap-1">
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
        </div>

        <!-- Prioridad: manual, o derivada de la matriz cuando hay impacto+urgencia -->
        <label class="flex flex-col gap-1">
          <span class="text-sm font-medium text-slate-700 dark:text-slate-300">
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

        <!-- Descripción -->
        <label class="flex flex-col gap-1">
          <span class="text-sm font-medium text-slate-700 dark:text-slate-300">
            {{ $t('CASE_TICKETS.MODAL.DESCRIPTION_LABEL') }}
          </span>
          <textarea
            v-model="form.description"
            class="input"
            rows="3"
            :placeholder="$t('CASE_TICKETS.MODAL.DESCRIPTION_PLACEHOLDER')"
          />
        </label>

        <!-- Acciones -->
        <div class="flex justify-end gap-2 mt-2">
          <woot-button
            variant="clear"
            color-scheme="secondary"
            type="button"
            @click="$emit('close')"
          >
            {{ $t('CASE_TICKETS.MODAL.CANCEL') }}
          </woot-button>
          <woot-button
            type="submit"
            :is-loading="isCreating"
            :disabled="!form.title.trim()"
          >
            {{ $t('CASE_TICKETS.MODAL.SUBMIT') }}
          </woot-button>
        </div>
      </form>
    </div>
  </woot-modal>
</template>
