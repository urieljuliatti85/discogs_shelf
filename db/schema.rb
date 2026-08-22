# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_01_01_000004) do
  create_table "collection_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "date_added"
    t.integer "folder_id"
    t.integer "instance_id", null: false
    t.json "notes", default: []
    t.integer "rating", default: 0
    t.integer "release_id", null: false
    t.datetime "updated_at", null: false
    t.index ["date_added"], name: "index_collection_items_on_date_added"
    t.index ["instance_id"], name: "index_collection_items_on_instance_id", unique: true
    t.index ["release_id"], name: "index_collection_items_on_release_id"
  end

  create_table "releases", force: :cascade do |t|
    t.string "artist", null: false
    t.json "artists", default: []
    t.string "catno"
    t.string "country"
    t.string "cover_url"
    t.datetime "created_at", null: false
    t.json "details"
    t.datetime "details_fetched_at"
    t.integer "discogs_id", null: false
    t.json "formats", default: []
    t.json "genres", default: []
    t.string "label"
    t.json "labels", default: []
    t.string "resource_url"
    t.json "styles", default: []
    t.string "thumb_url"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.integer "year"
    t.index ["artist"], name: "index_releases_on_artist"
    t.index ["discogs_id"], name: "index_releases_on_discogs_id", unique: true
    t.index ["year"], name: "index_releases_on_year"
  end

  create_table "sync_runs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error_message"
    t.datetime "finished_at"
    t.string "stage"
    t.datetime "started_at"
    t.string "status", default: "pending", null: false
    t.integer "synced_count", default: 0, null: false
    t.integer "total_count"
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_sync_runs_on_created_at"
  end

  create_table "wantlist_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "date_added"
    t.text "notes"
    t.integer "rating", default: 0
    t.integer "release_id", null: false
    t.datetime "updated_at", null: false
    t.index ["date_added"], name: "index_wantlist_items_on_date_added"
    t.index ["release_id"], name: "index_wantlist_items_on_release_id", unique: true
  end

  add_foreign_key "collection_items", "releases"
  add_foreign_key "wantlist_items", "releases"
end
