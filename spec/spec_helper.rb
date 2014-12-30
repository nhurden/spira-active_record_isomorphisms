require 'active_record'
require 'spira'
require 'spira/active_record_isomorphisms'

ActiveRecord::Base.establish_connection adapter: 'sqlite3', database: ':memory:'

ActiveRecord::Migration.create_table :users do |t|
  t.string :email,              null: false, default: ''
  t.string :encrypted_password, null: false, default: ''
  t.timestamps
end

ActiveRecord::Migration.add_index :users, :email, unique: true

RSpec.configure do |config|
  config.around do |example|
    ActiveRecord::Base.transaction do
      example.run
      raise ActiveRecord::Rollback
    end
  end
end
