<script>
// ================================================================================
// proyecto@ai_agent_assistant - F4
// ================================================================================
// Componente: VersionsDrawer
// Descripción: Historial en sitio del Agente IA. Lista los guardados, muestra el
//              diff línea por línea contra la versión anterior (o contra la que se
//              elija) y permite restaurar.
//
// También avisa de las copias «… V2 / V3 / V4» del mismo caso de uso: con
// versionado ya no hacen falta, y se pueden archivar sin borrar nada.
// ================================================================================
import TrackingTemplateVersionsAPI from 'dashboard/api/trackingTemplateVersions';
import { useAlert } from 'dashboard/composables';

export default {
  props: {
    show: {
      type: Boolean,
      default: false,
    },
    templateId: {
      type: [Number, String],
      default: null,
    },
  },
  emits: ['close', 'restored'],
  data() {
    return {
      versions: [],
      siblings: [],
      detail: null,
      selectedId: null,
      compareWith: '',
      isLoading: false,
      isRestoring: false,
      confirmingRestore: false,
    };
  },
  computed: {
    // Contra qué se puede comparar la versión abierta: cualquier otra del historial.
    comparableVersions() {
      return this.versions.filter(v => v.id !== this.selectedId);
    },
    // Las copias que se pueden archivar: todas menos la que se está editando.
    archivableSiblings() {
      return this.siblings.filter(s => !s.current && !s.archived);
    },
    hasSiblings() {
      return this.siblings.length > 1;
    },
  },
  watch: {
    show(value) {
      if (value) this.load();
    },
  },
  methods: {
    async load() {
      this.isLoading = true;
      this.confirmingRestore = false;
      try {
        const [{ data: history }, { data: family }] = await Promise.all([
          TrackingTemplateVersionsAPI.list(this.templateId),
          TrackingTemplateVersionsAPI.siblings(this.templateId),
        ]);
        this.versions = history.versions;
        this.siblings = family.siblings;
        if (this.versions.length) this.select(this.versions[0].id);
      } catch (error) {
        useAlert(this.$t('AI_AGENT_ASSISTANT.VERSIONS.LOAD_ERROR'));
      } finally {
        this.isLoading = false;
      }
    },
    async select(id) {
      this.selectedId = id;
      this.compareWith = '';
      this.confirmingRestore = false;
      await this.loadDetail();
    },
    async loadDetail() {
      try {
        const { data } = await TrackingTemplateVersionsAPI.show(
          this.templateId,
          this.selectedId,
          this.compareWith
        );
        this.detail = data;
      } catch (error) {
        this.detail = null;
      }
    },
    async onRestore() {
      if (!this.confirmingRestore) {
        this.confirmingRestore = true;
        return;
      }
      this.isRestoring = true;
      try {
        await TrackingTemplateVersionsAPI.restore(
          this.templateId,
          this.selectedId
        );
        useAlert(this.$t('AI_AGENT_ASSISTANT.VERSIONS.RESTORED'));
        this.$emit('restored');
        this.$emit('close');
      } catch (error) {
        useAlert(this.$t('AI_AGENT_ASSISTANT.VERSIONS.RESTORE_ERROR'));
      } finally {
        this.isRestoring = false;
        this.confirmingRestore = false;
      }
    },
    async onArchiveSibling(sibling) {
      try {
        await TrackingTemplateVersionsAPI.archive(sibling.id);
        useAlert(
          this.$t('AI_AGENT_ASSISTANT.VERSIONS.SIBLING_ARCHIVED', {
            name: sibling.name,
          })
        );
        const { data } = await TrackingTemplateVersionsAPI.siblings(
          this.templateId
        );
        this.siblings = data.siblings;
      } catch (error) {
        useAlert(this.$t('AI_AGENT_ASSISTANT.VERSIONS.ARCHIVE_ERROR'));
      }
    },
    fieldLabel(field) {
      return this.$t(`AI_AGENT_ASSISTANT.VERSIONS.FIELD.${field}`);
    },
    lineClasses(op) {
      if (op === 'add') {
        return 'bg-green-50 text-green-800 dark:bg-green-800/20 dark:text-green-300';
      }
      if (op === 'del') {
        return 'bg-red-50 text-red-800 line-through dark:bg-red-800/20 dark:text-red-300';
      }
      return 'text-slate-500 dark:text-slate-400';
    },
    lineMarker(op) {
      if (op === 'add') return '+';
      if (op === 'del') return '−';
      return ' ';
    },
    onClose() {
      this.$emit('close');
    },
  },
};
</script>

<template>
  <woot-modal :show="show" :on-close="onClose" size="medium">
    <div class="flex flex-col h-full max-h-[80vh]">
      <div class="px-8 pt-6">
        <h2 class="text-lg font-semibold text-slate-800 dark:text-slate-100">
          {{ $t('AI_AGENT_ASSISTANT.VERSIONS.TITLE') }}
        </h2>
        <p class="mt-1 text-sm text-slate-600 dark:text-slate-400">
          {{ $t('AI_AGENT_ASSISTANT.VERSIONS.DESCRIPTION') }}
        </p>
      </div>

      <!-- Las copias «… V2 / V3»: con historial en sitio ya no hacen falta -->
      <div v-if="hasSiblings" class="px-8 mt-4">
        <div
          class="px-4 py-3 text-xs border rounded-lg bg-amber-50 border-amber-200 dark:bg-amber-800/20 dark:border-amber-800"
        >
          <p class="m-0 font-semibold text-amber-800 dark:text-amber-200">
            {{
              $t('AI_AGENT_ASSISTANT.VERSIONS.SIBLINGS_TITLE', {
                count: siblings.length,
              })
            }}
          </p>
          <p class="mt-1 mb-2 text-amber-800 dark:text-amber-200">
            {{ $t('AI_AGENT_ASSISTANT.VERSIONS.SIBLINGS_HINT') }}
          </p>
          <ul class="m-0 list-none">
            <li
              v-for="sibling in siblings"
              :key="sibling.id"
              class="flex items-center gap-2 py-1"
            >
              <span class="text-amber-900 dark:text-amber-100">
                {{ sibling.name }}
              </span>
              <span v-if="sibling.current" class="text-amber-700">
                {{ $t('AI_AGENT_ASSISTANT.VERSIONS.SIBLING_CURRENT') }}
              </span>
              <span v-else-if="sibling.archived" class="text-amber-700">
                {{ $t('AI_AGENT_ASSISTANT.VERSIONS.SIBLING_ARCHIVED_TAG') }}
              </span>
              <span class="text-amber-700">
                {{
                  $t('AI_AGENT_ASSISTANT.VERSIONS.SIBLING_TRACKINGS', {
                    count: sibling.trackings_count,
                  })
                }}
              </span>
              <woot-button
                v-if="!sibling.current && !sibling.archived"
                size="tiny"
                variant="clear"
                color-scheme="warning"
                class="ml-auto"
                @click.prevent="onArchiveSibling(sibling)"
              >
                {{ $t('AI_AGENT_ASSISTANT.VERSIONS.ARCHIVE') }}
              </woot-button>
            </li>
          </ul>
          <p
            v-if="!archivableSiblings.length"
            class="mt-2 mb-0 text-amber-700 dark:text-amber-300"
          >
            {{ $t('AI_AGENT_ASSISTANT.VERSIONS.SIBLINGS_DONE') }}
          </p>
        </div>
      </div>

      <div v-if="isLoading" class="px-8 py-8 text-sm text-slate-500">
        {{ $t('AI_AGENT_ASSISTANT.VERSIONS.LOADING') }}
      </div>

      <div
        v-else-if="versions.length"
        class="flex flex-1 min-h-0 gap-6 px-8 pb-6 mt-4"
      >
        <!-- Historial -->
        <ul class="w-56 m-0 overflow-y-auto list-none shrink-0">
          <li v-for="version in versions" :key="version.id">
            <button
              class="w-full px-3 py-2 mb-1 text-left border rounded-md"
              :class="
                version.id === selectedId
                  ? 'bg-woot-25 border-woot-200 dark:bg-woot-800/30 dark:border-woot-700'
                  : 'bg-transparent border-transparent hover:bg-slate-25 dark:hover:bg-slate-800'
              "
              @click.prevent="select(version.id)"
            >
              <span
                class="block text-sm font-semibold text-slate-800 dark:text-slate-100"
              >
                {{
                  $t('AI_AGENT_ASSISTANT.VERSIONS.LABEL', {
                    version: version.version,
                  })
                }}
                <span class="font-normal text-slate-500 dark:text-slate-400">
                  ·
                  {{
                    $t(`AI_AGENT_ASSISTANT.VERSIONS.SOURCE.${version.source}`)
                  }}
                </span>
              </span>
              <span class="block text-xs text-slate-500 dark:text-slate-400">
                {{ new Date(version.created_at).toLocaleString() }}
              </span>
              <span
                v-if="version.author"
                class="block text-xs text-slate-500 dark:text-slate-400"
              >
                {{ version.author }}
              </span>
              <span
                v-if="version.note"
                class="block mt-1 text-xs italic text-slate-600 dark:text-slate-300"
              >
                {{ version.note }}
              </span>
              <span
                v-if="version.changed_fields.length"
                class="block mt-1 text-xs text-slate-500 dark:text-slate-400"
              >
                {{ version.changed_fields.map(fieldLabel).join(', ') }}
              </span>
            </button>
          </li>
        </ul>

        <!-- Diff -->
        <div class="flex-1 min-w-0 overflow-y-auto">
          <div class="flex items-center gap-2 mb-3">
            <label class="mb-0 text-xs text-slate-500 dark:text-slate-400">
              {{ $t('AI_AGENT_ASSISTANT.VERSIONS.COMPARE_WITH') }}
            </label>
            <select
              v-model="compareWith"
              class="h-8 py-0 mb-0 text-sm w-48"
              @change="loadDetail"
            >
              <option value="">
                {{ $t('AI_AGENT_ASSISTANT.VERSIONS.COMPARE_PREVIOUS') }}
              </option>
              <option
                v-for="version in comparableVersions"
                :key="version.id"
                :value="version.id"
              >
                {{
                  $t('AI_AGENT_ASSISTANT.VERSIONS.LABEL', {
                    version: version.version,
                  })
                }}
              </option>
            </select>
            <woot-button
              size="small"
              variant="smooth"
              class="ml-auto"
              :is-loading="isRestoring"
              :color-scheme="confirmingRestore ? 'alert' : 'secondary'"
              @click.prevent="onRestore"
            >
              {{
                confirmingRestore
                  ? $t('AI_AGENT_ASSISTANT.VERSIONS.RESTORE_CONFIRM')
                  : $t('AI_AGENT_ASSISTANT.VERSIONS.RESTORE')
              }}
            </woot-button>
          </div>

          <p
            v-if="detail && !detail.diff.length"
            class="text-sm text-slate-500 dark:text-slate-400"
          >
            {{ $t('AI_AGENT_ASSISTANT.VERSIONS.NO_CHANGES') }}
          </p>

          <div
            v-for="entry in detail ? detail.diff : []"
            :key="entry.field"
            class="mb-4"
          >
            <p
              class="mb-1 text-xs font-semibold text-slate-500 dark:text-slate-400"
            >
              {{ fieldLabel(entry.field) }}
            </p>
            <div
              class="overflow-x-auto text-xs rounded-lg bg-slate-25 dark:bg-slate-800"
            >
              <p
                v-for="(line, index) in entry.lines"
                :key="index"
                class="px-3 py-0.5 m-0 font-mono whitespace-pre-wrap"
                :class="lineClasses(line[0])"
              >
                {{ lineMarker(line[0]) }} {{ line[1] }}
              </p>
            </div>
          </div>
        </div>
      </div>

      <div v-else class="px-8 py-8 text-sm text-slate-500">
        {{ $t('AI_AGENT_ASSISTANT.VERSIONS.EMPTY') }}
      </div>

      <div class="px-8 py-4 border-t border-slate-200 dark:border-slate-700">
        <woot-button variant="clear" @click.prevent="onClose">
          {{ $t('AI_AGENT_ASSISTANT.VERSIONS.CLOSE') }}
        </woot-button>
      </div>
    </div>
  </woot-modal>
</template>
