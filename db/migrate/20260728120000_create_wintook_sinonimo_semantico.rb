# frozen_string_literal: true

# ================================================================================
# Sinónimos nativos (reemplazo del servicio externo WINTOOK_BOT)
# --------------------------------------------------------------------------------
# Trabaja sobre el esquema legacy `wintook` y sus nombres de tabla existentes:
#   - wintook.palabras_sinonimos  (YA existe en staging/prod; se crea en dev)
#   - wintook.sinonimo_semantico  (NUEVA: catálogo fijo de categorías)
#
# SQL crudo e idempotente (IF NOT EXISTS): en staging/prod, donde `wintook` y
# `palabras_sinonimos` ya existen, solo agrega la columna nueva + el catálogo.
# En chatwoot_dev crea el esquema y la tabla legacy para poder desarrollar/probar.
# Se usa `execute` (no create_table) a propósito: así NO se vuelca a db/schema.rb.
# ================================================================================
class CreateWintookSinonimoSemantico < ActiveRecord::Migration[7.0]
  CATEGORIAS = %w[marca color material medida modelo uso compatibilidad característica].freeze

  def up
    execute <<~SQL.squish
      CREATE SCHEMA IF NOT EXISTS wintook;
    SQL

    # Tabla legacy (no-op donde ya existe; la crea en dev con el shape real).
    execute <<~SQL
      CREATE TABLE IF NOT EXISTS wintook.palabras_sinonimos (
        palabra_id          bigserial PRIMARY KEY,
        palabra             varchar,
        palabra_sinonimo_id integer NOT NULL DEFAULT 0,
        account_id          integer NOT NULL DEFAULT 0
      );
    SQL

    # Catálogo semántico fijo.
    execute <<~SQL
      CREATE TABLE IF NOT EXISTS wintook.sinonimo_semantico (
        id     bigserial PRIMARY KEY,
        nombre varchar NOT NULL
      );
    SQL
    execute <<~SQL
      CREATE UNIQUE INDEX IF NOT EXISTS idx_wintook_sinonimo_semantico_nombre
        ON wintook.sinonimo_semantico (nombre);
    SQL

    # Columna nueva (opcional) en la tabla existente — solo aplica a las raíces.
    execute <<~SQL
      ALTER TABLE wintook.palabras_sinonimos
        ADD COLUMN IF NOT EXISTS sinonimo_semantico_id integer;
    SQL

    # Semilla del catálogo fijo (idempotente).
    CATEGORIAS.each do |nombre|
      execute(
        "INSERT INTO wintook.sinonimo_semantico (nombre) " \
        "VALUES (#{quote(nombre)}) ON CONFLICT (nombre) DO NOTHING;"
      )
    end
  end

  def down
    # No se destruye la tabla legacy; solo lo que agregó esta migración.
    execute 'ALTER TABLE wintook.palabras_sinonimos DROP COLUMN IF EXISTS sinonimo_semantico_id;'
    execute 'DROP TABLE IF EXISTS wintook.sinonimo_semantico;'
  end
end
