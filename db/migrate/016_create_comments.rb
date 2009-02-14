class CreateComments < ActiveRecord::Migration
  def self.up
    create_table :comments do |t|
      t.references  :user
      t.references  :commentable, :polymorphic => true
      t.boolean     :private  # TODO: add support for private comments.
      t.string      :title,   :default => "" 
      t.text        :comment, :default => "" 
      t.timestamps
    end
  end

  def self.down
    drop_table :comments
  end
end
