<!--
  «Ligar a un cliente»: un caso interno (se creó sin cliente) pasa a ser de un contacto y su
  organización. Deja de ser interno: aparece en la ficha de la organización y del contacto,
  en su portal y en sus reportes. Quien lo pidió se queda como solicitante.
  Emite `assigned` con el caso ya actualizado.
-->
<script>
import CaseTicketsAPI from 'dashboard/api/caseTickets';
import OrganizationContactFields from 'dashboard/views/organizations/OrganizationContactFields.vue';

export default {
  name: 'AssignClientModal',
  components: { OrganizationContactFields },
  props: {
    show: { type: Boolean, default: false },
    ticket: { type: Object, required: true },
  },
  emits: ['close', 'assigned'],
  data() {
    return { contact: null, organization: null, isSaving: false };
  },
  methods: {
    async submit() {
      if (!this.contact || this.isSaving) return;
      this.isSaving = true;
      try {
        const { data } = await CaseTicketsAPI.assignClient(this.ticket.id, {
          contact_id: this.contact.id,
          organization_id: this.organization?.id || undefined,
        });
        this.$emit('assigned', data.case_ticket);
      } catch (e) {
        this.$emitter.emit('newToastMessage', {
          message:
            e.response?.data?.error ||
            this.$t('CASE_TICKETS.ASSIGN_CLIENT.ERROR'),
        });
      } finally {
        this.isSaving = false;
      }
    },
  },
};
</script>

<template>
  <woot-modal :show="show" :on-close="() => $emit('close')" size="small">
    <div class="flex flex-col h-auto overflow-visible">
      <woot-modal-header
        :header-title="
          $t('CASE_TICKETS.ASSIGN_CLIENT.TITLE', { folio: ticket.folio })
        "
      />
      <form
        class="flex flex-col self-stretch w-full gap-2 pb-8"
        @submit.prevent="submit"
      >
        <p class="m-0 mb-2 text-sm text-slate-600 dark:text-slate-300">
          {{ $t('CASE_TICKETS.ASSIGN_CLIENT.HINT') }}
        </p>
        <OrganizationContactFields
          v-model="contact"
          :organization.sync="organization"
        />
        <div class="flex justify-end gap-2 mt-2">
          <woot-button
            variant="clear"
            color-scheme="secondary"
            type="button"
            @click="$emit('close')"
          >
            {{ $t('CASE_TICKETS.ASSIGN_CLIENT.CANCEL') }}
          </woot-button>
          <woot-button
            type="submit"
            :is-loading="isSaving"
            :disabled="!contact"
          >
            {{ $t('CASE_TICKETS.ASSIGN_CLIENT.CONFIRM') }}
          </woot-button>
        </div>
      </form>
    </div>
  </woot-modal>
</template>
