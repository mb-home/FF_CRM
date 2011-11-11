# == Schema Information
# Schema version: 23
#
# Table name: CustomFields
#
#  id                   :integer(4)      not null, primary key
#  user_id              :integer(4)
#  field_name,          :string(64)
#  field_type,          :string(32)
#  field_label,         :string(64)
#  table_name,          :string(32)
#  display_sequence,    :integer(4)
#  display_block,       :integer(4)
#  display_width,       :integer(4)
#  max_size,            :integer(4)
#  disabled,            :boolean
#  required,            :boolean
#  created_at           :datetime
#  updated_at           :datetime
#

require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe CustomField do

  it "should add a column to the database" do
    CustomField.connection.should_receive(:add_column).
                with("contacts", "cf_test_field", :string, {})

    c = Factory.create(:custom_field,
                       :as => "string",
                       :name => "cf_test_field",
                       :klass_name => "Contact")
  end

  it "should generate a unique column name for a custom field" do
    c = Factory.build(:custom_field, :label => "Test Field", :klass_name => "Contact")

    # Overwrite :klass_column_names with instance variable accessors
    c.class_eval { attr_accessor :klass_column_names }
    c.klass_column_names = []

    %w(cf_test_field cf_test_field_2 cf_test_field_3).each do |expected|
      c.send(:generate_column_name).should == expected
      c.klass_column_names << expected
    end
  end

  it "should evaluate the safety of database transitions" do
    c = Factory.build(:custom_field, :as => "string")
    c.send(:db_transition_safety, c.as, "email").should == :null
    c.send(:db_transition_safety, c.as, "text").should == :safe
    c.send(:db_transition_safety, c.as, "datetime").should == :unsafe

    c = Factory.build(:custom_field, :as => "datetime")
    c.send(:db_transition_safety, c.as, "date").should == :safe
    c.send(:db_transition_safety, c.as, "url").should == :unsafe
  end

  it "should return a safe list of types for the 'as' select options" do
    {"email"   => %w(string email url tel select radio),
     "integer" => %w(integer float)}.each do |type, expected_arr|
      c = Factory.build(:custom_field, :as => type)
      opts = c.available_as
      expected_arr.each {|t| opts.should include(t) }
    end
  end

  # Find ActiveRecord column by name
  def ar_column(custom_field, column)
    custom_field.klass.columns.detect{|c| c.name == column }
  end

  it "should change a column's type for safe transitions" do
    CustomField.connection.should_receive(:add_column).
                with("contacts", "cf_test_field", :string, {})
    CustomField.connection.should_receive(:change_column).
                with("contacts", "cf_test_field", :text, {})

    c = Factory.create(:custom_field,
                       :label => "Test Field",
                       :name => nil,
                       :as => "email",
                       :klass_name => "Contact")
    c.as = "text"
    c.save
  end

end

