<!-- @knowledge_sources -->
<!-- Tarjeta individual de una fuente de conocimiento configurada. -->
<script>
export default {
  name: 'KnowledgeSourceCard',
  props: {
    source:  { type: Object,  required: true },
    syncing: { type: Boolean, default: false },
  },
  emits: ['sync', 'delete', 'edit'],
  computed: {
    sourceIcon() {
      return this.source.source_type === 'canned_response' ? 'chat-multiple' : 'globe';
    },
    sourceLabel() {
      return this.source.source_type === 'canned_response' ? 'Respuestas Predefinidas' : 'Discourse';
    },
    isSyncing() {
      return this.source.sync_status === 'syncing';
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
      return this.source.config?.url || null;
    },
    discourseUsername() {
      return this.source.config?.username || null;
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-3 p-4 bg-white rounded-xl border border-slate-100 shadow-sm">

    <!-- Header -->
    <div class="flex items-start justify-between">
      <div class="flex items-center gap-3">
        <div class="flex items-center justify-center w-10 h-10 rounded-lg bg-woot-50">
          <fluent-icon :icon="sourceIcon" size="20" class="text-woot-500" />
        </div>
        <div>
          <p class="font-semibold text-slate-800 text-base">{{ source.name }}</p>
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
    <div v-if="discourseUsername && source.source_type === 'discourse'" class="flex items-center gap-1.5 text-sm text-slate-400">
      <fluent-icon icon="person" size="14" />
      <span>{{ discourseUsername }}</span>
    </div>

    <!-- Sincronización en progreso -->
    <div
      v-if="isSyncing"
      class="flex items-center gap-2 px-3 py-2 bg-woot-50 border border-woot-100 rounded-lg"
    >
      <span class="inline-block w-2 h-2 rounded-full bg-woot-500 animate-pulse" />
      <span class="text-sm text-woot-700 font-medium">
        Sincronizando{{ syncProgress ? ` — ${syncProgress}` : '...' }}
      </span>
    </div>
    <div v-else class="text-sm text-slate-400">
      Última sync: {{ lastSynced }}
    </div>

    <!-- Acciones -->
    <div class="flex gap-2 pt-1 border-t border-slate-100">
      <woot-button
        size="small"
        variant="smooth"
        color-scheme="primary"
        icon="arrow-clockwise"
        :disabled="syncing"
        @click="$emit('sync', source)"
      >
        {{ syncing ? 'Sincronizando...' : 'Sincronizar' }}
      </woot-button>
      <woot-button
        v-if="source.source_type !== 'canned_response'"
        size="small"
        variant="smooth"
        color-scheme="secondary"
        icon="edit"
        @click="$emit('edit', source)"
      />
      <woot-button
        v-if="source.source_type !== 'canned_response'"
        size="small"
        variant="smooth"
        color-scheme="alert"
        icon="delete"
        @click="$emit('delete', source)"
      />
    </div>

  </div>
</template>
