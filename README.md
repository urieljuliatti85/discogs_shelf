# Discogs Shelf

Navegador da sua coleção e da sua lista de desejos do Discogs.
Rails 8 (API + servidor), React 19 no frontend, SQLite como banco.

Os dados do Discogs são copiados para o SQLite local numa sincronização
explícita — a navegação, busca e filtros rodam inteiramente contra o banco
local, então a API do Discogs só é chamada quando você manda sincronizar
(e sob demanda, ao abrir um disco, para trazer faixas e vídeos).

## Configuração

```bash
cp .env.example .env
```

Preencha o `.env`:

| Variável | Obrigatória | Para quê |
| --- | --- | --- |
| `DISCOGS_USERNAME` | sim | De qual perfil ler a coleção e a lista de desejos |
| `DISCOGS_TOKEN` | não | Token pessoal: sobe o limite de 25 para 60 req/min e libera perfis privados |

O token é gerado em <https://www.discogs.com/settings/developers> ("Generate new token").

Confira as credenciais antes de sincronizar:

```bash
bin/rails discogs:check
```

## Rodando

```bash
bin/setup     # instala gems, npm e prepara o banco
bin/dev       # sobe Rails + esbuild + tailwind em watch
```

Abra <http://localhost:3001> e clique em **Sincronizar** — ou rode pelo terminal:

```bash
bin/rails discogs:sync
```

A sincronização roda em background (Active Job, adapter `:async` em
desenvolvimento) e a barra de progresso no cabeçalho acompanha em tempo real.

## O que dá para fazer

- **Coleção** e **lista de desejos** em grade ou lista
- Busca por título, artista, gravadora ou número de catálogo
- Filtros por gênero, estilo, formato e década — com contagem por faceta, que
  se ajusta conforme os outros filtros
- Ordenação por data de adição, artista, título, ano ou sua nota
- Página do disco com faixas, vídeos, dados da comunidade e sua avaliação
- **Estatísticas**: totais, gêneros, artistas, formatos e décadas
- Todo filtro vive na URL, então dá para compartilhar e usar o botão voltar

## Estrutura

```
app/services/discogs/     cliente HTTP, mapper e serviço de sincronização
app/queries/              filtro/ordenação/paginação compartilhados entre as listas
app/serializers/          payloads JSON
app/controllers/api/      endpoints
app/javascript/           SPA React (páginas, componentes, hooks)
```

### Endpoints

| Método | Rota | Descrição |
| --- | --- | --- |
| `GET` | `/api/collection` | Coleção, com filtros, ordenação, paginação e facetas |
| `GET` | `/api/wantlist` | Mesma coisa para a lista de desejos |
| `GET` | `/api/releases/:discogs_id` | Detalhe do disco (busca no Discogs e guarda em cache por 30 dias) |
| `GET` | `/api/profile` | Usuário configurado + estatísticas |
| `GET` | `/api/sync` | Estado da sincronização atual |
| `POST` | `/api/sync` | Dispara uma sincronização |

Parâmetros de lista: `q`, `genre`, `style`, `media`, `decade`, `sort`, `page`,
`per_page` (máx. 100).

## Notas

- A sincronização é um espelho: itens removidos no Discogs somem do banco local.
- Sem token, o Discogs limita a 25 requisições por minuto. O cliente respeita o
  header de rate limit e faz pausa antes de estourar, então coleções grandes
  demoram mais em vez de falhar.
- Nenhuma escrita é feita no Discogs — o app só lê.
