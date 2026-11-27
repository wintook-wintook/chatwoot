<!--
  Campaña con IA — paso «Respuestas y resultados»: lo que contesta TAL CUAL en cada momento y la etiqueta que le
  queda al contacto (TrackingCampaigns::CampaignKit):
    Lo logró          (confirmó, escribió la palabra clave, terminó la encuesta…)  → respuesta + etiqueta
    No esta vez       pregunta si le escribimos la próxima (Invitar, Ofrecer, Reactivar)
      · sí, la próxima → respuesta + etiqueta «volver a…»
    No me escriban    respuesta + etiqueta «no…»: la siguiente campaña del mismo tipo ya no lo inscribe
    Baja de todo      respuesta + etiqueta «baja» (fija): ninguna campaña lo vuelve a inscribir (ContactTrackings::OptOut)
  Vacío = el texto de fábrica (en gris). .sync: brief (replies, labels)
  compact (Invitar): cada momento en una línea con su texto de fábrica; «Personalizar» abre la caja.
-->
<script>
export default {
  name: 'CampaignReplies',
  props: {
    brief: { type: Object, required: true },
    kind: { type: String, default: 'offer' },
    kit: { type: Object, default: null },
    compact: { type: Boolean, default: false },
  },
  emits: ['update:brief'],
  data() {
    return { open: {} };
  },
  computed: {
    asksFuture() {
      return !!(this.kit && this.kit.asks_future);
    },
    moments() {
      return [
        { key: 'achieved', label: 'achieved' },
        ...(this.asksFuture
          ? [
              { key: 'not_now', label: null },
              { key: 'future_yes', label: 'future_yes' },
            ]
          : []),
        { key: 'opt_out', label: 'opt_out' },
        { key: 'unsubscribe', label: null, fixedLabel: 'baja' },
      ];
    },
    replies() {
      return this.brief.replies || {};
    },
    labels() {
      return this.brief.labels || {};
    },
    goal() {
      return this.brief.offer_goal;
    },
  },
  methods: {
    t(key, params) {
      return this.$t(`CAMPAIGNS2.REPLIES.${key}`, params);
    },
    fallback(key) {
      return ((this.kit && this.kit.replies) || {})[key] || '';
    },
    setReply(key, value) {
      this.$emit('update:brief', {
        ...this.brief,
        replies: { ...this.replies, [key]: value },
      });
    },
    // Minúsculas y sin espacios, como las etiquetas de la cuenta.
    setLabel(key, value) {
      const title = value
        .toLowerCase()
        .replace(/\s+/g, '-')
        .replace(/[^\p{L}\p{N}_-]/gu, '');
      this.$emit('update:brief', {
        ...this.brief,
        labels: { ...this.labels, [key]: title },
      });
    },
    // En modo compacto: abierta si la abrió o si ya tiene un texto propio.
    expanded(key) {
      return !this.compact || this.open[key] || !!this.replies[key];
    },
    toggle(key) {
      this.$set(this.open, key, !this.open[key]);
    },
    quoted(text) {
      return `«${text}»`;
    },
    momentTitle(key) {
      if (key === 'achieved') return this.t(`ACHIEVED.${this.goal || 'relay'}`);
      return this.t(`MOMENTS.${key}`);
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-3">
    <p class="m-0 text-xs text-slate-500">{{ t('HINT') }}</p>

    <section
      v-for="m in moments"
      :key="m.key"
      class="flex flex-col gap-2 p-3 border rounded-md border-slate-100 dark:border-slate-700"
    >
      <div class="flex flex-wrap items-center justify-between gap-2">
        <p class="m-0 text-sm font-semibold">{{ momentTitle(m.key) }}</p>
        <button
          v-if="compact && !replies[m.key]"
          type="button"
          class="text-xs text-woot-600 hover:underline"
          @click="toggle(m.key)"
        >
          {{ open[m.key] ? t('USE_DEFAULT') : t('CUSTOMIZE') }}
        </button>
      </div>
      <p class="m-0 text-xs text-slate-500">
        {{
          t(`ABOUT.${m.key}`, {
            kind: $t(`CAMPAIGNS2.KINDS.${kind}.TITLE`),
            examples: t(`OPT_OUT_EXAMPLES.${kind}`),
          })
        }}
      </p>
      <label
        v-if="
          !(m.key === 'achieved' && ['relay', 'appointment'].includes(goal)) &&
          expanded(m.key)
        "
        class="block"
      >
        <span class="field-label">{{ t('REPLY') }}</span>
        <textarea
          :value="replies[m.key]"
          rows="2"
          class="!mb-0"
          maxlength="600"
          :placeholder="fallback(m.key)"
          @input="setReply(m.key, $event.target.value)"
        />
      </label>
      <p
        v-if="
          !expanded(m.key) &&
          fallback(m.key) &&
          !(m.key === 'achieved' && ['relay', 'appointment'].includes(goal))
        "
        class="m-0 text-xs italic text-slate-500"
      >
        {{ quoted(fallback(m.key)) }}
      </p>
      <label v-if="m.label" class="flex flex-wrap items-center gap-2 text-sm">
        {{ t('LABEL') }}
        <input
          :value="labels[m.label]"
          type="text"
          class="!mb-0 !w-56"
          maxlength="50"
          :placeholder="t('NO_LABEL')"
          @input="setLabel(m.label, $event.target.value)"
        />
      </label>
      <p v-if="m.fixedLabel" class="m-0 text-sm">
        {{ t('FIXED_LABEL', { label: m.fixedLabel }) }}
      </p>
      <p
        v-if="m.key === 'opt_out' && labels.opt_out"
        class="m-0 text-[11px] text-slate-500"
      >
        {{
          t('EXCLUDES', {
            label: labels.opt_out,
            kind: $t(`CAMPAIGNS2.KINDS.${kind}.TITLE`),
          })
        }}
      </p>
    </section>
  </div>
</template>
