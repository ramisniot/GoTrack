module EnumFactory

  def self.factory(enum_name, value_attr, label_attr, value_hash)
    enum_item_struct = create_struct enum_name, value_attr, label_attr

    enum_module = Module.new
    all_items = []

    value_hash.each do |label, value|
      enum_module.const_set label, value
      all_items << enum_item_struct[label, value]
    end

    enum_module.class_eval do

      instance_variable_set :@all_items, all_items

      def self.all
        @all_items
      end

      def self.get id
        @all_items.find {|item| item.id == id}
      end
    end

    enum_module
  end

  def self.create_struct(struct_name, label_attr, value_attr)
    return Struct.const_get struct_name if Struct.const_defined? struct_name

    Struct.new struct_name, label_attr.to_sym, value_attr.to_sym
  end

end
