<script>
// proyecto@publicar_prompts (F7) — EL AUTOR PUBLICÓ UNA VERSIÓN NUEVA
// ============================================================================
// Para un agente que se bajó de la Galería: muestra en qué cambia el Entrenamiento de
// la versión nueva respecto del que está en el editor (con lo que la cuenta ya le
// adecuó). Nunca se aplica solo:
//   · «Cargar en el Asistente» pone el texto nuevo en el editor SIN guardar; la persona
//     lo revisa y decide si guarda.
//   · «Ignorar esta versión» solo deja de avisar hasta que salga otra.
// Las dos marcan la versión como revisada (…/published_prompts/:id/seen).
// Plan: docs/publicar_prompts_plan.md
// ============================================================================
import { useAlert } from 'dashboard/composables';
import Spinner from 'shared/components/Spinner.vue';
import AssistantAPI from 'dashboard/api/assistant';
import { diffHunks, diffStats } from './lineDiff';

export default {
  components: { Spinner },
  props: {
    show: { type: Boolean, default: false },
    // { published_prompt_id, version, current_version } (TrackingTemplate#published_prompt_update)
    update: { type: Object, default: null },
    templateId: { type: Number, default: null },
    // El Entrenamiento que está hoy en el editor.
    draft: { type: String, default: '' },
  },
  emits: ['close', 'load', 'seen'],
  data() {
    return { isLoading: false, isSaving: false, published: null };
  },
  computed: {
    newPrompt() {
      return this.published ? this.published.prompt || '' : '';
    },
    hunks() {
      return this.published ? diffHunks(this.draft, this.newPrompt) : [];
    },
    stats() {
      return this.published ? diffStats(this.draft, this.newPrompt) : null;
    },
    hasChanges() {
      return !!this.stats && (this.stats.added > 0 || this.stats.removed > 0);
    },
  },
  watch: {
    show(visible) {
      if (visible) this.load();
    },
  },
  methods: {
    async load() {
      if (!this.update) return;
      this.isLoading = true;
      this.published = null;
      try {
        const { data } = await AssistantAPI.getPublishedPrompt(
          this.update.published_prompt_id
        );
        this.published = data;
      } catch (error) {
        useAlert(this.$t('TRACKING_ASSISTANT_VIEW.GALLERY.UPDATE_LOAD_ERROR'));
        this.$emit('close');
      } finally {
        this.isLoading = false;
      }
    },
    async markSeen() {
      await AssistantAPI.markPublishedPromptSeen(
        this.update.published_prompt_id,
        this.templateId
      );
      this.$emit('seen');
    },
    async loadNewVersion() {
      this.isSaving = true;
      try {
        await this.markSeen();
        this.$emit('load', this.published);
        this.$emit('close');
      } catch (error) {
        useAlert(this.$t('TRACKING_ASSISTANT_VIEW.GALLERY.UPDATE_SAVE_ERROR'));
      } finally {
        this.isSaving = false;
      }
    },
    async ignore() {
      this.isSaving = true;
      try {
        await this.markSeen();
        this.$emit('close');
      } catch (error) {
        useAlert(this.$t('TRACKING_ASSISTANT_VIEW.GALLERY.UPDATE_SAVE_ERROR'));
      } finally {
        this.isSaving = false;
      }
    },
  },
};
</script>

<template>
  <woot-modal :show="show" :on-close="() => $emit('close')" size="medium">
    <div class="flex flex-col h-auto overflow-auto">
      <woot-modal-header
        :header-title="
          $t('TRACKING_ASSISTANT_VIEW.GALLERY.UPDATE_TITLE', {
            version: update ? update.version : '',
          })
        "
        :header-content="
          $t('TRACKING_ASSISTANT_VIEW.GALLERY.UPDATE_DESCRIPTION')
        "
      />
      <div class="flex flex-col gap-3 px-8 pb-6 text-sm">
        <div v-if="isLoading" class="flex justify-center py-8">
          <Spinner size="" />
        </div>
        <template v-else-if="published">
          <p class="!m-0 text-slate-600 dark:text-slate-300">
            {{
              hasChanges
                ? $t('TRACKING_ASSISTANT_VIEW.GALLERY.UPDATE_STATS', stats)
                : $t('TRACKING_ASSISTANT_VIEW.GALLERY.UPDATE_SAME')
            }}
          </p>
          <div
            v-if="hasChanges"
            class="overflow-auto rounded max-h-96 bg-slate-50 dark:bg-slate-900"
          >
            <pre class="!m-0 p-2 font-mono text-xs leading-5"><template
              v-for="(line, lineIndex) in hunks"
            ><span
              v-if="line.type === 'skip'"
              :key="`s${lineIndex}`"
              class="block text-slate-400 dark:text-slate-500"
            >{{ $t('TRACKING_ASSISTANT_VIEW.VERSION_DIFF_SKIP', { count: line.count }) }}</span><span
              v-else
              :key="`l${lineIndex}`"
              class="block whitespace-pre-wrap"
              :class="{
                'bg-red-100 text-red-800 dark:bg-red-900/40 dark:text-red-200': line.type === 'del',
                'bg-green-100 text-green-800 dark:bg-green-900/40 dark:text-green-200': line.type === 'add',
              }"
            >{{ line.type === 'del' ? '− ' : line.type === 'add' ? '+ ' : '  ' }}{{ line.text }}</span></template></pre>
          </div>
          <p class="!m-0 text-xs text-slate-500 dark:text-slate-400">
            {{ $t('TRACKING_ASSISTANT_VIEW.GALLERY.UPDATE_NOTE') }}
          </p>
          <div class="flex flex-wrap justify-end gap-2">
            <woot-button
              variant="clear"
              color-scheme="secondary"
              :is-disabled="isSaving"
              @click="ignore"
            >
              {{ $t('TRACKING_ASSISTANT_VIEW.GALLERY.UPDATE_IGNORE') }}
            </woot-button>
            <woot-button
              :is-loading="isSaving"
              :is-disabled="!hasChanges"
              @click="loadNewVersion"
            >
              {{ $t('TRACKING_ASSISTANT_VIEW.GALLERY.UPDATE_LOAD') }}
            </woot-button>
          </div>
        </template>
      </div>
    </div>
  </woot-modal>
</template>
