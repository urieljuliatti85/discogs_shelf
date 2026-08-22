class CreateCollectionItems < ActiveRecord::Migration[8.1]
  def change
    create_table :collection_items do |t|
      t.references :release, null: false, foreign_key: true
      t.integer :instance_id, null: false
      t.integer :folder_id
      t.integer :rating, default: 0
      t.datetime :date_added
      t.json :notes, default: []

      t.timestamps
    end

    add_index :collection_items, :instance_id, unique: true
    add_index :collection_items, :date_added
  end
end
