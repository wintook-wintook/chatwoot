# Plan-Organizaciones O5 — {{organizacion.nombre}} (o {{organization.name}}) en mensajes,
# plantillas y correos: la organización del contacto. Sin organización, todo vacío.
class OrganizationDrop < BaseDrop
  def nombre
    @obj.try(:name)
  end
  alias name nombre

  def rfc
    @obj.try(:tax_id)
  end
  alias tax_id rfc

  def giro
    @obj.try(:industry)
  end
  alias industry giro

  def telefono
    @obj.try(:phone_number)
  end
  alias phone_number telefono

  def sitio_web
    @obj.try(:website)
  end
  alias website sitio_web

  # «Prospecto» / «Cliente» y «Empresa» / «Público en general».
  def etapa
    I18n.t("organizations.stages.#{@obj.stage}") if @obj
  end
  alias stage etapa

  def tipo
    I18n.t("organizations.kinds.#{@obj.kind}") if @obj
  end
  alias kind tipo
end
