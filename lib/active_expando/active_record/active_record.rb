module ActiveExpando
  module ActiveRecord
    
    def self.included(tweet_class)
      tweet_class.instance_eval do
        extend ClassMethods
        include InstanceMethods
        before_save :validate_expandos
        after_save :save_expandos
      end
    end    
  
    module ClassMethods
      
      def expando_config(&block)
        Config.new(self,expandos_class,&block)
      end
      
      def attr_expando(*args)
        args.each do |arg|
          delegate arg.to_sym, "#{arg}=".to_sym, :to=>:expandos
        end        
      end
      
      def method_missing(name,*args)
        if name.to_s =~ /expando_(.+)/
          result = expandos_class.send($1.to_sym,*args)
          result ? convert_result(result) : nil
        else
          super(name,*args)
        end
      end
      
      def expandos_class
        @expandos_class ||= ExpandoStore.new_class(self)
      end
      
      private
        def convert_result(result)
          if result.kind_of?(ExpandoStore::Base)
            obj = find_by_id(result.ar_id)
            obj.send(:expandos=,result)
            obj
          elsif enumerable_of_expando_stores?(result)
            by_id_map = result.inject({}) {|h,k| h[k.ar_id] = k; h }
            ids = result.map {|r| r.ar_id }
            find(:all,:conditions=>{self.primary_key=>ids}).each do |t|
              t.send(:expandos=,by_id_map[t.id])
            end
          else
            result
          end
        end
        
        def enumerable_of_expando_stores?(result)
          return false unless result.kind_of?(Enumerable)
          #Use any? because it's reasonable to assume that if 1 is, they all are
          result.any?{|item| item.kind_of?(ExpandoStore::Base)}
        end
  
    end # End ClassMethods
    
    module InstanceMethods
      
      def expandos
        @expandos ||= new_expandos_instance
      end
      
      private
        def new_expandos_instance
          self.class.expandos_class.new_for_active_record(self)
        end
        
        def validate_expandos
          return unless defined?(@expandos)
          unless @expandos.valid?
            @expandos.errors.each do |attr, msgs|
              Array(msgs).each do |msg|
                self.errors.add(attr,msg)
              end
            end
            return false
          end
        end
        
        def save_expandos
          @expandos.save if defined?(@expandos)
        end
        
        def expandos=(expandos_store)
          @expandos = expandos_store
        end        
      end
    end # End InstanceMethods

end