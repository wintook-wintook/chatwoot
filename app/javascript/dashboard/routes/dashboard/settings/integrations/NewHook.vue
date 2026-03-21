<!-- DEV0002 -->
<!-- eslint-disable vue/v-slot-style -->
<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { useIntegrationHook } from 'dashboard/composables/useIntegrationHook';
import axios from 'axios';

export default {
  props: {
    integrationId: {
      type: String,
      required: true,
    },
  },
  setup(props) {
    const { integration, isHookTypeInbox } = useIntegrationHook(
      props.integrationId
    );

    return { integration, isHookTypeInbox };
  },
  data() {
    return {
      endPoint: '',
      alertMessage: '',
      values: {},
      isValidating: false,
    };
  },
  computed: {
    ...mapGetters({
      uiFlags: 'integrations/getUIFlags',
      dialogFlowEnabledInboxes: 'inboxes/dialogFlowEnabledInboxes',
      allAgents: 'agents/getAgents', // proyecto@commands_agents
      currentUser: 'getCurrentUser',
    }),
    inboxes() {
      return this.dialogFlowEnabledInboxes
        .filter(inbox => {
          if (!this.isIntegrationDialogflow) {
            return true;
          }
          return !this.connectedDialogflowInboxIds.includes(inbox.id);
        })
        .map(inbox => ({ label: inbox.name, value: inbox.id }));
    },

    connectedDialogflowInboxIds() {
      if (!this.isIntegrationDialogflow) {
        return [];
      }
      return this.integration.hooks.map(hook => hook.inbox?.id);
    },
    formItems() {
      // proyecto@commands_agents: INI
      if (this.isCommandBot) {
        return this.integration.settings_form_schema.filter(
          item => item.name !== 'agent_id'
        );
      }
      // proyecto@commands_agents: FIN
      return this.integration.settings_form_schema;
    },
    isIntegrationDialogflow() {
      return this.integration.id === 'dialogflow';
    },
    // proyecto@commands_agents: INI
    isCommandBot() {
      return this.integration.id === 'command_bot';
    },
    // proyecto@commands_agents: Opciones de agentes confirmados para el selector
    agentOptions() {
      return this.allAgents
        .filter(agent => agent.confirmed)
        .map(agent => ({
          label: `${agent.name} (${agent.email})`,
          value: String(agent.id),
        }));
    },
    // proyecto@commands_agents: FIN
    isIntegrationCRMZeus() {
      return this.integration.id === 'crmzeus';
    },
  },
  mounted() {
     // proyecto@commands_agents: INI
    if (this.isCommandBot) {
      this.$store.dispatch('agents/get');
    }
     // proyecto@commands_agents: FIN
    console.log("🔍 Componente montado");
    console.log("👤 Current user:", this.currentUser);
    console.log("🔧 Integration:", this.integration);
    
    this.initializeIntegration();
  },
  methods: {
    onClose() {
      this.$emit('close');
    },

    initializeIntegration() {
      console.log("🚀 Inicializando integración:", this.integration.id);
      
      if (this.isIntegrationCRMZeus) {
        console.log("⚙️ Configurando CRM Zeus...");
        this.initializeCrmzeusDefaults();
      }
    },

    initializeCrmzeusDefaults() {
      const { access_token } = this.currentUser;
      
      if (!access_token) {
        console.warn("⚠️ No se encontró access_token en currentUser");
        console.log("📊 currentUser completo:", this.currentUser);
        return;
      }
      
      console.log("🔑 Access token encontrado:", access_token);
      console.log("📋 Form items:", this.formItems);
      
      // Procesar campos del formulario que contengan tokens
      const processedValues = {};
      
      this.formItems.forEach(item => {
        console.log(`🔍 Procesando campo: ${item.name}, valor: ${item.value}`);
        
        if (item.value && typeof item.value === 'string') {
          // Reemplazar tokens en los valores por defecto
          const originalValue = item.value;
          const processedValue = this.interpolateTokens(originalValue, access_token);
          processedValues[item.name] = processedValue;
          
          console.log(`🔄 Campo ${item.name}:`);
          console.log(`   Original: ${originalValue}`);
          console.log(`   Procesado: ${processedValue}`);
        } else if (item.value !== undefined) {
          processedValues[item.name] = item.value;
          console.log(`✅ Campo ${item.name}: ${item.value} (sin cambios)`);
        }
      });
      
      // Asignar valores procesados al formulario
      this.values = {
        ...this.values,
        ...processedValues,
      };
      
      console.log("✅ Valores finales asignados al formulario:", this.values);
    },

    interpolateTokens(value, accessToken) {
      console.log("🔄 Interpolando tokens en:", value);
      console.log("🔑 Access token:", accessToken);
      
      // Reemplazar diferentes formatos de tokens
      const result = value
        .replace(/\$token\$/g, accessToken)           // $token$
        .replace(/\{\{token\}\}/g, accessToken)       // {{token}}
        .replace(/\{\{access_token\}\}/g, accessToken) // {{access_token}}
        .replace(/\$\{access_token\}/g, accessToken)  // ${access_token}
        .replace(/\$\{token\}/g, accessToken);        // ${token}
      
      console.log("✅ Resultado interpolado:", result);
      return result;
    },

    async createWebhookForCrmzeus() {
      try {
        console.log("🔗 Creando webhook para CRM Zeus...");
        
        const { access_token } = this.currentUser;
        
        if (!access_token) {
          throw new Error('No se pudo obtener el access_token del usuario');
        }
        
        // Obtener la URL del webhook desde los valores del formulario o configuración
        let webhookUrl = '';
        
        if (this.values.webhook) {
          // Si ya hay un valor en el formulario, usarlo
          webhookUrl = this.values.webhook;
        } else {
          // Buscar en la configuración del formulario
          const webhookField = this.formItems.find(item => item.name === 'webhook');
          if (webhookField && webhookField.value) {
            webhookUrl = this.interpolateTokens(webhookField.value, access_token);
          } else {
            // Fallback
            webhookUrl = `http://localhost:3000/webhooks/${access_token}/crmzeus`;
          }
        }
        
        console.log("🌐 URL del webhook:", webhookUrl);
        
        const dataWebhook = {
          url: webhookUrl,
          subscriptions: [
            'conversation_created',
            'message_created'
          ],
        };
        
        console.log("📤 Datos del webhook a crear:", dataWebhook);
        
        const webhook = await this.$store.dispatch('webhooks/create', dataWebhook);
        
        if (!webhook) {
          throw new Error('No se recibió respuesta válida al crear webhook');
        }
        
        console.log("✅ Webhook creado exitosamente:", webhook);
        return webhook;
        
      } catch (error) {
        console.error("❌ Error creando webhook:", error);
        throw error;
      }
    },

    buildHookPayload(webhookId = null) {
      const hookPayload = {
        app_id: this.integration.id,
        settings: {},
      };

      hookPayload.settings = Object.keys(this.values).reduce((acc, key) => {
        if (key !== 'inbox') {
          acc[key] = this.values[key];
        }
        return acc;
      }, {});

      this.formItems.forEach(item => {
        if (item.validation && item.validation.includes('JSON')) {
          hookPayload.settings[item.name] = JSON.parse(
            hookPayload.settings[item.name]
          );
        }
      });

      // Si es CRM Zeus, realizar configuraciones específicas
      if (this.integration.id === 'crmzeus') {
        const { access_token } = this.currentUser;
        
        // Reemplazar tokens en la URL del webhook si es necesario
        if (hookPayload.settings.webhook && access_token) {
          hookPayload.settings.webhook = this.interpolateTokens(
            hookPayload.settings.webhook, 
            access_token
          );
        }
        
        // Asignar webhook_id si se proporciona
        if (webhookId) {
          hookPayload.settings.webhook_id = webhookId;
        }
      }

      if (this.isHookTypeInbox && this.values.inbox) {
        hookPayload.inbox_id = this.values.inbox;
      }

      return hookPayload;
    },

    async validateCrmzeusConnection(payload) {
      try {
        const { api_url_base, api_access_token } = payload.settings;
        
        if (!api_url_base || !api_access_token) {
          return {
            success: false,
            message: 'URL base y token de acceso son requeridos para CRM Zeus'
          };
        }

        const config = {
          method: 'post',
          maxBodyLength: Infinity,
          url: `${api_url_base}/apiCrm/externalAccess/accessToken/api/v1/test`,
          headers: { 
            'api_access_token': api_access_token, 
          }
        };

        const response = await axios.request(config);
        
        if (response.data && response.data.ERROR === "0") {
          return {
            success: true,
            message: response.data.TITULO || "Conexión establecida correctamente"
          };
        } else {
          return {
            success: false,
            message: "Conexión NO establecida: Verificar credenciales"
          };
        }
      } catch (error) {
        console.error('Error validating CRM Zeus connection:', error);
        return {
          success: false,
          message: "Error al conectar con CRM Zeus: " + (error.response?.data?.message || error.message)
        };
      }
    },

    async validateConfiguration(payload) {
      // Validación específica por tipo de integración
      switch (payload.app_id) {
        case 'crmzeus':
          return await this.validateCrmzeusConnection(payload);
        
        case 'discourse':
          // Aquí puedes agregar validación para Discourse si es necesaria
          return { success: true, message: 'Configuración válida' };
        
        default:
          // Para otras integraciones, no hay validación específica
          return { success: true, message: 'Configuración válida' };
      }
    },

    async submitForm() {
      this.isValidating = true;
      
      try {
        let webhookId = null;
        
        console.log("🚀 Iniciando envío del formulario...");
        
        // Si es CRM Zeus, crear primero el webhook
        if (this.integration.id === 'crmzeus') {
          console.log("⚙️ Procesando CRM Zeus...");
          
          try {
            const webhook = await this.createWebhookForCrmzeus();
            webhookId = webhook.id;
            console.log("🆔 ID del webhook para CRM Zeus:", webhookId);
          } catch (webhookError) {
            console.error("❌ Error creando webhook:", webhookError);
            this.alertMessage = `Error creando webhook: ${webhookError.message}`;
            useAlert(this.alertMessage);
            return;
          }
          
          // Verificar que el access_token esté disponible
          const { access_token } = this.currentUser;
          if (!access_token) {
            this.alertMessage = 'No se pudo obtener el token de acceso del usuario';
            useAlert(this.alertMessage);
            return;
          }
          console.log("🔑 Access token verificado");
        }
        
        const hookPayload = this.buildHookPayload(webhookId);
        console.log("📦 Payload final:", hookPayload);
        
        // Validación previa antes de guardar
        console.log("🔍 Validando configuración...");
        const validationResult = await this.validateConfiguration(hookPayload);
        
        if (!validationResult.success) {
          this.alertMessage = validationResult.message;
          useAlert(this.alertMessage);
          return;
        }
        
        console.log("✅ Validación exitosa");

        // Si la validación es exitosa, proceder a crear el hook
        console.log("💾 Creando hook de integración...");
        const result = await this.$store.dispatch(
          'integrations/createHook',
          hookPayload
        );
        
        console.log("✅ Hook creado exitosamente:", result);
        
        this.alertMessage = this.$t('INTEGRATION_APPS.ADD.API.SUCCESS_MESSAGE');
        useAlert(this.alertMessage);
        this.onClose();
        
      } catch (error) {
        console.error("❌ Error en submitForm:", error);
        const errorMessage = error?.response?.data?.message || error.message;
        this.alertMessage =
          errorMessage || this.$t('INTEGRATION_APPS.ADD.API.ERROR_MESSAGE');
        useAlert(this.alertMessage);
      } finally {
        this.isValidating = false;
      }
    },
  },
};
</script>

<template>
  <div class="flex flex-col h-auto overflow-auto integration-hooks">
    <woot-modal-header
      :header-title="integration.name"
      :header-content="integration.description"
    />
    <formulate-form
      v-slot="{ hasErrors }"
      v-model="values"
      class="w-full"
      @submit="submitForm"
    >
      <formulate-input
        v-for="item in formItems"
        :key="item.name"
        v-bind="item"
      />
      <!-- proyecto@commands_agents: Selector dinámico de agente autorizado -->
      <formulate-input
        v-if="isCommandBot"
        :options="agentOptions"
        type="select"
        name="agent_id"
        label="Agente Autorizado"
        placeholder="Seleccionar agente"
        validation="required"
        validation-name="Agente"
        help="Agente autorizado para enviar comandos en este inbox"
      />
      <formulate-input
        v-if="isHookTypeInbox"
        :options="inboxes"
        type="select"
        name="inbox"
        :placeholder="$t('INTEGRATION_APPS.ADD.FORM.INBOX.LABEL')"
        :label="$t('INTEGRATION_APPS.ADD.FORM.INBOX.PLACEHOLDER')"
        validation="required"
        validation-name="Inbox"
      />
      <div class="flex flex-row justify-end w-full gap-2 px-0 py-2">
        <woot-button 
          :disabled="hasErrors || isValidating" 
          :loading="uiFlags.isCreatingHook || isValidating"
        >
          {{ isValidating ? 'Validando...' : $t('INTEGRATION_APPS.ADD.FORM.SUBMIT') }}
        </woot-button>
        <woot-button class="button clear" @click.prevent="onClose">
          {{ $t('INTEGRATION_APPS.ADD.FORM.CANCEL') }}
        </woot-button>
      </div>
    </formulate-form>
  </div>
</template>