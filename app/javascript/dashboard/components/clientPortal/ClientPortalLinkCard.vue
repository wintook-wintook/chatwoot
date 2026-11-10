<!--
  Portal del cliente — el enlace de una organización (o de un contacto sin organización):
  crearlo, copiarlo, abrirlo, renovarlo (el anterior deja de servir) o desactivarlo.
  `owner`: { organization_id } o { contact_id }. Va en el caso, la organización y el contacto.
-->
<script>
import { useAlert } from 'dashboard/composables';
import ClientPortalLinksAPI from 'dashboard/api/clientPortalLinks';
import { copyTextToClipboard } from 'shared/helpers/clipboard';

const T = 'CLIENT_PORTAL_LINK';

export default {
  name: 'ClientPortalLinkCard',
  props: {
    owner: { type: Object, default: null },
    canEdit: { type: Boolean, default: true },
    compact: { type: Boolean, default: false },
  },
  data() {
    return { link: null, loaded: false, busy: false };
  },
  computed: {
    help() {
      return this.owner?.organization_id
        ? this.t('HELP_ORG')
        : this.t('HELP_CONTACT');
    },
    lastUsed() {
      if (!this.link) return '';
      if (!this.link.last_used_at) return this.t('NEVER_USED');
      return this.t('LAST_USED', {
        date: new Date(this.link.last_used_at).toLocaleDateString(),
      });
    },
  },
  watch: {
    owner: { immediate: true, handler: 'load' },
  },
  methods: {
    t(key, params) {
      return this.$t(`${T}.${key}`, params);
    },
    async load() {
      this.loaded = false;
      this.link = null;
      if (!this.owner) return;
      try {
        const { data } = await ClientPortalLinksAPI.show(this.owner);
        this.link = data.link;
      } finally {
        this.loaded = true;
      }
    },
    async run(action, confirmKey) {
      // eslint-disable-next-line no-alert
      if (confirmKey && !window.confirm(this.t(confirmKey))) return;
      this.busy = true;
      try {
        const { data } = await ClientPortalLinksAPI[action](this.owner);
        this.link = data.link;
      } finally {
        this.busy = false;
      }
    },
    async copy() {
      await copyTextToClipboard(this.link.url);
      useAlert(this.t('COPIED'));
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col gap-2"
    :class="
      compact
        ? ''
        : 'p-4 border rounded-lg border-slate-100 dark:border-slate-700'
    "
  >
    <div v-if="!compact">
      <h3 class="m-0 text-sm font-semibold text-slate-800 dark:text-slate-100">
        {{ t('TITLE') }}
      </h3>
      <p class="m-0 mt-1 text-xs text-slate-500">{{ help }}</p>
    </div>
    <p v-if="!owner" class="m-0 text-xs text-slate-500">
      {{ t('NO_OWNER') }}
    </p>
    <template v-else-if="loaded">
      <div v-if="link" class="flex flex-wrap items-center gap-2">
        <woot-button size="small" icon="copy" @click="copy">
          {{ t('COPY') }}
        </woot-button>
        <a
          :href="link.url"
          target="_blank"
          rel="noopener noreferrer"
          class="text-xs text-woot-600 hover:underline"
        >
          {{ t('OPEN') }}
        </a>
        <span class="text-xs text-slate-500">{{ lastUsed }}</span>
        <template v-if="canEdit">
          <woot-button
            size="small"
            variant="clear"
            color-scheme="secondary"
            :is-loading="busy"
            @click="run('renew', 'RENEW_CONFIRM')"
          >
            {{ t('RENEW') }}
          </woot-button>
          <woot-button
            size="small"
            variant="clear"
            color-scheme="alert"
            :is-disabled="busy"
            @click="run('disable', 'DISABLE_CONFIRM')"
          >
            {{ t('DISABLE') }}
          </woot-button>
        </template>
      </div>
      <div v-else class="flex flex-wrap items-center gap-2">
        <span class="text-xs text-slate-500">{{ t('NONE') }}</span>
        <woot-button
          v-if="canEdit"
          size="small"
          variant="smooth"
          icon="link"
          :is-loading="busy"
          @click="run('create')"
        >
          {{ t('CREATE') }}
        </woot-button>
      </div>
    </template>
  </div>
</template>
