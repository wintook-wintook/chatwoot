# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — RECIBIR UN ENCARGO (.md)
# ================================================================================
# Valida el archivo, lo deja como texto limpio y lo guarda (ver TrackingAgentBrief).
# No lo lee con IA: eso es de AgentBriefDigestJob (F2).
#
# EL MISMO ARCHIVO DOS VECES:
#   · en la misma conversación → se devuelve el que ya estaba (`reused: 'same_session'`):
#     subirlo de nuevo por error no puede dejar dos encargos en la misma entrevista;
#   · en otra conversación de la cuenta, con la lectura ya hecha → encargo nuevo con la
#     lectura copiada (`reused: 'reading'`): no se vuelve a pagar, y las respuestas del
#     chat empiezan de cero, porque son de ese agente.
#
# QUÉ ES "TEXTO":
#   UTF-8 válido y sin bytes nulos. Un .docx renombrado a .md es un zip: tiene bytes
#   nulos y se rechaza aquí, antes de que la IA intente entender basura binaria.
# ================================================================================

class ContactTrackings::Assistant::BriefIntake
  Result = Struct.new(:brief, :reused, :error, keyword_init: true)
  # Unas instrucciones que no vienen de un archivo sino de la conversación del
  # Asistente (DraftingChat): entran por el mismo camino que una subida.
  TextUpload = Struct.new(:text, :original_filename) do
    def read = text.to_s
    def size = text.to_s.bytesize
  end
  BOM = "\uFEFF"

  def initialize(account, user, file:, session: nil)
    @account = account
    @user = user
    @file = file
    @session = session
  end

  def call
    error = check_file
    return Result.new(error: error) if error

    texto = normalize(@file.read)
    return Result.new(error: :not_text) if texto.nil?
    return Result.new(error: :empty) if texto.strip.empty?

    store(texto)
  end

  private

  def check_file
    return :missing_file unless @file.respond_to?(:read) && @file.respond_to?(:original_filename)
    return :too_large if @file.size > TrackingAgentBrief::MAX_BYTES
    return :bad_extension if TrackingAgentBrief::EXTENSIONS.exclude?(File.extname(@file.original_filename.to_s).downcase)

    nil
  end

  def normalize(bytes)
    texto = bytes.to_s.dup.force_encoding(Encoding::UTF_8)
    return nil if !texto.valid_encoding? || texto.include?("\u0000")

    texto.delete_prefix(BOM).gsub(/\r\n?/, "\n")
  end

  def store(texto)
    huella = TrackingAgentBrief.fingerprint(texto)
    mismo = same_session_brief(huella)
    return Result.new(brief: mismo, reused: 'same_session') if mismo

    brief = TrackingAgentBrief.new(account: @account, user: @user, tracking_assistant_session: @session,
                                   filename: File.basename(@file.original_filename.to_s), content: texto,
                                   sha256: huella)
    gemelo = TrackingAgentBrief.read_twin(@account, huella)
    brief.copy_reading_from(gemelo) if gemelo
    brief.save!
    Result.new(brief: brief, reused: gemelo ? 'reading' : nil)
  end

  def same_session_brief(huella)
    return nil if @session.nil?

    TrackingAgentBrief.where(account: @account, tracking_assistant_session: @session, sha256: huella)
                      .recent_first.first
  end
end
