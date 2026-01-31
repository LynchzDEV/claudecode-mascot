class CreateMascotSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :mascot_sessions do |t|
      t.string :token, null: false
      t.string :name
      t.string :state, default: 'sleeping'
      t.datetime :last_seen_at

      t.timestamps
    end
    add_index :mascot_sessions, :token, unique: true
  end
end
