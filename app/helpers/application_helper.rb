module ApplicationHelper

	def active_class?(*paths)
    active = false
    paths.each { |path| active ||= current_page?(path) }
    active ? 'active' : nil
  end

  def render_markdown(text)
    options = {
      filter_html:     true,
      hard_wrap:       true, 
      space_after_headers: true, 
      fenced_code_blocks: true
    }

    extensions = {
      autolink:           true,
      superscript:        true,
      disable_indented_code_blocks: true
    }

    renderer = Redcarpet::Render::HTML.new(options)
    markdown = Redcarpet::Markdown.new(renderer, extensions)

    markdown.render(text).html_safe

  end

  def user_display_name(user)
    user&.fullname || "Gelöschter Benutzer"
  end

end
