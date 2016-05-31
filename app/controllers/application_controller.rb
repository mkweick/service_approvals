class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  def escape_apostrophes(string)
    string.chars.map { |char| char == "\'" ? "\'\'" : char }.join('')
  end
end
