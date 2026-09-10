# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — EN QUÉ IDIOMA HABLA EL ASISTENTE
# ================================================================================
# El Asistente soporta DOS idiomas y no todos los de Chatwoot. No es pereza: cada
# idioma nuevo obliga a traducir los mensajes del comprobador, y esos mensajes no
# son cosmética — son lo que decide si un Entrenamiento roto se repara o no (medido
# el 08/09/2026: veredicto pelado 1/3, diagnóstico con el carácter que falta 3/3).
# Una traducción floja de esos textos rompe el bucle de corrección en silencio.
#
# POR QUÉ NO SE CONFÍA EN EL FALLBACK DE RAILS:
#   `config.i18n.fallbacks` solo está puesto en production y staging. En desarrollo
#   no hay fallback, así que una cuenta en `pt` vería "translation missing" en el
#   panel. Acá se resuelve a uno de los dos idiomas soportados SIEMPRE, en cualquier
#   entorno, y el resultado es el mismo en los tres.
#
# DE DÓNDE SALE EL IDIOMA:
#   De `I18n.locale`, que ya viene puesto: Api::V1::Accounts::BaseController tiene
#   `around_action :switch_locale_using_account_locale`. O sea, el idioma de la
#   cuenta, el mismo que ve la persona en el resto del dashboard.
#
# QUÉ SE TRADUCE Y QUÉ NO:
#   Se traducen los mensajes del comprobador y lo que el asistente le dice a la
#   persona. NO se traduce la gramática del motor: `@ruta`, `@crear_ticket`,
#   `@buscar_predefinidas` son literales que el parser busca con regex fijas. Un
#   `@route(...)` no lo lee nadie.
# ================================================================================

class ContactTrackings::Assistant::Language
  SUPPORTED = %i[es en].freeze
  DEFAULT   = :es

  # Nombre del idioma tal como se le nombra al modelo en el prompt.
  NAMES = { es: 'español', en: 'English' }.freeze

  def self.resolve(locale = I18n.locale)
    key = locale.to_s.downcase.split(/[-_]/).first.to_s.to_sym
    SUPPORTED.include?(key) ? key : DEFAULT
  end

  def self.name_for(locale = I18n.locale)
    NAMES.fetch(resolve(locale))
  end
end
