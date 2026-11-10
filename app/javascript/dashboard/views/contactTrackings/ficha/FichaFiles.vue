<script>
// feat/ficha_agente_ia — LOS ARCHIVOS EN RECURSOS
// ============================================================================
// Dos modos:
//  · Agente nuevo (sin templateId): se eligen VARIOS archivos y se quedan en la lista
//    con su nombre ({{nombre}}, editable). La pantalla los sube al crear el agente.
//    v-model = [{ key, file, name }]
//  · Agente que ya existe (templateId): se suben al momento, uno por uno, y avisa
//    con 'uploaded' (la ficha los marca para que el Entrenamiento los pueda mandar).
// El nombre: letras, números, guion y guion bajo; único en el agente (AiAgentAttachment).
// ============================================================================
import AiAgentAttachmentsAPI from 'dashboard/api/aiAgentAttachments';
import FileRule, { defaultRule } from './FileRule.vue';

const NAME_FORMAT = /^[a-zA-Z0-9_-]{1,60}$/;
let siguiente = 0;

export const nameFromFile = filename =>
  (filename || '')
    .replace(/\.[^.]+$/, '')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9_-]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 60) || 'archivo';

export const uniqueName = (base, taken) => {
  const ocupados = taken.map(n => (n || '').toLowerCase());
  if (!ocupados.includes(base.toLowerCase())) return base;
  let n = 2;
  while (ocupados.includes(`${base}-${n}`.toLowerCase())) n += 1;
  return `${base.slice(0, 60 - `-${n}`.length)}-${n}`;
};

export default {
  components: { FileRule },
  model: { prop: 'value', event: 'input' },
  props: {
    value: { type: Array, default: () => [] },
    templateId: { type: Number, default: null },
    // Los nombres que ya usa el agente.
    existingNames: { type: Array, default: () => [] },
    // Intentos del seguimiento (para la regla «en el intento N»).
    attempts: { type: Number, default: 3 },
  },
  emits: ['input', 'uploaded'],
  data() {
    return { dragging: false, uploading: false, errors: [] };
  },
  computed: {
    taken() {
      return [...this.existingNames, ...this.value.map(item => item.name)];
    },
  },
  methods: {
    add(lista) {
      const nuevos = [];
      Array.from(lista || []).forEach(file => {
        const name = uniqueName(nameFromFile(file.name), [
          ...this.taken,
          ...nuevos.map(item => item.name),
        ]);
        siguiente += 1;
        nuevos.push({ key: siguiente, file, name, ...defaultRule() });
      });
      if (this.templateId) {
        this.upload(nuevos);
        return;
      }
      this.$emit('input', [...this.value, ...nuevos]);
    },
    onPick(event) {
      this.add(event.target.files);
      event.target.value = '';
    },
    onDrop(event) {
      this.dragging = false;
      this.add(event.dataTransfer && event.dataTransfer.files);
    },
    rename(item, name) {
      this.$emit(
        'input',
        this.value.map(entry =>
          entry.key === item.key ? { ...entry, name: name.trim() } : entry
        )
      );
    },
    ruleOf(item) {
      return { ask: item.ask, welcome: item.welcome, attempts: item.attempts };
    },
    setRule(item, regla) {
      this.$emit(
        'input',
        this.value.map(entry =>
          entry.key === item.key ? { ...entry, ...regla } : entry
        )
      );
    },
    remove(item) {
      this.$emit(
        'input',
        this.value.filter(entry => entry.key !== item.key)
      );
    },
    invalid(item) {
      if (!NAME_FORMAT.test(item.name)) return true;
      const iguales = this.taken.filter(
        name => (name || '').toLowerCase() === item.name.toLowerCase()
      );
      return iguales.length > 1;
    },
    async upload(lista) {
      this.uploading = true;
      this.errors = [];
      // eslint-disable-next-line no-restricted-syntax
      for (const item of lista) {
        try {
          // eslint-disable-next-line no-await-in-loop
          const { data } = await AiAgentAttachmentsAPI.upload(this.templateId, {
            name: item.name,
            file: item.file,
          });
          this.$emit('uploaded', data);
        } catch (error) {
          const datos = error && error.response && error.response.data;
          this.errors.push(
            `${item.file.name}: ${
              (datos && datos.errors && datos.errors.join(', ')) ||
              this.$t('TRACKING_TEMPLATES.FICHA.UPLOAD_ERROR')
            }`
          );
        }
      }
      this.uploading = false;
    },
    size(bytes) {
      if (bytes < 1024 * 1024)
        return `${Math.max(1, Math.round(bytes / 1024))} KB`;
      return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-2">
    <div
      class="flex flex-wrap items-center justify-center gap-2 px-3 py-5 text-sm border border-dashed rounded-lg text-slate-500 dark:text-slate-400"
      :class="
        dragging
          ? 'border-woot-500 bg-woot-25 dark:bg-woot-900/20'
          : 'border-slate-300 dark:border-slate-600'
      "
      @dragover.prevent="dragging = true"
      @dragleave.prevent="dragging = false"
      @drop.prevent="onDrop"
    >
      <fluent-icon icon="attach" size="16" />
      <span>{{ $t('TRACKING_TEMPLATES.FICHA.FILES_DROP') }}</span>
      <input
        ref="fileInput"
        type="file"
        multiple
        class="hidden"
        @change="onPick"
      />
      <woot-button
        size="small"
        icon="attach"
        :is-loading="uploading"
        @click.prevent="$refs.fileInput.click()"
      >
        {{ $t('TRACKING_TEMPLATES.FICHA.FILES_SELECT') }}
      </woot-button>
    </div>
    <p v-if="!templateId" class="!m-0 text-xs text-slate-500">
      {{ $t('TRACKING_TEMPLATES.FICHA.FILES_ON_CREATE') }}
    </p>
    <ul v-if="errors.length" class="!m-0 pl-5 text-xs text-red-600">
      <li v-for="(error, index) in errors" :key="index">{{ error }}</li>
    </ul>
    <ul v-if="value.length" class="!m-0 !p-0 list-none flex flex-col gap-1.5">
      <li
        v-for="item in value"
        :key="item.key"
        class="flex flex-col gap-1.5 p-2 border rounded-lg border-slate-200 dark:border-slate-700"
      >
        <div class="flex items-center gap-2">
          <fluent-icon
            icon="document"
            size="16"
            class="text-slate-400 shrink-0"
          />
          <span
            class="w-1/3 min-w-0 text-sm truncate text-slate-700 dark:text-slate-200"
            :title="item.file.name"
          >
            {{ item.file.name }}
          </span>
          <input
            :value="item.name"
            type="text"
            class="flex-1 min-w-0 !mb-0 !h-8 text-sm"
            :class="{ '!border-red-400': invalid(item) }"
            :title="$t('TRACKING_TEMPLATES.FICHA.FILES_NAME_HINT')"
            @change="rename(item, $event.target.value)"
          />
          <span class="w-16 text-xs text-right text-slate-400 shrink-0">
            {{ size(item.file.size) }}
          </span>
          <woot-button
            size="tiny"
            variant="clear"
            color-scheme="secondary"
            icon="dismiss"
            @click.prevent="remove(item)"
          />
        </div>
        <FileRule
          class="pl-6"
          :value="ruleOf(item)"
          :attempts="attempts"
          @input="setRule(item, $event)"
        />
      </li>
    </ul>
  </div>
</template>
