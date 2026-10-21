<script>
// feat/agentes_ia_unificado — ESPACIO DEL AGENTE
// ============================================================================
// Todo lo de un Agente IA en una sola pantalla, sin ir y venir entre «Agentes IA»
// y «Asistente». Contenedor, encabezado (BaseSettingsHeader + BackButton) y
// pestañas (woot-tabs) como la configuración de un inbox (fase B del ajuste visual):
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
import BaseSettingsHeader from 'dashboard/routes/dashboard/settings/components/BaseSettingsHeader.vue';
import BackButton from 'dashboard/components/widgets/BackButton.vue';

export default {
  components: {
    Assistant,
    AgentVersions,
    TemplateForm,
    BaseSettingsHeader,
    BackButton,
  },
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
    // BaseSettingsHeader pide descripción: el objetivo del agente, o qué es esto.
    description() {
      if (this.template && this.template.objective)
        return this.template.objective;
      return this.isNew ? this.t('NEW_DESCRIPTION') : '';
    },
    // woot-tabs numera por POSICIÓN y las pestañas cambian según el rol y si el
    // agente ya existe: se traduce posición ↔ sección.
    sectionPosition() {
      return Math.max(
        0,
        this.sections.findIndex(item => item.id === this.section)
      );
    },
    listRoute() {
      return { name: 'contact_trackings_agents' };
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
  <div
    class="flex flex-col w-full h-full p-6 overflow-hidden bg-white sm:py-8 lg:px-16 dark:bg-slate-900 font-inter"
  >
    <div class="flex flex-col flex-1 w-full min-h-0 mx-auto max-w-8xl">
      <div class="shrink-0">
        <BackButton compact :back-url="listRoute" :button-label="t('BACK')" />
        <BaseSettingsHeader :title="title" :description="description">
          <template #actions>
            <woot-label
              v-if="inboxName"
              small
              color-scheme="primary"
              class="!mb-0"
              :title="inboxName"
            />
            <woot-label
              v-if="versionLabel"
              small
              color-scheme="success"
              class="!mb-0"
              :title="versionLabel"
            />
          </template>
        </BaseSettingsHeader>

        <woot-tabs
          class="mt-4"
          :index="sectionPosition"
          :border="false"
          @change="goSection(sections[$event].id)"
        >
          <woot-tabs-item
            v-for="(item, position) in sections"
            :key="item.id"
            :index="position"
            :name="t(item.label)"
            :show-badge="false"
          />
        </woot-tabs>
        <p
          v-if="!isAdmin"
          class="mt-2 mb-0 text-sm text-slate-500 dark:text-slate-400"
        >
          {{ t('AGENT_ROLE_HINT') }}
        </p>
      </div>

      <div class="flex flex-col flex-1 min-h-0 mt-6">
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
          class="flex-1 min-h-0 overflow-auto"
          @restored="onRestored"
        />
      </div>
    </div>
  </div>
</template>
