require 'openssl'
require 'digest/sha1'
require 'base64'

# shadow pw from host
shadow = ARGV.shift
# in s3://chef-secrets-remedy/
opsworks_users = ARGV.shift || ENV['HOME'] + '/.chef/opsworks_users'
# In OpsWork pick a "Stack" to to "setttings"
iv = ARGV.shift || ENV['HOME'] + '/.chef/iv'

if shadow.nil? && !File.file?(opsworks_users) && !File.file?(iv)
  puts "Somethings wrong at minimal pass a shadow"
  puts "  Usage: "
  puts "    #{$0} <shadow> <optional opsworks_users> <optional iv> "
  exit;
end

cipher = OpenSSL::Cipher::Cipher.new("aes-256-cbc")
cipher.encrypt

key = Digest::SHA1.hexdigest(IO.read("#{opsworks_users}"))
iv = Base64.decode64(IO.read("#{iv}"))

cipher.key = key
cipher.iv = iv

encrypted =
cipher.update("#{shadow}")
encrypted << cipher.final
encrypted_64 = Base64.encode64(encrypted)

puts encrypted_64

