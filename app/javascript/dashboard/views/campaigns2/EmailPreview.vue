<!--
  Campaña con Vendedor IA — cómo se ve el correo del toque en la bandeja del contacto (asunto, remitente, bloques y
  firma), con las variables llenas de ejemplo ({{contacto}}, {{empresa}}, {{oferta}}, {{que_vence}}…).
-->
<script>
import { fillCampaignText, sampleValues } from './campaignFlow';

export default {
  name: 'EmailPreview',
  props: {
    subject: { type: String, default: '' },
    from: { type: String, default: '' },
    blocks: { type: Array, default: () => [] },
    signature: { type: String, default: '' },
    brief: { type: Object, default: () => ({}) },
  },
  methods: {
    fill(text) {
      return fillCampaignText(text, sampleValues(this.brief));
    },
  },
};
</script>

<template>
  <div
    class="w-full overflow-hidden bg-white border rounded-lg shadow-sm dark:bg-slate-800 border-slate-100 dark:border-slate-700"
  >
    <div class="px-3 py-2 border-b border-slate-100 dark:border-slate-700">
      <p class="m-0 text-sm font-semibold text-slate-800 dark:text-slate-100">
        {{ fill(subject) || $t('CAMPAIGNS2.EMAIL.NO_SUBJECT') }}
      </p>
      <p class="m-0 text-xs text-slate-500">{{ from }}</p>
    </div>
    <div
      class="flex flex-col gap-2 p-3 text-sm text-slate-700 dark:text-slate-200"
    >
      <p v-if="!blocks.length" class="m-0 text-xs italic text-slate-500">
        {{ $t('CAMPAIGNS2.EMAIL.AI_PREVIEW') }}
      </p>
      <template v-for="(block, i) in blocks">
        <h3
          v-if="block.type === 'heading'"
          :key="i"
          class="m-0 text-base font-semibold"
        >
          {{ fill(block.text) }}
        </h3>
        <p
          v-else-if="block.type === 'text'"
          :key="i"
          class="m-0 whitespace-pre-line"
        >
          {{ fill(block.text) }}
        </p>
        <span
          v-else-if="block.type === 'button'"
          :key="i"
          class="self-start px-4 py-2 text-sm font-medium text-white rounded-md bg-woot-500"
        >
          {{ block.text }}
        </span>
        <img
          v-else-if="block.type === 'image' && block.url"
          :key="i"
          :src="block.url"
          :alt="block.text"
          class="max-w-full rounded-md"
        />
      </template>
      <p
        v-if="signature"
        class="pt-2 m-0 text-xs whitespace-pre-line border-t text-slate-500 border-slate-100 dark:border-slate-700"
      >
        {{ signature }}
      </p>
      <p class="m-0 text-[11px] text-slate-400">
        {{ $t('CAMPAIGNS2.EMAIL.UNSUBSCRIBE') }}
      </p>
    </div>
  </div>
</template>
