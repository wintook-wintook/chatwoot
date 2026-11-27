// Menú de acciones de una fila (los tres puntos al final de la fila, columna fija a la
// derecha). Se pinta con posición FIJA, fuera de la tabla que recorta, y se coloca con
// su tamaño real: termina en el borde derecho del botón, abre hacia abajo y, si no cabe,
// hacia arriba; nunca se sale de la ventana.
const GAP = 4;
const MARGIN = 8;

export const placeRowMenu = (anchor, menu) => {
  const width = menu.offsetWidth;
  const height = menu.offsetHeight;
  const maxLeft = window.innerWidth - width - MARGIN;
  const left = Math.max(MARGIN, Math.min(anchor.right - width, maxLeft));
  let top = anchor.bottom + GAP;
  if (top + height > window.innerHeight - MARGIN)
    top = anchor.top - height - GAP;
  const maxTop = window.innerHeight - height - MARGIN;
  return { left, top: Math.max(MARGIN, Math.min(top, maxTop)) };
};

// Para los componentes: abre el menú oculto, lo mide y lo coloca. Requiere
// `rowMenu` en data y la clase `js-row-menu` en el contenedor del menú.
export default {
  methods: {
    openRowMenu(event, row) {
      const btn = event.target && event.target.closest('button');
      if (!btn) return;
      const anchor = btn.getBoundingClientRect();
      this.rowMenu = {
        row,
        top: anchor.bottom + GAP,
        left: anchor.left,
        ready: false,
      };
      this.$nextTick(() => {
        const box = this.$el && this.$el.querySelector('.js-row-menu');
        if (!box || !this.rowMenu) return;
        this.rowMenu = {
          ...this.rowMenu,
          ...placeRowMenu(anchor, box),
          ready: true,
        };
        // Al hacer scroll el menú fijo quedaría descolgado: se cierra.
        window.addEventListener('scroll', this.closeRowMenu, {
          capture: true,
          once: true,
        });
      });
    },
    closeRowMenu() {
      this.rowMenu = null;
      window.removeEventListener('scroll', this.closeRowMenu, {
        capture: true,
      });
    },
    rowMenuStyle() {
      if (!this.rowMenu) return {};
      return {
        top: `${this.rowMenu.top}px`,
        left: `${this.rowMenu.left}px`,
        visibility: this.rowMenu.ready ? 'visible' : 'hidden',
      };
    },
  },
};
