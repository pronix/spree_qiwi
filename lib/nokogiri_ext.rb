Nokogiri::XML::Builder.class_eval do
  class << self
  def new_for_qiwi(id,password,request_type,&block)
    new(:encoding => 'utf-8') do
      request do
        send('protocol-version', "4.0")
        send("request-type",request_type)
        send("terminal-id",id)
        extra password, :name => "password"
        instance_eval(&block)
      end
    end
  end
  end
end

