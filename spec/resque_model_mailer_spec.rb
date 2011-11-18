require File.join(File.expand_path(File.dirname(__FILE__)), 'spec_helper')

class FakeResque
  def self.enqueue(*args); end
end

class FakeModel
  def id; 1; end  
  def self.find(_); new; end
end

class Rails3ModelMailer < ActionMailer::Base
  include Resque::ModelMailer
  
  default :from => "from@example.org", :subject => "Subject"
  MAIL_PARAMS = { :to => "crafty@example.org" }
  
  def test_mail(record)
    Resque::ModelMailer.success!
    mail MAIL_PARAMS
  end
end

describe Resque::ModelMailer do
  let(:resque) { FakeResque }
  let(:fake_model) { FakeModel.new }

  before do
    Resque::Mailer.default_queue_target = resque
    Resque::ModelMailer.stub(:success!)
    Rails3ModelMailer.stub(:current_env => :test)
  end
  
  describe '#deliver' do
    before(:all) do
      @delivery = lambda {
        Rails3ModelMailer.test_mail(fake_model).deliver
      }
    end
    
    it 'should not deliver the email synchronously' do
      lambda { @delivery.call }.should_not change(ActionMailer::Base.deliveries, :size)
    end

    it 'should place the deliver action on the Resque "mailer" queue' do
      resque.should_receive(:enqueue).with(Rails3ModelMailer, :test_mail, "FakeModel", 1)
      @delivery.call
    end
  end
  
  describe '#deliver!' do
    it 'should deliver the email synchronously' do
      lambda { Rails3ModelMailer.test_mail(fake_model).deliver! }.should change(ActionMailer::Base.deliveries, :size).by(1)
    end
  end

  describe 'perform' do
    it 'should perform a queued mailer job' do
      lambda {
        Rails3ModelMailer.perform(:test_mail, "FakeModel", 1)
      }.should change(ActionMailer::Base.deliveries, :size).by(1)
    end
  end

  describe 'original mail methods' do
    it 'should be preserved' do
      Rails3ModelMailer.test_mail(fake_model).subject.should == 'Subject'
      Rails3ModelMailer.test_mail(fake_model).from.should include('from@example.org')
      Rails3ModelMailer.test_mail(fake_model).to.should include('crafty@example.org')
    end
  
    it 'should require execution of the method body prior to queueing' do
      Resque::ModelMailer.should_receive(:success!).once
      Rails3ModelMailer.test_mail(fake_model).subject
    end
  end
end
