<!--
  Academia Kontrolya — «Mi capacitación» (Inicio). Módulos de su rol, cada uno con
  lecciones (las guías de Dali) y ejercicios que el servidor revisa con los datos de verdad
  (Academy::Board / Academy::Checks): «Hazlo» lleva a la pantalla y empieza a contar,
  «Revisar» comprueba, «¿Cómo?» le pregunta a Dali. Los de contactos y casos se hacen sobre
  su Cliente de práctica.
-->
<script>
import AcademyAPI from 'dashboard/api/academy';
import MessageFormatter from 'shared/helpers/MessageFormatter';
import { toggleAssistant } from 'dashboard/helper/assistantState';
import {
  nextModuleKey,
  percent,
  stepBlockedKey,
} from 'dashboard/views/academy/academyHelpers';

const T = 'ACADEMY';

export default {
  name: 'AcademyIndex',
  data() {
    return {
      board: null,
      isLoading: true,
      openKey: null,
      busy: null,
      notes: {}, // lo que contestó «Revisar», por paso
      guide: null,
    };
  },
  computed: {
    accountId() {
      return this.$route.params.accountId;
    },
    modules() {
      return (this.board && this.board.modules) || [];
    },
    practice() {
      return (this.board && this.board.practice) || {};
    },
    nextKey() {
      return nextModuleKey(this.modules);
    },
    totalPercent() {
      return this.board ? percent(this.board.done, this.board.total) : 0;
    },
    guideHtml() {
      return this.guide
        ? new MessageFormatter(this.guide.content).formattedMessage
        : '';
    },
  },
  mounted() {
    this.load();
  },
  methods: {
    t(key, params) {
      return this.$t(`${T}.${key}`, params);
    },
    async load() {
      try {
        const { data } = await AcademyAPI.get();
        this.board = data;
        if (!this.openKey) this.openKey = this.nextKey;
      } finally {
        this.isLoading = false;
      }
    },
    toggle(key) {
      this.openKey = this.openKey === key ? null : key;
    },
    percentOf(mod) {
      return percent(mod.done, mod.total);
    },
    blockedText(step) {
      const key = stepBlockedKey(step);
      return key ? this.t(key) : '';
    },
    stepId(mod, step) {
      return `${mod.key}/${step.key}`;
    },
    async run(id, action) {
      this.busy = id;
      try {
        return await action();
      } catch (_e) {
        this.$emitter.emit('newToastMessage', { message: this.t('ERROR') });
        return null;
      } finally {
        this.busy = null;
      }
    },
    async read(mod, step) {
      await this.run(this.stepId(mod, step), async () => {
        const [{ data }] = await Promise.all([
          AcademyAPI.guide(step.guide),
          AcademyAPI.start(mod.key, step.key),
        ]);
        this.guide = data;
        await this.load();
      });
    },
    async doIt(mod, step) {
      await this.run(this.stepId(mod, step), async () => {
        await AcademyAPI.start(mod.key, step.key);
        if (step.path) {
          this.$router.push(`/app/accounts/${this.accountId}/${step.path}`);
        } else {
          await this.load();
        }
      });
    },
    async check(mod, step) {
      const id = this.stepId(mod, step);
      await this.run(id, async () => {
        const { data } = await AcademyAPI.check(mod.key, step.key);
        this.notes = {
          ...this.notes,
          [id]: data.found ? this.t('FOUND') : data.message,
        };
        await this.load();
      });
    },
    how(step) {
      toggleAssistant(true);
      const question = this.t('HOW_QUESTION', {
        title: step.title,
        text: step.text || '',
      });
      this.$nextTick(() => this.$emitter.emit('assistant:ask', question));
    },
    async createPractice(mod, step) {
      await this.run(this.stepId(mod, step), async () => {
        await AcademyAPI.createPractice();
        await AcademyAPI.check(mod.key, step.key);
        await this.load();
      });
    },
    openPractice() {
      this.$router.push(
        `/app/accounts/${this.accountId}/contacts/${this.practice.contact_id}`
      );
    },
    async deletePractice() {
      const ok = await this.$refs.confirmDelete.showConfirmation();
      if (!ok) return;
      await this.run('practice', async () => {
        const { data } = await AcademyAPI.deletePractice();
        this.board = data;
        this.$emitter.emit('newToastMessage', {
          message: this.t('PRACTICE.DELETED'),
        });
      });
    },
  },
};
</script>

<template>
  <div class="flex-1 overflow-y-auto bg-slate-25 dark:bg-slate-900">
    <div class="max-w-4xl px-4 py-6 mx-auto">
      <header class="mb-5">
        <h1
          class="m-0 text-2xl font-semibold text-slate-800 dark:text-slate-100"
        >
          {{ t('TITLE') }}
        </h1>
        <p class="mt-1 mb-3 text-sm text-slate-600 dark:text-slate-300">
          {{ t('SUBTITLE') }}
        </p>
        <div v-if="board" class="flex items-center gap-3">
          <div
            class="flex-1 h-2 overflow-hidden rounded-full bg-slate-100 dark:bg-slate-800"
          >
            <div
              class="h-full rounded-full bg-woot-500"
              :style="{ width: `${totalPercent}%` }"
            />
          </div>
          <span class="text-sm text-slate-600 dark:text-slate-300">
            {{ t('PROGRESS', { done: board.done, total: board.total }) }}
          </span>
        </div>
      </header>

      <p v-if="isLoading" class="text-sm text-slate-500">{{ t('LOADING') }}</p>
      <p v-else-if="!modules.length" class="text-sm text-slate-500">
        {{ t('EMPTY') }}
      </p>

      <template v-else>
        <!-- Cliente de práctica -->
        <section
          class="flex flex-wrap items-center justify-between gap-3 p-4 mb-4 bg-white border rounded-lg border-slate-100 dark:bg-slate-800 dark:border-slate-700"
        >
          <div class="min-w-0">
            <h2
              class="m-0 text-sm font-semibold text-slate-800 dark:text-slate-100"
            >
              {{ t('PRACTICE.TITLE') }}
            </h2>
            <p class="m-0 text-sm text-slate-600 dark:text-slate-300">
              {{ practice.contact_name || t('PRACTICE.NONE') }}
            </p>
          </div>
          <div v-if="practice.contact_id" class="flex gap-2">
            <woot-button size="small" variant="smooth" @click="openPractice">
              {{ t('PRACTICE.OPEN') }}
            </woot-button>
            <woot-button
              size="small"
              variant="clear"
              color-scheme="alert"
              :is-loading="busy === 'practice'"
              @click="deletePractice"
            >
              {{ t('PRACTICE.DELETE') }}
            </woot-button>
          </div>
        </section>

        <!-- Módulos -->
        <section
          v-for="mod in modules"
          :key="mod.key"
          class="mb-3 bg-white border rounded-lg border-slate-100 dark:bg-slate-800 dark:border-slate-700"
        >
          <button
            type="button"
            class="flex items-center w-full gap-3 px-4 py-3 text-left"
            @click="toggle(mod.key)"
          >
            <fluent-icon
              :icon="mod.status === 'done' ? 'checkmark-circle' : 'book'"
              size="20"
              :class="
                mod.status === 'done' ? 'text-green-600' : 'text-slate-500'
              "
            />
            <span class="flex-1 min-w-0">
              <span
                class="block font-medium text-slate-800 dark:text-slate-100"
              >
                {{ mod.title }}
                <span
                  v-if="mod.key === nextKey"
                  class="ml-2 px-2 py-0.5 text-xs rounded-full bg-woot-50 text-woot-700 dark:bg-woot-900/40 dark:text-woot-200"
                >
                  {{ t('NEXT') }}
                </span>
              </span>
              <span class="block text-sm text-slate-500 dark:text-slate-400">
                {{ mod.summary }}
              </span>
            </span>
            <span class="text-sm text-slate-600 dark:text-slate-300">
              {{ t('MODULE_PROGRESS', { done: mod.done, total: mod.total }) }}
            </span>
            <span
              class="hidden w-20 h-1.5 overflow-hidden rounded-full sm:block bg-slate-100 dark:bg-slate-700"
            >
              <span
                class="block h-full bg-woot-500"
                :style="{ width: `${percentOf(mod)}%` }"
              />
            </span>
          </button>

          <ol
            v-if="openKey === mod.key"
            class="px-4 pb-4 m-0 list-none border-t border-slate-50 dark:border-slate-700"
          >
            <li
              v-for="step in mod.steps"
              :key="step.key"
              class="flex gap-3 py-3 border-b last:border-b-0 border-slate-50 dark:border-slate-700"
            >
              <fluent-icon
                :icon="step.status === 'done' ? 'checkmark-circle' : 'circle'"
                size="18"
                class="mt-0.5 flex-shrink-0"
                :class="
                  step.status === 'done' ? 'text-green-600' : 'text-slate-300'
                "
              />
              <div class="flex-1 min-w-0">
                <p class="m-0 text-xs uppercase text-slate-400">
                  {{ step.kind === 'lesson' ? t('LESSON') : t('EXERCISE') }}
                  · {{ t(`STATUS.${step.status}`) }}
                </p>
                <p class="m-0 font-medium text-slate-800 dark:text-slate-100">
                  {{ step.title }}
                </p>
                <p
                  v-if="step.text"
                  class="m-0 mt-0.5 text-sm text-slate-600 dark:text-slate-300"
                >
                  {{ step.text }}
                </p>
                <p
                  v-if="blockedText(step)"
                  class="m-0 mt-1 text-sm text-amber-700 dark:text-amber-300"
                >
                  {{ blockedText(step) }}
                </p>
                <p
                  v-if="notes[stepId(mod, step)]"
                  class="m-0 mt-1 text-sm"
                  :class="
                    step.status === 'done'
                      ? 'text-green-700 dark:text-green-300'
                      : 'text-slate-700 dark:text-slate-200'
                  "
                >
                  {{ notes[stepId(mod, step)] }}
                </p>

                <div class="flex flex-wrap gap-2 mt-2">
                  <woot-button
                    v-if="step.kind === 'lesson'"
                    size="small"
                    variant="smooth"
                    :is-loading="busy === stepId(mod, step)"
                    @click="read(mod, step)"
                  >
                    {{ step.status === 'done' ? t('READ_AGAIN') : t('READ') }}
                  </woot-button>
                  <template
                    v-else-if="step.status !== 'done' && !blockedText(step)"
                  >
                    <woot-button
                      v-if="step.key === 'practica' && !practice.contact_id"
                      size="small"
                      :is-loading="busy === stepId(mod, step)"
                      @click="createPractice(mod, step)"
                    >
                      {{ t('PRACTICE.CREATE') }}
                    </woot-button>
                    <template v-else>
                      <woot-button
                        v-if="step.path"
                        size="small"
                        :is-loading="busy === stepId(mod, step)"
                        @click="doIt(mod, step)"
                      >
                        {{ t('DO_IT') }}
                      </woot-button>
                      <woot-button
                        size="small"
                        variant="smooth"
                        :is-loading="busy === stepId(mod, step)"
                        @click="check(mod, step)"
                      >
                        {{ t('CHECK') }}
                      </woot-button>
                    </template>
                    <woot-button
                      size="small"
                      variant="clear"
                      color-scheme="secondary"
                      @click="how(step)"
                    >
                      {{ t('HOW') }}
                    </woot-button>
                  </template>
                </div>
              </div>
            </li>
          </ol>
        </section>
      </template>
    </div>

    <!-- La lección: el texto de la guía -->
    <woot-modal v-if="guide" :show="!!guide" :on-close="() => (guide = null)">
      <div class="flex flex-col h-auto overflow-auto max-h-[80vh] p-6">
        <h2
          class="m-0 mb-3 text-lg font-semibold text-slate-800 dark:text-slate-100"
        >
          {{ guide.title }}
        </h2>
        <!-- eslint-disable-next-line vue/no-v-html -->
        <div class="text-sm academy-guide" v-html="guideHtml" />
        <div class="flex justify-end gap-2 mt-4">
          <a
            v-if="guide.url"
            :href="guide.url"
            target="_blank"
            rel="noopener noreferrer"
            class="self-center text-sm underline text-woot-600"
          >
            {{ t('GUIDE.FULL') }}
          </a>
          <woot-button size="small" @click="guide = null">
            {{ t('GUIDE.CLOSE') }}
          </woot-button>
        </div>
      </div>
    </woot-modal>

    <woot-confirm-modal
      ref="confirmDelete"
      :title="t('PRACTICE.CONFIRM_TITLE')"
      :description="t('PRACTICE.CONFIRM_MESSAGE')"
      :confirm-label="t('PRACTICE.CONFIRM_YES')"
      :cancel-label="t('PRACTICE.CONFIRM_NO')"
    />
  </div>
</template>

<style scoped lang="scss">
.academy-guide :deep(h2) {
  @apply mt-4 mb-1 text-base font-semibold;
}
.academy-guide :deep(h3) {
  @apply mt-3 mb-1 text-sm font-semibold;
}
.academy-guide :deep(ol),
.academy-guide :deep(ul) {
  @apply pl-5 my-1;
}
</style>
