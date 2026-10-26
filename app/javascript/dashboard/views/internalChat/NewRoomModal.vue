<script>
// feat/chat_interno (F3) — NUEVO CHAT: DIRECTO O GRUPO
// Directo: un agente (si ya existe el chat con él, se abre el mismo). Grupo: nombre y
// varios agentes; quien lo crea queda de dueño. La lista son los agentes de la cuenta.
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';

export default {
  emits: ['close', 'created'],
  data() {
    return {
      mode: 'direct',
      direct: null,
      groupName: '',
      groupMembers: [],
      saving: false,
    };
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
      if (this.saving) return false;
      if (this.mode === 'direct') return Boolean(this.direct);
      return this.groupName.trim().length > 0 && this.groupMembers.length > 0;
    },
  },
  methods: {
    async create() {
      if (!this.canCreate) return;
      this.saving = true;
      try {
        const room =
          this.mode === 'direct'
            ? await this.$store.dispatch(
                'internalChat/openDirect',
                this.direct.id
              )
            : await this.$store.dispatch('internalChat/createGroup', {
                name: this.groupName.trim(),
                userIds: this.groupMembers.map(member => member.id),
              });
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
        <div class="flex gap-2">
          <woot-button
            v-for="option in ['direct', 'group']"
            :key="option"
            size="small"
            :variant="mode === option ? 'smooth' : 'clear'"
            :color-scheme="mode === option ? 'primary' : 'secondary'"
            @click.prevent="mode = option"
          >
            {{ $t(`INTERNAL_CHAT.NEW_ROOM.${option.toUpperCase()}`) }}
          </woot-button>
        </div>

        <label v-if="mode === 'direct'">
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

        <template v-else>
          <label>
            {{ $t('INTERNAL_CHAT.NEW_ROOM.GROUP_NAME') }}
            <input
              v-model="groupName"
              type="text"
              maxlength="80"
              :placeholder="$t('INTERNAL_CHAT.NEW_ROOM.GROUP_NAME_PLACEHOLDER')"
            />
          </label>
          <label>
            {{ $t('INTERNAL_CHAT.NEW_ROOM.AGENTS') }}
            <multiselect
              v-model="groupMembers"
              :options="options"
              track-by="id"
              label="name"
              multiple
              :close-on-select="false"
              :placeholder="$t('INTERNAL_CHAT.NEW_ROOM.SELECT_PLACEHOLDER')"
              selected-label=""
              select-label=""
              deselect-label=""
            />
          </label>
        </template>

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
