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
      key :ar_id, Integer
      
      class << self
        def new_for_active_record(ar_obj)
          if ar_obj.new_record?
            ds = new
          else
            id = ar_obj[ar_obj.class.primary_key]
            ds = find(:first,:ar_id=>id) || new(:ar_id=>id)
          end
          ds
        end
        
        def attr_alias(aliases)
          attr_aliases.merge!(aliases.symbolize_keys)
          attributes_to_aliases!
        end
        
        def attr_aliases
          aliases_to_attributes
        end
        
        def aliases_to_attributes
          @aliases_to_attributes ||= {}
        end
        
        def attributes_to_aliases!
          @attributes_to_aliases = aliases_to_attributes.invert.symbolize_keys!
        end
        
        def attributes_to_aliases
          unless defined?(@attributes_to_aliases)
            attributes_to_aliases!
          end
          @attributes_to_aliases
        end
        
        def aliased_attribute(key)
          attributes_to_aliases.fetch(key.to_sym,key).to_s
        end
        
      end
      
      def changed_with_aliases
        changed.map do |attr|
          self.class.aliased_attribute(attr)
        end
      end
      
      def changes_with_aliases
        changes.inject({}) do |h,(attr,changes)|
          h[self.class.aliased_attribute(attr)] = changes
          h
        end
      end
      
      def method_missing(name,*args)
        name = name.to_s
        self.class.attr_aliases.each do |pub,attr|
          if name.gsub!(/^#{pub}/,attr.to_s)
            return send(name,*args)
          end
        end
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