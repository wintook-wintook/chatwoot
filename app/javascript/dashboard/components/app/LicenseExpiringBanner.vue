<script>
// feat/licencias (F5) — AVISO DE LICENCIA POR VENCER
// ============================================================================
// Arriba del dashboard, para los administradores de la cuenta, cuando a su licencia le quedan
// 10 días o menos y no tiene otro periodo en cola (en ese caso no se le va a cortar). Se puede
// cerrar; vuelve al día siguiente (se recuerda por día en este navegador).
// Mismos datos que Configuración › Licencia (license en accounts/show).
// Plan: docs/licencias_plan_v1.md §5 (F5)
// ============================================================================
import { mapGetters } from 'vuex';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { useAccount } from 'dashboard/composables/useAccount';
import Banner from 'dashboard/components/ui/Banner.vue';

const SOON_DAYS = 10;
const STORAGE_KEY = 'license_banner_dismissed';

const today = () => new Date().toISOString().slice(0, 10);

export default {
  components: { Banner },
  setup() {
    const { isAdmin } = useAdmin();
    const { accountId } = useAccount();
    return { isAdmin, accountId };
  },
  data() {
    return { dismissedOn: null };
  },
  computed: {
    ...mapGetters({ getAccount: 'accounts/getAccount' }),
    license() {
      const account = this.getAccount(this.accountId);
      return (account && account.license) || null;
    },
    daysLeft() {
      const current = this.license && this.license.current;
      return current && current.days_left !== null ? current.days_left : null;
    },
    shouldShowBanner() {
      if (!this.isAdmin || !this.license || this.license.next) return false;
      if (this.daysLeft === null || this.daysLeft > SOON_DAYS) return false;
      return this.dismissedOn !== `${this.accountId}:${today()}`;
    },
    bannerMessage() {
      return this.$t('LICENSES.BANNER.MESSAGE', {
        count: Math.max(this.daysLeft, 0),
      });
    },
  },
  mounted() {
    try {
      this.dismissedOn = window.localStorage.getItem(STORAGE_KEY);
    } catch (error) {
      this.dismissedOn = null;
    }
  },
  methods: {
    openLicense() {
      this.$router.push({
        name: 'account_license_index',
        params: { accountId: this.accountId },
      });
    },
    dismiss() {
      this.dismissedOn = `${this.accountId}:${today()}`;
      try {
        window.localStorage.setItem(STORAGE_KEY, this.dismissedOn);
      } catch (error) {
        // Sin almacenamiento el aviso solo se cierra hasta recargar.
      }
    },
  },
};
</script>

<template>
  <Banner
    v-if="shouldShowBanner"
    color-scheme="warning"
    :banner-message="bannerMessage"
    :action-button-label="$t('LICENSES.BANNER.ACTION')"
    has-action-button
    has-close-button
    @click="openLicense"
    @close="dismiss"
  />
</template>
