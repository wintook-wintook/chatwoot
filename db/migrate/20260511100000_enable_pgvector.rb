# @knowledge_sources
# Habilita la extensión pgvector en PostgreSQL para soporte de vectores de embeddings.
class EnablePgvector < ActiveRecord::Migration[6.1]
  def up
    enable_extension 'vector'
  end

  def down
    disable_extension 'vector'
  end
end
