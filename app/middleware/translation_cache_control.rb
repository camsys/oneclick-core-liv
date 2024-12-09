class TranslationCacheControl
  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, response = @app.call(env)

    if env['PATH_INFO'].start_with?('/admin/simple_translation_engine/translations')
      headers['Cache-Control'] = 'no-cache, no-store, must-revalidate'
      headers['Pragma'] = 'no-cache'
      headers['Expires'] = '0'
    end

    [status, headers, response]
  end
end
