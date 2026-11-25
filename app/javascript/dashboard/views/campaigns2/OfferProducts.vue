<!--
  Campaña con IA · Ofrecer — paso «La oferta»: los productos del Catálogo que se ofrecen (llegan con su nombre, precio,
  descripción y foto; la foto se pega sola como imagen de la campaña: evento photo), el precio de promoción de cada
  uno (precio o % de descuento, con el normal a la vista), la vigencia (la campaña termina sola ese día) y lo demás que
  sabe la IA (CampaignKnowledge sin qué es/precio/vigencia si hay productos). Lo que no está en el Catálogo se escribe
  a mano como antes. Backend: TrackingCampaigns::OfferProducts.
  .sync: brief (products [{ catalog_item_id, promo_price }], valid_until, facts…)
-->
<script>
import CatalogItemsAPI from 'dashboard/api/catalogItems';
import CatalogPicker from 'dashboard/views/gestorTickets/catalog/CatalogPicker.vue';
import { formatMoney } from 'dashboard/helper/caseCommercial';
import CampaignKnowledge from './CampaignKnowledge.vue';

const round2 = n => Math.round(Number(n) * 100) / 100;

export default {
  name: 'OfferProducts',
  components: { CatalogPicker, CampaignKnowledge },
  props: {
    brief: { type: Object, required: true },
    // offer | reactivate (en Reactivar, lo del Catálogo es el incentivo para que vuelva)
    kind: { type: String, default: 'offer' },
    kit: { type: Object, default: null },
    campaignId: { type: Number, default: null },
    save: { type: Function, required: true },
    attempts: { type: Number, default: 1 },
    filesVersion: { type: Number, default: 0 },
  },
  emits: ['update:brief', 'photo', 'catalog'],
  data() {
    return { items: {} };
  },
  computed: {
    products() {
      return this.brief.products || [];
    },
    hiddenFacts() {
      if (this.kind === 'reactivate')
        return this.products.length
          ? ['incentive', 'valid_until']
          : ['valid_until'];
      return this.products.length
        ? ['what_is', 'price', 'valid_until']
        : ['valid_until'];
    },
    // Los textos de Reactivar donde cambian.
    prefix() {
      return this.kind === 'reactivate'
        ? 'CAMPAIGNS2.REACT_FLOW'
        : 'CAMPAIGNS2.OFFER_FLOW';
    },
  },
  mounted() {
    this.loadItems();
  },
  methods: {
    t(key, params) {
      const own = `${this.prefix}.${key}`;
      return this.$te(own)
        ? this.$t(own, params)
        : this.$t(`CAMPAIGNS2.OFFER_FLOW.${key}`, params);
    },
    set(field, value) {
      this.$emit('update:brief', { ...this.brief, [field]: value });
    },
    // Los productos ya elegidos (campaña guardada): sus datos del Catálogo.
    async loadItems() {
      const ids = this.products.map(p => p.catalog_item_id);
      if (!ids.length) return;
      try {
        const { data } = await CatalogItemsAPI.search({
          ids: ids.join(','),
          active: 'all',
        });
        const map = {};
        (data.catalog_items || []).forEach(item => {
          map[item.id] = item;
        });
        this.items = map;
        this.$emit('catalog', map);
      } catch {
        // se ven sin sus datos
      }
    },
    add(item) {
      if (this.products.some(p => p.catalog_item_id === item.id)) return;
      this.$set(this.items, item.id, item);
      this.$emit('catalog', this.items);
      this.set('products', [
        ...this.products,
        { catalog_item_id: item.id, promo_price: '' },
      ]);
      if (item.image_url) this.$emit('photo', item.id);
    },
    remove(index) {
      this.set(
        'products',
        this.products.filter((_p, i) => i !== index)
      );
    },
    setPromo(index, value) {
      const rows = this.products.map((p, i) =>
        i === index ? { ...p, promo_price: value } : p
      );
      this.set('products', rows);
    },
    // % de descuento ↔ precio de promoción.
    percent(row) {
      const item = this.items[row.catalog_item_id];
      if (!item || !row.promo_price || !item.price) return '';
      return Math.round((1 - Number(row.promo_price) / item.price) * 100);
    },
    setPercent(index, row, value) {
      const item = this.items[row.catalog_item_id];
      if (!item) return;
      const pct = Number(value);
      this.setPromo(
        index,
        pct > 0 && pct < 100 ? String(round2(item.price * (1 - pct / 100))) : ''
      );
    },
    money(value, item) {
      return formatMoney(value, (item && item.currency) || 'MXN');
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-3">
    <section
      class="flex flex-col gap-2 p-3 border rounded-md border-slate-100 dark:border-slate-700"
    >
      <p class="m-0 text-sm font-semibold">{{ t('PRODUCTS_TITLE') }}</p>
      <p class="m-0 text-xs text-slate-500">{{ t('PRODUCTS_HINT') }}</p>
      <div
        v-for="(row, index) in products"
        :key="row.catalog_item_id"
        class="grid items-center grid-cols-1 gap-2 p-2 rounded-md sm:grid-cols-[3rem_1fr_7rem_8rem_5rem_auto] bg-slate-25 dark:bg-slate-800"
      >
        <img
          v-if="
            items[row.catalog_item_id] && items[row.catalog_item_id].image_url
          "
          :src="items[row.catalog_item_id].image_url"
          alt=""
          class="object-cover w-12 h-12 rounded"
        />
        <span v-else class="w-12 h-12 rounded bg-slate-100 dark:bg-slate-700" />
        <span class="min-w-0 text-sm">
          <span class="block font-medium truncate">
            {{
              items[row.catalog_item_id]
                ? items[row.catalog_item_id].name
                : `#${row.catalog_item_id}`
            }}
          </span>
          <span
            v-if="items[row.catalog_item_id]"
            class="block text-xs text-slate-500"
          >
            {{
              t('NORMAL', {
                price: money(
                  items[row.catalog_item_id].price,
                  items[row.catalog_item_id]
                ),
              })
            }}
          </span>
        </span>
        <span class="text-xs text-slate-500 sm:text-right">
          {{ t('PROMO') }}
        </span>
        <input
          :value="row.promo_price"
          type="number"
          min="0"
          step="0.01"
          class="!mb-0 !h-8 !py-0 text-sm"
          :placeholder="t('PROMO_PLACEHOLDER')"
          @input="setPromo(index, $event.target.value)"
        />
        <label class="flex items-center gap-1 mb-0 text-xs text-slate-500">
          <input
            :value="percent(row)"
            type="number"
            min="0"
            max="99"
            class="!mb-0 !h-8 !py-0 !w-14 text-sm"
            @change="setPercent(index, row, $event.target.value)"
          />
          %
        </label>
        <woot-button
          v-tooltip="t('REMOVE')"
          variant="clear"
          color-scheme="alert"
          size="small"
          icon="delete"
          @click="remove(index)"
        />
      </div>
      <CatalogPicker :allow-free="false" @select="add" />
      <p v-if="!products.length" class="m-0 text-xs text-slate-500">
        {{ t('NO_PRODUCTS') }}
      </p>
    </section>

    <section
      class="flex flex-wrap items-center gap-2 p-3 border rounded-md border-slate-100 dark:border-slate-700"
    >
      <span class="text-sm font-semibold">{{ t('VALID_UNTIL') }}</span>
      <input
        :value="brief.valid_until"
        type="date"
        class="!mb-0 !w-48"
        @input="set('valid_until', $event.target.value)"
      />
      <span class="w-full text-xs text-slate-500">{{ t('VALID_HINT') }}</span>
    </section>

    <p class="m-0 text-sm font-semibold">{{ t('KNOWLEDGE_TITLE') }}</p>
    <CampaignKnowledge
      :key="filesVersion"
      :brief="brief"
      :kind="kind"
      :kit="kit"
      :campaign-id="campaignId"
      :save="save"
      :attempts="attempts"
      :hidden-facts="hiddenFacts"
      @update:brief="$emit('update:brief', $event)"
    />
  </div>
</template>
