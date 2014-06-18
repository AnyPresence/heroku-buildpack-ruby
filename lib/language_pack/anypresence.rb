require 'fileutils'
module LanguagePack
  module Anypresence
    CHAMELEON_S3_BUCKET = 'https://s3.amazonaws.com/chameleon-heroku-assets'

    OCI8_TRIGGER_NAME = '.oracle.ini'
    ORACLE_INSTANT_CLIENT_TGZ_URL = "#{CHAMELEON_S3_BUCKET}/instantclient_11_2_with_libaio_oci8.tar.gz"
    ORACLE_INSTANT_CLIENT_DIR = "#{ARGV[0]}/vendor/instant_client_11_2"
    ORACLE_INSTANT_CLIENT_DIR_FOR_RELEASE = "/app/vendor/instant_client_11_2"

    FREETDS_TRIGGER_NAME = '.freetds.conf'
    FREETDS_TGZ_URL="#{CHAMELEON_S3_BUCKET}/freetds.tar.gz"
    FREETDS_DIR_ABSOLUTE_PATH = "#{ARGV[0]}/vendor/freetds"
    FREETDS_DIR_FOR_RELEASE = "/app/vendor/freetds"

    SAP_HANA_TRIGGER = '.odbc.ini'
    UNIX_ODBC_WITH_HANA_TGZ_URL = "#{CHAMELEON_S3_BUCKET}/unixodbc.tar.gz"
    UNIX_ODBC_DIR_ABSOLUTE_PATH = "#{ARGV[0]}/vendor/unixodbc"
    UNIX_ODBC_DIR_FOR_RELEASE = "/app/vendor/unixodbc"
    
    def merge_native_config_vars(vars={})
      extra_vars = {}
      ld_library_vars = []
      
      if uses_oci8?
        ld_library_vars << ORACLE_INSTANT_CLIENT_DIR
        ld_library_vars << ORACLE_INSTANT_CLIENT_DIR_FOR_RELEASE
        extra_vars["NLS_LANG"] = 'AMERICAN_AMERICA.UTF8'
        `export NLS_LANG='AMERICAN_AMERICA.UTF8'`
        ENV['NLS_LANG'] = 'AMERICAN_AMERICA.UTF8'
      end
      
      if uses_freetds?
        ld_library_vars << "#{FREETDS_DIR_FOR_RELEASE}/lib" 
        extra_vars["FREETDS_DIR"] = FREETDS_DIR_FOR_RELEASE
        `export FREETDS_DIR=#{FREETDS_DIR_FOR_RELEASE}`
      end
      
      if uses_sap_hana?
        ld_library_vars << "#{UNIX_ODBC_DIR_FOR_RELEASE}"
        ld_library_vars << "#{UNIX_ODBC_DIR_FOR_RELEASE}/lib"
      end
      
      unless ld_library_vars.empty?
        new_ld_library_path = ld_library_vars.join(":")
        extra_vars.merge!("LD_LIBRARY_PATH" => new_ld_library_path) 
        `export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:#{new_ld_library_path}`
      end
      
      puts "Merging variables of #{extra_vars.inspect}" unless extra_vars.empty?
      
      vars.merge!(extra_vars) unless extra_vars.empty?
    end
    
    def uses_oci8?
      File.exist?(File.join(Dir.pwd,OCI8_TRIGGER_NAME))
    end

    def install_oci8_binaries
      FileUtils.mkdir_p(ORACLE_INSTANT_CLIENT_DIR) unless Dir.exists?(ORACLE_INSTANT_CLIENT_DIR)

      result = `curl #{ORACLE_INSTANT_CLIENT_TGZ_URL} -s -o - | tar -xz -C #{ORACLE_INSTANT_CLIENT_DIR} -f - `
      if $?.success?
        puts "ORACLE_INSTANT_CLIENT_DIR has"
        puts `ls -alh #{ORACLE_INSTANT_CLIENT_DIR}`
        
        puts "Creating Bundler configuration file for OCI8"
        `bundle config build.ruby-oci8 --with-instant-client=#{ORACLE_INSTANT_CLIENT_DIR} 2&>1`
        raise "Error configuring OCI8! #{$?}" unless $?.success?
      else
        raise "Failed to install OCI8 binaries"
      end
    end

    def install_freetds_binaries
      `mkdir -p #{FREETDS_DIR_FOR_RELEASE}` unless Dir.exists?(FREETDS_DIR_FOR_RELEASE)
      `mkdir -p #{FREETDS_DIR_ABSOLUTE_PATH}` unless Dir.exists?(FREETDS_DIR_ABSOLUTE_PATH)

      result = `curl #{FREETDS_TGZ_URL} -s -o - | tar -xz -C #{FREETDS_DIR_ABSOLUTE_PATH} -f - `
      if $?.success?
        puts "Setting FreeTDS environment variables"
        ENV["FREETDS_DIR"] = "#{FREETDS_DIR_ABSOLUTE_PATH}"  # Required for tiny_tds gem
      else
        raise "Failed to install FreeTDS binaries"
      end
    end

    def uses_freetds?
      File.exist?(File.join(Dir.pwd,FREETDS_TRIGGER_NAME))
    end

    def uses_sap_hana?
      File.exist?(File.join(Dir.pwd,SAP_HANA_TRIGGER))
    end

    def install_sap_hana_binaries
      `mkdir -p #{UNIX_ODBC_DIR_ABSOLUTE_PATH}` unless Dir.exists?(UNIX_ODBC_DIR_ABSOLUTE_PATH)
      `mkdir -p #{UNIX_ODBC_DIR_FOR_RELEASE}` unless Dir.exists?(UNIX_ODBC_DIR_FOR_RELEASE)

      result = `curl #{UNIX_ODBC_WITH_HANA_TGZ_URL} -s -o - | tar -xz -C #{UNIX_ODBC_DIR_ABSOLUTE_PATH} -f - `
      if $?.success?
        puts "Creating Bundler configuration file for SAP HANA"
        
        `bundle config build.ruby-odbc --enable-dlopen --with-odbc-include=#{UNIX_ODBC_DIR_ABSOLUTE_PATH}/include --with-odbc-lib=#{UNIX_ODBC_DIR_ABSOLUTE_PATH}/lib 2&>1`
        raise "Error configuring ODBC! #{$?}" unless $?.success?
      else
        raise "Failed to install SAP HANA binaries"
      end
    end

    def append_config_to_dot_bundle_config_file(key_to_check_for, gem_configuration_to_append)
      if File.exists?(dot_bundle_config_file) && File.file?(dot_bundle_config_file)
        existing_config = File.read(dot_bundle_config_file)
        File.open(dot_bundle_config_file, 'a') {|f| f.write(gem_configuration_to_append) } unless existing_config.include?(key_to_check_for)
      else
        File.open(dot_bundle_config_file, 'w') do |f|
          f.write <<-CONFIG
---
BUNDLE_PATH: vendor/bundle
BUNDLE_DISABLE_SHARED_GEMS: '1'
BUNDLE_CACHE_ALL: false
CONFIG
          f.write(gem_configuration_to_append) 
        end
      end
    end
    
    def ruby_odbc_gem_bundle_key
      'BUNDLE_BUILD__RUBY-ODBC'
    end
    
    def ruby_oci8_gem_bundle_key
      'BUNDLE_BUILD__RUBY-OCI8'
    end
    
    def dot_bundle_config_file
      File.join(dot_bundle,'config')
    end
    
    def dot_bundle 
      File.join(Dir.pwd,'.bundle')
    end
    
    def build_native_gems
      puts "Building native gems..."
      puts "\nBEFORE: Bundle Config is #{`bundle config`}"
      
      if uses_oci8?
        puts "Found OCI8 trigger"
        install_oci8_binaries 
      end

      if uses_freetds?
        puts "Found FreeTDS trigger"
        install_freetds_binaries
      end

      if uses_sap_hana?
        puts "Found SAP HANA trigger"
        install_sap_hana_binaries
      end
      puts "\nAFTER: Bundle Config is #{`more ~/.bundle/config`}"
      puts "Done building native gems."
    end
    
  end
end