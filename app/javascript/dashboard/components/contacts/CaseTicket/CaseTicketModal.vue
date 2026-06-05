<!--
  @tickets_cases
  Modal de creación de ticket desde el panel derecho de conversación.
-->
<template>
  <woot-modal :show="show" :on-close="() => $emit('close')" size="small">
    <div class="flex flex-col h-auto overflow-auto">
      <woot-modal-header
        :header-title="$t('CASE_TICKETS.MODAL.TITLE_CREATE')"
      />

      <form class="flex flex-col self-stretch w-full gap-4 pb-8" @submit.prevent="onSubmit">
        <!-- Tipo -->
        <label class="flex flex-col gap-1">
          <span class="text-sm font-medium text-slate-700 dark:text-slate-300">
            {{ $t('CASE_TICKETS.MODAL.CASE_TYPE_LABEL') }}
          </span>
          <select
            v-model="form.case_type_id"
            class="input"
            required
          >
            <option v-for="t in types" :key="t.id" :value="t.id">
              {{ t.name }}
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

        <!-- Prioridad -->
        <label class="flex flex-col gap-1">
          <span class="text-sm font-medium text-slate-700 dark:text-slate-300">
            {{ $t('CASE_TICKETS.MODAL.PRIORITY_LABEL') }}
          </span>
          <select v-model="form.priority" class="input">
            <option v-for="(label, key) in priorityOptions" :key="key" :value="key">
              {{ label }}
            </option>
          </select>
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

<script>
import { mapGetters } from 'vuex';

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
    }),
    isCreating() {
      return this.uiFlags.isCreating;
    },
    priorityOptions() {
      return this.$t('CASE_TICKETS.PRIORITIES');
    },
  },
  mounted() {
    this.$store.dispatch('caseTickets/fetchTypes').then(() => {
      if (!this.form.case_type_id && this.types.length) {
        this.form.case_type_id = this.types[0].id;
      }
    });
  },
  methods: {
    async onSubmit() {
      try {
        const ticket = await this.$store.dispatch('caseTickets/createTicket', {
          contact_id: this.contactId,
          conversation_id: this.conversationId || undefined,
          case_type_id: this.form.case_type_id,
          title: this.form.title.trim(),
          priority: this.form.priority,
          description: this.form.description.trim() || undefined,
        });
        this.$emit('created', ticket);
        this.$emit('close');
        bus.$emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.MODAL.SUCCESS'),
          type: 'success',
        });
      } catch (_e) {
        bus.$emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.MODAL.ERROR'),
          type: 'error',
        });
      }
    },
  },
};
</script>
