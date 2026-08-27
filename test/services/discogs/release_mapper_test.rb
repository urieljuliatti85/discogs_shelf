require "test_helper"

class Discogs::ReleaseMapperTest < ActiveSupport::TestCase
  def map(info)
    Discogs::ReleaseMapper.attributes_from(info)
  end

  test "maps a basic_information payload onto Release attributes" do
    attributes = map(basic_information(id: 42, title: "Disco", artist: "Banda"))

    assert_equal 42, attributes[:discogs_id]
    assert_equal "Disco", attributes[:title]
    assert_equal "Banda", attributes[:artist]
    assert_equal 1979, attributes[:year]
    assert_equal "Brazil", attributes[:country]
    assert_equal [ "Rock" ], attributes[:genres]
    assert_equal [ "Post-Punk" ], attributes[:styles]
  end

  test "accepts string or symbol keys" do
    assert_equal 7, map({ id: 7, title: "T", artists: [ { "name" => "A" } ] })[:discogs_id]
  end

  # --- artist names ---

  test "strips the numeric disambiguation Discogs adds to duplicate names" do
    assert_equal "Nirvana", Discogs::ReleaseMapper.clean_name("Nirvana (2)")
    assert_equal "Ratos De Porão", Discogs::ReleaseMapper.clean_name("Ratos De Porão (12)")
  end

  test "keeps parentheses that are part of the name" do
    assert_equal "Godspeed You! Black Emperor (Live)",
                 Discogs::ReleaseMapper.clean_name("Godspeed You! Black Emperor (Live)")
  end

  test "joins collaborating artists with the join phrase Discogs supplies" do
    info = basic_information(id: 1, artists: [
      { "name" => "Miles Davis", "join" => "&" },
      { "name" => "John Coltrane", "join" => "" }
    ])

    assert_equal "Miles Davis & John Coltrane", map(info)[:artist]
  end

  test "falls back to a comma when there is no join phrase" do
    info = basic_information(id: 1, artists: [
      { "name" => "A", "join" => "" },
      { "name" => "B", "join" => "" }
    ])

    assert_equal "A, B", map(info)[:artist]
  end

  test "prefers the artist name variation when Discogs sends one" do
    info = basic_information(id: 1, artists: [ { "name" => "Prince", "anv" => "TAFKAP", "join" => "" } ])

    assert_equal "TAFKAP", map(info)[:artist]
  end

  test "names every artist in the artists array, disambiguation removed" do
    info = basic_information(id: 1, artists: [
      { "name" => "Nirvana (2)", "join" => "/" },
      { "name" => "Jesus Lizard, The", "join" => "" }
    ])

    assert_equal [ "Nirvana", "Jesus Lizard, The" ], map(info)[:artists]
  end

  test "falls back to placeholders when the payload has no title or artist" do
    attributes = map({ "id" => 9 })

    assert_equal "Sem título", attributes[:title]
    assert_equal "Artista desconhecido", attributes[:artist]
  end

  # --- labels and formats ---

  test "promotes the first label to the flat label and catno columns" do
    info = basic_information(id: 1, labels: [
      { "name" => "Factory (2)", "catno" => "FACT 10" },
      { "name" => "Outro Selo", "catno" => "OS 1" }
    ])
    attributes = map(info)

    assert_equal "Factory", attributes[:label]
    assert_equal "FACT 10", attributes[:catno]
    assert_equal 2, attributes[:labels].size
  end

  test "keeps only the format fields the app renders" do
    info = basic_information(id: 1, formats: [
      { "name" => "Vinyl", "qty" => "2", "text" => "180g", "descriptions" => [ "LP" ], "lixo" => "x" }
    ])

    assert_equal [ { "name" => "Vinyl", "qty" => "2", "text" => "180g", "descriptions" => [ "LP" ] } ],
                 map(info)[:formats]
  end

  test "year zero and missing years become nil" do
    assert_nil map(basic_information(id: 1, year: 0))[:year]
    assert_nil map(basic_information(id: 1, year: nil))[:year]
  end

  test "cover falls back to the thumbnail when Discogs omits the big image" do
    info = basic_information(id: 1, cover_image: "", thumb: "https://img/t.jpg")

    assert_equal "https://img/t.jpg", map(info)[:cover_url]
  end

  test "blank image urls become nil rather than empty strings" do
    assert_nil map(basic_information(id: 1, thumb: "", cover_image: ""))[:thumb_url]
  end

  test "the mapped attributes are assignable to a Release" do
    release = Release.new(map(basic_information(id: 4242, title: "Novo", artist: "Alguém")))

    assert release.valid?, release.errors.full_messages.to_sentence
  end
end
