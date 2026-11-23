# frozen_string_literal: true

require 'resolv'

# Campaña con Vendedor IA por correo — ¿el dominio de la bandeja está listo para mandar campañas? Gmail y Yahoo
# piden a quien manda correo masivo SPF o DKIM, y DMARC; sin eso el correo cae en spam o se rechaza.
#
#   SPF    TXT del dominio que empieza con «v=spf1»
#   DMARC  TXT de _dmarc.<dominio> que empieza con «v=DMARC1»
#   DKIM   TXT de <selector>._domainkey.<dominio> con «v=DKIM1» o «p=»; el selector lo pone cada proveedor, así que se
#          prueban los comunes (Google, Microsoft, los de los envíos más usados). No encontrarlo no es prueba de que falte.
#   free   gmail.com, hotmail.com…: un correo gratis no sirve para campañas (no se le pueden poner SPF ni DKIM propios)
#
# Si el DNS no contesta, el dato queda en nil («no se pudo revisar»), no en false. Se recuerda una hora por dominio.
#
#   TrackingCampaigns::EmailDomainCheck.call('ventas@empresa.com')
#   → { domain: 'empresa.com', free: false, spf: true, dmarc: false, dkim: nil }
module TrackingCampaigns::EmailDomainCheck
  FREE = %w[gmail.com googlemail.com hotmail.com hotmail.es outlook.com outlook.es live.com live.com.mx yahoo.com yahoo.com.mx
            yahoo.es icloud.com me.com aol.com prodigy.net.mx protonmail.com proton.me].freeze
  SELECTORS = %w[google selector1 selector2 default k1 k2 s1 s2 dkim mail smtp mandrill mxvault zoho zmail].freeze
  TIMEOUT = 2
  CACHE = 'campaigns/email_domain/v1'

  module_function

  def call(email)
    domain = email.to_s.split('@').last.to_s.downcase.strip
    return { domain: domain, free: false, spf: nil, dmarc: nil, dkim: nil } if domain.blank?
    return { domain: domain, free: true, spf: nil, dmarc: nil, dkim: nil } if FREE.include?(domain)

    Rails.cache.fetch("#{CACHE}/#{domain}", expires_in: 1.hour) { lookup(domain) }
  end

  def lookup(domain)
    { domain: domain, free: false,
      spf: record?(domain) { |t| t.start_with?('v=spf1') },
      dmarc: record?("_dmarc.#{domain}") { |t| t.start_with?('v=dmarc1') },
      dkim: dkim?(domain) }
  end

  # true si algún selector común tiene llave; nil si no se encontró (puede usar otro selector).
  def dkim?(domain)
    SELECTORS.any? { |s| record?("#{s}._domainkey.#{domain}") { |t| t.start_with?('v=dkim1') || t.include?('p=') } } || nil
  end

  # true / false según los TXT; nil si el DNS no contestó.
  def record?(name, &)
    texts(name).any? { |t| yield(t.downcase) }
  rescue Resolv::ResolvError, Resolv::ResolvTimeout, SocketError
    nil
  end

  def texts(name)
    Resolv::DNS.open do |dns|
      dns.timeouts = TIMEOUT
      dns.getresources(name, Resolv::DNS::Resource::IN::TXT).map { |r| r.strings.join }
    end
  end
end
