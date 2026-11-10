<!--
  Portal de Dali — lo nuevo para el usuario:
    · campanita con lo no leído (conversaciones asignadas y mensajes nuevos) y su lista;
    · franja en tiempo real «Mario te escribió…» al llegar un aviso (ActionCable);
    · globito con el número en el ícono instalado;
    · ofrecer «Activar avisos en este teléfono» (push, también con la app cerrada).
  Tocar un aviso le pide a Dali que lea esa conversación (evento `ask`).
  Métodos para el padre (ref): enablePush, openConversation(displayId).
-->
<script>
import { mapGetters } from 'vuex';
import types from 'dashboard/store/mutation-types';
import {
  daliPushState,
  enableDaliPush,
  offerDismissed,
  dismissOffer,
  setAppBadge,
} from 'dashboard/helper/daliPush';

const T = 'ASSISTANT.PORTAL.NOTICES';
const BANNER_MS = 9000;
const LIST_LIMIT = 8;

const senderOf = n =>
  n?.primary_actor?.meta?.sender?.name || n?.secondary_actor?.name || '';

export default {
  name: 'DaliNotifications',
  emits: ['ask'],
  data() {
    return {
      open: false,
      banner: null,
      pushState: daliPushState(),
      showOffer: false,
      enabling: false,
      pushError: '',
    };
  },
  computed: {
    ...mapGetters({
      meta: 'notifications/getMeta',
      all: 'notifications/getNotifications',
    }),
    unread() {
      return (this.meta && this.meta.unreadCount) || 0;
    },
    // Solo lo de conversaciones (asignadas, mensajes nuevos, menciones).
    items() {
      return this.all
        .filter(n => !n.read_at && n.primary_actor_type === 'Conversation')
        .slice(0, LIST_LIMIT);
    },
  },
  watch: {
    unread: {
      immediate: true,
      handler(count) {
        setAppBadge(count);
      },
    },
  },
  mounted() {
    this.$store.dispatch('notifications/unReadCount');
    this.unsubscribe = this.$store.subscribe(mutation => {
      // El módulo es namespaced: «notifications/ADD_NOTIFICATION».
      if (mutation.type.endsWith(types.ADD_NOTIFICATION)) {
        this.onNew(mutation.payload?.notification);
      }
    });
    this.showOffer = this.pushState === 'off' && !offerDismissed();
  },
  beforeDestroy() {
    if (this.unsubscribe) this.unsubscribe();
    clearTimeout(this.bannerTimer);
  },
  methods: {
    t(key, params) {
      return this.$t(`${T}.${key}`, params);
    },
    sender: senderOf,
    text(n) {
      return n.push_message_title || '';
    },
    onNew(notification) {
      if (!notification || notification.primary_actor_type !== 'Conversation')
        return;
      this.banner = notification;
      clearTimeout(this.bannerTimer);
      this.bannerTimer = setTimeout(() => {
        this.banner = null;
      }, BANNER_MS);
    },
    async toggle() {
      this.open = !this.open;
      if (this.open) await this.$store.dispatch('notifications/get', {});
    },
    // Dali lee la conversación; el aviso queda leído.
    pick(notification) {
      this.open = false;
      this.banner = null;
      const displayId = notification.primary_actor?.id;
      this.markRead(notification);
      this.$emit('ask', this.t('ASK_CONVERSATION', { id: displayId }));
    },
    markRead(notification) {
      this.$store.dispatch('notifications/read', {
        id: notification.id,
        primaryActorType: notification.primary_actor_type,
        primaryActorId: notification.primary_actor_id,
        unreadCount: this.unread,
      });
    },
    // Desde un aviso push (dali?conversation=N): marca leídos los de esa conversación.
    async openConversation(displayId) {
      await this.$store.dispatch('notifications/get', {});
      this.all
        .filter(n => !n.read_at && n.primary_actor?.id === Number(displayId))
        .forEach(n => this.markRead(n));
    },
    pending() {
      this.open = false;
      this.$emit('ask', this.t('ASK_PENDING'));
    },
    readAll() {
      this.open = false;
      this.$store.dispatch('notifications/readAll');
    },
    async enablePush() {
      this.enabling = true;
      this.pushError = '';
      try {
        this.pushState = await enableDaliPush();
        if (this.pushState === 'denied') this.pushError = this.t('DENIED');
        if (this.pushState === 'unsupported') {
          this.pushError = this.t('UNSUPPORTED');
        }
        if (this.pushState === 'on') this.showOffer = false;
      } catch (_e) {
        this.pushError = this.t('ERROR');
      } finally {
        this.enabling = false;
      }
    },
    notNow() {
      dismissOffer();
      this.showOffer = false;
    },
  },
};
</script>

<template>
  <div class="contents">
    <!-- Campanita -->
    <div class="relative">
      <woot-button
        :aria-label="t('BELL', { count: unread })"
        size="small"
        variant="clear"
        color-scheme="secondary"
        icon="alert"
        @click="toggle"
      />
      <span
        v-if="unread"
        class="absolute top-0 right-0 min-w-[1rem] h-4 px-1 text-[10px] font-semibold leading-4 text-center text-white rounded-full bg-red-500 pointer-events-none"
      >
        {{ unread > 99 ? '99+' : unread }}
      </span>
      <div
        v-if="open"
        class="absolute right-0 z-20 py-1 bg-white border rounded-lg shadow-lg w-72 top-10 border-slate-100 dark:bg-slate-800 dark:border-slate-700"
      >
        <p v-if="!items.length" class="px-4 py-3 m-0 text-sm text-slate-500">
          {{ t('EMPTY') }}
        </p>
        <button
          v-for="n in items"
          :key="n.id"
          type="button"
          class="block w-full px-4 py-2 text-left hover:bg-slate-50 dark:hover:bg-slate-700"
          @click="pick(n)"
        >
          <span
            class="block text-sm font-medium truncate text-slate-800 dark:text-slate-100"
          >
            {{ sender(n) || t('CONVERSATION', { id: n.primary_actor.id }) }}
          </span>
          <span class="block text-xs truncate text-slate-500">
            {{ text(n) }}
          </span>
        </button>
        <div
          class="flex justify-between gap-2 px-4 pt-2 mt-1 border-t border-slate-100 dark:border-slate-700"
        >
          <button
            type="button"
            class="py-1 text-xs text-woot-600 dark:text-woot-300"
            @click="pending"
          >
            {{ t('SEE_PENDING') }}
          </button>
          <button
            v-if="items.length"
            type="button"
            class="py-1 text-xs text-slate-500"
            @click="readAll"
          >
            {{ t('READ_ALL') }}
          </button>
        </div>
      </div>
    </div>

    <!-- Franja en tiempo real y ofrecimiento de avisos: justo debajo de la cabecera
         (la cabecera de DaliApp es `relative`; este bloque no tiene caja propia). -->
    <div class="absolute left-0 right-0 z-10 shadow-sm top-full">
      <button
        v-if="banner"
        type="button"
        class="flex items-start w-full gap-2 px-4 py-2 text-left border-b bg-violet-50 border-violet-100 dark:bg-violet-900/30 dark:border-violet-800"
        @click="pick(banner)"
      >
        <fluent-icon
          icon="chat"
          size="16"
          class="mt-0.5 text-violet-600 dark:text-violet-300 shrink-0"
        />
        <span class="flex-1 min-w-0">
          <span
            class="block text-sm font-medium truncate text-slate-800 dark:text-slate-100"
          >
            {{ t('NEW_FROM', { name: sender(banner) || '' }) }}
          </span>
          <span
            class="block text-xs truncate text-slate-600 dark:text-slate-300"
          >
            {{ text(banner) }}
          </span>
        </span>
      </button>
      <div
        v-if="showOffer"
        class="flex flex-wrap items-center gap-2 px-4 py-2 text-sm border-b bg-slate-50 border-slate-100 dark:bg-slate-800 dark:border-slate-700"
      >
        <span class="flex-1 min-w-[12rem] text-slate-700 dark:text-slate-200">
          {{ t('OFFER') }}
        </span>
        <woot-button size="small" :is-loading="enabling" @click="enablePush">
          {{ t('ENABLE') }}
        </woot-button>
        <woot-button
          size="small"
          variant="clear"
          color-scheme="secondary"
          @click="notNow"
        >
          {{ t('NOT_NOW') }}
        </woot-button>
        <p v-if="pushError" class="w-full m-0 text-xs text-red-600">
          {{ pushError }}
        </p>
      </div>
    </div>
  </div>
</template>
