<script>
// feat/agentes_ia_unificado — VERSIONES DEL AGENTE
// ============================================================================
// El historial vive en el agente (tracking_template_versions), no en la
// conversación del Asistente: cada guardado que cambia su comportamiento deja una
// versión con desde dónde se hizo (ficha, Asistente, «Configurar», Galería,
// restaurar). Aquí se listan, se comparan campo por campo con la anterior (o con
// la que se elija) y se restauran. Restaurar avanza: deja una versión nueva.
// Las diferencias se pintan con diffHunks, el mismo que usa el Asistente. Tabla con
// el estilo nativo (fase B del ajuste visual); el diff se abre bajo la fila.
// ============================================================================
import { useAlert } from 'dashboard/composables';
import TrackingTemplatesAPI from 'dashboard/api/trackingTemplates';
import { diffHunks, diffStats } from '../assistant/lineDiff';

export default {
  props: {
    templateId: { type: Number, required: true },
    // Restaurar cambia el Entrenamiento: solo admin (el servidor también lo exige).
    canRestore: { type: Boolean, default: false },
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
      const campos = (version.changed_fields || []).map(this.fieldLabel);
      return campos.length ? campos.join(' · ') : '-';
    },
    // El color del origen: lo hecho por el Asistente o «Configurar» se distingue de
    // lo hecho a mano; restaurar, en ámbar.
    sourceScheme(source) {
      if (source === 'assistant' || source === 'configured') return 'primary';
      if (source === 'restore') return 'warning';
      if (source === 'gallery') return 'success';
      return 'secondary';
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
  <div class="text-slate-700 dark:text-slate-300">
    <p class="mb-4 text-base text-slate-600 dark:text-slate-300">
      {{ t('HINT') }}
    </p>
    <woot-loading-state v-if="isLoading" :message="t('LOADING')" />
    <p
      v-else-if="!versions.length"
      class="flex flex-col items-center justify-center h-full py-8 text-base text-slate-600 dark:text-slate-300"
    >
      {{ t('EMPTY') }}
    </p>

    <div v-else class="min-w-full overflow-x-auto">
      <table class="min-w-full divide-y divide-slate-75 dark:divide-slate-700">
        <thead>
          <th
            v-for="col in [
              'VERSION',
              'SOURCE',
              'NOTE',
              'CHANGED',
              'AUTHOR',
              'DATE',
            ]"
            :key="col"
            class="py-4 pr-4 font-semibold text-left whitespace-nowrap text-slate-700 dark:text-slate-300"
          >
            {{ t(`COLUMNS.${col}`) }}
          </th>
          <th class="py-4" />
        </thead>
        <tbody
          class="divide-y divide-slate-50 dark:divide-slate-800 text-slate-700 dark:text-slate-300"
        >
          <template v-for="version in versions">
            <tr :key="`fila-${version.id}`">
              <td class="py-4 pr-4 font-medium whitespace-nowrap">
                {{ t('LABEL', { number: version.version }) }}
                <woot-label
                  v-if="version.version === latestVersion"
                  small
                  color-scheme="success"
                  class="!mb-0 ltr:ml-2 rtl:mr-2"
                  :title="t('ACTIVE')"
                />
              </td>
              <td class="py-4 pr-4">
                <woot-label
                  small
                  class="!mb-0"
                  :color-scheme="sourceScheme(version.source)"
                  :title="sourceLabel(version.source)"
                />
              </td>
              <td class="max-w-xs py-4 pr-4">
                <div class="line-clamp-2" :title="version.note || ''">
                  {{ version.note || '-' }}
                </div>
              </td>
              <td class="max-w-xs py-4 pr-4">
                <div class="line-clamp-2">{{ changedLabel(version) }}</div>
              </td>
              <td class="py-4 pr-4 whitespace-nowrap">
                {{ version.author || '-' }}
              </td>
              <td class="py-4 pr-4 whitespace-nowrap">
                {{ time(version.created_at) }}
              </td>
              <td class="py-4">
                <div class="flex justify-end gap-1">
                  <woot-button
                    v-tooltip.top="
                      openId === version.id ? t('HIDE_DIFF') : t('SHOW_DIFF')
                    "
                    variant="smooth"
                    size="tiny"
                    color-scheme="secondary"
                    :icon="
                      openId === version.id ? 'chevron-up' : 'chevron-down'
                    "
                    :is-loading="isLoadingDetail && openId === version.id"
                    @click="toggle(version)"
                  />
                  <woot-button
                    v-if="canRestore && version.version !== latestVersion"
                    v-tooltip.top="t('RESTORE')"
                    variant="smooth"
                    size="tiny"
                    color-scheme="secondary"
                    icon="arrow-clockwise"
                    :is-loading="isRestoring && restoreTarget === version"
                    @click="askRestore(version)"
                  />
                </div>
              </td>
            </tr>
            <tr
              v-if="openId === version.id && detail"
              :key="`diff-${version.id}`"
            >
              <td colspan="7" class="py-4">
                <label
                  class="flex flex-wrap items-center gap-2 mb-3 text-sm text-slate-600 dark:text-slate-300"
                >
                  {{ t('COMPARE_WITH') }}
                  <select
                    v-model="compareWith"
                    class="!mb-0 !w-auto"
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
                <p v-if="!fields.length" class="mb-0 text-sm">
                  {{ t('NO_CHANGES') }}
                </p>
                <div v-for="campo in fields" :key="campo.field" class="mb-3">
                  <p class="mb-1 text-sm font-semibold">
                    {{ fieldLabel(campo.field) }}
                    <span
                      class="font-normal text-slate-500 dark:text-slate-400"
                    >
                      {{ t('STATS', campo.stats) }}
                    </span>
                  </p>
                  <div
                    class="overflow-x-auto rounded-md bg-slate-25 dark:bg-slate-800"
                  >
                    <pre class="!m-0 p-3 font-mono text-xs leading-5"><template
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
              </td>
            </tr>
          </template>
        </tbody>
      </table>
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
