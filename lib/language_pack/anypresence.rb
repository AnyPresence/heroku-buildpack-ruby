require 'fileutils'
module LanguagePack
  module Anypresence
    CHAMELEON_S3_BUCKET = 'https://s3.amazonaws.com/chameleon-heroku-assets'

    OCI8_TRIGGER_NAME = '.oracle.ini'
    ORACLE_INSTANT_CLIENT_TGZ_URL = "#{CHAMELEON_S3_BUCKET}/instantclient_11_2_with_libaio_oci8.tar.gz"
    ORACLE_INSTANT_CLIENT_DIR = "vendor/instant_client_11_2"
    ORACLE_INSTANT_CLIENT_DIR_FOR_RELEASE = "/app/vendor/instant_client_11_2"

    FREETDS_TRIGGER_NAME = '.freetds.conf'
    FREETDS_TGZ_URL="#{CHAMELEON_S3_BUCKET}/freetds.tar.gz"
    FREETDS_DIR = "vendor/freetds"
    FREETDS_DIR_FOR_RELEASE = "/app/vendor/freetds"

    SAP_HANA_TRIGGER = '.odbc.ini'
    UNIX_ODBC_WITH_HANA_TGZ_URL = "#{CHAMELEON_S3_BUCKET}/unixodbc.tar.gz"
    UNIX_ODBC_DIR = 'vendor/unixodbc'
    UNIX_ODBC_DIR_FOR_RELEASE = "/app/vendor/unixodbc"
    
    def merge_native_config_vars(vars={})
      extra_vars = {}
      ld_library_vars = []
      
      if uses_oci8?
        ld_library_vars << ORACLE_INSTANT_CLIENT_DIR_FOR_RELEASE # Needed to load resulting SO
        ld_library_vars << ORACLE_INSTANT_CLIENT_DIR # Needed for the actual build
        extra_vars["NLS_LANG"] = 'AMERICAN_AMERICA.UTF8'
        `export NLS_LANG='AMERICAN_AMERICA.UTF8'` # Needed for Rake tasks
        ENV['NLS_LANG'] = 'AMERICAN_AMERICA.UTF8'
      end
      
      if uses_freetds?
        ld_library_vars << "#{FREETDS_DIR}/lib" # Needed to load resulting SO
        ld_library_vars << "#{FREETDS_DIR}"
        ld_library_vars << "#{FREETDS_DIR_FOR_RELEASE}/lib"
        ld_library_vars << "#{FREETDS_DIR_FOR_RELEASE}"
        extra_vars["FREETDS_DIR"] = FREETDS_DIR_FOR_RELEASE
      end
      
      if uses_sap_hana?
        ld_library_vars << "#{UNIX_ODBC_DIR_FOR_RELEASE}"
        ld_library_vars << "#{UNIX_ODBC_DIR_FOR_RELEASE}/lib"
      end
      
      unless ld_library_vars.empty?
        new_ld_library_path = ld_library_vars.join(":")
        extra_vars.merge!("LD_LIBRARY_PATH" => new_ld_library_path) 
        `export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:#{new_ld_library_path}`
        ENV['LD_LIBRARY_PATH'] = "#{ENV['LD_LIBRARY_PATH']}:#{new_ld_library_path}"
      end
      
      vars.merge!(extra_vars) unless extra_vars.empty?
    end
    
    def uses_oci8?
      File.exist?(File.join(Dir.pwd,OCI8_TRIGGER_NAME))
    end

    def install_oci8_binaries
      FileUtils.mkdir_p(ORACLE_INSTANT_CLIENT_DIR) unless Dir.exists?(ORACLE_INSTANT_CLIENT_DIR)
      FileUtils.mkdir_p(ORACLE_INSTANT_CLIENT_DIR_FOR_RELEASE) unless Dir.exists?(ORACLE_INSTANT_CLIENT_DIR_FOR_RELEASE)
      puts "Downloading Oracle client package for OCI8"
      `curl #{ORACLE_INSTANT_CLIENT_TGZ_URL} -s -o - | tar -xz -C #{ORACLE_INSTANT_CLIENT_DIR} -f - `
      `curl #{ORACLE_INSTANT_CLIENT_TGZ_URL} -s -o - | tar -xz -C #{ORACLE_INSTANT_CLIENT_DIR_FOR_RELEASE} -f - `
      if $?.success?
        puts "Done"
      else
        raise "Failed to install OCI8 binaries"
      end
    end

    def install_freetds_binaries
      FileUtils.mkdir_p(FREETDS_DIR) unless Dir.exists?(FREETDS_DIR)
      FileUtils.mkdir_p(FREETDS_DIR_FOR_RELEASE) unless Dir.exists?(FREETDS_DIR_FOR_RELEASE)
      puts "Downloading FreeTDS package for SQL Server"
      `curl #{FREETDS_TGZ_URL} -s -o - | tar -xz -C #{FREETDS_DIR} -f - `
      `curl #{FREETDS_TGZ_URL} -s -o - | tar -xz -C #{FREETDS_DIR_FOR_RELEASE} -f - `
      if $?.success?
        puts "Setting environment variable for SQL Server"
        ENV["FREETDS_DIR"] = FREETDS_DIR_FOR_RELEASE
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
      FileUtils.mkdir_p(UNIX_ODBC_DIR_FOR_RELEASE) unless Dir.exists?(UNIX_ODBC_DIR_FOR_RELEASE)
      FileUtils.mkdir_p(UNIX_ODBC_DIR) unless Dir.exists?(UNIX_ODBC_DIR)
      puts "Downloading package for SAP HANA"
      `curl #{UNIX_ODBC_WITH_HANA_TGZ_URL} -s -o - | tar -xz -C #{UNIX_ODBC_DIR} -f - `
      `curl #{UNIX_ODBC_WITH_HANA_TGZ_URL} -s -o - | tar -xz -C #{UNIX_ODBC_DIR_FOR_RELEASE} -f - `
      if $?.success?
        puts "Creating Bundler configuration file for SAP HANA"
        `bundle config build.ruby-odbc --enable-dlopen --with-odbc-include=#{UNIX_ODBC_DIR_FOR_RELEASE}/include  --with-odbc-lib=#{UNIX_ODBC_DIR_FOR_RELEASE}/lib`
        raise "Error building bundle config for HANA!" unless $?.success?
      else
        raise "Failed to install SAP HANA binaries"
      end
    end
        
    def dot_bundle_config_file
      File.join(dot_bundle,'config')
    end
    
    def dot_bundle 
      File.join(ARGV[0],'.bundle')
    end
    
    def build_native_gems
      puts "Building native gems..."
      
      if uses_oci8?
        puts "Found OCI8 trigger"
        install_oci8_binaries 
      end

      if uses_sap_hana?
        puts "Found SAP HANA trigger"
        install_sap_hana_binaries
      end
      
      if uses_freetds?
        puts "Found FreeTDS trigger"
        install_freetds_binaries
      end

      puts "Done building native gems."
    end
    
  end
end