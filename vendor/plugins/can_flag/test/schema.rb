ActiveRecord::Schema.define(:version => 0) do
  
  create_table :articles do |t|
    t.string  :title
    t.string  :body
    t.integer :user_id
  end

  create_table :users do |t|
    t.string  :login
  end
  
  create_table :flags do |t|
    t.integer :user_id
    t.integer :flaggable_id
    t.string  :flaggable_type
    t.integer :flagger_id
    t.string  :flagger_type
    t.integer :owner_id
    t.string  :owner_type
    t.string  :reason
  end
end