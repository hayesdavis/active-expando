module ActiveExpando
  module ExpandoStore    
    module Aliasing
      
      def self.included(clazz)
        clazz.extend(ClassMethods)
      end
      
      module ClassMethods

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
        
        def aliased_attribute?(key)
          attributes_to_aliases.has_key?(key.to_sym)
        end
        
        def attribute_for_alias(al)
          aliases_to_attributes.fetch(al.to_sym,al).to_s
        end
        
        def attribute_alias?(al)
          aliases_to_attributes.has_key?(al.to_sym)
        end
        
        def to_criteria(options={})
          criteria_with_aliases(super)
        end
        
        def to_finder_options(options={})
          criteria, options = super
          [criteria_with_aliases(criteria),options_with_aliases(options)]
        end        
        
        private
          def options_with_aliases(options)
            fields = options[:fields]
            if fields && fields.kind_of?(Array)
              options[:fields] = fields_with_aliases(fields)
            end
            sorts = options[:sort]
            if sorts && sorts.kind_of?(Array)
              options[:sort] = sort_with_aliases(sorts)
            end
            options
          end
          
          def sort_with_aliases(sorts)
            sorts.map do |field,dir|
              [attribute_for_alias(field),dir]
            end
          end
          
          def fields_with_aliases(fields)
            fields.map do |field|
              attribute_for_alias(field)
            end
          end
          
          def criteria_with_aliases(criteria)
            return criteria unless criteria.kind_of?(Hash)
            criteria.each do |key,value|
              value = criteria_with_aliases(value)
              if attribute_alias?(key)
                criteria.delete(key)
                criteria[attribute_for_alias(key)] = value
              end
            end
          end
        
      end #End ClassMethods
      
      #Instance Methods
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
      
      def errors_with_aliases
        err = Validatable::Errors.new
        err.merge!(errors)
        err.errors.each do |key,value|
          if self.class.aliased_attribute?(key)
            err.errors.delete(key)
            err.errors[self.class.aliased_attribute(key)] = value
          end
        end
        err
      end
      
      def method_missing(name,*args)
        name = name.to_s
        self.class.attr_aliases.each do |pub,attr|
          if name.gsub!(/^#{pub}/,attr.to_s)
            return send(name,*args)
          end
        end
        super
      end     
    end
  end
end