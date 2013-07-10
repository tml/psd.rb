class PSD
  class Descriptor
    attr_reader :klass, :items

    def initialize(file)
      @file = file
      @data = {}
    end

    def parse
      @data[:class] = parse_class

      num_items = @file.read_int
      num_items.times do |i|
        id, value = parse_key_item
        @data[id] = value
      end

      @data
    end

    private

    def parse_class
      {
        name: @file.read_unicode_string,
        id: parse_id
      }
    end

    def parse_id
      len = @file.read_int
      len == 0 ? @file.read_int : @file.read_string(len)
    end

    def parse_key_item
      id = parse_id
      value = parse_item(id)

      return id, value
    end

    def parse_item(id, type = nil)
      type = @file.read_string(4) if type.nil?

      value = case type
      when 'bool'         then parse_boolean
      when 'type', 'GlbC' then parse_class
      when 'Objc', 'GlbO' then parse
      when 'doub'         then parse_double
      when 'enum'         then parse_enum
      when 'alis'         then parse_alias
      when 'Pth'          then parse_file_path
      when 'long'         then parse_integer
      when 'comp'         then parse_large_integer
      when 'VlLs'         then parse_list
      when 'ObAr'         then parse_object_array
      when 'tdta'         then parse_raw_data
      when 'obj '         then parse_reference
      when 'TEXT'         then @file.read_unicode_string
      when 'UntF'         then parse_unit_double
      end

      return value
    end

    def parse_boolean;  @file.read_boolean; end
    def parse_double;   @file.read_double; end
    def parse_integer;  @file.read_int; end
    def parse_large_integer; @file.read_longlong; end
    def parse_identifier; @file.read_int; end
    def parse_index; @file.read_int; end
    def parse_offset; @file.read_int; end
    def parse_property; parse_id; end

    # Discard the first ID becasue it's the same as the key
    # parsed from the Key/Item. Also, YOLO.
    def parse_enum
      parse_id
      parse_id
    end

    def parse_alias
      len = @file.read_int
      @file.read_string len
    end

    def parse_file_path
      len = @file.read_int

      # Little-endian, because fuck the world.
      sig = @file.read_string(4)
      path_size = @file.read('l<')
      num_chars = @file.read('l<')

      path = @file.read_unicode_string(num_chars)

      {sig: sig, path: path}
    end

    def parse_list
      count = @file.read_int
      items = []

      count.times do |i|
        items << parse_item
      end

      return items
    end

    def parse_object_array
      count = @file.read_int
      klass = parse_class
      items_in_obj = @file.read_int

      obj = []
      count.times do |i|
        item = []
        items_in_obj.times do |j|
          item << parse_object_array
        end

        obj << item
      end

      return obj
    end

    def parse_raw_data
      len = @file.read_int
      @file.read(len)
    end

    def parse_reference
      form = @file.read_string(4)
      klass = parse_class

      case form
      when 'Clss' then nil
      when 'Enmr' then parse_enum
      when 'Idnt' then parse_identifier
      when 'indx' then parse_index
      when 'name' then @file.read_unicode_string
      when 'rele' then parse_offset
      when 'prop' then parse_property
      end
    end

    def parse_unit_double
      unit_id = @file.read_string(4)
      unit = case unit_id
      when '#Ang' then 'Angle'
      when '#Rsl' then 'Density'
      when '#Rlt' then 'Distance'
      when '#Nne' then 'None'
      when '#Prc' then 'Percent'
      when '#Pxl' then 'Pixels'
      when '#Mlm' then 'Millimeters'
      when '#Pnt' then 'Points'
      end

      value = @file.read_double
      {id: unit_id, unit: unit, value: value}
    end
  end
end