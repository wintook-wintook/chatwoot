<script>
// proyecto@asistente_agentes_ia — CREAR UNA ETIQUETA QUE NO EXISTE, SIN SALIR DEL ASISTENTE
// ============================================================================
// Pedido del usuario (25/09/2026): una ruta con #etiqueta que la cuenta no tiene se
// veía marcada («no existe») y había que ir a Ajustes → Etiquetas. Es el mismo modal
// de Ajustes (AddLabel, con el nombre pre-llenado), no una réplica. Al cerrarlo avisa
// al Asistente para que recargue el inventario y vuelva a comprobar: si se creó, la
// marca ámbar desaparece del árbol y del editor.
// ============================================================================
import AddLabel from 'dashboard/routes/dashboard/settings/labels/AddLabel.vue';
import { emitter } from 'shared/helpers/mitt';
import { ASSISTANT_SOURCES_CHANGED } from './sourceDirective';

export default {
  components: { AddLabel },
  props: {
    // Con o sin «#»: «#solicita_servicio» o «solicita_servicio».
    tag: { type: String, required: true },
  },
  data() {
    return { show: false };
  },
  computed: {
    title() {
      return this.tag.replace(/^#/, '');
    },
  },
  methods: {
    close() {
      this.show = false;
      emitter.emit(ASSISTANT_SOURCES_CHANGED);
    },
  },
};
</script>

<template>
  <span class="inline-flex">
    <woot-button
      size="tiny"
      variant="smooth"
      icon="add"
      @click.stop="show = true"
    >
      {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_TAG_ADD') }}
    </woot-button>
    <woot-modal :show.sync="show" :on-close="close">
      <AddLabel v-if="show" :prefill-title="title" @close="close" />
    </woot-modal>
  </span>
</template>
