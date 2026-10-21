<script>
// feat/agentes_ia_unificado — ESPACIO DEL AGENTE
// ============================================================================
// Todo lo de un Agente IA en una sola pantalla, sin ir y venir entre «Agentes IA»
// y «Asistente»:
//
//   ← Agentes IA   Nombre · Bandeja · v12
//   ┌──────────────┬───────────────────────────────────────────┐
//   │ Entrenamiento│  el Asistente (Estructura/Chat + Editor,   │  solo admin
//   │ Ficha        │  Configurar…) · «Publicar cambios»         │
//   │ Versiones    │  la ficha (sin Entrenamiento para admin)   │
//   │              │  el historial con su origen y restaurar    │
//   └──────────────┴───────────────────────────────────────────┘
//
// Rutas: /tracking-dashboard/agents/:templateId (un número, o «new»).
//   ?session=ID   retomar una conversación de «En construcción»
//   ?galeria=1    abrir la Galería al entrar (agente nuevo)
//   ?seccion=     training · profile · versions
//
// El Entrenamiento trabaja sobre un BORRADOR (la conversación del Asistente, que se
// guarda sola) y «Publicar cambios» lo aplica al agente dejando una versión. Al
// volver al agente se retoma su borrador abierto. La ficha guarda directo, y también
// deja versión (origen «A mano»).
// ============================================================================
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import Assistant from './Assistant.vue';
import AgentVersions from './agents/AgentVersions.vue';
import TemplateForm from 'dashboard/routes/dashboard/settings/trackingTemplates/EditTemplate.vue';
import TrackingTemplatesAPI from 'dashboard/api/trackingTemplates';

export default {
  components: { Assistant, AgentVersions, TemplateForm },
  data() {
    return {
      section: null,
      versionCount: null,
      latestVersion: null,
      // Cambia al restaurar: el Asistente y la ficha se vuelven a montar con lo
      // que quedó publicado.
      reloadKey: 0,
    };
  },
  computed: {
    ...mapGetters({
      currentRole: 'getCurrentRole',
      templates: 'trackingTemplates/getTemplates',
    }),
    isAdmin() {
      return this.currentRole === 'administrator';
    },
    isNew() {
      return this.$route.params.templateId === 'new';
    },
    templateId() {
      return this.isNew ? null : Number(this.$route.params.templateId);
    },
    template() {
      return (this.templates || []).find(t => t.id === this.templateId) || null;
    },
    sessionId() {
      const id = Number(this.$route.query.session);
      return id || null;
    },
    sections() {
      return [
        this.isAdmin && { id: 'training', label: 'SECTION_TRAINING' },
        !this.isNew && { id: 'profile', label: 'SECTION_PROFILE' },
        !this.isNew && { id: 'versions', label: 'SECTION_VERSIONS' },
      ].filter(Boolean);
    },
    title() {
      if (this.template) return this.template.name;
      return this.isNew ? this.t('NEW_TITLE') : '…';
    },
    inboxName() {
      return (this.template && this.template.inbox_name) || '';
    },
    versionLabel() {
      return this.latestVersion
        ? this.t('ACTIVE_VERSION', { number: this.latestVersion })
        : '';
    },
  },
  watch: {
    '$route.params.templateId': {
      immediate: true,
      handler() {
        this.pickSection();
        this.fetchVersionInfo();
      },
    },
  },
  mounted() {
    this.$store.dispatch('trackingTemplates/get');
  },
  methods: {
    t(key, args) {
      return this.$t(`TRACKING_TEMPLATES.WORKSPACE.${key}`, args);
    },
    pickSection() {
      const pedida = this.$route.query.seccion;
      const valida = this.sections.some(s => s.id === pedida);
      this.section = valida
        ? pedida
        : (this.sections[0] && this.sections[0].id) || null;
    },
    goSection(id) {
      this.section = id;
      if (id === 'versions') this.fetchVersionInfo();
    },
    goBack() {
      this.$router.push({ name: 'contact_trackings_agents' });
    },
    async fetchVersionInfo() {
      if (!this.templateId) {
        this.latestVersion = null;
        return;
      }
      try {
        const { data } = await TrackingTemplatesAPI.getVersions(
          this.templateId
        );
        const versiones = data.versions || [];
        this.versionCount = versiones.length;
        this.latestVersion = versiones.length ? versiones[0].version : null;
      } catch (error) {
        this.latestVersion = null;
      }
    },
    // El agente nuevo ya existe (publicado o bajado de la Galería): la ruta pasa a él
    // sin desmontar el Asistente (replace, y el Asistente ignora su propio id).
    goToAgent(id) {
      if (!id) return;
      this.$router.replace({
        name: 'contact_trackings_agent',
        params: { templateId: String(id) },
        query: { seccion: 'training' },
      });
      this.fetchVersionInfo();
    },
    onAssistantSession(id) {
      if (this.sessionId && this.sessionId !== id) {
        this.$router.replace({ query: { ...this.$route.query, session: id } });
      }
    },
    async onProfileSave(payload) {
      try {
        await this.$store.dispatch('trackingTemplates/update', payload);
        useAlert(this.$t('TRACKING_TEMPLATES.EDIT.API.SUCCESS_MESSAGE'));
        this.fetchVersionInfo();
      } catch (error) {
        const servidor = error && error.response && error.response.data;
        useAlert(
          (servidor && servidor.message) ||
            this.$t('TRACKING_TEMPLATES.EDIT.API.ERROR_MESSAGE')
        );
      }
    },
    async onRestored() {
      await this.$store.dispatch('trackingTemplates/get');
      this.reloadKey += 1;
      this.fetchVersionInfo();
    },
  },
};
</script>

<template>
  <div class="flex flex-col flex-1 w-full h-full min-h-0 p-4 overflow-hidden">
    <div class="flex flex-wrap items-center gap-3 mb-3 shrink-0">
      <woot-sidemenu-icon />
      <woot-button
        variant="clear"
        color-scheme="secondary"
        size="small"
        icon="chevron-left"
        @click="goBack"
      >
        {{ t('BACK') }}
      </woot-button>
      <h1
        class="!m-0 text-xl font-bold truncate text-slate-800 dark:text-slate-100"
      >
        {{ title }}
      </h1>
      <span
        v-if="inboxName"
        class="px-2 py-0.5 text-xs rounded bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300"
      >
        {{ inboxName }}
      </span>
      <span
        v-if="versionLabel"
        class="px-2 py-0.5 text-xs rounded bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-300"
      >
        {{ versionLabel }}
      </span>
    </div>

    <div class="flex flex-1 min-h-0 gap-4">
      <nav class="flex flex-col w-44 gap-1 shrink-0" role="tablist">
        <woot-button
          v-for="item in sections"
          :key="item.id"
          size="small"
          :variant="section === item.id ? 'smooth' : 'clear'"
          :color-scheme="section === item.id ? 'primary' : 'secondary'"
          class="!justify-start"
          role="tab"
          :aria-selected="section === item.id"
          @click="goSection(item.id)"
        >
          {{ t(item.label) }}
        </woot-button>
        <p
          v-if="!isAdmin"
          class="!mt-3 text-xs text-slate-500 dark:text-slate-400"
        >
          {{ t('AGENT_ROLE_HINT') }}
        </p>
      </nav>

      <div class="flex flex-col flex-1 min-w-0 min-h-0">
        <Assistant
          v-if="section === 'training'"
          :key="`training-${reloadKey}`"
          :template-id="templateId"
          :initial-session-id="sessionId"
          :open-gallery="!!$route.query.galeria"
          @saved="goToAgent"
          @installed="goToAgent"
          @session="onAssistantSession"
        />
        <div
          v-else-if="section === 'profile' && template"
          class="flex-1 min-h-0 overflow-auto"
        >
          <TemplateForm
            :key="`profile-${template.id}-${reloadKey}`"
            mode="edit"
            :template-data="template"
            :hide-training="isAdmin"
            @save="onProfileSave"
            @cancel="goBack"
          />
        </div>
        <AgentVersions
          v-else-if="section === 'versions' && templateId"
          :key="`versions-${templateId}-${reloadKey}`"
          :template-id="templateId"
          @restored="onRestored"
        />
      </div>
    </div>
  </div>
</template>
