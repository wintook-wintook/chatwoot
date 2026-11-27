<script>
// Motor 2.0 — 👎 en una respuesta real de un agente 2.0 (solo administradores): se dice qué
// estuvo mal y contesta el mismo entrenador del probador (corrige el agente, señala la fuente o
// lo reporta a Kontrolya). Plan-Motor-Agentes.md §11.8 punto 4.
import { useAlert } from 'dashboard/composables';
import Motor2AgentsAPI from 'dashboard/api/motor2Agents';

export default {
  props: {
    messageId: { type: Number, required: true },
  },
  data() {
    return { open: false, feedback: '', sending: false, answer: null };
  },
  methods: {
    t(key, args) {
      return this.$t(`MOTOR2.REAL.${key}`, args);
    },
    async send() {
      this.sending = true;
      try {
        const { data } = await Motor2AgentsAPI.correctMessage(
          this.messageId,
          this.feedback
        );
        this.answer = data;
      } catch (e) {
        useAlert(e.response?.data?.error || this.t('ERROR'));
      } finally {
        this.sending = false;
      }
    },
    openAgent() {
      this.$router.push({
        name: 'motor2_agent',
        params: { templateId: String(this.answer.template_id) },
        query: { seccion: 'tests' },
      });
    },
  },
};
</script>

<template>
  <div class="mt-1 text-xs">
    <button
      v-if="!open"
      type="button"
      class="opacity-70 hover:opacity-100"
      @click="open = true"
    >
      {{ t('BUTTON') }}
    </button>
    <div
      v-else
      class="p-2 space-y-1 rounded bg-white/80 dark:bg-slate-800 text-slate-800 dark:text-slate-100"
    >
      <template v-if="!answer">
        <span class="block font-medium">{{ t('WHAT_WRONG') }}</span>
        <textarea v-model="feedback" rows="3" class="!mb-0 text-xs" />
        <span class="flex justify-end gap-2">
          <woot-button size="tiny" variant="clear" @click="open = false">
            {{ t('CANCEL') }}
          </woot-button>
          <woot-button
            size="tiny"
            :is-loading="sending"
            :disabled="!feedback.trim()"
            @click="send"
          >
            {{ t('SEND') }}
          </woot-button>
        </span>
      </template>
      <template v-else>
        <span
          v-for="(m, i) in answer.messages || []"
          :key="i"
          class="block whitespace-pre-line"
        >
          {{ m.text }}
        </span>
        <woot-button size="tiny" variant="smooth" @click="openAgent">
          {{ t('OPEN_AGENT') }}
        </woot-button>
      </template>
    </div>
  </div>
</template>
