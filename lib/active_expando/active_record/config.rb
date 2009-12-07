module ActiveExpando
  module ActiveRecord

    class Config
      
      attr_accessor :expando_store_class, :ar_class
      
      def initialize(ar_class,expando_store_class,&block)
        self.ar_class = ar_class
        self.expando_store_class = expando_store_class
        instance_eval(&block)
      end
      
      def delegate(*args)
        ar_class.attr_expando(*args)
      end
      
      def method_missing(name,*args)
        expando_store_class.send(name,*args)
      end
      
      def key(*args)
        intercept_key_options(*args)
        expando_store_class.key(*args)
      end
      
      private
        def intercept_key_options(*args)
          key_name = args.first
          opts = args.extract_options!
          if opts
            pub_name = opts.delete(:alias)
            del = opts.delete(:delegate)
            if pub_name
              expando_store_class.attr_alias(pub_name=>key_name)
              if del != false
                delegate(pub_name)
              end
            elsif del == true
              delegate(key_name)
            end
            args << opts
          end
        end
      
    end        
    
  end
end