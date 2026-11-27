<!--
  Campaña con Vendedor IA — «Probar»: tú eres el contacto que contesta el primer mensaje; el vendedor contesta con
  la oferta de esta campaña (sin guardar ni mandar nada). payload(): { template_id, brief }.
  explain(kind): desde «Simular», qué pasaría en la campaña con esa decisión (relevo a…, sale de la campaña…).
-->
<script>
import Motor2CampaignsAPI from 'dashboard/api/motor2Campaigns';

export default {
  name: 'CampaignChat',
  props: {
    payload: { type: Function, required: true },
    opener: { type: String, default: '' },
    disabled: { type: Boolean, default: false },
    explain: { type: Function, default: null },
  },
  data() {
    return { chat: [], chatState: {}, draft: '', testing: false };
  },
  watch: {
    // Otro toque como punto de partida: la plática empieza de nuevo.
    opener() {
      this.reset();
    },
  },
  methods: {
    t(key, params) {
      return this.$t(`CAMPAIGNS2.CHAT.${key}`, params);
    },
    reset() {
      this.chat = [];
      this.chatState = {};
    },
    async send() {
      const text = this.draft.trim();
      if (!text || this.testing || this.disabled) return;
      this.chat.push({ role: 'user', content: text });
      this.draft = '';
      this.testing = true;
      try {
        const opener = this.opener.trim()
          ? [{ role: 'assistant', content: this.opener.trim() }]
          : [];
        const { data } = await Motor2CampaignsAPI.test({
          ...this.payload(),
          state: this.chatState,
          messages: [
            ...opener,
            ...this.chat
              .filter(m => ['user', 'assistant'].includes(m.role))
              .map(({ role, content }) => ({ role, content })),
          ],
        });
        this.chatState = data.state || this.chatState;
        this.chat.push({
          role: 'assistant',
          content: data.reply || this.t('NO_MESSAGE'),
          decision: data.decision,
          tools: data.tools || [],
          previews: data.previews || [],
        });
      } catch (e) {
        this.chat.push({
          role: 'error',
          content: e.response?.data?.error || this.t('ERROR'),
        });
      } finally {
        this.testing = false;
        this.$nextTick(() => {
          const box = this.$refs.box;
          if (box) box.scrollTop = box.scrollHeight;
        });
      }
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col min-h-0 border rounded-md border-slate-100 dark:border-slate-700"
  >
    <div
      class="flex items-center justify-between px-3 py-2 border-b border-slate-100 dark:border-slate-700"
    >
      <span class="text-sm font-medium text-slate-800 dark:text-slate-100">
        {{ t('TITLE') }}
      </span>
      <button
        type="button"
        class="text-xs text-woot-600 hover:underline"
        @click="reset"
      >
        {{ t('RESET') }}
      </button>
    </div>
    <div
      ref="box"
      class="flex flex-col flex-1 gap-2 p-3 overflow-y-auto min-h-[12rem]"
    >
      <p v-if="disabled" class="m-0 text-xs text-amber-700">
        {{ t('NEEDS_SELLER') }}
      </p>
      <div
        v-if="opener.trim()"
        class="self-start max-w-[85%] p-2 text-sm rounded-lg bg-slate-50 dark:bg-slate-700 whitespace-pre-line"
      >
        {{ opener }}
      </div>
      <div
        v-for="(m, i) in chat"
        :key="i"
        class="max-w-[85%] p-2 text-sm rounded-lg whitespace-pre-line"
        :class="{
          'self-end bg-woot-50 dark:bg-woot-800': m.role === 'user',
          'self-start bg-slate-50 dark:bg-slate-700': m.role === 'assistant',
          'self-start text-red-600': m.role === 'error',
        }"
      >
        <span>{{ m.content }}</span>
        <span
          v-if="m.decision"
          class="block mt-1 text-[11px] font-medium text-woot-700"
        >
          {{ t('DECISION', { decision: m.decision[0] || m.decision }) }}
        </span>
        <span
          v-if="m.decision && explain && explain(m.decision[0])"
          class="block mt-0.5 text-[11px] text-slate-600 dark:text-slate-300"
        >
          {{ explain(m.decision[0]) }}
        </span>
        <span
          v-if="(m.previews || []).length"
          class="flex flex-wrap gap-2 mt-1"
        >
          <img
            v-for="file in m.previews.filter(f => f.image)"
            :key="file.url"
            :src="file.url"
            :alt="file.name"
            class="object-cover w-24 h-24 rounded-md"
          />
        </span>
      </div>
      <p v-if="testing" class="m-0 text-xs text-slate-500">
        {{ t('THINKING') }}
      </p>
    </div>
    <form
      class="flex gap-2 p-2 border-t border-slate-100 dark:border-slate-700"
      @submit.prevent="send"
    >
      <input
        v-model="draft"
        type="text"
        class="flex-1 !mb-0"
        :disabled="disabled"
        :placeholder="t('PLACEHOLDER')"
      />
      <woot-button size="small" :is-loading="testing" :disabled="disabled">
        {{ t('SEND') }}
      </woot-button>
    </form>
  </div>
</template>
