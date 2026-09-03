# frozen_string_literal: true

# @kbase_contpaq — Identidad del contacto para el Agente de Servicio CONTPAQi.
#
# El servicio EXIGE `user_id` y solo acepta un correo valido o un RFC mexicano; si no
# cumple el formato, rechaza la peticion con 422. Nuestros contactos no siempre tienen
# correo, asi que se sintetiza uno estable en el dominio de Kontrolya:
#
#   con telefono  ->  los ultimos 10 digitos del E.164, sin el '+'
#                     +523121122345          ->  3121122345@kontrolya.com
#   sin telefono  ->  el contacto y su cuenta, la cuenta a cuatro digitos
#                     cuenta 2, contacto 15783  ->  15783_0002@kontrolya.com
#
# Se prefiere el telefono porque identifica a la persona aunque cambie de cuenta o se
# recree el contacto; el par contacto/cuenta es el respaldo, no la primera opcion.
class Contpaq::UserIdBuilder
  DOMAIN = 'kontrolya.com'

  # Ancho del identificador de cuenta en el respaldo. Una cuenta de mas de 9999 crece
  # el identificador y no rompe nada: el tope del campo son 256 caracteres.
  ACCOUNT_WIDTH = 4

  # E.164 admite desde 2 digitos, asi que `last(10)` puede devolver menos de 10: se toma
  # lo que haya en vez de descartar el telefono, que sigue siendo el mejor identificador.
  PHONE_DIGITS = 10

  def initialize(contact, account)
    @contact = contact
    @account = account
  end

  # nil cuando no hay con que identificar: sin `user_id` no se consulta (el servicio lo
  # rechazaria igual, y aqui se evita gastar una llamada de la cuota).
  def build
    return nil if @contact.blank? || @account.blank?

    local = phone_local_part || fallback_local_part
    return nil if local.blank?

    "#{local}@#{DOMAIN}"
  end

  private

  def phone_local_part
    digits = @contact.phone_number.to_s.delete('^0-9')
    return nil if digits.blank?

    digits.last(PHONE_DIGITS)
  end

  def fallback_local_part
    return nil if @contact.id.blank?

    "#{@contact.id}_#{format("%0#{ACCOUNT_WIDTH}d", @account.id)}"
  end
end
