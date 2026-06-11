<!--
  @tickets_cases Fase C
  Modal para crear un ticket INTERNO (agente → agente, sin contacto).
  El solicitante es el usuario actual; se asigna a un agente y/o equipo.
  Incluye naturaleza ITIL y los campos personalizados (2K) del tipo elegido.
-->
<script>
import { mapGetters } from 'vuex';

export default {
  name: 'CaseTicketInternalModal',
  props: {
    show: { type: Boolean, default: false },
  },
  emits: ['close', 'created'],
  data() {
    return {
      form: {
        assignee_id: '',
        team_id: '',
        case_type_id: null,
        ticket_kind: 'service_request',
        title: '',
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
    }),
    ticketKindOptions() {
      return this.$t('CASE_TICKETS.TICKET_KIND');
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
  },
  methods: {
    async onSubmit() {
      try {
        const ticket = await this.$store.dispatch('caseTickets/createTicket', {
          internal: true,
          assignee_id: this.form.assignee_id || undefined,
          team_id: this.form.team_id || undefined,
          case_type_id: this.form.case_type_id,
          ticket_kind: this.form.ticket_kind,
          title: this.form.title.trim(),
          priority: this.form.priority,
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
        <div class="grid grid-cols-2 gap-3 [&_.input]:!mb-0">
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

          <!-- Prioridad -->
          <label class="flex flex-col gap-1">
            <span
              class="text-sm font-medium text-slate-700 dark:text-slate-300"
            >
              {{ $t('CASE_TICKETS.MODAL.PRIORITY_LABEL') }}
            </span>
            <select v-model="form.priority" class="input">
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

          <!-- Campos personalizados (2K) del tipo -->
          <template v-if="selectedTypeFields.length">
            <div
              class="col-span-2 pt-1 mt-1 text-xs font-semibold tracking-wide uppercase border-t text-slate-400 dark:text-slate-500 border-slate-100 dark:border-slate-700"
            >
              {{ $t('CASE_TICKETS.INTERNAL.CUSTOM_FIELDS') }}
            </div>
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
          </template>
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
