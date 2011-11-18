module Resque
  module ModelMailer
    class << self      
      def included(base)
        base.send(:include, Resque::Mailer)
        base.extend(ModelClassMethods)
      end
    end

    module ModelClassMethods
      def method_missing(method_name, *args)
        return super if environment_excluded?
      
        if action_methods.include?(method_name.to_s)
          ModelMessageDecoy.new(self, method_name, *args)
        else
          super
        end
      end

      def perform(action, class_name, id)
        record = class_name.constantize.find(id)
        self.send(:new, action, record).message.deliver
      end
    end

    class ModelMessageDecoy < Mailer::MessageDecoy
      def deliver
        if @mailer_class.deliver?
          record = @args.first
          resque.enqueue @mailer_class, @method_name, record.class.name, record.id
        end
      end
    end
  end
end
