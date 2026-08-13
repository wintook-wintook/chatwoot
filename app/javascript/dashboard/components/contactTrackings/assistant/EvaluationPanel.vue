<script>
// ================================================================================
// proyecto@ai_agent_assistant - F7
// ================================================================================
// Componente: EvaluationPanel
// Descripción: El probador en vivo. Ejecuta los motores reales con el envío
//              desconectado y enseña lo que no se puede ver de otra forma:
//
//   · en vivo  — el mensaje inicial de cada intento y la respuesta a lo que
//                escribas, con la ruta del router, el consumo real de tokens
//                contra el tope y «esto habría pasado».
//   · auto     — un segundo modelo hace de cliente y conversa solo, para
//                detectar bucles que probando a mano nunca se ven.
//   · replay   — mensajes REALES de conversaciones cerradas de ese inbox, con la
//                respuesta de la persona al lado. La comparación honesta.
//   · A/B      — el mismo mensaje contra dos versiones del prompt.
//
// Cada pestaña gasta tokens de verdad de la cuenta. Por eso ninguna se dispara
// sola: todas esperan a que se pulse.
// ================================================================================
import AiAgentAssistantAPI from 'dashboard/api/aiAgentAssistant';

export default {
  props: {
    // El borrador tal y como se guardaría. Se prueba lo que hay en pantalla.
    payload: {
      type: Object,
      default: () => ({}),
    },
  },
  data() {
    return {
      tab: 'live',
      attempt: 1,
      message: '',
      turns: [],
      auto: null,
      replayResult: null,
      comparison: null,
      variantPrompt: '',
      isRunning: false,
      error: null,
      persona: 'interested',
      autoTurns: 5,
      replayLimit: 3,
    };
  },
  computed: {
    tabs() {
      return ['live', 'auto', 'replay', 'ab'];
    },
    tabIndex() {
      return Math.max(this.tabs.indexOf(this.tab), 0);
    },
    personas() {
      return ['interested', 'skeptical', 'annoyed', 'confused'];
    },
    // El historial que se manda al motor, como lo vería en una conversación real.
    history() {
      return this.turns
        .map(t => `${t.role === 'agent' ? 'Agente' : 'Cliente'}: ${t.text}`)
        .join('\n');
    },
  },
  methods: {
    // Cambiar de pestaña no borra lo ya corrido: cada prueba costó tokens.
    onTabChange(index) {
      this.tab = this.tabs[index] || 'live';
    },
    body(extra = {}) {
      return { ...this.payload, ...extra };
    },
    async run(request) {
      this.isRunning = true;
      this.error = null;
      try {
        const { data } = await request();
        if (data.error) this.error = data.error;
        return data;
      } catch (e) {
        this.error = 'request_failed';
        return null;
      } finally {
        this.isRunning = false;
      }
    },
    async onOpening() {
      const data = await this.run(() =>
        AiAgentAssistantAPI.simulate(this.body({ attempt: this.attempt }))
      );
      if (data && data.text) this.turns = [{ role: 'agent', ...data }];
    },
    async onSend() {
      const text = this.message.trim();
      if (!text) return;
      this.message = '';
      this.turns.push({ role: 'customer', text });
      const data = await this.run(() =>
        AiAgentAssistantAPI.simulate(
          this.body({ message: text, history: this.history })
        )
      );
      if (data && data.text) this.turns.push({ role: 'agent', ...data });
    },
    async onAuto() {
      this.auto = await this.run(() =>
        AiAgentAssistantAPI.autoConversation(
          this.body({ persona: this.persona, turns: this.autoTurns })
        )
      );
    },
    async onReplay() {
      this.replayResult = await this.run(() =>
        AiAgentAssistantAPI.replay(this.body({ limit: this.replayLimit }))
      );
    },
    async onCompare() {
      const variant = {
        ...this.payload.tracking_template,
        complementary_prompt: this.variantPrompt,
      };
      this.comparison = await this.run(() =>
        AiAgentAssistantAPI.compare(
          this.body({ variant, message: this.message.trim() || undefined })
        )
      );
    },
    onReset() {
      this.turns = [];
      this.auto = null;
      this.replayResult = null;
      this.comparison = null;
      this.error = null;
    },
    budgetClasses(turn) {
      return turn.truncated
        ? 'text-red-700 dark:text-red-300'
        : 'text-slate-500 dark:text-slate-400';
    },
  },
};
</script>

<template>
  <div class="flex flex-col flex-1 min-h-0">
    <div class="flex items-center gap-2 pb-3">
      <woot-tabs
        class="flex-1 [&_.tabs]:p-0 [&_.tabs]:mb-0"
        :index="tabIndex"
        @change="onTabChange"
      >
        <woot-tabs-item
          v-for="option in tabs"
          :key="option"
          :name="$t(`AI_AGENT_ASSISTANT.EVAL.TAB_${option.toUpperCase()}`)"
          :show-badge="false"
        />
      </woot-tabs>
      <woot-button
        size="tiny"
        variant="clear"
        class="ml-auto"
        @click.prevent="onReset"
      >
        {{ $t('AI_AGENT_ASSISTANT.EVAL.RESET') }}
      </woot-button>
    </div>

    <!-- Cada pestaña gasta tokens reales de la cuenta -->
    <p class="mb-3 text-xs text-slate-500 dark:text-slate-400">
      {{ $t('AI_AGENT_ASSISTANT.EVAL.COST_NOTE') }}
    </p>

    <div
      v-if="error"
      class="px-4 py-3 mb-3 text-xs border rounded-lg bg-amber-50 border-amber-200 dark:bg-amber-800/20 dark:border-amber-800 text-amber-800 dark:text-amber-200"
    >
      {{ $t(`AI_AGENT_ASSISTANT.EVAL.ERROR_${error.toUpperCase()}`) }}
    </div>

    <div class="flex-1 min-h-0 overflow-y-auto">
      <!-- ─── En vivo ─────────────────────────────────────────────────── -->
      <template v-if="tab === 'live'">
        <div class="flex items-center gap-2 mb-3">
          <label class="mb-0 text-xs text-slate-500 dark:text-slate-400">
            {{ $t('AI_AGENT_ASSISTANT.EVAL.ATTEMPT') }}
          </label>
          <select v-model.number="attempt" class="w-16 h-8 py-0 mb-0 text-sm">
            <option v-for="n in 3" :key="n" :value="n">{{ n }}</option>
          </select>
          <woot-button
            size="small"
            :is-loading="isRunning"
            @click.prevent="onOpening"
          >
            {{ $t('AI_AGENT_ASSISTANT.EVAL.RUN_OPENING') }}
          </woot-button>
        </div>

        <div v-for="(turn, index) in turns" :key="index" class="mb-3">
          <p
            class="inline-block max-w-[85%] px-3 py-2 m-0 text-sm whitespace-pre-wrap rounded-lg"
            :class="
              turn.role === 'customer'
                ? 'bg-woot-50 text-slate-800 dark:bg-woot-800/40 dark:text-slate-100'
                : 'bg-slate-50 text-slate-700 dark:bg-slate-800 dark:text-slate-200'
            "
          >
            {{ turn.text }}
          </p>
          <div v-if="turn.role === 'agent'" class="mt-1 text-xs">
            <p v-if="turn.route" class="m-0 text-slate-500 dark:text-slate-400">
              {{
                $t('AI_AGENT_ASSISTANT.EVAL.ROUTE', {
                  route: turn.route.route,
                  confidence: turn.route.confidence,
                })
              }}
            </p>
            <p class="m-0" :class="budgetClasses(turn)">
              {{
                $t('AI_AGENT_ASSISTANT.EVAL.TOKENS', {
                  used: turn.tokens_used,
                  max: turn.max_tokens,
                })
              }}
              <span v-if="turn.truncated">
                · {{ $t('AI_AGENT_ASSISTANT.EVAL.TRUNCATED') }}
              </span>
            </p>
            <p
              v-if="turn.keyword_action"
              class="m-0 text-slate-500 dark:text-slate-400"
            >
              {{
                $t('AI_AGENT_ASSISTANT.EVAL.KEYWORD', {
                  keyword: turn.keyword_action.keyword,
                  action: turn.keyword_action.action,
                })
              }}
            </p>
            <p
              v-if="turn.would_have && turn.would_have.length"
              class="m-0 text-slate-500 dark:text-slate-400"
            >
              {{ $t('AI_AGENT_ASSISTANT.EVAL.WOULD_HAVE') }}
              {{
                turn.would_have
                  .map(e => $t(`AI_AGENT_ASSISTANT.EVAL.EFFECT.${e}`))
                  .join(' · ')
              }}
            </p>
          </div>
        </div>

        <div class="flex items-end gap-2 pt-2">
          <textarea
            v-model="message"
            rows="2"
            class="mb-0 text-sm"
            :placeholder="$t('AI_AGENT_ASSISTANT.EVAL.PLACEHOLDER')"
            @keydown.enter.exact.prevent="onSend"
          />
          <woot-button
            :is-loading="isRunning"
            :is-disabled="!message.trim()"
            @click.prevent="onSend"
          >
            {{ $t('AI_AGENT_ASSISTANT.EVAL.SEND') }}
          </woot-button>
        </div>
      </template>

      <!-- ─── Auto-conversación ───────────────────────────────────────── -->
      <template v-else-if="tab === 'auto'">
        <div class="flex flex-wrap items-center gap-2 mb-3">
          <select v-model="persona" class="h-8 py-0 mb-0 text-sm w-44">
            <option v-for="option in personas" :key="option" :value="option">
              {{ $t(`AI_AGENT_ASSISTANT.EVAL.PERSONA.${option}`) }}
            </option>
          </select>
          <select v-model.number="autoTurns" class="w-16 h-8 py-0 mb-0 text-sm">
            <option v-for="n in 8" :key="n" :value="n">{{ n }}</option>
          </select>
          <woot-button
            size="small"
            :is-loading="isRunning"
            @click.prevent="onAuto"
          >
            {{ $t('AI_AGENT_ASSISTANT.EVAL.RUN_AUTO') }}
          </woot-button>
        </div>

        <template v-if="auto">
          <div
            v-if="auto.loop_detected"
            class="px-4 py-3 mb-3 text-xs border rounded-lg bg-red-50 border-red-200 dark:bg-red-800/20 dark:border-red-800 text-red-800 dark:text-red-200"
          >
            {{ $t('AI_AGENT_ASSISTANT.EVAL.LOOP_DETECTED') }}
          </div>
          <p class="mb-2 text-xs text-slate-500 dark:text-slate-400">
            {{
              $t('AI_AGENT_ASSISTANT.EVAL.AUTO_TOKENS', {
                tokens: auto.tokens_used,
              })
            }}
          </p>
          <div v-for="(turn, index) in auto.turns" :key="index" class="mb-2">
            <p
              class="inline-block max-w-[85%] px-3 py-2 m-0 text-sm whitespace-pre-wrap rounded-lg"
              :class="
                turn.role === 'customer'
                  ? 'bg-woot-50 text-slate-800 dark:bg-woot-800/40 dark:text-slate-100'
                  : 'bg-slate-50 text-slate-700 dark:bg-slate-800 dark:text-slate-200'
              "
            >
              {{ turn.text }}
            </p>
          </div>
        </template>
      </template>

      <!-- ─── Replay ──────────────────────────────────────────────────── -->
      <template v-else-if="tab === 'replay'">
        <div class="flex items-center gap-2 mb-3">
          <label class="mb-0 text-xs text-slate-500 dark:text-slate-400">
            {{ $t('AI_AGENT_ASSISTANT.EVAL.REPLAY_LIMIT') }}
          </label>
          <select
            v-model.number="replayLimit"
            class="w-16 h-8 py-0 mb-0 text-sm"
          >
            <option v-for="n in 5" :key="n" :value="n">{{ n }}</option>
          </select>
          <woot-button
            size="small"
            :is-loading="isRunning"
            @click.prevent="onReplay"
          >
            {{ $t('AI_AGENT_ASSISTANT.EVAL.RUN_REPLAY') }}
          </woot-button>
        </div>

        <div
          v-for="(item, index) in replayResult ? replayResult.cases : []"
          :key="index"
          class="p-3 mb-3 border rounded-lg border-slate-100 dark:border-slate-700"
        >
          <p
            class="m-0 text-xs font-semibold text-slate-500 dark:text-slate-400"
          >
            {{ $t('AI_AGENT_ASSISTANT.EVAL.CUSTOMER_SAID') }}
          </p>
          <p
            class="mt-1 mb-3 text-sm whitespace-pre-wrap text-slate-800 dark:text-slate-100"
          >
            {{ item.customer }}
          </p>
          <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
            <div>
              <p
                class="m-0 text-xs font-semibold text-slate-500 dark:text-slate-400"
              >
                {{ $t('AI_AGENT_ASSISTANT.EVAL.HUMAN_SAID') }}
              </p>
              <p
                class="mt-1 mb-0 text-xs whitespace-pre-wrap text-slate-700 dark:text-slate-200"
              >
                {{ item.human }}
              </p>
            </div>
            <div>
              <p
                class="m-0 text-xs font-semibold text-slate-500 dark:text-slate-400"
              >
                {{ $t('AI_AGENT_ASSISTANT.EVAL.AGENT_WOULD_SAY') }}
              </p>
              <p
                class="mt-1 mb-0 text-xs whitespace-pre-wrap text-slate-700 dark:text-slate-200"
              >
                {{ item.agent }}
              </p>
            </div>
          </div>
        </div>
      </template>

      <!-- ─── A/B ─────────────────────────────────────────────────────── -->
      <template v-else>
        <p class="mb-2 text-xs text-slate-500 dark:text-slate-400">
          {{ $t('AI_AGENT_ASSISTANT.EVAL.AB_HINT') }}
        </p>
        <textarea
          v-model="variantPrompt"
          rows="6"
          class="mb-2 text-sm font-mono"
          :placeholder="$t('AI_AGENT_ASSISTANT.EVAL.VARIANT_PLACEHOLDER')"
        />
        <div class="flex items-end gap-2 mb-3">
          <textarea
            v-model="message"
            rows="2"
            class="mb-0 text-sm"
            :placeholder="$t('AI_AGENT_ASSISTANT.EVAL.PLACEHOLDER')"
          />
          <woot-button
            :is-loading="isRunning"
            :is-disabled="!variantPrompt.trim()"
            @click.prevent="onCompare"
          >
            {{ $t('AI_AGENT_ASSISTANT.EVAL.RUN_COMPARE') }}
          </woot-button>
        </div>

        <div v-if="comparison" class="grid grid-cols-1 gap-3 sm:grid-cols-2">
          <div
            v-for="side in ['a', 'b']"
            :key="side"
            class="p-3 border rounded-lg border-slate-100 dark:border-slate-700"
          >
            <p
              class="m-0 text-xs font-semibold text-slate-500 dark:text-slate-400"
            >
              {{ $t(`AI_AGENT_ASSISTANT.EVAL.SIDE_${side.toUpperCase()}`) }}
            </p>
            <p
              class="mt-1 mb-1 text-sm whitespace-pre-wrap text-slate-800 dark:text-slate-100"
            >
              {{ comparison[side].text }}
            </p>
            <p class="m-0 text-xs" :class="budgetClasses(comparison[side])">
              {{
                $t('AI_AGENT_ASSISTANT.EVAL.TOKENS', {
                  used: comparison[side].tokens_used,
                  max: comparison[side].max_tokens,
                })
              }}
            </p>
          </div>
        </div>
      </template>
    </div>
  </div>
</template>
