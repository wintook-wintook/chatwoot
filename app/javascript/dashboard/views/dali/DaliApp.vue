<!--
  Portal de Dali — Dali a pantalla completa, pensado para el teléfono y para
  instalarse como app («Agregar a pantalla de inicio»; manifiesto /dali-manifest.json).
    /dali  y  /app/dali          → el de la empresa activa
    /app/accounts/:id/dali       → el de esa empresa
  Misma sesión, permisos y plática que el panel de la plataforma (AssistantChat), más:
  dictado, botones rápidos (Assistant::Capabilities.shortcuts) y cambio de empresa.
  Lo que Dali abre (una cotización, un caso) se abre en la plataforma; de ahí
  «Volver a Dali» (Dashboard.vue) regresa al portal.
-->
<script>
import { mapGetters } from 'vuex';
import {
  assistantState,
  DEFAULT_ASSISTANT_NAME,
} from 'dashboard/helper/assistantState';
import AssistantChat from 'dashboard/components/assistant/AssistantChat.vue';
import { markDaliReturn } from 'dashboard/helper/daliPortal';
import { frontendURL } from 'dashboard/helper/URLHelper';

const T = 'ASSISTANT.PORTAL';

export default {
  name: 'DaliApp',
  components: { AssistantChat },
  data() {
    return {
      state: assistantState,
      shortcuts: [],
      menuOpen: false,
      installPrompt: null,
    };
  },
  computed: {
    ...mapGetters({ currentUser: 'getCurrentUser' }),
    name() {
      return this.state.name || DEFAULT_ASSISTANT_NAME;
    },
    accountId() {
      return Number(this.$route.params.accountId);
    },
    accounts() {
      return (this.currentUser && this.currentUser.accounts) || [];
    },
    accountName() {
      const account = this.accounts.find(a => a.id === this.accountId);
      return account ? account.name : '';
    },
  },
  mounted() {
    document.title = this.name;
    window.addEventListener('beforeinstallprompt', this.onInstallPrompt);
  },
  beforeDestroy() {
    window.removeEventListener('beforeinstallprompt', this.onInstallPrompt);
  },
  methods: {
    t(key, params) {
      return this.$t(`${T}.${key}`, { name: this.name, ...params });
    },
    onLoaded(data) {
      this.shortcuts = data.shortcuts || [];
      document.title = data.name || this.name;
    },
    // Chrome/Android ofrece instalar; en iPhone es «Compartir › Agregar a inicio».
    onInstallPrompt(event) {
      event.preventDefault();
      this.installPrompt = event;
    },
    async install() {
      this.menuOpen = false;
      if (!this.installPrompt) return;
      this.installPrompt.prompt();
      await this.installPrompt.userChoice;
      this.installPrompt = null;
    },
    reset() {
      this.menuOpen = false;
      this.$refs.chat.reset();
    },
    switchAccount(id) {
      this.menuOpen = false;
      if (id === this.accountId) return;
      // Recarga completa: la plataforma activa la empresa al abrirla (App.vue).
      window.location.assign(frontendURL(`accounts/${id}/dali`));
    },
    openPlatform(path) {
      this.menuOpen = false;
      markDaliReturn(this.$route.fullPath);
      this.$router.push(
        path || frontendURL(`accounts/${this.accountId}/start`)
      );
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col w-full bg-white h-[100dvh] dark:bg-slate-900 text-slate-800 dark:text-slate-100"
  >
    <header
      class="relative flex items-center gap-3 px-4 py-3 border-b border-slate-100 dark:border-slate-800"
    >
      <span
        class="flex items-center justify-center rounded-full w-9 h-9 shrink-0 bg-woot-50 text-woot-600 dark:bg-woot-900/40"
      >
        <fluent-icon icon="wand" size="18" />
      </span>
      <div class="flex flex-col flex-1 min-w-0">
        <span class="text-base font-semibold truncate">{{ name }}</span>
        <span class="text-xs truncate text-slate-500">{{ accountName }}</span>
      </div>
      <woot-button
        :aria-label="t('NEW')"
        size="small"
        variant="clear"
        color-scheme="secondary"
        icon="add"
        @click="reset"
      />
      <woot-button
        :aria-label="t('MENU')"
        size="small"
        variant="clear"
        color-scheme="secondary"
        icon="more-vertical"
        @click="menuOpen = !menuOpen"
      />
      <div
        v-if="menuOpen"
        class="absolute z-10 w-64 py-1 bg-white border rounded-lg shadow-lg right-3 top-14 border-slate-100 dark:bg-slate-800 dark:border-slate-700"
      >
        <button type="button" class="dali-menu-item" @click="openPlatform()">
          {{ t('OPEN_PLATFORM') }}
        </button>
        <button
          v-if="installPrompt"
          type="button"
          class="dali-menu-item"
          @click="install"
        >
          {{ t('INSTALL') }}
        </button>
        <template v-if="accounts.length > 1">
          <p class="px-4 pt-2 pb-1 m-0 text-xs text-slate-500">
            {{ t('ACCOUNTS') }}
          </p>
          <button
            v-for="account in accounts"
            :key="account.id"
            type="button"
            class="dali-menu-item"
            :class="{ 'font-semibold': account.id === accountId }"
            @click="switchAccount(account.id)"
          >
            {{ account.name }}
          </button>
        </template>
      </div>
    </header>

    <AssistantChat
      ref="chat"
      class="dali-chat"
      :context="{ page: 'dali_app' }"
      :auto-navigate="false"
      voice
      @loaded="onLoaded"
      @navigate="openPlatform"
    >
      <template #above-input="{ ask, busy }">
        <div
          v-if="shortcuts.length"
          class="flex gap-1.5 pb-2 -mx-1 px-1 overflow-x-auto"
        >
          <button
            v-for="shortcut in shortcuts"
            :key="shortcut.key"
            type="button"
            class="px-3 py-1.5 text-sm border rounded-full whitespace-nowrap border-slate-200 text-slate-700 hover:bg-slate-50 disabled:opacity-50 dark:border-slate-700 dark:text-slate-200 dark:hover:bg-slate-800"
            :disabled="busy"
            @click="ask(shortcut.prompt)"
          >
            {{ shortcut.label }}
          </button>
        </div>
      </template>
    </AssistantChat>
  </div>
</template>

<style scoped>
.dali-menu-item {
  @apply block w-full px-4 py-2 text-sm text-left text-slate-700 hover:bg-slate-50 dark:text-slate-200 dark:hover:bg-slate-700;
}
/* En el teléfono, el cuadro de texto a 16px para que iOS no haga zoom. */
.dali-chat ::v-deep textarea {
  font-size: 16px;
}
.dali-chat ::v-deep footer {
  padding-bottom: calc(0.75rem + env(safe-area-inset-bottom));
}
</style>
