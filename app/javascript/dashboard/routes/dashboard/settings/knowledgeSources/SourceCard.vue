<!-- @knowledge_sources -->
<!-- Tarjeta individual de una fuente de conocimiento configurada. -->
<!-- «¿Qué hay aquí?»: lo lee el agente 2.0 para saber en qué fuente buscar cada cosa
     (Motor2::SourceMap). Vacío = lo que se calcula de lo que tiene dentro (about_auto). -->
<script>
import { useAlert } from 'dashboard/composables';
import KnowledgeBaseAPI from './api';

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
  data() {
    // saved: lo que se guardó aquí (la lista no se recarga); null = lo que trajo la fuente.
    return {
      editingPurpose: false,
      purposeDraft: '',
      savingPurpose: false,
      saved: null,
    };
  },
  computed: {
    purpose() {
      return this.saved === null ? this.source.purpose || '' : this.saved;
    },
    about() {
      return this.purpose || this.source.about_auto || '';
    },
    sourceIcon() {
      return (
        {
          canned_response: 'chat-multiple',
          article: 'library',
          google_doc: 'document',
          google_sheet: 'document',
          contpaq_support: 'cloud',
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
          contpaq_support: 'Agente de Servicio CONTPAQi',
        }[this.source.source_type] || 'Discourse'
      );
    },
    // Fuentes configurables por el usuario (se editan/borran): Discourse, Docs y Sheets.
    // Las nativas (Respuestas predefinidas, Centro de Ayuda) son fijas.
    isConfigurable() {
      return [
        'discourse',
        'google_doc',
        'google_sheet',
        'contpaq_support',
      ].includes(this.source.source_type);
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
    sourceUrl() {
      return (
        this.source.config?.url ||
        this.source.config?.file_url ||
        this.source.config?.base_url ||
        null
      );
    },
    discourseUsername() {
      return this.source.config?.username || null;
    },
  },
  methods: {
    editPurpose() {
      this.purposeDraft = this.purpose;
      this.editingPurpose = true;
    },
    async savePurpose() {
      this.savingPurpose = true;
      try {
        const { data } = await KnowledgeBaseAPI.setPurpose(
          this.$route.params.accountId,
          this.source.id,
          this.purposeDraft.trim()
        );
        this.saved = data.purpose || '';
        this.editingPurpose = false;
      } catch (e) {
        useAlert(this.$t('KNOWLEDGE_CARD.PURPOSE.ERROR'));
      } finally {
        this.savingPurpose = false;
      }
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
    <div v-if="sourceUrl" class="text-sm text-slate-500 truncate">
      {{ sourceUrl }}
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
        {{ $t('KNOWLEDGE_CARD.GOOGLE_OFF') }}
      </span>
    </div>

    <!-- Aviso: falta integración OpenAI para poder vectorizar -->
    <div
      v-if="needsOpenai && !googleDisabled"
      class="flex items-center gap-2 px-3 py-2 bg-amber-50 border border-amber-100 rounded-lg"
    >
      <fluent-icon icon="warning" size="14" class="text-amber-500" />
      <span class="text-sm text-amber-700">
        {{ $t('KNOWLEDGE_CARD.NEEDS_OPENAI') }}
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
          {{ $t('KNOWLEDGE_CARD.SYNCING')
          }}{{ syncProgress ? ` — ${syncProgress}` : '…' }}
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
        {{ $t('KNOWLEDGE_CARD.LAST_SYNC', { when: lastSynced }) }}
      </div>
    </template>

    <!-- ¿Qué hay aquí? (lo lee el agente para saber dónde buscar) -->
    <div class="flex flex-col gap-1 text-sm">
      <span class="text-xs font-medium text-slate-600">
        {{ $t('KNOWLEDGE_CARD.PURPOSE.LABEL') }}
      </span>
      <template v-if="editingPurpose">
        <textarea
          v-model="purposeDraft"
          rows="3"
          maxlength="300"
          class="!mb-0 text-sm"
          :placeholder="
            source.about_auto || $t('KNOWLEDGE_CARD.PURPOSE.PLACEHOLDER')
          "
        />
        <p class="m-0 text-xs text-slate-500">
          {{ $t('KNOWLEDGE_CARD.PURPOSE.HINT') }}
        </p>
        <div class="flex gap-2">
          <woot-button
            size="tiny"
            :is-loading="savingPurpose"
            @click="savePurpose"
          >
            {{ $t('KNOWLEDGE_CARD.PURPOSE.SAVE') }}
          </woot-button>
          <woot-button
            size="tiny"
            variant="clear"
            color-scheme="secondary"
            @click="editingPurpose = false"
          >
            {{ $t('KNOWLEDGE_CARD.PURPOSE.CANCEL') }}
          </woot-button>
        </div>
      </template>
      <button
        v-else
        type="button"
        class="text-left text-slate-600 hover:underline"
        :title="$t('KNOWLEDGE_CARD.PURPOSE.EDIT')"
        @click="editPurpose"
      >
        <span v-if="about">{{ about }}</span>
        <span v-else class="text-slate-400">{{
          $t('KNOWLEDGE_CARD.PURPOSE.EMPTY')
        }}</span>
        <span
          v-if="!purpose && source.about_auto"
          class="block text-xs text-slate-400"
          >{{ $t('KNOWLEDGE_CARD.PURPOSE.AUTO') }}</span
        >
      </button>
    </div>

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
