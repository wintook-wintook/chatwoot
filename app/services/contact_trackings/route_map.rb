# frozen_string_literal: true

# ================================================================================
# proyecto@contact_tracking — MAPA DE RUTAS POR RAMA (@ruta)
# ================================================================================
# Permite que UN mismo Agente IA use una fuente distinta según la rama de la
# conversación, con un número de ramas libre y nombres definidos por quien configura
# el agente. El motor no sabe qué significa "soporte": solo lee las etiquetas que
# encuentra declaradas.
#
#   @ruta(soporte: fallas, errores, integraciones): @discourse -> @crear_ticket(tipo=Soporte)
#   @ruta(comercial: precios, licencias): {{hoja:Info Licencia}} -> @crear_ticket(tipo=Comercial)
#   @ruta(administrativo: facturas, RFC, pagos): - -> @crear_ticket(tipo=Administrativo)
#   @ruta_por_defecto: comercial
#
# Se lee "consulta esta fuente; si no resuelve el turno, escala así". La parte de la
# derecha (tras -> o →) es opcional: sin ella la rama cae al conversacional. Un guion
# como fuente significa "esta rama no consulta nada".
# Sin líneas @ruta( el mapa queda vacío y el motor se comporta como siempre.
# ================================================================================

module ContactTrackings
  class RouteMap
    LINE_RE    = /^[ \t]*@ruta\([ \t]*([a-z0-9_-]+)[ \t]*(?::[ \t]*([^)]*))?\)[ \t]*:[ \t]*(.*)$/i
    DEFAULT_RE = /^[ \t]*@ruta_por_defecto[ \t]*:[ \t]*([a-z0-9_-]+)[ \t]*$/i
    # Marcas que declaran explícitamente "sin fuente": guion corto, medio o largo.
    NO_SOURCE  = ['-', '–', '—'].freeze
    # Separa la fuente del escalamiento: "fuente -> qué hacer si no resuelve".
    ARROW_RE   = /\s*(?:->|=>|→)\s*/

    Route = Struct.new(:name, :description, :directive, :escalation, keyword_init: true) do
      def source?
        directive.present?
      end

      def escalates?
        escalation.present?
      end
    end

    def self.parse(text)
      new(text)
    end

    # Quita del texto las líneas de configuración, para que nunca lleguen al modelo
    # ni al cliente.
    def self.strip(text)
      text.to_s.gsub(LINE_RE, '').gsub(DEFAULT_RE, '').gsub(/\n{3,}/, "\n\n").strip
    end

    def initialize(text)
      @text   = text.to_s
      @routes = build_routes
      @default_name = @text[DEFAULT_RE, 1]&.downcase
    end

    attr_reader :routes

    def present?
      @routes.any?
    end

    def names
      @routes.map(&:name)
    end

    def [](name)
      return nil if name.blank?

      @routes.find { |r| r.name == name.to_s.strip.downcase }
    end

    # Rama declarada como por defecto, si existe y es una de las declaradas.
    def default
      self[@default_name]
    end

    # ¿Alguna rama declara su propio escalamiento? Si ninguna lo hace, el motor sigue
    # usando la directiva global del prompt (compatibilidad).
    def escalations?
      @routes.any?(&:escalates?)
    end

    # Cada rama con su descripción, para alimentar al clasificador.
    def catalog
      @routes.map { |r| r.description.present? ? "#{r.name}: #{r.description}" : r.name }
    end

    private

    def build_routes
      @text.scan(LINE_RE).filter_map do |name, description, body|
        source, escalation = body.to_s.strip.split(ARROW_RE, 2).map { |part| part.to_s.strip }
        Route.new(
          name: name.to_s.strip.downcase,
          description: description.to_s.strip.presence,
          directive: NO_SOURCE.include?(source) ? nil : source.presence,
          escalation: escalation.presence
        )
      end.uniq(&:name)
    end
  end
end
