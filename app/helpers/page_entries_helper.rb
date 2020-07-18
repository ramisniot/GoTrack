module PageEntriesHelper
  # <%= page_entries @posts, :entry_name => 'item' %>
  #  items 6 - 10 of 26
  def page_entries(collection, options = {})
    entry_name = options[:entry_name] ||
      (collection.empty? ? 'entry' : collection.first.class.name.underscore.sub('_', ' '))
    message = options[:message]
    raw(
      if collection.total_pages < 2
        case collection.size
          when 0
            %{<span class="page-title">#{entry_name.pluralize.capitalize} (0 total) #{message}</span class="page_entries">}.html_safe
          when 1
            %{<span class="page-title">#{entry_name.pluralize.capitalize} (1 total) #{message}</span class="page_entries">}.html_safe
          else
            (%{<span class="page-title">#{entry_name.pluralize.capitalize} (%d&nbsp;-&nbsp;%d of %d) #{message}</span>} % [
              collection.offset + 1,
              collection.offset + collection.length,
              collection.total_entries]).html_safe
        end
      else
        (%{<span class="page-title"> #{entry_name.pluralize.capitalize} (%d&nbsp;-&nbsp;%d of %d) #{message}</span class="page_entries">} % [
          collection.offset + 1,
          collection.offset + collection.length,
          collection.total_entries
        ]).html_safe
      end
    )
  end
end
