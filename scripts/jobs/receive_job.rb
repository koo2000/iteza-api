require 'tempfile'
require 'rest-client'
require 'json'

require File.expand_path(File.dirname(__FILE__) + '/../modules/send_mail')

class ReceiveJob
  include SendMail

  TMP_DIR = "tmp"
  TMP_FILE_PREFIX = "checky_"
  TMP_FILE_EXTENSION = ".jpg"

  SCRIPT_PATH = "scripts/dummy_facevalue.sh"

  API_URL = "http://www.fiftyriver.net:3000/api/check/receive"

  def receive(message, params)
    if message.multipart? && message.has_attachments?
      message.attachments.each do |a|
        puts "添付ファイル？ #{a.mime_type}"
        if ["image/jpeg"].include? a.mime_type
          f = Tempfile.new([TMP_FILE_PREFIX, TMP_FILE_EXTENSION], TMP_DIR)
          f.write a.body.decoded

          puts "添付ファイルみっけ。 #{a.filename} -> #{f.path}"

          r = `#{SCRIPT_PATH} #{File.absolute_path f}`
          puts r

          if ($? == 0 && r.lines.size == 2)
            face_value = r.lines[0].match(/[0-9,]+/)[0].gsub(/(\d{0,3}),(\d{3})/, '\1\2').to_i
            id = r.lines[1].delete("idText:")
            receiver = message.from_addrs[0]

            begin
              response = RestClient.post API_URL,
                { id: id, receiver: receiver }.to_json,
                content_type: :json,
                accept: :json

                puts JSON.parse(response)

                send_receive_success(receiver)
            rescue => e
              puts e.message
            end
          end
        end
      end
    end
  end
end