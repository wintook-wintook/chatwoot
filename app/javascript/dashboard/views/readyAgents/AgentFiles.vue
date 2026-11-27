<!--
  Agentes listos — «Imágenes y archivos» del agente (los tres asistentes: prospectos, clientes y
  campaña). Cada archivo lleva una descripción (el agente no ve la imagen: con eso sabe cuándo sirve
  y no inventa lo que trae) y cuándo se manda; las opciones dependen de la función (`kind`).
    · Agente ya guardado (agentId): se sube al momento.
    · Agente nuevo: se queda en la lista y el asistente lo sube al guardar (emite `pending`).
  v-model = reglas por nombre: { foto-paquete: { about, ask, interest, confirm, welcome, booking,
  tickets: [], attempts: [] } } (Motor2::Functions::Form#assign_files, Motor2::Skills::Files).
  WhatsApp: imagen JPG/PNG hasta 5 MB, video o audio hasta 16 MB, documento hasta 100 MB.
-->
<script>
import { useAlert } from 'dashboard/composables';
import AiAgentAttachmentsAPI from 'dashboard/api/aiAgentAttachments';
import {
  nameFromFile,
  uniqueName,
} from '../contactTrackings/ficha/FichaFiles.vue';

const T = 'READY_AGENTS.FILES';
const MB = 1024 * 1024;
const IMAGE_TYPES = ['image/jpeg', 'image/png'];
const LIMITS = { image: 5, video: 16, audio: 16 };
const DOCUMENT_LIMIT = 100;
const ACCEPT = 'image/jpeg,image/png,application/pdf,video/mp4';
// Qué momentos tiene cada función.
const OPTIONS = {
  campaign_seller: ['interest', 'ask', 'confirm'],
  prospects: ['ask', 'welcome', 'booking'],
  customers: ['ask', 'tickets'],
};

export const blankRule = () => ({
  about: '',
  ask: true,
  welcome: false,
  interest: false,
  confirm: false,
  booking: false,
  tickets: [],
  attempts: [],
});

// ¿WhatsApp lo acepta? Regresa la llave del error o null.
export const fileProblem = file => {
  const type = file.type || '';
  const kind = type.split('/')[0];
  if (kind === 'image' && !IMAGE_TYPES.includes(type)) return 'IMAGE_TYPE';
  const limit = LIMITS[kind] || DOCUMENT_LIMIT;
  return file.size > limit * MB ? 'TOO_BIG' : null;
};

export default {
  name: 'AgentFiles',
  model: { prop: 'value', event: 'input' },
  props: {
    value: { type: Object, default: () => ({}) },
    kind: { type: String, required: true },
    agentId: { type: Number, default: null },
    // Vendedor de campaña: cuántos toques tiene (botones «En el toque N»).
    touches: { type: Number, default: 0 },
    // Vendedor de campaña › Invitar: «Al confirmar el evento».
    invite: { type: Boolean, default: false },
    // Atención a prospectos con citas: «Al agendar».
    booking: { type: Boolean, default: false },
  },
  emits: ['input', 'pending'],
  data() {
    return { saved: [], pending: [], uploading: false, accept: ACCEPT };
  },
  computed: {
    options() {
      return (OPTIONS[this.kind] || ['ask']).filter(option => {
        if (option === 'confirm') return this.invite;
        if (option === 'booking') return this.booking;
        return true;
      });
    },
    touchList() {
      return Array.from({ length: this.touches || 0 }, (_, i) => i + 1);
    },
    // Los subidos y los que esperan a que se guarde el agente, con su regla.
    rows() {
      return [
        ...this.saved.map(f => ({ ...f, pending: false })),
        ...this.pending.map(p => ({
          name: p.name,
          filename: p.file.name,
          content_type: p.file.type,
          url: p.preview,
          pending: true,
        })),
      ];
    },
  },
  watch: {
    agentId: {
      immediate: true,
      handler() {
        this.load();
      },
    },
  },
  methods: {
    t(key, params) {
      return this.$t(`${T}.${key}`, params);
    },
    async load() {
      if (!this.agentId) return;
      try {
        const { data } = await AiAgentAttachmentsAPI.list(this.agentId);
        this.saved = data;
      } catch (e) {
        this.saved = [];
      }
    },
    rule(name) {
      return { ...blankRule(), ...(this.value[name] || {}) };
    },
    setRule(name, field, val) {
      this.$emit('input', {
        ...this.value,
        [name]: { ...this.rule(name), [field]: val },
      });
    },
    isOn(name, option) {
      const r = this.rule(name);
      return option === 'tickets' ? r.tickets.includes('*') : !!r[option];
    },
    toggle(name, option) {
      if (option === 'tickets')
        this.setRule(name, 'tickets', this.isOn(name, 'tickets') ? [] : ['*']);
      else this.setRule(name, option, !this.rule(name)[option]);
    },
    toggleTouch(name, n) {
      const list = this.rule(name).attempts;
      this.setRule(
        name,
        'attempts',
        list.includes(n) ? list.filter(i => i !== n) : [...list, n].sort()
      );
    },
    isImage(row) {
      return (row.content_type || '').startsWith('image/');
    },
    async add(event) {
      const files = Array.from(event.target.files || []);
      event.target.value = '';
      const ok = files.filter(file => {
        const problem = fileProblem(file);
        if (problem) useAlert(this.t(problem, { name: file.name }));
        return !problem;
      });
      const rules = { ...this.value };
      const taken = this.rows.map(r => r.name);
      const added = ok.map(file => {
        const name = uniqueName(nameFromFile(file.name), taken);
        taken.push(name);
        // La primera foto suele ser «la del producto»: por omisión va al mostrar interés.
        rules[name] = {
          ...blankRule(),
          interest: this.kind === 'campaign_seller',
        };
        return { name, file };
      });
      this.$emit('input', rules);
      if (this.agentId) await this.upload(added);
      else {
        this.pending = [
          ...this.pending,
          ...added.map(a => ({
            ...a,
            preview: a.file.type.startsWith('image/')
              ? URL.createObjectURL(a.file)
              : null,
          })),
        ];
        this.$emit(
          'pending',
          this.pending.map(({ name, file }) => ({ name, file }))
        );
      }
    },
    async upload(list) {
      this.uploading = true;
      try {
        await Promise.all(
          list.map(item => AiAgentAttachmentsAPI.upload(this.agentId, item))
        );
      } catch (e) {
        useAlert(e.response?.data?.message || this.t('UPLOAD_ERROR'));
      } finally {
        this.uploading = false;
        this.load();
      }
    },
    async remove(row) {
      if (row.pending) {
        this.pending = this.pending.filter(p => p.name !== row.name);
        this.$emit(
          'pending',
          this.pending.map(({ name, file }) => ({ name, file }))
        );
      } else {
        await AiAgentAttachmentsAPI.remove(this.agentId, row.id);
        this.load();
      }
      const rules = { ...this.value };
      delete rules[row.name];
      this.$emit('input', rules);
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-2">
    <p
      v-if="kind === 'campaign_seller'"
      class="p-2 m-0 text-xs rounded-md bg-slate-25 dark:bg-slate-800 text-slate-600 dark:text-slate-300"
    >
      {{ t('FIRST_MESSAGE') }}
    </p>
    <p class="m-0 text-xs text-slate-500">{{ t('HINT') }}</p>
    <div
      v-for="row in rows"
      :key="row.name"
      class="flex flex-col gap-1.5 p-2 border rounded-md border-slate-100 dark:border-slate-700"
    >
      <div class="flex items-center gap-2">
        <img
          v-if="isImage(row) && row.url"
          :src="row.url"
          :alt="row.name"
          class="object-cover w-10 h-10 rounded"
        />
        <span
          v-else
          class="flex items-center justify-center w-10 h-10 text-lg rounded bg-slate-100 dark:bg-slate-700"
        >
          <fluent-icon icon="document" size="18" />
        </span>
        <span class="flex-1 min-w-0">
          <span class="block text-sm font-medium truncate">{{ row.name }}</span>
          <span class="block text-xs truncate text-slate-500">
            {{ row.pending ? t('PENDING') : row.filename }}
          </span>
        </span>
        <button
          type="button"
          class="px-1 text-slate-400 hover:text-red-600"
          :title="t('REMOVE')"
          @click="remove(row)"
        >
          <fluent-icon icon="delete" size="14" />
        </button>
      </div>
      <input
        :value="rule(row.name).about"
        type="text"
        maxlength="200"
        class="!mb-0 h-8 text-sm"
        :placeholder="t('ABOUT_PLACEHOLDER')"
        @input="setRule(row.name, 'about', $event.target.value)"
      />
      <span
        v-if="!rule(row.name).about.trim()"
        class="text-xs text-amber-700 dark:text-amber-400"
      >
        {{ t('ABOUT_MISSING') }}
      </span>
      <div class="flex flex-wrap gap-x-3 gap-y-1">
        <label
          v-for="option in options"
          :key="option"
          class="flex items-center gap-1 text-xs"
        >
          <input
            type="checkbox"
            class="!m-0"
            :checked="isOn(row.name, option)"
            @change="toggle(row.name, option)"
          />
          {{ t(`WHEN.${option}`) }}
        </label>
        <label
          v-for="n in touchList"
          :key="`touch-${n}`"
          class="flex items-center gap-1 text-xs"
        >
          <input
            type="checkbox"
            class="!m-0"
            :checked="rule(row.name).attempts.includes(n)"
            @change="toggleTouch(row.name, n)"
          />
          {{ t('WHEN.touch', { n }) }}
        </label>
      </div>
    </div>
    <label
      class="flex items-center justify-center gap-2 p-3 text-sm border border-dashed rounded-md cursor-pointer border-slate-300 text-woot-600 dark:border-slate-600"
    >
      <fluent-icon icon="add" size="14" />
      {{ uploading ? t('UPLOADING') : t('ADD') }}
      <input
        type="file"
        class="hidden"
        multiple
        :accept="accept"
        @change="add"
      />
    </label>
    <p class="m-0 text-xs text-slate-500">{{ t('LIMITS') }}</p>
  </div>
</template>
