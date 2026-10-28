# frozen_string_literal: true

# ================================================================================
# prospeccion V7a — ¿ESTE CORREO PUEDE RECIBIR?
# ================================================================================
# Plan: docs/prospeccion_estudio.md (§10.8 V7). Antes de inscribir a alguien en una
# campaña por correo: escribir a una dirección muerta rebota, y los rebotes queman el
# buzón con el que se prospecta.
#
#   mal escrito (no pasa Devise.email_regexp)         → inválido
#   el dominio no tiene MX ni A, o tiene «MX nulo» (.) → inválido
#   el DNS no contesta o tarda                         → VÁLIDO (no se frena una campaña por la red)
#
# El dominio se recuerda en caché: 7 días si recibe, 1 día si no (por si lo arreglan).
# Lo usa ContactTrackings::Eligibility, así el lote, su vista previa y la automatización
# omiten a los mismos contactos.
# ================================================================================
require 'resolv'

module ContactTrackings::EmailCheck
  DNS_TIMEOUT = 2
  CACHE_OK = 7.days
  CACHE_BAD = 1.day

  module_function

  def deliverable?(email)
    email = email.to_s.strip
    return false unless Devise.email_regexp.match?(email)

    domain_receives_mail?(email.split('@').last.downcase)
  end

  def domain_receives_mail?(domain)
    cached = Rails.cache.read(cache_key(domain))
    return cached unless cached.nil?

    result = lookup(domain)
    return true if result.nil?

    Rails.cache.write(cache_key(domain), result, expires_in: result ? CACHE_OK : CACHE_BAD)
    result
  end

  # true / false según el DNS; nil si el DNS no contestó (no se guarda en caché).
  # Sin raise_timeout_errors, Resolv devuelve [] igual para «no existe» que para «no contestó».
  def lookup(domain)
    Resolv::DNS.open(Resolv::DNS::Config.default_config_hash.merge(raise_timeout_errors: true)) do |dns|
      dns.timeouts = DNS_TIMEOUT
      mx = dns.getresources(domain, Resolv::DNS::Resource::IN::MX)
      next mx.any? { |r| r.exchange.to_s.present? } if mx.any?

      dns.getresources(domain, Resolv::DNS::Resource::IN::A).any?
    end
  rescue Resolv::ResolvError, Resolv::ResolvTimeout, SocketError, Errno::ECONNREFUSED
    nil
  end

  def cache_key(domain)
    "prospeccion:email_domain:#{domain}"
  end
end
