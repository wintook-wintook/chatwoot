<script>
// feat/chat_interno (F3) — NUEVO CHAT DIRECTO
// Se elige un agente de la cuenta; si ya existe el chat con él, se abre el mismo.
// Los grupos son los equipos de Chatwoot: no se crean aquí (Ajustes → Equipos).
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';

export default {
  emits: ['close', 'created'],
  data() {
    return { direct: null, saving: false };
  },
  computed: {
    ...mapGetters({
      agents: 'agents/getAgents',
      currentUserId: 'getCurrentUserID',
    }),
    options() {
      return this.agents
        .filter(agent => agent.id !== this.currentUserId)
        .map(agent => ({
          id: agent.id,
          name: agent.available_name || agent.name,
        }));
    },
    canCreate() {
      return !this.saving && Boolean(this.direct);
    },
  },
  methods: {
    async create() {
      if (!this.canCreate) return;
      this.saving = true;
      try {
        const room = await this.$store.dispatch(
          'internalChat/openDirect',
          this.direct.id
        );
        this.$emit('created', room);
      } catch (error) {
        useAlert(this.$t('INTERNAL_CHAT.NEW_ROOM.ERROR'));
      } finally {
        this.saving = false;
      }
    },
  },
};
</script>

<template>
  <woot-modal show :on-close="() => $emit('close')">
    <div class="flex flex-col h-auto overflow-visible">
      <woot-modal-header
        :header-title="$t('INTERNAL_CHAT.NEW_ROOM.TITLE')"
        :header-content="$t('INTERNAL_CHAT.NEW_ROOM.DESCRIPTION')"
      />
      <form class="flex flex-col gap-4 px-8 pb-6" @submit.prevent="create">
        <label>
          {{ $t('INTERNAL_CHAT.NEW_ROOM.AGENT') }}
          <multiselect
            v-model="direct"
            :options="options"
            track-by="id"
            label="name"
            :placeholder="$t('INTERNAL_CHAT.NEW_ROOM.SELECT_PLACEHOLDER')"
            allow-empty
            selected-label=""
            select-label=""
            deselect-label=""
          />
        </label>


        <div class="flex justify-end gap-2">
          <woot-button
            variant="clear"
            color-scheme="secondary"
            @click.prevent="$emit('close')"
          >
            {{ $t('INTERNAL_CHAT.NEW_ROOM.CANCEL') }}
          </woot-button>
          <woot-button :is-disabled="!canCreate" :is-loading="saving">
            {{ $t('INTERNAL_CHAT.NEW_ROOM.CREATE') }}
          </woot-button>
        </div>
      </form>
    </div>
  </woot-modal>
</template>
