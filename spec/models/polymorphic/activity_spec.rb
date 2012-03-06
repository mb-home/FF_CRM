# == Schema Information
#
# Table name: activities
#
#  id           :integer         not null, primary key
#  user_id      :integer
#  subject_id   :integer
#  subject_type :string(255)
#  action       :string(32)      default("created")
#  info         :string(255)     default("")
#  private      :boolean         default(FALSE)
#  created_at   :datetime
#  updated_at   :datetime
#

require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe Activity do

  before { login }

  it "should create a new instance given valid attributes" do
    Activity.create!(:user => FactoryGirl.create(:user), :subject => FactoryGirl.create(:lead))
  end

  describe "with multiple activity records" do
    before do
      @user = FactoryGirl.create(:user)
      @actions = %w(created deleted updated viewed).freeze
      @actions.each_with_index do |action, index|
        FactoryGirl.create(:activity, :action => action, :user => @user, :subject => FactoryGirl.create(:lead))
        FactoryGirl.create(:activity, :action => action, :subject => FactoryGirl.create(:lead)) # different user
      end
    end

    it "should select all activities except one" do
      @activities = Activity.for(@user).without_actions(:viewed)
      @activities.map(&:action).sort.should == %w(created deleted updated)
    end

    it "should select all activities except many" do
      @activities = Activity.for(@user).without_actions(:created, :updated, :deleted)
      @activities.map(&:action).should == %w(viewed)
    end

    it "should select one requested activity" do
      @activities = Activity.for(@user).with_actions(:deleted)
      @activities.map(&:action).should == %w(deleted)
    end

    it "should select many requested activities" do
      @activities = Activity.for(@user).with_actions(:created, :updated)
      @activities.map(&:action).sort.should == %w(created updated)
    end

    it "should select activities for given user" do
      @activities = Activity.for(@user)
      @activities.map(&:action).sort.should == @actions
    end
  end

  %w(account campaign contact lead opportunity task).each do |subject|
    describe "Create, update, and delete (#{subject})" do
      before :each do
        @subject = FactoryGirl.create(subject.to_sym, :user => @current_user)
        @conditions = [ 'user_id = ? AND subject_id = ? AND subject_type = ? AND action = ?', @current_user.id, @subject.id, @subject.class.name ]
      end

      it "should add an activity when creating new #{subject}" do
        @activity = Activity.where(@conditions << 'created').first
        @activity.should_not == nil
        @activity.info.should == (@subject.respond_to?(:full_name) ? @subject.full_name : @subject.name)
      end

      it "should add an activity when updating existing #{subject}" do
        if @subject.respond_to?(:full_name)
          @subject.update_attributes(:first_name => "Billy", :last_name => "Bones")
        else
          @subject.update_attributes(:name => "Billy Bones")
        end
        @activity = Activity.where(@conditions << 'updated').first

        @activity.should_not == nil
        @activity.info.ends_with?("Billy Bones").should == true
      end

      it "should add an activity when deleting #{subject}" do
        @subject.destroy
        @activity = Activity.where(@conditions << 'deleted').first

        @activity.should_not == nil
        @activity.info.should == (@subject.respond_to?(:full_name) ? @subject.full_name : @subject.name)
      end

      it "should add an activity when commenting on a #{subject}" do
        @comment = FactoryGirl.create(:comment, :commentable => @subject, :user => @current_user)

        @activity = Activity.where(@conditions << 'commented').first
        @activity.should_not == nil
        @activity.info.should == (@subject.respond_to?(:full_name) ? @subject.full_name : @subject.name)
      end
    end
  end

  %w(account campaign contact lead opportunity).each do |subject|
    describe "Recently viewed items (#{subject})" do
      before do
        @subject = FactoryGirl.create(subject.to_sym, :user => @current_user)
        @conditions = [ "user_id = ? AND subject_id = ? AND subject_type = ? AND action = 'viewed'", @current_user.id, @subject.id, @subject.class.name ]
      end

      it "creating a new #{subject} should also make it a recently viewed item" do
        @activity = Activity.where(@conditions).first

        @activity.should_not == nil
      end

      it "updating #{subject} should also mark it as recently viewed" do
        @before = Activity.where(@conditions).first
        if @subject.respond_to?(:full_name)
          @subject.update_attributes(:first_name => "Billy", :last_name => "Bones")
        else
          @subject.update_attributes(:name => "Billy Bones")
        end
        @after = Activity.where(@conditions).first

        @before.should_not == nil
        @after.should_not == nil
        @after.updated_at.should >= @before.updated_at
      end

      it "deleting #{subject} should remove it from recently viewed items" do
        @subject.destroy
        @activity = Activity.where(@conditions).first

        @activity.should be_nil
      end

      it "deleting #{subject} should remove it from recently viewed items for all other users" do
        @somebody = FactoryGirl.create(:user)
        @subject = FactoryGirl.create(subject.to_sym, :user => @somebody,  :access => "Public")
        FactoryGirl.create(:activity, :user => @somebody, :subject => @subject, :action => "viewed")

        @activity = Activity.where("user_id = ? AND subject_id = ? AND subject_type = ? AND action = 'viewed'", @somebody.id, @subject.id, @subject.class.name).first
        @activity.should_not == nil

        # Now @current_user destroys somebody's object: somebody should no longer have it :viewed.
        @subject.destroy
        @activity = Activity.where("user_id = ? AND subject_id = ? AND subject_type = ? AND action = 'viewed'", @somebody.id, @subject.id, @subject.class.name).first
        @activity.should be_nil
      end
    end
  end

  describe "Recently viewed items (task)" do
    before do
      @task = FactoryGirl.create(:task)
      @conditions = [ "subject_id = ? AND subject_type = 'Task'", @task.id ]
    end

    it "creating a new task should not add it to recently viewed items list" do
      @activities = Activity.where(@conditions)

      @activities.map(&:action).should == %w(created) # but not viewed
    end

    it "updating a new task should not add it to recently viewed items list" do
      @task.update_attribute(:updated_at, 1.second.ago)
      @activities = Activity.where(@conditions)

      @activities.map(&:action).sort.should == %w(created updated) # but not viewed
    end
  end

  describe "Action refinements for task updates" do
    before do
      @task = FactoryGirl.create(:task, :user => @current_user)
      @conditions = [ "subject_id=? AND subject_type='Task' AND user_id=?", @task.id, @current_user ]
    end

    it "should create 'completed' task action" do
      @task.update_attribute(:completed_at, 1.second.ago)
      @activities = Activity.where(@conditions)

      @activities.map(&:action).sort.should == %w(completed created)
    end

    it "should create 'reassigned' task action" do
      @task.update_attribute(:assigned_to, @current_user.id + 1)
      @activities = Activity.where(@conditions)

      @activities.map(&:action).sort.should == %w(created reassigned)
    end

    it "should create 'rescheduled' task action" do
      @task.update_attribute(:bucket, "due_tomorrow") # FactoryGirl creates :due_asap task
      @activities = Activity.where(@conditions)

      @activities.map(&:action).sort.should == %w(created rescheduled)
    end
  end

  describe "Rejecting a lead" do
    before do
      @lead = FactoryGirl.create(:lead, :user => @current_user, :status => "new")
      @conditions = [ "subject_id = ? AND subject_type = 'Lead' AND user_id = ?", @lead.id, @current_user ]
    end

    it "should create 'rejected' lead action" do
      @lead.update_attribute(:status, "rejected")
      @activities = Activity.where(@conditions)

      @activities.map(&:action).sort.should == %w(created rejected viewed)
    end

    it "should not mark it as recently viewed" do
      Activity.delete_all                                   # delete :created and :viewed
      @lead.update_attribute(:status, "rejected")
      @activities = Activity.where(@conditions)

      @activities.map(&:action).sort.should == %w(rejected) # no :viewed, only :rejected
    end
  end

  describe "Permissions" do
    it "should not show the created/updated activities if the subject is private" do
      @subject = FactoryGirl.create(:account, :user => FactoryGirl.create(:user), :access => "Private")
      @subject.update_attribute(:updated_at,  1.second.ago)

      @activities = Activity.where('subject_id = ? AND subject_type = ?', @subject.id, @subject.class.name)
      @activities.map(&:action).sort.should == %w(created updated viewed)
      @activities = Activity.latest({}).visible_to(@current_user)
      @activities.should == []
    end

    it "should not show the deleted activity if the subject is private" do
      @subject = FactoryGirl.create(:account, :user => FactoryGirl.create(:user), :access => "Private")
      @subject.destroy

      @activities = Activity.where('subject_id = ? AND subject_type = ?', @subject.id, @subject.class.name)
      @activities.map(&:action).sort.should == %w(created deleted)
      @activities = Activity.latest({}).visible_to(@current_user)
      @activities.should == []
    end

    it "should not show created/updated activities if the subject was not shared with the user" do
      @user = FactoryGirl.create(:user)
      @subject = FactoryGirl.create(:account,
        :user => @user,
        :access => "Shared",
        :permissions => [ FactoryGirl.build(:permission, :user => @user, :asset => @subject) ]
      )
      @subject.update_attribute(:updated_at, 1.second.ago)

      @activities = Activity.where('subject_id = ? AND subject_type = ?', @subject.id, @subject.class.name)
      @activities.map(&:action).sort.should == %w(created updated viewed)
      @activities = Activity.latest({}).visible_to(@current_user)
      @activities.should == []
    end

    it "should not show the deleted activity if the subject was not shared with the user" do
      @user = FactoryGirl.create(:user)
      @subject = FactoryGirl.create(:account,
        :user => @user,
        :access => "Shared",
        :permissions => [ FactoryGirl.build(:permission, :user => @user, :asset => @subject) ]
      )
      @subject.destroy

      @activities = Activity.where('subject_id = ? AND subject_type = ?', @subject.id, @subject.class.name)
      @activities.map(&:action).sort.should == %w(created deleted)
      @activities = Activity.latest({}).visible_to(@current_user)
      @activities.should == []
    end

    it "should show created/updated activities if the subject was shared with the user" do
      @subject = FactoryGirl.create(:account,
        :user => FactoryGirl.create(:user),
        :access => "Shared",
        :permissions => [ FactoryGirl.build(:permission, :user => @current_user, :asset => @subject) ]
      )
      @subject.update_attribute(:updated_at, 1.second.ago)

      @activities = Activity.where('subject_id = ? AND subject_type = ?', @subject.id, @subject.class.name)
      @activities.map(&:action).sort.should == %w(created updated viewed)

      @activities = Activity.latest({}).visible_to(@current_user)
      @activities.map(&:action).sort.should == %w(created updated viewed)
    end
  end

  describe "Exportable" do
    before do
      Activity.delete_all
      FactoryGirl.create(:activity, :user => FactoryGirl.create(:user), :subject => FactoryGirl.create(:account))
      FactoryGirl.create(:activity, :user => FactoryGirl.create(:user, :first_name => nil, :last_name => nil), :subject => FactoryGirl.create(:account))
      Activity.delete_all("action IS NOT NULL") # Delete created and views actions that are created implicitly.
    end
    it_should_behave_like("exportable") do
      let(:exported) { Activity.all }
    end
  end
end
