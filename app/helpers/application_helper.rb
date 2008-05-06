# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  def path?(path)
    controller_path[0..path.length-1] == path
  end

  def use_login_form?
    @use_login_form ||= !cookies['use_svn'].blank? && cookies['use_svn'].to_s == '1'
  end
  
  def nb_pad(s, num)
    s.to_s.ljust(num).gsub(' ', '&nbsp;')
  end
  
  def title(ttl)
    @title = ttl || ' '
  end
  
  def submit_image(img, options = {})
    tag('input', { :type => 'image', :class => 'submit', :src => "/images/app/btns/#{img}" }.merge(options))
  end
  
  def cancel_image(options = {})
    image_tag('/images/app/btns/cancel.png', {:class => 'imgbtn cancelbtn'}.merge(options))
  end
  
  @@selected_attribute = %( class="selected").freeze
  def class_for(options)
    @@selected_attribute if current_page?(options)
  end
  
  def selected_navigation?(navigation)
    @@selected_attribute if current_navigation?(navigation)
  end
  
  def current_navigation?(navigation)
    @current_navigation ||= \
      case controller.controller_name
        when /browser|history/ then :browser
        when /change/          then :activity
        else                        :admin
      end
    @current_navigation == navigation
  end
  
  def avatar_for(user)
    img = user && user.avatar? ? user.avatar_path : '/images/app/icons/member.png'
    tag('img', :src => img, :class => 'avatar', :alt => 'avatar')
  end

  @@default_jstime_format = "%d %b, %Y %I:%M %p"
  def jstime(time, format = nil)
    content_tag 'span', time.strftime(format || @@default_jstime_format), :class => 'time'
  end

  # simple wrapper around #cache that checks the current_cache hash 
  # for cached data before reading the fragment.  See #current_cache
  # and #cached_in? in ApplicationController
  def cache_or_show(name, use_cache = true, &block)
    if name.nil? || !use_cache
      block.call
    elsif current_cache[name]
      concat current_cache[name], block.binding
    else
      cache(name, &block)
    end
  end
  
  def link_to_tab(name, url = {}, options = {})
    link_to name, url, options
  end
end
