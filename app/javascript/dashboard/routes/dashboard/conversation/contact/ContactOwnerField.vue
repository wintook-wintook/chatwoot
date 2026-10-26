<!--
  Responsable fijo del contacto: sus conversaciones y casos nuevos van siempre
  con esta persona (ver ContactOwnerAssignment en el servidor). Lo ve quien ve
  el contacto; lo cambia quien tiene «Asignar a otra persona» (`can_edit`).
  Avisa en qué bandejas del contacto no está el responsable: ahí siguen las reglas.
-->
<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import ContactOwnerAPI from 'dashboard/api/contactOwner';

export default {
  name: 'ContactOwnerField',
  props: {
    contactId: { type: Number, required: true },
  },
  data() {
    return { owner: null, canEdit: false, missingInboxes: [], loaded: false };
  },
  computed: {
    ...mapGetters({ agents: 'agents/getAgents' }),
    ownerId() {
      return this.owner ? this.owner.id : '';
    },
  },
  watch: {
    contactId: { immediate: true, handler: 'fetch' },
  },
  mounted() {
    if (!this.agents.length) this.$store.dispatch('agents/get');
  },
  methods: {
    apply(data) {
      this.owner = data.owner;
      this.canEdit = data.can_edit;
      this.missingInboxes = data.missing_inboxes || [];
      this.loaded = true;
    },
    async fetch() {
      if (!this.contactId) return;
      try {
        const { data } = await ContactOwnerAPI.show(this.contactId);
        this.apply(data);
      } catch {
        this.loaded = false;
      }
    },
    async change(event) {
      try {
        const { data } = await ContactOwnerAPI.change(
          this.contactId,
          event.target.value
        );
        this.apply(data);
        useAlert(this.$t('CONTACT_OWNER.SAVED'));
      } catch {
        useAlert(this.$t('CONTACT_OWNER.ERROR'));
        this.fetch();
      }
    },
  },
};
</script>

<template>
  <div v-show="loaded" class="flex flex-col w-full gap-1">
    <div class="flex items-center w-full gap-2">
      <fluent-icon
        icon="person"
        size="16"
        class="flex-shrink-0 text-slate-500 dark:text-slate-400"
      />
      <span
        v-tooltip.left="$t('CONTACT_OWNER.HINT')"
        class="flex-shrink-0 text-sm text-slate-600 dark:text-slate-300"
      >
        {{ $t('CONTACT_OWNER.LABEL') }}
      </span>
      <select
        v-if="canEdit"
        class="h-8 py-0 mb-0 text-sm"
        :value="ownerId"
        @change="change"
      >
        <option value="">{{ $t('CONTACT_OWNER.NONE') }}</option>
        <option v-for="agent in agents" :key="agent.id" :value="agent.id">
          {{ agent.name }}
        </option>
      </select>
      <span
        v-else
        class="text-sm font-medium truncate text-slate-800 dark:text-slate-100"
      >
        {{ owner ? owner.name : $t('CONTACT_OWNER.NONE') }}
      </span>
    </div>
    <p
      v-if="missingInboxes.length"
      class="mb-0 text-xs text-yellow-800 dark:text-yellow-300"
    >
      {{
        $t('CONTACT_OWNER.MISSING_INBOXES', {
          inboxes: missingInboxes.join(', '),
        })
      }}
    </p>
  </div>
</template>
