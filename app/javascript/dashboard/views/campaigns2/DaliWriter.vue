<!--
  Campaña con Vendedor IA — «Redactar con Dali» (Motor2Campaigns::CopiesController → TrackingCampaigns::CopyWriter).
  Escribe con lo que ya tiene la campaña. Primero guarda la campaña (para que Dali lea lo último), luego muestra la
  propuesta: «Usar este texto» la pone (emit use), «Otra versión» pide otra, y con texto escrito se puede mejorar.
    target   info | opener | touch | email | reminder     number  el toque o el correo · extra  más datos
    current  el texto de ahora                 compact  solo el botón y una línea (apertura y toques)
  emit use: { text } · email: { subject, subject_b, blocks }
-->
<script>
import { useAlert } from 'dashboard/composables';
import Motor2CampaignsAPI from 'dashboard/api/motor2Campaigns';

const TONES = ['cercano', 'profesional', 'entusiasta'];

export default {
  name: 'DaliWriter',
  props: {
    target: { type: String, required: true },
    number: { type: Number, default: 1 },
    current: { type: String, default: '' },
    campaignId: { type: Number, default: null },
    save: { type: Function, required: true },
    compact: { type: Boolean, default: false },
    // Más datos para el pedido (recordatorios: { kind, pending }).
    extra: { type: Object, default: () => ({}) },
  },
  emits: ['use'],
  data() {
    return {
      open: false,
      tone: 'cercano',
      length: 'completo',
      instruction: '',
      improve: false,
      loading: false,
      result: null,
      tones: TONES,
    };
  },
  computed: {
    isEmail() {
      return this.target === 'email';
    },
    // El largo solo en lo que es largo (la información completa y el primer correo).
    hasLength() {
      return this.target === 'info' || (this.isEmail && this.number === 1);
    },
    hasCurrent() {
      return !!(this.current || '').trim();
    },
  },
  methods: {
    t(key, params) {
      return this.$t(`CAMPAIGNS2.DALI_WRITER.${key}`, params);
    },
    async write() {
      if (!(await this.save())) return;
      this.loading = true;
      try {
        const { data } = await Motor2CampaignsAPI.copy(this.campaignId, {
          ...this.extra,
          target: this.target,
          number: this.number,
          tone: this.tone,
          length: this.hasLength ? this.length : 'corto',
          instruction: this.instruction,
          current: this.improve && this.hasCurrent ? this.current : '',
        });
        this.result = data;
      } catch (e) {
        useAlert(e.response?.data?.error || this.t('ERROR'));
      } finally {
        this.loading = false;
      }
    },
    use() {
      this.$emit('use', this.result);
      this.result = null;
      this.instruction = '';
      this.open = false;
    },
    blockText(block) {
      return block.type === 'button'
        ? `[${block.text}] → ${block.url}`
        : block.text;
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-2">
    <button
      v-if="!open"
      type="button"
      class="self-start text-xs font-medium text-woot-600 hover:underline"
      @click="open = true"
    >
      {{ t('OPEN') }}
    </button>
    <section
      v-else
      class="flex flex-col gap-2 p-3 border rounded-md border-woot-100 bg-woot-25 dark:bg-slate-800 dark:border-slate-700"
    >
      <div class="flex flex-wrap items-center gap-2 text-xs">
        <span class="font-semibold text-woot-700 dark:text-woot-300">
          {{ t('TITLE') }}
        </span>
        <select v-model="tone" class="!mb-0 !w-auto !h-8 !py-0 text-xs">
          <option v-for="key in tones" :key="key" :value="key">
            {{ t(`TONES.${key}`) }}
          </option>
        </select>
        <select
          v-if="hasLength"
          v-model="length"
          class="!mb-0 !w-auto !h-8 !py-0 text-xs"
        >
          <option value="corto">{{ t('SHORT') }}</option>
          <option value="completo">{{ t('FULL') }}</option>
        </select>
        <label v-if="hasCurrent" class="flex items-center gap-1">
          <input v-model="improve" type="checkbox" class="!m-0" />
          {{ t('IMPROVE') }}
        </label>
        <button
          type="button"
          class="ml-auto text-slate-500 hover:underline"
          @click="open = false"
        >
          {{ t('CLOSE') }}
        </button>
      </div>
      <input
        v-model="instruction"
        type="text"
        maxlength="300"
        class="!mb-0 text-sm"
        :placeholder="t('ASK_PLACEHOLDER')"
        @keyup.enter="write"
      />
      <div v-if="!result">
        <woot-button size="small" :is-loading="loading" @click="write">
          {{ t('WRITE') }}
        </woot-button>
      </div>

      <!-- La propuesta -->
      <template v-if="result">
        <div
          class="p-2 text-sm bg-white rounded-md dark:bg-slate-900 text-slate-800 dark:text-slate-100 [overflow-wrap:anywhere]"
        >
          <template v-if="isEmail">
            <p v-if="result.subject" class="m-0 text-xs">
              <strong>{{ t('SUBJECT') }}</strong> {{ result.subject }}
              <span v-if="result.subject_b" class="text-slate-500">
                {{ t('SUBJECT_B', { subject: result.subject_b }) }}
              </span>
            </p>
            <p
              v-for="(block, i) in result.blocks"
              :key="i"
              class="m-0 mt-2"
              :class="block.type === 'heading' ? 'font-semibold' : ''"
            >
              <span class="whitespace-pre-line">{{ blockText(block) }}</span>
            </p>
          </template>
          <span v-else class="whitespace-pre-line">{{ result.text }}</span>
        </div>
        <div class="flex flex-wrap gap-2">
          <woot-button size="small" color-scheme="success" @click="use">
            {{ hasCurrent ? t('REPLACE') : t('USE') }}
          </woot-button>
          <woot-button
            size="small"
            variant="smooth"
            color-scheme="secondary"
            :is-loading="loading"
            @click="write"
          >
            {{ t('AGAIN') }}
          </woot-button>
        </div>
        <p class="m-0 text-[11px] text-slate-500">{{ t('REVIEW_HINT') }}</p>
      </template>
      <p v-else-if="!compact" class="m-0 text-[11px] text-slate-500">
        {{ t(`HINT.${target}`) }}
      </p>
    </section>
  </div>
</template>
