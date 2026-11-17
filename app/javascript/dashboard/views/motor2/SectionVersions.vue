<script>
// Motor 2.0 › Versiones: cada guardado que cambió algo (a mano, el entrenador, restaurar).
// Restaurar no borra: deja una versión nueva igual a la elegida.
import { useAlert } from 'dashboard/composables';
import Motor2AgentsAPI from 'dashboard/api/motor2Agents';

export default {
  props: {
    templateId: { type: Number, default: null },
    // Cambia cuando se guarda: vuelve a leer la lista.
    stamp: { type: [String, Number], default: '' },
  },
  emits: ['restored'],
  data() {
    return { versions: [], loading: false, restoring: null };
  },
  watch: {
    stamp() {
      this.load();
    },
  },
  mounted() {
    this.load();
  },
  methods: {
    t(key, args) {
      return this.$t(`MOTOR2.VERSIONS.${key}`, args);
    },
    async load() {
      if (!this.templateId) return;
      this.loading = true;
      try {
        const { data } = await Motor2AgentsAPI.versions(this.templateId);
        this.versions = data;
      } finally {
        this.loading = false;
      }
    },
    async restore(version) {
      this.restoring = version.id;
      try {
        const { data } = await Motor2AgentsAPI.restore(
          this.templateId,
          version.id
        );
        this.$emit('restored', data);
        useAlert(this.t('RESTORED', { n: version.version }));
        await this.load();
      } catch (e) {
        useAlert(e.response?.data?.error || this.t('ERROR'));
      } finally {
        this.restoring = null;
      }
    },
    when(date) {
      return new Date(date).toLocaleString();
    },
  },
};
</script>

<template>
  <div>
    <p v-if="!templateId" class="m2-hint">{{ t('SAVE_FIRST') }}</p>
    <p v-else-if="loading && !versions.length" class="m2-hint">
      {{ t('LOADING') }}
    </p>
    <ul v-else class="divide-y divide-slate-100 dark:divide-slate-700">
      <li
        v-for="(v, i) in versions"
        :key="v.id"
        class="flex items-center gap-3 py-2 text-sm"
      >
        <span class="font-medium w-10">{{ t('V', { n: v.version }) }}</span>
        <span class="flex-1 min-w-0">
          <span class="block"
            >{{ t(`SOURCES.${v.source}`)
            }}{{ v.note ? ` · ${v.note}` : '' }}</span
          >
          <span class="block text-xs text-slate-500">
            {{ when(v.created_at) }}{{ v.author ? ` · ${v.author}` : '' }}
          </span>
        </span>
        <span v-if="i === 0" class="text-xs text-green-700">{{
          t('CURRENT')
        }}</span>
        <woot-button
          v-else
          size="tiny"
          variant="smooth"
          :is-loading="restoring === v.id"
          @click="restore(v)"
        >
          {{ t('RESTORE') }}
        </woot-button>
      </li>
    </ul>
  </div>
</template>
