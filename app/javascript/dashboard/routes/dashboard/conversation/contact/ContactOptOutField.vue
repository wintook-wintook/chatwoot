<!--
  prospeccion V4 — «no contactar»: el contacto pidió no volver a ser contactado (por el
  enlace del correo, respondiendo o porque un agente lo marcó). Mientras lo tenga, ninguna
  campaña lo inscribe y sus seguimientos quedan cancelados. Aquí se ve y se marca o se quita.
-->
<script>
import { useAlert } from 'dashboard/composables';
import ContactOptOutAPI from 'dashboard/api/contactOptOut';

export default {
  name: 'ContactOptOutField',
  props: {
    contact: { type: Object, required: true },
  },
  data() {
    return { busy: false };
  },
  computed: {
    optedOut() {
      return !!this.contact.opted_out_at;
    },
    detail() {
      const date = new Date(
        this.contact.opted_out_at * 1000
      ).toLocaleDateString('es-MX', {
        day: '2-digit',
        month: 'short',
        year: 'numeric',
      });
      const source = this.$t(
        `CONTACT_OPT_OUT.SOURCE.${this.contact.opted_out_source || 'agent'}`
      );
      return `${date} · ${source}`;
    },
  },
  methods: {
    async run(action, done) {
      this.busy = true;
      try {
        await ContactOptOutAPI[action](this.contact.id);
        await this.$store.dispatch('contacts/show', { id: this.contact.id });
        useAlert(this.$t(done));
      } catch {
        useAlert(this.$t('CONTACT_OPT_OUT.ERROR'));
      } finally {
        this.busy = false;
      }
    },
    mark() {
      this.run('mark', 'CONTACT_OPT_OUT.MARKED');
    },
    undo() {
      this.run('undo', 'CONTACT_OPT_OUT.UNDONE');
    },
  },
};
</script>

<template>
  <div class="w-full">
    <div
      v-if="optedOut"
      class="flex items-start w-full gap-2 p-2 rounded-md bg-red-50 dark:bg-red-900/20 text-red-800 dark:text-red-200"
    >
      <fluent-icon
        icon="dismiss-circle"
        size="16"
        class="flex-shrink-0 mt-0.5"
      />
      <div class="flex-1 min-w-0 text-sm">
        <p class="mb-0 font-medium">{{ $t('CONTACT_OPT_OUT.LABEL') }}</p>
        <p class="mb-0 text-xs">{{ detail }}</p>
      </div>
      <woot-button
        size="tiny"
        variant="clear"
        color-scheme="secondary"
        :is-loading="busy"
        @click="undo"
      >
        {{ $t('CONTACT_OPT_OUT.UNDO') }}
      </woot-button>
    </div>
    <woot-button
      v-else
      v-tooltip.left="$t('CONTACT_OPT_OUT.HINT')"
      size="tiny"
      variant="clear"
      color-scheme="secondary"
      icon="dismiss-circle"
      :is-loading="busy"
      @click="mark"
    >
      {{ $t('CONTACT_OPT_OUT.MARK') }}
    </woot-button>
  </div>
</template>
