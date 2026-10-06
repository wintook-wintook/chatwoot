# frozen_string_literal: true

# ================================================================================
# CRUD nativo de sinónimos (reemplaza los POST/GET al servicio externo WINTOOK_BOT).
# Guarda "como Chatwoot": ActiveRecord + Current.account, contra wintook.palabras_sinonimos.
#
#   GET  ?tipo=raiz&search=&page=              → raíces paginadas (+ categoría)
#   GET  ?tipo=raiz&select=1                   → raíces mínimas para el <select>
#   GET  ?tipo=sinonimo&raiz_id=&search=&page= → sinónimos de una raíz
#   POST { tipo, palabra, palabra_sinonimo_id?, sinonimo_semantico_id? }
#   PATCH/DELETE :id
# ================================================================================
class Api::V1::Accounts::PalabrasSinonimosController < Api::V1::Accounts::BaseController
  PER_PAGE = 15

  before_action :set_registro, only: [:update, :destroy]

  def index
    if params[:tipo] == 'sinonimo'
      render json: paginated(scope_sinonimos, :sinonimo)
    elsif params[:select].present?
      render json: { data: raices_select }
    else
      render json: paginated(scope_raices, :raiz)
    end
  end

  def create
    reg = PalabraSinonimo.new(account_id: Current.account.id, palabra: normaliza(params[:palabra]))

    if params[:tipo] == 'sinonimo'
      reg.palabra_sinonimo_id = params[:palabra_sinonimo_id]
      guard_sinonimo!(reg)
      reg.save!
    else
      reg.sinonimo_semantico_id = params[:sinonimo_semantico_id].presence
      reg.palabra_sinonimo_id = 0
      reg.save!
      reg.update_column(:palabra_sinonimo_id, reg.palabra_id) # la raíz apunta a sí misma
    end

    render json: serialize(reg)
  end

  def update
    @registro.palabra = normaliza(params[:palabra]) if params[:palabra].present?
    if @registro.raiz? && params.key?(:sinonimo_semantico_id)
      @registro.sinonimo_semantico_id = params[:sinonimo_semantico_id].presence
    end
    @registro.save!
    render json: serialize(@registro)
  end

  def destroy
    if @registro.raiz?
      # Borrar una raíz arrastra sus sinónimos (cascada manual: no hay FK en la tabla legacy).
      cuenta_scope.where(palabra_sinonimo_id: @registro.palabra_id).delete_all
    else
      @registro.destroy!
    end
    head :ok
  end

  private

  def cuenta_scope
    PalabraSinonimo.where(account_id: Current.account.id)
  end

  def set_registro
    @registro = cuenta_scope.find(params[:id])
  end

  def normaliza(palabra)
    palabra.to_s.strip.upcase
  end

  # Evita sinónimos duplicados dentro de la misma raíz (mismo texto).
  def guard_sinonimo!(reg)
    return if reg.palabra.blank? || reg.palabra_sinonimo_id.blank?

    dup = cuenta_scope.where(palabra_sinonimo_id: reg.palabra_sinonimo_id, palabra: reg.palabra).exists?
    raise ActiveRecord::RecordInvalid, reg if dup
  end

  # --- scopes de listado -----------------------------------------------------
  def scope_raices
    s = cuenta_scope.raices.order(:palabra)
    s = s.buscar(params[:search]) if params[:search].present?
    s
  end

  def scope_sinonimos
    s = cuenta_scope.sinonimos.order(:palabra)
    # raiz_id 0/ausente = todos los sinónimos; >0 = solo los de esa raíz.
    s = s.where(palabra_sinonimo_id: params[:raiz_id]) if params[:raiz_id].to_i.positive?
    s = s.buscar(params[:search]) if params[:search].present?
    s
  end

  def raices_select
    scope_raices.map { |r| { palabra_id: r.palabra_id, palabra: r.palabra, sinonimo_semantico_id: r.sinonimo_semantico_id } }
  end

  # --- paginación + serialización -------------------------------------------
  def paginated(scope, tipo)
    page  = [params[:page].to_i, 1].max
    total = scope.count
    rows  = scope.limit(PER_PAGE).offset((page - 1) * PER_PAGE)
    {
      data: rows.map { |r| tipo == :sinonimo ? serialize_sinonimo(r) : serialize(r) },
      meta: { current_page: page, page_size: PER_PAGE, count: total }
    }
  end

  def serialize(raiz)
    {
      palabra_id: raiz.palabra_id,
      palabra: raiz.palabra,
      palabra_sinonimo_id: raiz.palabra_sinonimo_id,
      sinonimo_semantico_id: raiz.sinonimo_semantico_id,
      sinonimo_semantico_nombre: catalogo[raiz.sinonimo_semantico_id],
      sinonimos_count: conteos[raiz.palabra_id] || 0
    }
  end

  def serialize_sinonimo(sin)
    {
      palabra_id: sin.palabra_id,
      palabra: sin.palabra,
      palabra_sinonimo_id: sin.palabra_sinonimo_id,
      palabra_raiz: raices_words[sin.palabra_sinonimo_id]
    }
  end

  def catalogo
    @catalogo ||= SinonimoSemantico.pluck(:id, :nombre).to_h
  end

  # Nº de sinónimos por raíz (para el aviso de borrado en cascada).
  def conteos
    @conteos ||= cuenta_scope.sinonimos.group(:palabra_sinonimo_id).count
  end

  def raices_words
    @raices_words ||= cuenta_scope.raices.pluck(:palabra_id, :palabra).to_h
  end
end
