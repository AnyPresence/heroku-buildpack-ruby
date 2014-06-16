module LanguagePack
  module Anypresence
    CHAMELEON_S3_BUCKET = 'https://s3.amazonaws.com/chameleon-heroku-assets'

    OCI8_TRIGGER_NAME = '.oracle.ini'
    ORACLE_INSTANT_CLIENT_TGZ_URL = "#{CHAMELEON_S3_BUCKET}/instantclient_11_2_with_libaio_oci8.tar.gz"
    ORACLE_INSTANT_CLIENT_DIR_ABSOLUTE_PATH = "#{ARGV[0]}/vendor/instant_client_11_2"
    ORACLE_INSTANT_CLIENT_DIR_FOR_RELEASE = "#{ENV['HOME']}/vendor/instant_client_11_2"

    FREETDS_TRIGGER_NAME = '.freetds.conf'
    FREETDS_TGZ_URL="#{CHAMELEON_S3_BUCKET}/freetds.tar.gz"
    FREETDS_DIR_ABSOLUTE_PATH = "#{ARGV[0]}/vendor/freetds"
    FREETDS_DIR_FOR_RELEASE = "#{ENV['HOME']}/vendor/freetds"

    SAP_HANA_TRIGGER = '.odbc.ini'
    UNIX_ODBC_WITH_HANA_TGZ_URL = "#{CHAMELEON_S3_BUCKET}/unixodbc.tar.gz"
    UNIX_ODBC_DIR_ABSOLUTE_PATH = "#{ARGV[0]}/vendor/unixodbc"
    UNIX_ODBC_DIR_FOR_RELEASE = "#{ENV['HOME']}/vendor/unixodbc"
    
    def merge_native_config_vars(vars={})
      extra_vars = {}
      ld_library_vars = []
      
      if uses_oci8?
        ld_library_vars << ORACLE_INSTANT_CLIENT_DIR_FOR_RELEASE
        extra_vars["NLS_LANG"] = 'AMERICAN_AMERICA.UTF8'
        ENV["NLS_LANG"] = 'AMERICAN_AMERICA.UTF8'
      end
      
      if uses_freetds?
        ld_library_vars << "#{FREETDS_DIR_FOR_RELEASE}/lib" 
        extra_vars["FREETDS_DIR"] = FREETDS_DIR_FOR_RELEASE
        ENV["FREETDS_DIR"] = FREETDS_DIR_FOR_RELEASE
      end
      
      if uses_sap_hana?
        ld_library_vars << "#{UNIX_ODBC_DIR_FOR_RELEASE}"
        ld_library_vars << "#{UNIX_ODBC_DIR_FOR_RELEASE}/lib"
      end
      
      extra_vars.merge!("LD_LIBRARY_PATH" => ld_library_vars.join(":")) unless ld_library_vars.empty?
      ENV["LD_LIBRARY_PATH"]= ld_library_vars.join(":") unless ld_library_vars.empty?
      
      puts "Merging variables of #{extra_vars.inspect}" unless extra_vars.empty?
      
      vars.merge!(extra_vars) unless extra_vars.empty?
    end
    
    def uses_oci8?
      File.exist?(File.join(Dir.pwd,OCI8_TRIGGER_NAME))
    end

    def install_oci8_binaries
      `mkdir -p #{ORACLE_INSTANT_CLIENT_DIR_ABSOLUTE_PATH}` unless Dir.exists?(ORACLE_INSTANT_CLIENT_DIR_ABSOLUTE_PATH)
      `mkdir -p #{ORACLE_INSTANT_CLIENT_DIR_FOR_RELEASE}` unless Dir.exists?(ORACLE_INSTANT_CLIENT_DIR_FOR_RELEASE)

      result = `curl #{ORACLE_INSTANT_CLIENT_TGZ_URL} -s -o - | tar -xz -C #{ORACLE_INSTANT_CLIENT_DIR_ABSOLUTE_PATH} -f - `
      if $?.success?
        puts "Setting OCI8 environment variables"
        ENV["LD_LIBRARY_PATH"]="#{ORACLE_INSTANT_CLIENT_DIR_ABSOLUTE_PATH}:#{ENV['LD_LIBRARY_PATH']}" # Required for oci8 gem
        ENV["NLS_LANG"]='AMERICAN_AMERICA.UTF8'
        puts "Done installing OCI8 binaries"
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
        ruby_odbc_bundle_config = <<-CONFIG
---
BUNDLE_BUILD__RUBY-ODBC: --with-odbc-include=#{UNIX_ODBC_DIR_ABSOLUTE_PATH}/include --with-odbc-lib=#{UNIX_ODBC_DIR_ABSOLUTE_PATH}/lib
BUNDLE_PATH: vendor
BUNDLE_DISABLE_SHARED_GEMS: '1'
BUNDLE_CACHE_ALL: true

CONFIG
        dot_bundle = File.join(Dir.pwd,'.bundle')
        Dir.mkdir(dot_bundle)
        File.open(File.join(dot_bundle,'config'), 'w') {|f| f.write(ruby_odbc_bundle_config) }
      else
        raise "Failed to install SAP HANA binaries"
      end
    end

    def build_native_gems
      puts "Building native gems..."

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

      puts "Done building native gems."
    end
    
  end
end