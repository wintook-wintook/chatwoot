// ================================================================================
// @knowledge_sources
// Traducciones en Español para el módulo Base de Conocimiento.
// ================================================================================

export default {
  KNOWLEDGE_SOURCES: {
    TITLE: 'Base de Conocimiento',
    DESCRIPTION:
      'Administra las fuentes de información que alimentan la búsqueda semántica. Conecta foros Discourse o usa las Respuestas Predefinidas para que el asistente encuentre contenido relevante en cada conversación.',

    TABS: {
      INDEXED_CONTENT: 'Contenido indexado',
      SOURCES: 'Fuentes (%{count})',
      SEARCH_CONSOLE: 'Consola de Búsqueda (Fuentes)',
      CONFIG: 'Configuración',
      ERP_CONNECTION: 'Conexión ERP',
      COLLECTION_AGENT: 'Agente Cobrador',
      QUERY_CONSOLE: 'Consola de Consulta (ERP)',
    },

    ACTIONS: {
      ADD: 'Agregar Fuente',
    },

    EMPTY_STATE: 'No hay fuentes de conocimiento configuradas',

    API: {
      FETCH_ERROR: 'Error al cargar las fuentes de conocimiento',
      CREATE_SUCCESS: 'Fuente creada correctamente',
      UPDATE_SUCCESS: 'Fuente actualizada correctamente',
      DELETE_SUCCESS: 'Fuente eliminada correctamente',
      ERROR: 'Ocurrió un error. Intenta de nuevo',
    },

    // @knowledge_sources — fuente WordPress
    WORDPRESS: {
      SITE_URL: 'URL del sitio',
      SITE_URL_PLACEHOLDER: 'https://misitio.com',
      TEST_CONNECTION: 'Probar conexión',
      CONNECT_HINT:
        'Conectar solo lee los títulos. Qué entra al índice se elige en el paso siguiente.',
      PROBE_OK:
        'Responde. %{posts} entradas · %{pages} páginas · %{products} productos · %{categories} categorías.',
      ERROR_FORBIDDEN:
        'El sitio bloqueó la lectura de su API (403). Suele ser un plugin de seguridad: hay que permitir el acceso de lectura a /wp-json/ y volver a probar.',
      ERROR_UNREACHABLE:
        'No se pudo llegar al sitio. Revisá que la dirección sea correcta y que el sitio esté en línea.',
      ERROR_NOT_WORDPRESS:
        'La dirección responde, pero no devuelve la API de WordPress. Puede ser una portada de mantenimiento o un cortafuegos.',
      ERROR_INVALID_URL: 'Esa dirección no es válida.',
      ERROR_GENERIC: 'No se pudo leer el sitio. Intentá de nuevo.',

      PICKER_TITLE: 'Elegir qué sabe el agente',
      PICKER_HINT:
        'Elegí las categorías que entran completas; abajo podés hacer excepciones una por una. Lo que se publique después en una categoría elegida entra solo.',
      TYPES: '¿Qué tipo de contenido?',
      TYPE_POSTS: 'Entradas',
      TYPE_PAGES: 'Páginas',
      TYPE_PRODUCTS: 'Productos',
      NO_TYPES: 'Este sitio no tiene contenido legible.',
      CATEGORIES: 'Categorías',
      CATEGORIES_HINT:
        'Sin ninguna elegida entra todo. Elegir una hace que entre todo lo suyo, incluso lo que se publique más adelante.',
      SEARCH: 'Buscar por título…',
      ONLY_SELECTED: 'solo las elegidas',
      NO_RESULTS: 'No hay contenido que coincida.',
      CATALOG_ERROR: 'No se pudo leer el listado del sitio.',
      ESTIMATE:
        '%{selected} de %{total} elegidas · ≈ %{chunks} fragmentos · unos %{seconds} s',
      INDEX_SELECTED: 'Indexar lo elegido',
      CANCEL: 'Cancelar',
      NEW_ENTRIES: '%{count} entradas nuevas se agregaron al índice',
      PICK_CONTENT: 'Elegir contenido',
    },
  },
};
