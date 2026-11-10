<!--
  «Crear con IA» — el usuario dice qué quiere lograr y el asistente llena el formulario:
  nombre estructurado, categoría (con su porqué), encabezado, cuerpo, pie, botones de
  respuesta rápida y ejemplos (Whatsapp::TemplateDrafter). No guarda ni llama a Meta, y el
  canal lo sigue eligiendo el usuario. «Otra propuesta» y «Ajustar» parten de lo que ya
  está en el formulario.
  Emite `apply` con los campos del formulario.
-->
<script>
import WhatsappTemplatesAPI from 'dashboard/api/whatsapp/templates';

const T = 'WHATSAPP_TEMPLATE_EDITOR.AI';
const TONES = ['', 'cercano', 'formal', 'directo'];

export default {
  name: 'AiTemplateDraft',
  props: {
    language: { type: String, default: 'es' },
    // Lo que hay en el formulario: para «Otra propuesta» y «Ajustar».
    current: { type: Object, default: null },
  },
  emits: ['apply'],
  computed: {
    // Las variables que se llenan al enviar, escritas como en el mensaje.
    manualList() {
      const open = String.fromCharCode(123, 123);
      const close = String.fromCharCode(125, 125);
      return this.manual.map(v => `${open}${v}${close}`).join(', ');
    },
  },
  data() {
    return {
      open: true,
      goal: '',
      tone: '',
      adjust: '',
      busy: false,
      error: '',
      reason: '',
      warnings: [],
      manual: [],
      proposed: false,
      tones: TONES,
    };
  },
  methods: {
    t(key, params) {
      return this.$t(`${T}.${key}`, params);
    },
    previous() {
      const f = this.current || {};
      return {
        name: f.name,
        category: f.category,
        header: f.header_content,
        body: f.body_text,
        footer: f.footer_text,
        buttons: (f.buttons || []).map(b => b.text),
      };
    },
    async propose(mode = 'new') {
      if (!this.goal.trim() || this.busy) return;
      this.busy = true;
      this.error = '';
      try {
        const payload = {
          goal: this.goal,
          tone: this.tone,
          language: this.language,
        };
        if (mode !== 'new') payload.previous = this.previous();
        if (mode === 'adjust') payload.adjust = this.adjust;
        const { data } = await WhatsappTemplatesAPI.aiDraft(payload);
        this.reason = data.reason || '';
        this.warnings = data.warnings || [];
        this.manual = data.manual_variables || [];
        this.proposed = true;
        if (mode === 'adjust') this.adjust = '';
        this.$emit('apply', data.draft);
      } catch (e) {
        this.error = e.response?.data?.error || this.t('ERROR');
      } finally {
        this.busy = false;
      }
    },
  },
};
</script>

<template>
  <section
    class="p-3 mb-3 border rounded-lg border-woot-100 bg-woot-25 dark:bg-slate-800 dark:border-slate-700"
  >
    <button
      type="button"
      class="flex items-center gap-2 p-0 text-sm font-medium bg-transparent border-0 text-woot-700 dark:text-woot-200"
      @click="open = !open"
    >
      <fluent-icon icon="wand" size="16" />
      {{ t('TITLE') }}
      <fluent-icon :icon="open ? 'chevron-up' : 'chevron-down'" size="12" />
    </button>
    <div v-if="open" class="flex flex-col gap-2 mt-2">
      <label class="text-sm text-slate-700 dark:text-slate-200">
        {{ t('GOAL') }}
        <textarea
          v-model="goal"
          rows="2"
          class="!mb-0"
          :placeholder="t('GOAL_PLACEHOLDER')"
        />
      </label>
      <div class="flex flex-wrap items-center gap-2">
        <select v-model="tone" class="!mb-0 !w-auto text-sm">
          <option v-for="tono in tones" :key="tono || 'any'" :value="tono">
            {{ t(`TONES.${tono || 'ANY'}`) }}
          </option>
        </select>
        <woot-button
          size="small"
          :is-loading="busy"
          :is-disabled="!goal.trim()"
          @click="propose(proposed ? 'other' : 'new')"
        >
          {{ proposed ? t('OTHER') : t('PROPOSE') }}
        </woot-button>
        <span class="text-xs text-slate-500 dark:text-slate-400">
          {{ t('CHANNEL_HINT') }}
        </span>
      </div>
      <p v-if="error" class="m-0 text-xs text-red-600">{{ error }}</p>
      <template v-if="proposed">
        <p v-if="reason" class="m-0 text-xs text-slate-600 dark:text-slate-300">
          {{ t('REASON', { reason }) }}
        </p>
        <p
          v-if="manual.length"
          class="m-0 text-xs text-slate-600 dark:text-slate-300"
        >
          {{ t('MANUAL', { list: manualList }) }}
        </p>
        <ul
          v-if="warnings.length"
          class="m-0 text-xs list-disc ltr:pl-4 rtl:pr-4 text-amber-700 dark:text-amber-300"
        >
          <li v-for="w in warnings" :key="w">{{ w }}</li>
        </ul>
        <div class="flex items-center gap-2">
          <input
            v-model="adjust"
            type="text"
            class="!mb-0 text-sm"
            :placeholder="t('ADJUST_PLACEHOLDER')"
            @keydown.enter.prevent="propose('adjust')"
          />
          <woot-button
            size="small"
            variant="smooth"
            :is-loading="busy"
            :is-disabled="!adjust.trim()"
            @click="propose('adjust')"
          >
            {{ t('ADJUST') }}
          </woot-button>
        </div>
      </template>
    </div>
  </section>
</template>
