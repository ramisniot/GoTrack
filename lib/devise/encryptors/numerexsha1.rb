#require "digest/sha1"
#
#module Devise
#  module Encryptors
#    # = NumerexSha1
#    # An encryption method compatible with numerex's old password scheme
#    class Numerexsha1 < Base
#
#      # Gererates a default password digest based on salt and
#      # incoming password.
#      def self.digest(password, stretches, salt, pepper)
#        Digest::SHA1.hexdigest("--#{salt}--#{password}--")
#      end
#    end
#  end
#end
