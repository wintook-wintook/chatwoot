<!--
  @tickets_cases Fase C
  Modal para crear un ticket INTERNO (agente → agente, sin contacto).
  El solicitante es el usuario actual; se asigna opcionalmente a otro agente.
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
        case_type_id: null,
        ticket_kind: 'service_request',
        title: '',
        priority: 'medium',
        description: '',
      },
    };
  },
  computed: {
    ...mapGetters({
      uiFlags: 'caseTickets/getUIFlags',
      types: 'caseTickets/getTypes',
      agents: 'agents/getAgents',
    }),
    isValid() {
      return this.form.title.trim().length > 0;
    },
  },
  mounted() {
    this.$store.dispatch('caseTickets/fetchTypes').then(() => {
      if (!this.form.case_type_id && this.types.length) {
        this.form.case_type_id = this.types[0].id;
      }
    });
    this.$store.dispatch('agents/get');
  },
  methods: {
    async onSubmit() {
      try {
        const ticket = await this.$store.dispatch('caseTickets/createTicket', {
          internal: true,
          assignee_id: this.form.assignee_id || undefined,
          case_type_id: this.form.case_type_id,
          ticket_kind: this.form.ticket_kind,
          title: this.form.title.trim(),
          priority: this.form.priority,
          description: this.form.description.trim() || undefined,
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
          <!-- Asignar a (agente) -->
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

          <!-- Título (ocupa el espacio restante de la fila) -->
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
