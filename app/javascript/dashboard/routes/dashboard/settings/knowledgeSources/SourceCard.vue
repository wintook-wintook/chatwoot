<!-- @knowledge_sources -->
<!-- Tarjeta individual de una fuente de conocimiento configurada. -->
<script>
export default {
  name: 'KnowledgeSourceCard',
  props: {
    source: { type: Object, required: true },
    syncing: { type: Boolean, default: false },
    // True cuando es una fuente Google pero la cuenta no tiene la feature
    // google_calendar activada: se deshabilita sync y la directiva no opera.
    googleDisabled: { type: Boolean, default: false },
  },
  emits: ['sync', 'delete', 'edit'],
  computed: {
    sourceIcon() {
      return (
        {
          canned_response: 'chat-multiple',
          article: 'library',
          google_doc: 'document',
          google_sheet: 'document',
        }[this.source.source_type] || 'globe'
      );
    },
    sourceLabel() {
      return (
        {
          canned_response: 'Respuestas predefinidas',
          article: 'Centro de Ayuda',
          google_doc: 'Google Doc',
          google_sheet: 'Google Sheets',
        }[this.source.source_type] || 'Discourse'
      );
    },
    // Fuentes configurables por el usuario (se editan/borran): Discourse, Docs y Sheets.
    // Las nativas (Respuestas predefinidas, Centro de Ayuda) son fijas.
    isConfigurable() {
      return ['discourse', 'google_doc', 'google_sheet'].includes(
        this.source.source_type
      );
    },
    // Fuentes vectorizadas/indexadas localmente: el sync re-procesa.
    // Discourse queda fuera: se busca en vivo, no hay copia local que sincronizar.
    isSyncable() {
      return [
        'canned_response',
        'article',
        'google_doc',
        'google_sheet',
      ].includes(this.source.source_type);
    },
    // Sin integración OpenAI no se puede vectorizar: avisamos y bloqueamos el sync.
    needsOpenai() {
      return this.isSyncable && this.source.openai_configured === false;
    },
    isSyncing() {
      return this.source.sync_status === 'syncing';
    },
    syncError() {
      if (this.source.sync_status !== 'error') return '';
      return this.source.config?.last_error || 'La sincronización falló.';
    },
    syncProgress() {
      if (!this.isSyncing || !this.source.sync_jobs_pending) return '';
      return `${this.source.sync_jobs_pending} restantes`;
    },
    lastSynced() {
      if (!this.source.last_synced_at) return 'Nunca sincronizado';
      return new Date(this.source.last_synced_at).toLocaleString('es-MX', {
        dateStyle: 'short',
        timeStyle: 'short',
      });
    },
    statusClass() {
      return this.source.status === 'active'
        ? 'bg-green-50 text-green-700'
        : 'bg-slate-50 text-slate-500';
    },
    discourseUrl() {
      return this.source.config?.url || this.source.config?.file_url || null;
    },
    discourseUsername() {
      return this.source.config?.username || null;
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col gap-3 p-4 bg-white rounded-xl border border-slate-100 shadow-sm"
  >
    <!-- Header -->
    <div class="flex items-start justify-between">
      <div class="flex items-center gap-3">
        <div
          class="flex items-center justify-center w-10 h-10 rounded-lg bg-woot-50"
        >
          <fluent-icon :icon="sourceIcon" size="20" class="text-woot-500" />
        </div>
        <div>
          <p class="font-semibold text-slate-800 text-base">
            {{ source.name }}
          </p>
          <p class="text-sm text-slate-500">{{ sourceLabel }}</p>
        </div>
      </div>
      <span class="text-sm font-medium px-2 rounded-full" :class="statusClass">
        {{ source.status === 'active' ? 'Activo' : 'Inactivo' }}
      </span>
    </div>

    <!-- URL del foro -->
    <div v-if="discourseUrl" class="text-sm text-slate-500 truncate">
      {{ discourseUrl }}
    </div>

    <!-- Usuario API -->
    <div
      v-if="discourseUsername && source.source_type === 'discourse'"
      class="flex items-center gap-1.5 text-sm text-slate-400"
    >
      <fluent-icon icon="person" size="14" />
      <span>{{ discourseUsername }}</span>
    </div>

    <!-- Aviso: la feature Google (Calendario) está desactivada para la cuenta -->
    <div
      v-if="googleDisabled"
      class="flex items-center gap-2 px-3 py-2 bg-amber-50 border border-amber-100 rounded-lg"
    >
      <fluent-icon icon="warning" size="14" class="text-amber-500" />
      <span class="text-sm text-amber-700">
        Integración de Google desactivada para esta cuenta: esta fuente y su
        directiva no funcionan hasta reactivarla.
      </span>
    </div>

    <!-- Aviso: falta integración OpenAI para poder vectorizar -->
    <div
      v-if="needsOpenai && !googleDisabled"
      class="flex items-center gap-2 px-3 py-2 bg-amber-50 border border-amber-100 rounded-lg"
    >
      <fluent-icon icon="warning" size="14" class="text-amber-500" />
      <span class="text-sm text-amber-700">
        Configura la integración de OpenAI para vectorizar esta fuente.
      </span>
    </div>

    <!-- Sincronización en progreso (solo fuentes sincronizables) -->
    <template v-if="isSyncable">
      <div
        v-if="isSyncing"
        class="flex items-center gap-2 px-3 py-2 bg-woot-50 border border-woot-100 rounded-lg"
      >
        <span
          class="inline-block w-2 h-2 rounded-full bg-woot-500 animate-pulse"
        />
        <span class="text-sm text-woot-700 font-medium">
          Sincronizando{{ syncProgress ? ` — ${syncProgress}` : '...' }}
        </span>
      </div>
      <div
        v-else-if="syncError"
        class="flex items-start gap-2 px-3 py-2 bg-red-50 border border-red-100 rounded-lg"
      >
        <fluent-icon
          icon="warning"
          size="14"
          class="text-red-500 mt-0.5 flex-shrink-0"
        />
        <span class="text-sm text-red-700">{{ syncError }}</span>
      </div>
      <div v-else class="text-sm text-slate-400">
        Última sync: {{ lastSynced }}
      </div>
    </template>

    <!-- Acciones -->
    <div
      v-if="isSyncable || isConfigurable"
      class="flex gap-2 pt-1 border-t border-slate-100"
    >
      <woot-button
        v-if="isSyncable"
        size="small"
        variant="smooth"
        color-scheme="primary"
        icon="arrow-clockwise"
        :disabled="syncing || needsOpenai || googleDisabled"
        @click="$emit('sync', source)"
      >
        {{ syncing ? 'Sincronizando...' : 'Sincronizar' }}
      </woot-button>
      <woot-button
        v-if="isConfigurable"
        size="small"
        variant="smooth"
        color-scheme="secondary"
        icon="edit"
        @click="$emit('edit', source)"
      />
      <woot-button
        v-if="isConfigurable"
        size="small"
        variant="smooth"
        color-scheme="alert"
        icon="delete"
        @click="$emit('delete', source)"
      />
    </div>
  </div>
</template>
