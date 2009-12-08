module ActiveExpando
  module ExpandoStore
    
    class << self

      def new_class(ar_class)
        Class.new(Base).instance_eval do
          set_collection_name(ar_class.table_name)
          self
        end
      end
      
    end
    
    class Base
      
      include MongoMapper::Document
      include ExpandoStore::Aliasing
      
      key :_id, Integer
      
      class << self
        def new_for_active_record(ar_obj)
          if ar_obj.new_record?
            ds = new
          else
            id = ar_obj[ar_obj.class.primary_key]
            ds = find(:first,:_id=>id) || new(:_id=>id)
          end
          ds
        end
      end
      
      def method_missing(name,*args)
        begin
          super
        rescue NoMethodError
          if name.to_s =~ /(.*)=$/
            self[$1] = *args
          elsif args.length == 0
            begin
              self[name]
            rescue
              self[name] = nil
              self[name]
            end
          end
        end
      end      
    end

  end
end