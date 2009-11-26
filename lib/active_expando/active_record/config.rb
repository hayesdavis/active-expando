module ActiveExpando
  module ActiveRecord

    class Config
      
      attr_accessor :data_store_class, :ar_class
      
      def initialize(ar_class,data_store_class,&block)
        self.ar_class = ar_class
        self.data_store_class = data_store_class
        instance_eval(&block)
      end
      
      def delegate(*args)
        ar_class.attr_expando(*args)
      end
      
      def method_missing(name,*args)
        data_store_class.send(name,*args)
      end
      
    end        
    
  end
end