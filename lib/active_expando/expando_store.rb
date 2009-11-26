module ActiveExpando
  module ExpandoStore
    
    class << self

      def new_class(ar_class)
        Class.new(Base).instance_eval do
          include MongoMapper::Document
          set_collection_name(ar_class.table_name)
          attr_accessor :ar_object
          key :ar_id, Integer
          self
        end
      end
      
    end
    
    class Base
      class << self
        def new_for_active_record(ar_obj)
          if ar_obj.new_record?
            ds = new
          else
            id = ar_obj[ar_obj.class.primary_key]
            ds = find(:first,:ar_id=>id) || new(:ar_id=>id)
          end
          ds.ar_object = ds
        end
      end
      
      def method_missing(name,*args)
        if name.to_s =~ /(.*)=$/
          self[$1] = *args
        elsif args.length == 0
          begin
            self[name]
          rescue
            self[name] = nil
            self[name]
          end
        else
          super(name,*args)
        end
      end      
    end

  end
end