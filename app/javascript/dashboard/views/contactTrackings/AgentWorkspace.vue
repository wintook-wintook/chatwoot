<script>
// feat/agentes_ia_unificado — ESPACIO DEL AGENTE
// ============================================================================
// Todo lo de un Agente IA en una sola pantalla, sin ir y venir entre «Agentes IA»
// y «Asistente». Contenedor, encabezado (BaseSettingsHeader, con «← Agentes IA» a la derecha) y
// pestañas (woot-tabs) como la configuración de un inbox (fase B del ajuste visual):
//
//   Nombre                    ← Agentes IA · Bandeja · v12
//   ┌──────────────┬───────────────────────────────────────────┐
//   │ Entrenamiento│  el Asistente (Estructura/Chat + Editor,   │  solo admin
//   │ Pruebas y    │  Configurar…) · «Publicar cambios»         │
//   │  diagrama    │  la pila y el agente dibujado (mismo       │  solo admin
//   │              │  Asistente, otra vista: no se recarga)     │
//   │ Ficha        │                                           │
//   │ Versiones    │  la ficha (sin Entrenamiento para admin)   │
//   │              │  el historial con su origen y restaurar    │
//   └──────────────┴───────────────────────────────────────────┘
//
// Rutas: /tracking-dashboard/agents/:templateId (un número, o «new»).
//   ?session=ID   retomar una conversación de «En construcción»
//   ?galeria=1    abrir la Galería al entrar (agente nuevo)
//   ?seccion=     training · tests · sources · profile · versions
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
// feat/ficha_agente_ia: la ficha de recursos (agente nuevo en 3 pasos, o la de uno que ya existe)
import FichaWizard from './ficha/FichaWizard.vue';
import AgentFicha from './ficha/AgentFicha.vue';
import FichaAPI from 'dashboard/api/fichaAgente';

export default {
  components: {
    Assistant,
    AgentVersions,
    TemplateForm,
    BaseSettingsHeader,
    FichaWizard,
    AgentFicha,
  },
  data() {
    return {
      section: null,
      versionCount: null,
      latestVersion: null,
      // Cambia al restaurar: el Asistente y la ficha se vuelven a montar con lo
      // que quedó publicado.
      reloadKey: 0,
      // feat/ficha_agente_ia: cuántos cambios de la ficha faltan en el Entrenamiento.
      fichaChanges: 0,
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
    // feat/ficha_agente_ia: un agente nuevo empieza SOLO en Recursos; el Entrenamiento y lo
    // demás aparecen al crearlo (o si se elige crearlo conversando: ?modo=conversar).
    conversational() {
      return this.$route.query.modo === 'conversar';
    },
    sections() {
      if (this.isNew && this.isAdmin && !this.conversational)
        return [{ id: 'ficha', label: 'SECTION_FICHA' }];
      return [
        // feat/ficha_agente_ia: primero la ficha (D6). En un agente nuevo es el asistente de 3 pasos.
        this.isAdmin && { id: 'ficha', label: 'SECTION_FICHA' },
        this.isAdmin && { id: 'training', label: 'SECTION_TRAINING' },
        // proyecto@diagrama_agente_ia: pruebas y diagrama en su propia pestaña, a lo ancho.
        this.isAdmin && { id: 'tests', label: 'SECTION_TESTS' },
        // crear_agente_conversando §15: probar las fuentes como las busca el agente.
        this.isAdmin && { id: 'sources', label: 'SECTION_SOURCES' },
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
    versionLabel() {
      return this.latestVersion
        ? this.t('ACTIVE_VERSION', { number: this.latestVersion })
        : '';
    },
  },
  watch: {
    '$route.query.modo'() {
      this.pickSection();
    },
    '$route.params.templateId': {
      immediate: true,
      handler() {
        this.pickSection();
        this.fetchVersionInfo();
        this.fetchFichaChanges();
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
    async fetchFichaChanges() {
      this.fichaChanges = 0;
      if (!this.templateId || !this.isAdmin) return;
      try {
        const { data } = await FichaAPI.get(this.templateId);
        const cambios = data.changes || {};
        this.fichaChanges =
          (cambios.added || []).length + (cambios.removed || []).length;
      } catch (error) {
        this.fichaChanges = 0;
      }
    },
    onFichaApplied() {
      this.reloadKey += 1;
      this.fetchVersionInfo();
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
    startConversation() {
      this.$router.replace({
        query: { ...this.$route.query, modo: 'conversar', seccion: 'training' },
      });
    },
    // Recién creado desde la ficha: al Entrenamiento, para verlo y afinarlo.
    goToFicha(id) {
      this.goToAgent(id);
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
    class="flex flex-col flex-1 w-full h-full min-h-0 p-6 overflow-hidden bg-white sm:py-8 lg:px-16 dark:bg-slate-900 font-inter"
  >
    <div class="flex flex-col flex-1 w-full min-h-0 mx-auto max-w-8xl">
      <div class="shrink-0">
        <BaseSettingsHeader :title="title" :description="description">
          <template #actions>
            <!-- «← Agentes IA» subió aquí (pedido 22/10/2026), igual que «Volver» de la
               lista de Agentes IA; las etiquetas de al lado con su mismo alto (h-10). -->
            <div class="flex items-center gap-2">
              <woot-button
                variant="smooth"
                color-scheme="secondary"
                icon="chevron-left"
                @click="goBack"
              >
                {{ t('BACK') }}
              </woot-button>
              <woot-label
                v-if="inboxName"
                small
                color-scheme="primary"
                class="!mb-0 !mr-0 !h-10 !px-3 !text-sm !font-semibold !rounded-md"
                :title="inboxName"
              />
              <woot-label
                v-if="versionLabel"
                small
                color-scheme="success"
                class="!mb-0 !mr-0 !h-10 !px-3 !text-sm !rounded-md"
                :title="versionLabel"
              />
            </div>
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
            :count="item.id === 'ficha' ? fichaChanges : 0"
            :show-badge="item.id === 'ficha' && fichaChanges > 0"
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
        <!-- Entrenamiento y Pruebas son el MISMO Asistente con otra vista: un solo
             elemento con la misma key, así cambiar de pestaña no lo vuelve a montar. -->
        <FichaWizard
          v-if="section === 'ficha' && isNew"
          @created="goToFicha"
          @conversation="startConversation"
        />
        <AgentFicha
          v-else-if="section === 'ficha' && templateId"
          :key="`ficha-${templateId}-${reloadKey}`"
          :template-id="templateId"
          @applied="onFichaApplied"
          @changes="fichaChanges = $event"
        />
        <Assistant
          v-else-if="['training', 'tests', 'sources'].includes(section)"
          :key="`training-${reloadKey}`"
          :view="section"
          :template-id="templateId"
          :initial-session-id="sessionId"
          :open-gallery="!!$route.query.galeria"
          @saved="goToAgent"
          @installed="goToAgent"
          @session="onAssistantSession"
          @openTests="goSection('tests')"
          @openTraining="goSection('training')"
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
          :can-restore="isAdmin"
          class="flex-1 min-h-0 overflow-auto"
          @restored="onRestored"
        />
      </div>
    </div>
  </div>
</template>
