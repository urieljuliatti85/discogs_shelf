namespace :discogs do
  desc "Baixa a coleção e a lista de desejos do Discogs para o banco local"
  task sync: :environment do
    client = Discogs::Client.new

    abort "DISCOGS_USERNAME não está definido (veja .env.example)" unless client.configured?

    puts "Sincronizando @#{client.username}#{client.authenticated? ? ' (autenticado)' : ' (sem token)'}…"

    sync_run = Discogs::Sync.new(client: client).call

    puts "Pronto: #{CollectionItem.count} itens na coleção, #{WantlistItem.count} na lista de desejos " \
         "(#{sync_run.synced_count} registros processados)."
  rescue Discogs::Error => e
    abort "Falhou: #{e.message}"
  end

  desc "Verifica as credenciais do Discogs"
  task check: :environment do
    client = Discogs::Client.new

    abort "DISCOGS_USERNAME não está definido (veja .env.example)" unless client.configured?

    if client.authenticated?
      identity = client.identity
      puts "Token válido para @#{identity['username']}."
    else
      puts "Sem DISCOGS_TOKEN — usando acesso público (25 req/min)."
    end

    profile = client.profile
    puts "Perfil @#{profile['username']}: #{profile['num_collection']} na coleção, #{profile['num_wantlist']} na lista de desejos."
  rescue Discogs::Error => e
    abort "Falhou: #{e.message}"
  end
end
