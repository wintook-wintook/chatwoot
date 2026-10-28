# Plan-Organizaciones O5 — lo que el agente IA sabe de la organización del contacto: una
# línea para el prompt (nil si no tiene).
module Organizations::PromptContext
  def self.for(contact)
    organization = contact&.organization
    return if organization.nil?

    details = [I18n.t("organizations.stages.#{organization.stage}"), I18n.t("organizations.kinds.#{organization.kind}"),
               organization.industry].compact_blank.join(', ')
    "SOBRE EL CLIENTE: la persona con la que hablas es de la organización «#{organization.name}» (#{details})."
  end
end
