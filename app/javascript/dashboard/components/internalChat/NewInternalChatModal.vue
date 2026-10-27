<script>
// feat/chat_interno (plan v2) — NUEVO CHAT DIRECTO EN «INTERNO»
// Se elige un agente de la cuenta; si ya existe la conversación con él, se abre la misma.
// Los grupos son los equipos de Chatwoot: no se crean aquí (Ajustes → Equipos).
// Mismo molde que los modales nativos (settings/agents/AddAgent.vue): lo envuelve
// <woot-modal> en ChatList.vue y el relleno del <form> lo pone Modal.vue.
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import Thumbnail from 'dashboard/components/widgets/Thumbnail.vue';
import InternalChannelAPI from 'dashboard/api/internalChannel';

export default {
  components: { Thumbnail },
  emits: ['close', 'created'],
  data() {
    return { agent: null, saving: false };
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
          thumbnail: agent.thumbnail,
          availability_status: agent.availability_status,
        }));
    },
    canCreate() {
      return !this.saving && Boolean(this.agent);
    },
  },
  methods: {
    async create() {
      if (!this.canCreate) return;
      this.saving = true;
      try {
        const { data } = await InternalChannelAPI.openDirect(this.agent.id);
        this.$emit('created', data);
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
  <div class="flex flex-col h-auto">
    <woot-modal-header
      :header-title="$t('INTERNAL_CHAT.NEW_ROOM.TITLE')"
      :header-content="$t('INTERNAL_CHAT.NEW_ROOM.DESCRIPTION')"
    />
    <form class="flex flex-col items-start w-full" @submit.prevent="create">
      <!-- El selector va fuera de <label>: dentro, el clic en una opción también
           «activaba» la etiqueta y reabría la lista sin elegir (solo servía Enter). -->
      <div class="w-full">
        <span
          class="block mb-1 text-sm font-medium text-slate-800 dark:text-slate-100"
        >
          {{ $t('INTERNAL_CHAT.NEW_ROOM.AGENT') }}
        </span>
        <multiselect
          v-model="agent"
          :options="options"
          track-by="id"
          label="name"
          :placeholder="$t('INTERNAL_CHAT.NEW_ROOM.SELECT_PLACEHOLDER')"
          selected-label=""
          :select-label="$t('FORMS.MULTISELECT.ENTER_TO_SELECT')"
          :deselect-label="$t('FORMS.MULTISELECT.ENTER_TO_REMOVE')"
          :max-height="240"
          close-on-select
        >
          <template #singleLabel="{ option }">
            <span class="flex items-center gap-2">
              <Thumbnail
                :src="option.thumbnail"
                :username="option.name"
                size="20px"
              />
              {{ option.name }}
            </span>
          </template>
          <template #option="{ option }">
            <span class="flex items-center gap-2">
              <Thumbnail
                :src="option.thumbnail"
                :username="option.name"
                :status="option.availability_status"
                should-show-status-always
                size="24px"
              />
              {{ option.name }}
            </span>
          </template>
        </multiselect>
      </div>

      <div class="flex flex-row justify-end w-full gap-2 px-0 py-2">
        <div class="w-full">
          <woot-submit-button
            :disabled="!canCreate"
            :button-text="$t('INTERNAL_CHAT.NEW_ROOM.CREATE')"
            :loading="saving"
          />
          <button class="button clear" @click.prevent="$emit('close')">
            {{ $t('INTERNAL_CHAT.NEW_ROOM.CANCEL') }}
          </button>
        </div>
      </div>
    </form>
  </div>
</template>
