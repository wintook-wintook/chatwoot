<script>
// Probador de agentes › Revisión (quien entrena). Quien probó solo dijo qué debió responder; aquí
// se ve, plática por plática y mensaje por mensaje, la respuesta mala, lo que debió responder, el
// diagnóstico (que corrió aparte) y los arreglos de un clic. Acciones: «Corregido · probar de
// nuevo» (uno o todos los que apuntan a la misma respuesta), «No es error» y «Otro diagnóstico».
import { useAlert } from 'dashboard/composables';
import AgentTesterAPI from 'dashboard/api/agentTester';

const ICONS = {
  pending: '⏳',
  prompt: '✏️',
  content: '📚',
  search: '🔎',
  category: '🏷️',
  model: '🧠',
  engine: '🔧',
  question: '❓',
};
const POLL_MS = 5000;

export default {
  props: {
    agents: { type: Array, default: () => [] },
  },
  emits: ['changed'],
  data() {
    return {
      status: 'open',
      templateId: '',
      groups: [],
      loading: false,
      open: null,
      detail: null,
      notes: {},
      timer: null,
    };
  },
  computed: {
    diagnosing() {
      return (this.detail?.messages || []).some(m =>
        (m.logs || []).some(l => l.diagnosing && !l.error)
      );
    },
  },
  watch: {
    status() {
      this.load();
    },
    templateId() {
      this.load();
    },
  },
  mounted() {
    this.load();
    // Mientras un diagnóstico corre, la plática abierta se actualiza sola.
    this.timer = setInterval(() => {
      if (this.open && this.diagnosing) this.loadDetail(this.open);
    }, POLL_MS);
  },
  beforeDestroy() {
    clearInterval(this.timer);
  },
  methods: {
    t(key, args) {
      return this.$t(`AGENT_TESTER.REVIEW.${key}`, args);
    },
    icon(kind) {
      return ICONS[kind] || '🎓';
    },
    when(date) {
      return date ? new Date(date).toLocaleString() : '';
    },
    errorText(e) {
      const data = e && e.response ? e.response.data : null;
      return (data && data.error) || this.t('ERROR');
    },
    async load() {
      this.loading = true;
      try {
        const { data } = await AgentTesterAPI.review({
          status: this.status,
          template_id: this.templateId || undefined,
        });
        this.groups = data.conversations || [];
      } catch (e) {
        useAlert(this.errorText(e));
      } finally {
        this.loading = false;
      }
    },
    async select(group) {
      if (this.open === group.conversation_id) {
        this.open = null;
        this.detail = null;
        return;
      }
      this.open = group.conversation_id;
      await this.loadDetail(group.conversation_id);
    },
    async loadDetail(conversationId) {
      try {
        const { data } =
          await AgentTesterAPI.reviewConversation(conversationId);
        this.detail = data;
      } catch (e) {
        useAlert(this.errorText(e));
      }
    },
    async refresh() {
      await Promise.all([this.load(), this.open && this.loadDetail(this.open)]);
      this.$emit('changed');
    },
    async act(call) {
      try {
        await call();
        await this.refresh();
      } catch (e) {
        useAlert(this.errorText(e));
      }
    },
    retest(log) {
      return this.act(() => AgentTesterAPI.retest(log.id));
    },
    retestSame(log) {
      return this.act(() =>
        AgentTesterAPI.retestGroup([log.id, ...(log.same_canned || [])])
      );
    },
    dismiss(log) {
      const reason = (this.notes[log.id] || '').trim();
      return this.act(() => AgentTesterAPI.dismiss(log.id, reason));
    },
    rediagnose(log) {
      const note = (this.notes[log.id] || '').trim();
      return this.act(() => AgentTesterAPI.rediagnose(log.id, note));
    },
    fixKind(log) {
      return this.act(() =>
        AgentTesterAPI.fixKind(
          log.diagnosis.canned_id,
          log.diagnosis.should_kind
        )
      );
    },
    fixStart(log) {
      return this.act(() =>
        AgentTesterAPI.fixStart(log.diagnosis.canned_id, log.diagnosis.add)
      );
    },
    apply(log) {
      return this.act(() => AgentTesterAPI.apply(log.id));
    },
    copy(text) {
      if (navigator.clipboard) navigator.clipboard.writeText(text);
      useAlert(this.$t('AGENT_TESTER.COPIED'));
    },
    openCanned(cannedId) {
      const route = { name: 'canned_list', query: { fix: String(cannedId) } };
      window.open(this.$router.resolve(route).href, '_blank');
    },
    kindName(kind) {
      return this.$t(`CANNED_MGMT.KIND.${(kind || 'general').toUpperCase()}`);
    },
    // Lo que se puede copiar o aplicar del diagnóstico.
    suggestion(log) {
      const d = log.diagnosis || {};
      return log.kind === 'search' ? d.add || '' : d.suggestion || '';
    },
    ratingText(rating) {
      return { down: '· 👎', up: '· 👍' }[rating] || '';
    },
    statusClass(status) {
      return {
        pending: 'bg-amber-50 text-amber-800',
        retesting: 'bg-slate-100 text-slate-700',
        passed: 'bg-green-50 text-green-800',
        failing: 'bg-red-50 text-red-800',
        dismissed: 'bg-slate-50 text-slate-500',
      }[status];
    },
  },
};
</script>

<template>
  <div class="space-y-3 max-w-5xl">
    <p class="m-0 text-sm text-slate-500">{{ t('HINT') }}</p>
    <div class="flex flex-wrap items-center gap-2">
      <select v-model="templateId" class="!mb-0 h-9 text-sm w-64">
        <option value="">{{ t('ALL_AGENTS') }}</option>
        <option v-for="a in agents" :key="a.id" :value="a.id">
          {{ a.name }}
        </option>
      </select>
      <woot-button
        size="tiny"
        :variant="status === 'open' ? 'smooth' : 'clear'"
        @click="status = 'open'"
      >
        {{ t('OPEN') }}
      </woot-button>
      <woot-button
        size="tiny"
        :variant="status === 'all' ? 'smooth' : 'clear'"
        @click="status = 'all'"
      >
        {{ t('ALL') }}
      </woot-button>
    </div>
    <p v-if="!loading && !groups.length" class="text-sm text-slate-500">
      {{ t('EMPTY') }}
    </p>
    <div
      v-for="group in groups"
      :key="group.conversation_id"
      class="border rounded-lg border-slate-100 dark:border-slate-700"
    >
      <button
        type="button"
        class="flex items-center w-full gap-3 p-3 text-left"
        @click="select(group)"
      >
        <span class="flex-1 text-sm">
          <span class="block font-medium">{{
            t('CHAT_TITLE', { agent: group.agent, tester: group.tester || '—' })
          }}</span>
          <span class="block text-xs text-slate-500">{{
            when(group.last_at)
          }}</span>
        </span>
        <span
          class="text-xs font-semibold"
          :class="group.open ? 'text-amber-700' : 'text-green-700'"
        >
          {{ t('COUNT', { open: group.open, total: group.total }) }}
        </span>
      </button>

      <div
        v-if="open === group.conversation_id && detail"
        class="p-3 space-y-2 border-t border-slate-100 dark:border-slate-700"
      >
        <div
          v-for="m in detail.messages"
          :key="m.id"
          class="text-sm"
          :class="m.role === 'user' ? 'text-slate-700' : ''"
        >
          <div
            class="px-3 py-2 rounded-lg whitespace-pre-line"
            :class="
              m.role === 'user'
                ? 'bg-slate-50 dark:bg-slate-800'
                : 'bg-woot-25 dark:bg-woot-900/30'
            "
          >
            <span class="block text-[11px] text-slate-500">
              {{ m.role === 'user' ? t('CUSTOMER') : t('AGENT') }}
              {{ ratingText(m.rating) }}
            </span>
            {{ m.content }}
            <span
              v-for="(line, j) in m.lines || []"
              :key="j"
              class="block mt-1 text-[11px] text-slate-500"
              >{{ line }}</span
            >
          </div>

          <div
            v-for="log in m.logs"
            :key="log.id"
            class="p-2 mt-1 ml-4 text-xs border-l-2 border-amber-300 space-y-1"
          >
            <span class="block font-medium">{{
              t('SHOULD', { text: log.feedback })
            }}</span>
            <span v-if="log.note" class="block text-slate-600">{{
              t('NOTE', { text: log.note })
            }}</span>
            <span
              class="inline-block px-1 rounded"
              :class="statusClass(log.status)"
              >{{ t(`STATUS.${log.status}`) }}</span
            >
            <span v-if="log.dismissed_reason" class="block text-slate-500">{{
              t('DISMISSED_REASON', { text: log.dismissed_reason })
            }}</span>

            <span v-if="log.diagnosing && !log.error" class="block">
              {{ icon('pending') }} {{ t('DIAGNOSING') }}
            </span>
            <span v-else-if="log.error" class="block text-red-700">{{
              log.error
            }}</span>
            <span v-else class="block">
              {{ icon(log.kind) }} {{ log.diagnosis.text }}
            </span>

            <span
              v-if="suggestion(log)"
              class="block p-2 whitespace-pre-line rounded bg-white dark:bg-slate-900"
              >{{ suggestion(log) }}</span
            >

            <span
              v-if="log.status !== 'dismissed'"
              class="flex flex-wrap gap-2 pt-1"
            >
              <woot-button
                v-if="
                  log.kind === 'category' &&
                  log.diagnosis.can_fix &&
                  log.diagnosis.current_kind !== log.diagnosis.should_kind
                "
                size="tiny"
                @click="fixKind(log)"
              >
                {{
                  $t('AGENT_TESTER.CHANGE_KIND', {
                    kind: kindName(log.diagnosis.should_kind),
                  })
                }}
              </woot-button>
              <woot-button
                v-if="log.kind === 'search' && log.diagnosis.can_fix"
                size="tiny"
                @click="fixStart(log)"
              >
                {{ $t('AGENT_TESTER.ADD_AT_START') }}
              </woot-button>
              <woot-button
                v-if="log.kind === 'prompt' && log.engine === '2'"
                size="tiny"
                @click="apply(log)"
              >
                {{ $t('AGENT_TESTER.APPLY') }}
              </woot-button>
              <woot-button
                v-if="suggestion(log)"
                size="tiny"
                variant="smooth"
                @click="copy(suggestion(log))"
              >
                {{ $t('AGENT_TESTER.COPY') }}
              </woot-button>
              <woot-button
                v-if="log.canned_id"
                size="tiny"
                variant="smooth"
                color-scheme="secondary"
                @click="openCanned(log.canned_id)"
              >
                {{ $t('AGENT_TESTER.OPEN_CANNED') }}
              </woot-button>
              <woot-button
                v-if="log.has_case && log.status !== 'retesting'"
                size="tiny"
                variant="smooth"
                @click="retest(log)"
              >
                {{ t('RETEST') }}
              </woot-button>
              <woot-button
                v-if="
                  log.has_case &&
                  log.same_canned &&
                  log.same_canned.length &&
                  log.status !== 'retesting'
                "
                size="tiny"
                variant="smooth"
                @click="retestSame(log)"
              >
                {{ t('RETEST_SAME', { n: log.same_canned.length + 1 }) }}
              </woot-button>
            </span>

            <span
              v-if="log.status !== 'dismissed'"
              class="flex flex-wrap items-center gap-2"
            >
              <input
                type="text"
                class="flex-1 !mb-0 h-7 text-xs min-w-[12rem]"
                :value="notes[log.id] || ''"
                :placeholder="t('NOTE_PH')"
                @input="$set(notes, log.id, $event.target.value)"
              />
              <woot-button size="tiny" variant="clear" @click="rediagnose(log)">
                {{ t('REDIAGNOSE') }}
              </woot-button>
              <woot-button
                size="tiny"
                variant="clear"
                color-scheme="secondary"
                @click="dismiss(log)"
              >
                {{ t('DISMISS') }}
              </woot-button>
            </span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
