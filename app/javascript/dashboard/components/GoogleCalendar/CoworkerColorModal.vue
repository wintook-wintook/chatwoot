<!--
  fix/calendario_eliminar F4 — color de un compañero en MI calendario (nadie más lo ve).
  Fondo: la paleta de los calendarios (D6). Letra: Automática / Blanca / Negra (D7).
  Emite `save` con { bg, text }, `reset` (vuelve al de siempre) y `close`.
-->
<script>
import WootSubmitButton from '../buttons/FormSubmitButton.vue';
import { CALENDAR_COLORS } from './calendarPalette';
import { textColorFor } from './agentColor';

const T = 'GOOGLE_CALENDAR.COWORKERS.COLOR';

export default {
  name: 'CoworkerColorModal',
  components: { WootSubmitButton },
  props: {
    show: { type: Boolean, default: false },
    name: { type: String, default: '' },
    // Color que se ve ahora (escogido o el de siempre).
    bg: { type: String, default: '#6366f1' },
    text: { type: String, default: 'auto' },
    custom: { type: Boolean, default: false },
  },
  emits: ['save', 'reset', 'close'],
  data() {
    return {
      colors: CALENDAR_COLORS,
      textOptions: ['auto', 'white', 'black'],
      draft: { bg: this.bg, text: this.text },
    };
  },
  computed: {
    sampleStyle() {
      return {
        backgroundColor: this.draft.bg,
        borderColor: this.draft.bg,
        color: textColorFor(this.draft.bg, this.draft.text),
      };
    },
  },
  watch: {
    show(open) {
      if (open) this.draft = { bg: this.bg, text: this.text };
    },
  },
  methods: {
    t(key, params) {
      return this.$t(`${T}.${key}`, params);
    },
    textLabel(opt) {
      return this.t(`TEXT_${opt.toUpperCase()}`);
    },
    swatchStyle(c) {
      return {
        backgroundColor: c,
        borderColor: c === this.draft.bg ? '#1d1d1d' : c,
      };
    },
    onSave() {
      this.$emit('save', { ...this.draft });
    },
    onClose() {
      this.$emit('close');
    },
  },
};
</script>

<template>
  <woot-modal :show="show" :on-close="onClose" size="small">
    <div class="flex flex-col h-auto">
      <woot-modal-header
        :header-title="t('TITLE', { name })"
        :header-content="t('DESCRIPTION')"
      />
      <form
        class="flex flex-col items-start w-full gap-4"
        @submit.prevent="onSave"
      >
        <div class="w-full">
          <label>{{ t('BACKGROUND') }}</label>
          <div class="flex flex-wrap gap-2">
            <button
              v-for="c in colors"
              :key="c"
              type="button"
              class="w-7 h-7 border-2 rounded-full"
              :style="swatchStyle(c)"
              :aria-label="c"
              :data-test="'swatch-' + c"
              @click="draft.bg = c"
            />
          </div>
        </div>

        <div class="w-full">
          <label>{{ t('TEXT') }}</label>
          <div class="flex flex-wrap gap-x-4 gap-y-1">
            <label
              v-for="opt in textOptions"
              :key="opt"
              class="flex items-center gap-2 text-sm cursor-pointer"
            >
              <input
                v-model="draft.text"
                type="radio"
                class="!m-0"
                :value="opt"
              />
              {{ textLabel(opt) }}
            </label>
          </div>
        </div>

        <div class="w-full">
          <label>{{ t('PREVIEW') }}</label>
          <div
            class="px-2 py-1 text-sm truncate border rounded"
            :style="sampleStyle"
            data-test="color-sample"
          >
            {{ t('SAMPLE', { name }) }}
          </div>
        </div>

        <div class="flex flex-row items-center w-full gap-2 px-0 py-2">
          <button
            v-if="custom"
            type="button"
            class="button clear secondary mr-auto"
            data-test="color-reset"
            @click="$emit('reset')"
          >
            {{ t('RESET') }}
          </button>
          <div class="flex gap-2 ml-auto">
            <button type="button" class="button clear" @click="onClose">
              {{ t('CANCEL') }}
            </button>
            <WootSubmitButton :button-text="t('SAVE')" />
          </div>
        </div>
      </form>
    </div>
  </woot-modal>
</template>
