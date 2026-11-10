<!--
  Seguimiento IA — en qué va (estado, intentos, próximo contacto, última plantilla) y
  pausar / reanudar / cancelar. Se usa en el caso (caseId), en el panel de la conversación
  (conversationId = display_id) y en la ficha del contacto (contactId: el que está corriendo
  en cualquiera de sus conversaciones). El padre llama a set(followUp) al delegar uno nuevo.
-->
<script>
import { useAlert } from 'dashboard/composables';
import AiFollowUpsAPI from 'dashboard/api/aiFollowUps';

const F = 'ASSISTANT.AI_FOLLOW_UP';

export default {
  name: 'AiFollowUpStatus',
  props: {
    caseId: { type: [Number, String], default: null },
    conversationId: { type: [Number, String], default: null },
    contactId: { type: [Number, String], default: null },
  },
  // change(live): true si hay uno corriendo (activo o en pausa) → el botón se pone verde.
  emits: ['change'],
  data() {
    return { followUp: null, busy: false };
  },
  computed: {
    live() {
      return (
        this.followUp && ['active', 'paused'].includes(this.followUp.status)
      );
    },
    tooltip() {
      const fu = this.followUp;
      if (!fu) return '';
      return [
        this.f('STATUS_LINE', { status: this.f(`STATUS.${fu.status}`) }),
        fu.objective,
        fu.outcome,
        fu.last_error && this.f('LAST_ERROR', { error: fu.last_error }),
      ]
        .filter(Boolean)
        .join('\n');
    },
    next() {
      const at = this.followUp && this.followUp.next_run_at;
      return at && this.followUp.status === 'active'
        ? new Date(at).toLocaleString([], {
            dateStyle: 'short',
            timeStyle: 'short',
          })
        : '';
    },
  },
  watch: {
    live: {
      immediate: true,
      handler(value) {
        this.$emit('change', !!value);
      },
    },
    caseId: { immediate: true, handler: 'load' },
    conversationId: 'load',
    contactId: { immediate: true, handler: 'load' },
  },
  methods: {
    f(key, params) {
      return this.$t(`${F}.${key}`, params);
    },
    set(followUp) {
      this.followUp = followUp;
    },
    async load() {
      if (!this.caseId && !this.conversationId && !this.contactId) {
        this.followUp = null;
        return;
      }
      try {
        let request;
        if (this.caseId) request = AiFollowUpsAPI.forCase(this.caseId);
        else if (this.contactId)
          request = AiFollowUpsAPI.forContact(this.contactId);
        else request = AiFollowUpsAPI.forConversation(this.conversationId);
        const { data } = await request;
        this.followUp = (data.payload || [])[0] || null;
      } catch (_e) {
        this.followUp = null;
      }
    },
    async change(action) {
      // eslint-disable-next-line no-alert
      if (action === 'cancel' && !window.confirm(this.f('STOP_CONFIRM')))
        return;
      this.busy = true;
      try {
        const { data } = await AiFollowUpsAPI[action](this.followUp.id);
        this.followUp = data.payload;
      } catch (e) {
        useAlert(e.response?.data?.error || this.f('FAILED'));
      } finally {
        this.busy = false;
      }
    },
  },
};
</script>

<template>
  <!-- Un renglón: estado · intentos · próximo contacto · plantilla, y las acciones como enlaces.
       El objetivo, el resultado y el último problema salen al pasar el mouse. -->
  <div
    v-if="followUp"
    v-tooltip.top="tooltip"
    class="flex items-center w-full min-w-0 gap-1.5 px-2 py-1 text-xs rounded-md bg-slate-50 dark:bg-slate-800"
  >
    <fluent-icon icon="bot" size="14" class="flex-shrink-0 text-woot-600" />
    <span class="min-w-0 truncate text-slate-600 dark:text-slate-300">
      <span class="font-medium text-slate-700 dark:text-slate-200">
        {{ f(`STATUS.${followUp.status}`) }}
      </span>
      <template v-if="contactId">
        · {{ f('IN_CONVERSATION', { id: followUp.conversation_id }) }}
      </template>
      · {{ followUp.attempts }}/{{ followUp.max_attempts }}
      <template v-if="next"> · {{ next }} </template>
      <template v-if="followUp.last_template">
        · {{ followUp.last_template }}
      </template>
    </span>
    <fluent-icon
      v-if="followUp.last_error && live"
      icon="warning"
      size="14"
      class="flex-shrink-0 text-amber-600"
    />
    <div v-if="live" class="flex flex-shrink-0 gap-2 ltr:ml-auto rtl:mr-auto">
      <button
        v-if="followUp.status === 'active'"
        type="button"
        class="text-slate-600 hover:underline dark:text-slate-300"
        :disabled="busy"
        @click="change('pause')"
      >
        {{ f('PAUSE') }}
      </button>
      <button
        v-else
        type="button"
        class="text-woot-600 hover:underline"
        :disabled="busy"
        @click="change('resume')"
      >
        {{ f('RESUME') }}
      </button>
      <button
        type="button"
        class="text-red-600 hover:underline"
        :disabled="busy"
        @click="change('cancel')"
      >
        {{ f('STOP') }}
      </button>
    </div>
  </div>
</template>
