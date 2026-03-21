<script>
import { mapGetters } from 'vuex';
import { useIntegrationHook } from 'dashboard/composables/useIntegrationHook';
export default {
  props: {
    integrationId: {
      type: String,
      required: true,
    },
  },
  setup(props) {
    const { integration, isHookTypeInbox, hasConnectedHooks } =
      useIntegrationHook(props.integrationId);
    return { integration, isHookTypeInbox, hasConnectedHooks };
  },
  computed: {
    ...mapGetters({
      globalConfig: 'globalConfig/get',
      agents: 'agents/getAgents', // proyecto@commands_agents
    }),
    hookHeaders() {
      return this.integration.visible_properties;
    },
    hooks() {
      if (!this.hasConnectedHooks) {
        return [];
      }
      const { hooks } = this.integration;
      return hooks.map(hook => ({
        ...hook,
        id: hook.id,
        // proyecto@commands_agents: INI
        properties: this.hookHeaders.map(property => {
          const value = hook.settings[property];
          if (!value) return '--';
          // proyecto@commands_agents: mostrar nombre del agente en lugar del ID
          if (property === 'agent_id') {
            const agent = this.agents.find(a => a.id === Number(value));
            return agent ? agent.name : `Agente #${value}`;
          }
          return value;
        }),
        //properties: this.hookHeaders.map(property =>
        //  hook.settings[property] ? hook.settings[property] : '--'
        //),
        // proyecto@commands_agents: FIN
      }));
    },
  },
  mounted() {
    // proyecto@commands_agents: INI
    this.$store.dispatch('agents/get');
  },
    // proyecto@commands_agents: FIN
  methods: {
    inboxName(hook) {
      return hook.inbox ? hook.inbox.name : '';
    },
  },
};
</script>

<template>
  <!-- proyecto@commands_agents: INI -->
  <!-- <div class="flex flex-row gap-4"> -->
  <div class="flex flex-col gap-4 w-full">
    <div>
      <p class="font-semibold text-sm mb-1">{{ integration.name }}</p>
      <p
        class="text-sm text-slate-500"
        v-dompurify-html="
          $t(
            `INTEGRATION_APPS.SIDEBAR_DESCRIPTION.${integration.id.toUpperCase()}`,
            { installationName: globalConfig.installationName }
          )
        "
      />
    </div>
    <!--<div class="w-full lg:w-3/5"> -->
    <div class="w-full">
    <!-- proyecto@commands_agents: FIN -->
      <table v-if="hasConnectedHooks" class="woot-table">
        <thead>
          <th v-for="hookHeader in hookHeaders" :key="hookHeader">
            <!-- proyecto@commands_agents: INI -->
            <!--{{ hookHeader }}-->
            {{ hookHeader === 'agent_id' ? 'Agente' : hookHeader }}
            <!-- proyecto@commands_agents: FIN -->
          </th>
          <th v-if="isHookTypeInbox">
            {{ $t('INTEGRATION_APPS.LIST.INBOX') }}
          </th>
        </thead>
        <tbody>
          <tr v-for="hook in hooks" :key="hook.id">
            <td
              v-for="property in hook.properties"
              :key="property"
              class="break-words"
            >
              {{ property }}
            </td>
            <td v-if="isHookTypeInbox" class="break-words">
              {{ inboxName(hook) }}
            </td>
            <td class="flex justify-end gap-1">
              <woot-button
                v-tooltip.top="$t('INTEGRATION_APPS.LIST.DELETE.BUTTON_TEXT')"
                variant="smooth"
                color-scheme="alert"
                size="tiny"
                icon="dismiss-circle"
                class-names="grey-btn"
                @click="$emit('delete', hook)"
              />
            </td>
          </tr>
        </tbody>
      </table>
      <p v-else class="flex flex-col items-center justify-center h-full">
        {{
          $t('INTEGRATION_APPS.NO_HOOK_CONFIGURED', {
            integrationId: integration.id,
          })
        }}
      </p>
    </div>
  </div>
</template>
