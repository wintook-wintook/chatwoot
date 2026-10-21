<script>
// feat/agentes_ia_unificado — VERSIONES DEL AGENTE
// ============================================================================
// El historial vive en el agente (tracking_template_versions), no en la
// conversación del Asistente: cada guardado que cambia su comportamiento deja una
// versión con desde dónde se hizo (ficha, Asistente, «Configurar», Galería,
// restaurar). Aquí se listan, se comparan campo por campo con la anterior (o con
// la que se elija) y se restauran. Restaurar avanza: deja una versión nueva.
// Las diferencias se pintan con diffHunks, el mismo que usa el Asistente.
// ============================================================================
import { useAlert } from 'dashboard/composables';
import TrackingTemplatesAPI from 'dashboard/api/trackingTemplates';
import { diffHunks, diffStats } from '../assistant/lineDiff';

export default {
  props: {
    templateId: { type: Number, required: true },
  },
  emits: ['restored'],
  data() {
    return {
      versions: [],
      isLoading: false,
      openId: null,
      compareWith: '',
      detail: null,
      isLoadingDetail: false,
      restoreTarget: null,
      isRestoring: false,
    };
  },
  computed: {
    latestVersion() {
      return this.versions.length ? this.versions[0].version : null;
    },
    // Con qué se puede comparar la versión abierta: cualquier otra.
    compareOptions() {
      return this.versions.filter(v => v.id !== this.openId);
    },
    fields() {
      if (!this.detail) return [];
      return (this.detail.diff || []).map(entry => ({
        field: entry.field,
        stats: diffStats(entry.from, entry.to),
        hunks: diffHunks(entry.from, entry.to),
      }));
    },
    restoreDescription() {
      const version = this.restoreTarget || {};
      return this.t('RESTORE_DESCRIPTION', { number: version.version });
    },
  },
  watch: {
    templateId: { immediate: true, handler: 'fetchVersions' },
  },
  methods: {
    t(key, args) {
      return this.$t(`TRACKING_TEMPLATES.WORKSPACE.VERSIONS.${key}`, args);
    },
    sourceLabel(source) {
      return this.t(`SOURCE.${String(source || 'manual').toUpperCase()}`);
    },
    fieldLabel(field) {
      return this.t(`FIELD.${field.toUpperCase()}`);
    },
    changedLabel(version) {
      return (version.changed_fields || []).map(this.fieldLabel).join(' · ');
    },
    time(value) {
      if (!value) return '';
      return new Date(value).toLocaleString(undefined, {
        day: '2-digit',
        month: '2-digit',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
      });
    },
    async fetchVersions() {
      this.isLoading = true;
      try {
        const { data } = await TrackingTemplatesAPI.getVersions(
          this.templateId
        );
        this.versions = data.versions || [];
      } catch (error) {
        this.versions = [];
      } finally {
        this.isLoading = false;
      }
    },
    async toggle(version) {
      if (this.openId === version.id) {
        this.openId = null;
        this.detail = null;
        return;
      }
      this.openId = version.id;
      this.compareWith = '';
      await this.loadDetail();
    },
    async loadDetail() {
      this.isLoadingDetail = true;
      try {
        const { data } = await TrackingTemplatesAPI.getVersion(
          this.templateId,
          this.openId,
          this.compareWith || null
        );
        this.detail = data;
      } catch (error) {
        this.detail = null;
        useAlert(this.t('LOAD_ERROR'));
      } finally {
        this.isLoadingDetail = false;
      }
    },
    async askRestore(version) {
      this.restoreTarget = version;
      const ok = await this.$refs.restoreDialog.showConfirmation();
      if (!ok) return;
      this.isRestoring = true;
      try {
        const { data } = await TrackingTemplatesAPI.restoreVersion(
          this.templateId,
          version.id
        );
        useAlert(
          this.t('RESTORED', {
            number: version.version,
            version: data.version,
          })
        );
        this.openId = null;
        this.detail = null;
        await this.fetchVersions();
        this.$emit('restored', data);
      } catch (error) {
        useAlert(this.t('RESTORE_ERROR'));
      } finally {
        this.isRestoring = false;
      }
    },
  },
};
</script>

<template>
  <div class="flex flex-col flex-1 min-h-0 gap-3 overflow-y-auto text-sm">
    <p class="!m-0 text-xs text-slate-500 dark:text-slate-400">
      {{ t('HINT') }}
    </p>
    <p
      v-if="isLoading"
      class="!m-0 text-xs text-slate-500 dark:text-slate-400"
    >
      {{ t('LOADING') }}
    </p>
    <p
      v-else-if="!versions.length"
      class="!m-0 text-xs text-slate-500 dark:text-slate-400"
    >
      {{ t('EMPTY') }}
    </p>

    <div
      v-for="version in versions"
      :key="version.id"
      class="flex flex-col gap-2 p-3 bg-white border rounded-lg dark:bg-slate-800 border-slate-100 dark:border-slate-700"
    >
      <div class="flex flex-wrap items-center gap-2 text-xs">
        <span
          class="font-mono font-semibold text-slate-800 dark:text-slate-100"
        >
          {{ t('LABEL', { number: version.version }) }}
        </span>
        <span
          class="px-1.5 py-0.5 rounded bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300"
        >
          {{ sourceLabel(version.source) }}
        </span>
        <span
          v-if="version.version === latestVersion"
          class="px-1.5 py-0.5 rounded bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-300"
        >
          {{ t('ACTIVE') }}
        </span>
        <span class="text-slate-400 dark:text-slate-500">
          {{ time(version.created_at) }}
        </span>
        <span v-if="version.author" class="text-slate-500 dark:text-slate-400">
          · {{ version.author }}
        </span>
      </div>
      <p
        v-if="version.note"
        class="!m-0 text-xs text-slate-700 dark:text-slate-200"
      >
        {{ version.note }}
      </p>
      <p
        v-if="version.changed_fields && version.changed_fields.length"
        class="!m-0 text-xs text-slate-500 dark:text-slate-400"
      >
        {{ t('CHANGED', { fields: changedLabel(version) }) }}
      </p>
      <div class="flex flex-wrap gap-2">
        <woot-button
          size="tiny"
          variant="clear"
          color-scheme="secondary"
          :is-loading="isLoadingDetail && openId === version.id"
          @click="toggle(version)"
        >
          {{ openId === version.id ? t('HIDE_DIFF') : t('SHOW_DIFF') }}
        </woot-button>
        <woot-button
          v-if="version.version !== latestVersion"
          size="tiny"
          variant="smooth"
          :is-loading="isRestoring && restoreTarget === version"
          @click="askRestore(version)"
        >
          {{ t('RESTORE') }}
        </woot-button>
      </div>

      <div
        v-if="openId === version.id && detail"
        class="flex flex-col gap-2 text-xs"
      >
        <label
          class="flex flex-wrap items-center gap-2 !mb-0 text-slate-500 dark:text-slate-400"
        >
          {{ t('COMPARE_WITH') }}
          <select
            v-model="compareWith"
            class="!mb-0 !py-1 !w-auto text-xs"
            @change="loadDetail"
          >
            <option value="">{{ t('COMPARE_PREVIOUS') }}</option>
            <option
              v-for="opcion in compareOptions"
              :key="opcion.id"
              :value="opcion.id"
            >
              {{ t('LABEL', { number: opcion.version }) }} ·
              {{ sourceLabel(opcion.source) }}
            </option>
          </select>
        </label>
        <p v-if="!fields.length" class="!m-0 text-slate-500">
          {{ t('NO_CHANGES') }}
        </p>
        <div v-for="campo in fields" :key="campo.field">
          <p class="!m-0 mb-1 font-semibold text-slate-700 dark:text-slate-200">
            {{ fieldLabel(campo.field) }}
            <span class="font-normal text-slate-500 dark:text-slate-400">
              {{ t('STATS', campo.stats) }}
            </span>
          </p>
          <div class="overflow-x-auto rounded bg-slate-50 dark:bg-slate-900">
            <pre class="!m-0 p-2 font-mono text-xs leading-5"><template
              v-for="(line, lineIndex) in campo.hunks"
            ><span
              v-if="line.type === 'skip'"
              :key="`s${lineIndex}`"
              class="block text-slate-400 dark:text-slate-500"
            >{{ t('SKIP', { count: line.count }) }}</span><span
              v-else
              :key="`l${lineIndex}`"
              class="block whitespace-pre-wrap"
              :class="{
                'bg-red-100 text-red-800 dark:bg-red-900/40 dark:text-red-200': line.type === 'del',
                'bg-green-100 text-green-800 dark:bg-green-900/40 dark:text-green-200': line.type === 'add',
              }"
            >{{ line.type === 'del' ? '− ' : line.type === 'add' ? '+ ' : '  ' }}{{ line.text }}</span></template></pre>
          </div>
        </div>
      </div>
    </div>

    <woot-confirm-modal
      ref="restoreDialog"
      :title="t('RESTORE_TITLE')"
      :description="restoreDescription"
      :confirm-label="t('RESTORE_YES')"
      :cancel-label="t('RESTORE_NO')"
    />
  </div>
</template>
