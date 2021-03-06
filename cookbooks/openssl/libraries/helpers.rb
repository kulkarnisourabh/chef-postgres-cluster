module OpenSSLCookbook
  # Helper functions for the OpenSSL cookbook.
  module Helpers
    def self.included(_base)
      require 'openssl' unless defined?(OpenSSL)
    end

    # determine the key filename from the cert filename
    # @param [String] cert_filename the path to the certfile
    # @return [String] the path to the keyfile
    def get_key_filename(cert_filename)
      cert_file_path, cert_filename = ::File.split(cert_filename)
      cert_filename = ::File.basename(cert_filename, ::File.extname(cert_filename))
      cert_file_path + ::File::SEPARATOR + cert_filename + '.key'
    end

    # is the key length a valid key length
    # @param [Integer] number
    # @return [Boolean] is length valid
    def key_length_valid?(number)
      number >= 1024 && number & (number - 1) == 0
    end

    # validate a dhparam file from path
    # @param [String] dhparam_pem_path the path to the pem file
    # @return [Boolean] is the key valid
    def dhparam_pem_valid?(dhparam_pem_path)
      # Check if the dhparam.pem file exists
      # Verify the dhparam.pem file contains a key
      return false unless ::File.exist?(dhparam_pem_path)
      dhparam = OpenSSL::PKey::DH.new File.read(dhparam_pem_path)
      dhparam.params_ok?
    end

    # given either a key file path or key file content see if it's actually
    # a private key
    # @param [String] key_file the path to the keyfile or the key contents
    # @param [String] key_password optional password to the keyfile
    # @return [Boolean] is the key valid?
    def priv_key_file_valid?(key_file, key_password = nil)
      # if the file exists try to read the content
      # if not assume we were passed the key and set the string to the content
      key_content = ::File.exist?(key_file) ? File.read(key_file) : key_file

      begin
        key = OpenSSL::PKey.read key_content, key_password
      rescue OpenSSL::PKey::PKeyError
        return false
      end
      key.private?
    end

    # generate a dhparam file
    # @param [String] key_length the length of the key
    # @param [Integer] generator the dhparam generator to use
    # @return [OpenSSL::PKey::DH]
    def gen_dhparam(key_length, generator)
      raise ArgumentError, 'Key length must be a power of 2 greater than or equal to 1024' unless key_length_valid?(key_length)
      raise TypeError, 'Generator must be an integer' unless generator.is_a?(Integer)

      OpenSSL::PKey::DH.new(key_length, generator)
    end

    # generate an RSA private key given key length
    # @param [Integer] key_length the key length of the private key
    # @return [OpenSSL::PKey::DH]
    def gen_rsa_priv_key(key_length)
      raise ArgumentError, 'Key length must be a power of 2 greater than or equal to 1024' unless key_length_valid?(key_length)

      OpenSSL::PKey::RSA.new(key_length)
    end

    # generate pem format of the public key given a private key
    # @param [String] priv_key either the contents of the private key or the path to the file
    # @param [String] priv_key_password optional password for the private key
    # @return [String] pem format of the public key
    def gen_rsa_pub_key(priv_key, priv_key_password = nil)
      # if the file exists try to read the content
      # if not assume we were passed the key and set the string to the content
      key_content = ::File.exist?(priv_key) ? File.read(priv_key) : priv_key
      key = OpenSSL::PKey::RSA.new key_content, priv_key_password
      key.public_key.to_pem
    end

    # generate a pem file given a cipher, key, an optional key_password
    # @param [OpenSSL::PKey::RSA] rsa_key the private key object
    # @param [String] key_password the password for the private key
    # @param [String] key_cipher the cipher to use
    # @return [String] pem contents
    def encrypt_rsa_key(rsa_key, key_password, key_cipher)
      raise TypeError, 'rsa_key must be a Ruby OpenSSL::PKey::RSA object' unless rsa_key.is_a?(OpenSSL::PKey::RSA)
      raise TypeError, 'key_password must be a string' unless key_password.is_a?(String)
      raise TypeError, 'key_cipher must be a string' unless key_cipher.is_a?(String)
      raise ArgumentError, 'Specified key_cipher is not available on this system' unless OpenSSL::Cipher.ciphers.include?(key_cipher)

      cipher = OpenSSL::Cipher.new(key_cipher)
      rsa_key.to_pem(cipher, key_password)
    end

    # generate an ec private key given curve type
    # @param [String] curve the kind of curve to use
    # @return [OpenSSL::PKey::DH]
    def gen_ec_priv_key(curve)
      raise TypeError, 'curve must be a string' unless curve.is_a?(String)
      raise ArgumentError, 'Specified curve is not available on this system' unless curve == 'prime256v1' || curve == 'secp384r1' || curve == 'secp521r1'
      OpenSSL::PKey::EC.generate(curve)
    end

    # generate pem format of the public key given a private key
    # @param [String] priv_key either the contents of the private key or the path to the file
    # @param [String] priv_key_password optional password for the private key
    # @return [String] pem format of the public key
    def gen_ec_pub_key(priv_key, priv_key_password = nil)
      # if the file exists try to read the content
      # if not assume we were passed the key and set the string to the content
      key_content = ::File.exist?(priv_key) ? File.read(priv_key) : priv_key
      key = OpenSSL::PKey::EC.new key_content, priv_key_password

      # Get curve type (prime256v1...)
      group = OpenSSL::PKey::EC::Group.new(key.group.curve_name)
      # Get Generator point & public point (priv * generator)
      generator = group.generator
      pub_point = generator.mul(key.private_key)
      key.public_key = pub_point

      # Public Key in pem
      public_key = OpenSSL::PKey::EC.new
      public_key.group = group
      public_key.public_key = pub_point
      public_key.to_pem
    end

    # generate a pem file given a cipher, key, an optional key_password
    # @param [OpenSSL::PKey::EC] ec_key the private key object
    # @param [String] key_password the password for the private key
    # @param [String] key_cipher the cipher to use
    # @return [String] pem contents
    def encrypt_ec_key(ec_key, key_password, key_cipher)
      raise TypeError, 'ec_key must be a Ruby OpenSSL::PKey::EC object' unless ec_key.is_a?(OpenSSL::PKey::EC)
      raise TypeError, 'key_password must be a string' unless key_password.is_a?(String)
      raise TypeError, 'key_cipher must be a string' unless key_cipher.is_a?(String)
      raise ArgumentError, 'Specified key_cipher is not available on this system' unless OpenSSL::Cipher.ciphers.include?(key_cipher)

      cipher = OpenSSL::Cipher.new(key_cipher)
      ec_key.to_pem(cipher, key_password)
    end
  end
end
