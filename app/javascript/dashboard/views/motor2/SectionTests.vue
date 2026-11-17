<script>
// Motor 2.0 › Pruebas: las pláticas guardadas (a mano o al corregir un 👎) con lo que se espera.
// «Correr todas» vuelve a contestar cada una y un juez dice si cumple. El entrenador las corre
// antes de aplicar un cambio.
import { useAlert } from 'dashboard/composables';
import Motor2AgentsAPI from 'dashboard/api/motor2Agents';

export default {
  props: {
    templateId: { type: Number, default: null },
    stamp: { type: [String, Number], default: '' },
  },
  data() {
    return { tests: [], loading: false, running: null, editing: null };
  },
  computed: {
    passed() {
      return this.tests.filter(t => t.last_run && t.last_run.ok).length;
    },
  },
  watch: {
    stamp() {
      this.load();
    },
  },
  mounted() {
    this.load();
  },
  methods: {
    t(key, args) {
      return this.$t(`MOTOR2.TESTS.${key}`, args);
    },
    async load() {
      if (!this.templateId) return;
      this.loading = true;
      try {
        const { data } = await Motor2AgentsAPI.tests(this.templateId);
        this.tests = data;
      } finally {
        this.loading = false;
      }
    },
    async run(test = null) {
      this.running = test ? test.id : 'all';
      try {
        const { data } = await Motor2AgentsAPI.runTests(
          this.templateId,
          test && test.id
        );
        data.forEach(updated => {
          const i = this.tests.findIndex(item => item.id === updated.id);
          if (i >= 0) this.$set(this.tests, i, updated);
        });
      } catch (e) {
        useAlert(e.response?.data?.error || this.t('ERROR'));
      } finally {
        this.running = null;
      }
    },
    async remove(test) {
      await Motor2AgentsAPI.deleteTest(this.templateId, test.id);
      this.tests = this.tests.filter(item => item.id !== test.id);
    },
    status(test) {
      if (!test.last_run || test.last_run.ok === undefined) return 'never';
      return test.last_run.ok ? 'ok' : 'fail';
    },
  },
};
</script>

<template>
  <div class="space-y-3">
    <p v-if="!templateId" class="m2-hint">{{ t('SAVE_FIRST') }}</p>
    <template v-else>
      <div class="flex items-center gap-3">
        <p class="flex-1 m-0 m2-hint">
          {{ t('HINT') }}
          <strong v-if="tests.length">{{
            t('SUMMARY', { ok: passed, total: tests.length })
          }}</strong>
        </p>
        <woot-button
          size="small"
          :is-loading="running === 'all'"
          :disabled="!tests.length"
          @click="run()"
        >
          {{ t('RUN_ALL') }}
        </woot-button>
      </div>
      <p v-if="!tests.length && !loading" class="m2-hint">{{ t('EMPTY') }}</p>
      <div
        v-for="test in tests"
        :key="test.id"
        class="p-3 border rounded-lg border-slate-100 dark:border-slate-700"
      >
        <div class="flex items-center gap-2">
          <span>{{ { ok: '✅', fail: '❌', never: '⚪' }[status(test)] }}</span>
          <button
            type="button"
            class="flex-1 text-sm font-medium text-left"
            @click="editing = editing === test.id ? null : test.id"
          >
            {{ test.name }}
            <span
              v-if="test.origin === 'correction'"
              class="ml-1 text-xs text-slate-500"
              >· {{ t('FROM_CORRECTION') }}</span
            >
          </button>
          <woot-button
            size="tiny"
            variant="smooth"
            :is-loading="running === test.id"
            @click="run(test)"
          >
            {{ t('RUN') }}
          </woot-button>
          <woot-button
            size="tiny"
            variant="clear"
            color-scheme="secondary"
            icon="delete"
            @click="remove(test)"
          />
        </div>
        <p class="m-0 mt-1 text-xs text-slate-500">
          {{ t('EXPECTED', { text: test.expected }) }}
        </p>
        <p
          v-if="test.last_run && test.last_run.reason"
          class="m-0 text-xs"
          :class="test.last_run.ok ? 'text-green-700' : 'text-red-700'"
        >
          {{ test.last_run.reason }}
        </p>
        <div v-if="editing === test.id" class="mt-2 space-y-1 text-xs">
          <div v-for="(turn, i) in test.turns" :key="i">
            <strong
              >{{ turn.role === 'user' ? t('CUSTOMER') : t('AGENT') }}:</strong
            >
            {{ turn.content }}
          </div>
          <div
            v-if="test.last_run && test.last_run.reply"
            class="pt-1 text-slate-600"
          >
            <strong>{{ t('LAST_REPLY') }}</strong> {{ test.last_run.reply }}
          </div>
        </div>
      </div>
    </template>
  </div>
</template>
