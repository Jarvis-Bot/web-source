require 'webrick'
class WebSource
  def initialize
    @config = YAML.load_file(File.join(__dir__, 'config.yml'))
    @server = WEBrick::HTTPServer.new(options)
    mount_routes
    start
  end

  def options
    opts = {
      :Port         => @config['port'],
      :BindAddress  => @config['host']
    }
    unless Jarvis::JARVIS[:debug]
      opts.merge!({
        :AccessLog  => [],
        :Logger     => WEBrick::Log.new([], WEBrick::Log::WARN)
      })
    end
    opts
  end

  def webconfig_receivers
    config_receivers = {}
    Jarvis::API::Addons.call_receivers_for(:websource).each do |receiver|
      receiver = receiver.values[0]
      name = receiver['specs']['name']
      websource_options = receiver['receiver']['websource']
      config_receivers.store(name, websource_options)
    end
    config_receivers
  end

  def mount_routes
    webconfig_receivers.each do |name, options|
      route = format_route(options['route'])
      @server.mount_proc route do |req, res|
        infos_source = { source: 'WebSource', sub_source: name }
        Jarvis::Messages::Message.new(infos_source, "#{req.request_method} request received on #{route} from #{name.capitalize}", req)
        req.body
        res['Content-Type'] = req.content_type
        res.body = req.body
      end
    end
  end

  def format_route(route)
    prefix = "/#{@config['prefix'].chomp('/').reverse.chomp('/').reverse}/"
    route = "#{route.chomp('/').reverse.chomp('/').reverse}/"
    "#{prefix}#{route}"
  end

  def start
    @server.start
  end
end
