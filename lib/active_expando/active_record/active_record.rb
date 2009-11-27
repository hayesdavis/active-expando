module ActiveExpando
  module ActiveRecord
    
    def self.included(ar_class)
      ar_class.instance_eval do
        extend ClassMethods
        include InstanceMethods
        before_save :validate_expandos
        after_save :save_expandos
      end
    end    
  
    module ClassMethods
      
      PAGINATION_PROXY_INTERFACE = [
        :total_pages,:per_page,:current_page,:total_entries,:subject
      ]
      
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
          if result.kind_of?(expandos_class)
            ar_res = find(:first,:conditions=>{self.primary_key=>result.ar_id})
            ar_res.send(:expandos=,result)
            ar_res
          elsif paginated?(result)
            result.subject = expandos_to_active_records(result.subject)
            result
          elsif enumerable_of_expando_stores?(result)
            expandos_to_active_records(result)
          else
            result
          end
        end
        
        def enumerable_of_expando_stores?(result)
          return false unless result.kind_of?(Enumerable)
          #Use any? because it's reasonable to assume that if 1 is, they all are
          result.any?{|item| item.kind_of?(expandos_class)}
        end
      
        def expandos_to_active_records(exps)
          by_id_map = exps.inject({}) {|h,k| h[k.ar_id] = k; h }
          ids = exps.map {|r| r.ar_id }
          find(:all,:conditions=>{self.primary_key=>ids}).each do |t|
            t.send(:expandos=,by_id_map[t.id])
          end
        end
      
        # Nasty hack to check for whether the result is a 
        # MongoMapper::Pagination::PaginationProxy. Since that class implements 
        # method_missing that delegates just about everything to the 
        # underlying Array, I can't do a class or kind_of? test and respond_to?
        # doesn't work. So instead, I just check to see if I can call some of 
        # the methods on the PaginationProxy. If so, I assume it's a paginated 
        # result.
        def paginated?(result)
          PAGINATION_PROXY_INTERFACE.each do |meth|
            result.send(meth)
          end
          true
        rescue NoMethodError
          false
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