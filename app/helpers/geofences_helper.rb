module GeofencesHelper
  def text_field_tag_with_hint(name, hint, options = {})
    options[:onfocus] = "if(this.value=='#{hint}'){this.value=''; this.style.color='black'}"
    options[:onblur] = "if(this.value==''){this.value='#{hint}'; this.style.color='gray'}"

    default = nil

    if options[:value].blank?
      default = hint
      options[:style] = "#{options[:style]}; color: gray;"
    else
      default = options[:value]
      options[:style] = "#{options[:style]}; color: black;"
    end
    options.delete(:value)

    text_field_tag(name, default, options)
  end
end
