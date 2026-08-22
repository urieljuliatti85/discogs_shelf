module Discogs
  # Turns a Discogs `basic_information` payload into Release attributes.
  module ReleaseMapper
    module_function

    # Discogs disambiguates duplicate artist names with a numeric suffix,
    # e.g. "Nirvana (2)". That is noise for display purposes.
    DISAMBIGUATION = /\s\(\d+\)\z/

    def attributes_from(info)
      info = info.to_h.with_indifferent_access
      labels = Array(info[:labels]).map { |l| { "name" => clean_name(l["name"]), "catno" => l["catno"] } }
      formats = Array(info[:formats]).map do |f|
        {
          "name" => f["name"],
          "qty" => f["qty"],
          "text" => f["text"],
          "descriptions" => Array(f["descriptions"])
        }
      end

      {
        discogs_id: info[:id],
        title: info[:title].presence || "Sem título",
        artist: artist_name(info[:artists]),
        artists: Array(info[:artists]).map { |a| clean_name(a["name"]) },
        year: info[:year].to_i.positive? ? info[:year].to_i : nil,
        thumb_url: info[:thumb].presence,
        cover_url: info[:cover_image].presence || info[:thumb].presence,
        resource_url: info[:resource_url],
        country: info[:country].presence,
        formats: formats,
        genres: Array(info[:genres]),
        styles: Array(info[:styles]),
        labels: labels,
        label: labels.first&.dig("name"),
        catno: labels.first&.dig("catno")
      }
    end

    def artist_name(artists)
      list = Array(artists)
      return "Artista desconhecido" if list.empty?

      list.each_with_index.map { |a, i|
        name = clean_name(a["anv"].presence || a["name"])
        join = a["join"].to_s.strip
        next name if i == list.size - 1
        join.present? ? "#{name} #{join}" : "#{name},"
      }.join(" ").squeeze(" ").strip
    end

    def clean_name(name)
      name.to_s.sub(DISAMBIGUATION, "").strip
    end
  end
end
