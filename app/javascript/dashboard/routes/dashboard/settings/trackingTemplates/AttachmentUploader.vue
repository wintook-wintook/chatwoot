<script>
// fix/archivos_varios — SUBIR VARIOS ARCHIVOS AL AGENTE A LA VEZ
// ============================================================================
// Antes: un archivo, su nombre, [Subir], y otra vez. Ahora se seleccionan (o se
// arrastran) varios; cada uno trae su nombre sugerido ({{nombre}}), que se puede
// cambiar, y se suben UNO POR UNO con su estado. El servidor no cambia: una
// petición por archivo (AiAgentAttachmentsAPI.upload).
//
// Si uno falla, los demás sí entran; el que falló se queda en la lista con su
// motivo y se reintenta con el mismo botón.
// ============================================================================
import AiAgentAttachmentsAPI from 'dashboard/api/aiAgentAttachments';
import {
  nameFromFile,
  uniqueName,
  isValidName,
  isTaken,
} from './attachmentNames';

let siguienteClave = 0;

const tamano = bytes => {
  if (!bytes && bytes !== 0) return '';
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${Math.round(bytes / 1024)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
};

export default {
  props: {
    templateId: { type: Number, required: true },
    // Los nombres de los archivos que el agente ya tiene.
    existingNames: { type: Array, default: () => [] },
  },
  emits: ['uploaded'],
  data() {
    return {
      pending: [],
      dragging: false,
      uploading: false,
      open: '{{',
      close: '}}',
    };
  },
  computed: {
    toUpload() {
      return this.pending.filter(p => p.status !== 'uploading');
    },
    canUpload() {
      return (
        !this.uploading &&
        this.toUpload.length > 0 &&
        this.toUpload.every(p => !this.problem(p))
      );
    },
  },
  methods: {
    size: tamano,
    addFiles(lista) {
      Array.from(lista || []).forEach(file => {
        const tomados = [
          ...this.existingNames,
          ...this.pending.map(p => p.name),
        ];
        this.pending.push({
          key: (siguienteClave += 1),
          file,
          name: uniqueName(nameFromFile(file.name), tomados),
          status: 'pending',
          error: '',
        });
      });
    },
    onPick(event) {
      this.addFiles(event.target.files);
      event.target.value = '';
    },
    onDrop(event) {
      this.dragging = false;
      this.addFiles(event.dataTransfer && event.dataTransfer.files);
    },
    remove(item) {
      this.pending = this.pending.filter(p => p.key !== item.key);
    },
    // Lo que impide subir esta fila, o '' si está bien.
    problem(item) {
      if (!isValidName(item.name))
        return this.$t('TRACKING_TEMPLATES.FORM.ATTACHMENTS.INVALID_NAME');
      const otros = this.pending
        .filter(p => p.key !== item.key)
        .map(p => p.name);
      if (isTaken(item.name, this.existingNames, otros))
        return this.$t('TRACKING_TEMPLATES.FORM.ATTACHMENTS.DUPLICATE_NAME');
      return '';
    },
    async uploadAll() {
      if (!this.canUpload) return;
      this.uploading = true;
      // eslint-disable-next-line no-restricted-syntax
      for (const item of [...this.toUpload]) {
        item.status = 'uploading';
        item.error = '';
        try {
          // Uno por uno, a propósito: el orden y el error de cada uno se ven.
          // eslint-disable-next-line no-await-in-loop
          const { data } = await AiAgentAttachmentsAPI.upload(this.templateId, {
            name: item.name,
            file: item.file,
          });
          this.remove(item);
          this.$emit('uploaded', data);
        } catch (e) {
          const errores =
            e && e.response && e.response.data && e.response.data.errors;
          item.status = 'error';
          item.error =
            (errores && errores.join(', ')) ||
            this.$t('TRACKING_TEMPLATES.FORM.ATTACHMENTS.UPLOAD_ERROR');
        }
      }
      this.uploading = false;
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-2 mb-3">
    <!-- Soltar o seleccionar varios -->
    <div
      class="flex flex-wrap items-center justify-center gap-2 px-3 py-4 text-sm border border-dashed rounded-md text-slate-500 dark:text-slate-400"
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
      <span>{{ $t('TRACKING_TEMPLATES.FORM.ATTACHMENTS.DROP_HINT') }}</span>
      <input
        ref="fileInput"
        type="file"
        multiple
        class="hidden"
        @change="onPick"
      />
      <woot-button
        color-scheme="success"
        size="small"
        icon="attach"
        @click.prevent="$refs.fileInput.click()"
      >
        {{ $t('TRACKING_TEMPLATES.FORM.ATTACHMENTS.SELECT_FILES') }}
      </woot-button>
    </div>

    <!-- Por subir -->
    <template v-if="pending.length">
      <div class="flex items-center justify-between">
        <span class="text-xs font-medium text-slate-600 dark:text-slate-400">
          {{
            $t('TRACKING_TEMPLATES.FORM.ATTACHMENTS.PENDING_TITLE', {
              count: pending.length,
            })
          }}
          · {{ $t('TRACKING_TEMPLATES.FORM.ATTACHMENTS.NAME_LABEL') }}
        </span>
        <woot-button
          size="small"
          icon="upload"
          :is-loading="uploading"
          :is-disabled="!canUpload"
          @click.prevent="uploadAll"
        >
          {{
            $t('TRACKING_TEMPLATES.FORM.ATTACHMENTS.UPLOAD_ALL', {
              count: toUpload.length,
            })
          }}
        </woot-button>
      </div>
      <ul class="!m-0 !p-0 list-none space-y-1.5">
        <li
          v-for="item in pending"
          :key="item.key"
          class="flex flex-col gap-1 p-2 border rounded-md border-slate-200 dark:border-slate-600"
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
            <span class="text-xs text-slate-400 shrink-0">{{ open }}</span>
            <input
              v-model.trim="item.name"
              type="text"
              class="flex-1 min-w-0 !mb-0 !h-8 text-sm"
              :disabled="item.status === 'uploading'"
            />
            <span class="text-xs text-slate-400 shrink-0">{{ close }}</span>
            <span class="w-16 text-xs text-right text-slate-400 shrink-0">
              {{ size(item.file.size) }}
            </span>
            <woot-button
              v-tooltip.top="$t('TRACKING_TEMPLATES.FORM.ATTACHMENTS.REMOVE')"
              size="tiny"
              variant="clear"
              color-scheme="secondary"
              icon="dismiss"
              :is-disabled="item.status === 'uploading'"
              @click.prevent="remove(item)"
            />
          </div>
          <span
            v-if="item.status === 'uploading'"
            class="text-xs text-slate-500"
          >
            {{ $t('TRACKING_TEMPLATES.FORM.ATTACHMENTS.UPLOADING') }}
          </span>
          <span v-else-if="problem(item)" class="text-xs text-red-500">
            {{ problem(item) }}
          </span>
          <span v-else-if="item.error" class="text-xs text-red-500">
            {{ item.error }}
          </span>
        </li>
      </ul>
    </template>
  </div>
</template>
