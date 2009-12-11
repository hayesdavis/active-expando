module ActiveExpando
  module ActiveRecord
    
    def self.included(ar_class)
      ar_class.instance_eval do
        extend ClassMethods
        include InstanceMethods
        before_save :validate_expandos
        after_save :save_expandos
        after_destroy :destroy_expandos
      end
    end
  
    module ClassMethods
      
      PAGINATION_PROXY_INTERFACE = [
        :total_pages,:per_page,:current_page,:total_entries,:subject
      ]
      
      DIRTY_SUFFIXES = defined?(ActiveRecord::Dirty::DIRTY_SUFFIXES) ?
        ActiveRecord::Dirty::DIRTY_SUFFIXES :
        ['_changed?', '_change', '_will_change!', '_was']
      
      def expando_config(&block)
        Config.new(self,expandos_class,&block)
      end
      
      def attr_expando(*args)
        mappings = args.extract_options!
        args.each {|arg| mappings[arg] = arg}
        mappings.each do |intf_name,dest_name|
          define_method intf_name do
            expandos.send(dest_name)
          end
          define_method "#{intf_name}=" do |*method_args|
            expandos.send("#{dest_name}=",*method_args)
          end
          define_method "#{intf_name}?" do
            !expandos.send(dest_name).nil?
          end
          DIRTY_SUFFIXES.each do |suffix|
            define_method "#{intf_name}#{suffix}" do
              expandos.send("#{dest_name}#{suffix}")
            end
          end
        end
      end
      
      def method_missing(name,*args)
        if name.to_s =~ /expando_(.+)/
          ar_options = extract_ar_options!(args)
          result = expandos_class.send($1.to_sym,*args)
          result ? convert_result(result,ar_options) : nil
        else
          super(name,*args)
        end
      end
      
      def expandos_class
        @expandos_class ||= ExpandoStore.new_class(self)
      end
      
      private
        def convert_result(result,ar_options={})
          if result.kind_of?(expandos_class)
            expando_to_active_record(result,ar_options)
          elsif paginated?(result)
            result.subject = expandos_to_active_records(result.subject,ar_options)
            result
          elsif enumerable_of_expando_stores?(result)
            expandos_to_active_records(result,ar_options)
          else
            result
          end
        end
        
        def enumerable_of_expando_stores?(result)
          return false unless result.kind_of?(Enumerable)
          #Use any? because it's reasonable to assume that if 1 is, they all are
          result.any?{|item| item.kind_of?(expandos_class)}
        end
        
        def expando_to_active_record(result,ar_options={})
          ar_options = merge_active_record_options({
            :conditions=>{self.primary_key=>result.id}
          },ar_options)
          ar_res = find(:first,ar_options)
          if ar_res
            ar_res.send(:expandos=,result)
          end
          ar_res          
        end
      
        def expandos_to_active_records(exps,ar_options={})
          by_id_map = exps.inject({}) {|h,k| h[k.id] = k; h }
          ids = exps.map {|r| r.id }
          ar_options = merge_active_record_options({
            :conditions=>{self.primary_key=>ids}
          },ar_options)
          find(:all,ar_options).each do |t|
            t.send(:expandos=,by_id_map[t.id])
          end
        end
        
        def merge_active_record_options(ar1,ar2)
          merged = ar1.dup
          ar2.each do |k,v|
            v1 = merged[k]
            if v1.kind_of?(Hash) && v.kind_of?(Hash)
              merged[k] = merge_active_record_options(v1,v)
            else
              merged[k] = v
            end
          end
          merged
        end
        
        def extract_ar_options!(args)
          ar_options = args.last.kind_of?(Hash) ? 
            args.last.delete(:ar_options) : nil
          ar_options || {}
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
      
      def expandos_loaded?
        !@expandos.nil?
      end
      
      def changed
        res = super
        # Check that the expandos are loaded so we don't call the document 
        # store if we don't need to
        if expandos_loaded? 
          res += expandos.changed_with_aliases
        end
        res
      end
      
      def changed?
        # Check that the expandos are loaded so we don't call the document 
        # store if we don't need to        
        super || (expandos_loaded? && expandos.changed?)
      end
      
      def changes
        # Check that the expandos are loaded so we don't call the document 
        # store if we don't need to        
        res = super
        if expandos_loaded?
          res = res.merge(expandos.changes_with_aliases)
        end
        res
      end
      
      private
        def new_expandos_instance
          self.class.expandos_class.new_for_active_record(self)
        end
        
        def validate_expandos
          return true unless should_validate_expandos?
          unless expandos.valid?
            expandos.errors_with_aliases.each do |attr, msgs|
              Array(msgs).each do |msg|
                self.errors.add(attr,msg)
              end
            end
            return false
          end
        end
        
        def should_validate_expandos?
          if self.class.expandos_class.validations.empty?
            # Don't bother validating if there's no validations to be done
            false
          else
            # Always validate a new record but only validate expandos if 
            # for an existing record if they've been loaded up and potentially 
            # changed
            new_record? || expandos_loaded?
          end
        end
        
        def save_expandos
          return unless expandos_loaded?
          if @expandos.id.nil?
            @expandos.id = self[self.class.primary_key]
          end
          @expandos.save
        end

        def destroy_expandos
          expandos.destroy unless expandos.new_record?
        end
        
        def expandos=(expandos_store)
          @expandos = expandos_store
        end        
      end
    end # End InstanceMethods

end