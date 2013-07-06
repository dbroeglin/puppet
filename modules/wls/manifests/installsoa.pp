# == Define: wls::installsoa
#
# installs Oracle SOA Suite addon   
#
# === Examples
#
#    $jdkWls11gJDK = 'jdk1.7.0_09'
#    $wls11gVersion = "1036"
#
#  case $operatingsystem {
#     CentOS, RedHat, OracleLinux, Ubuntu, Debian: { 
#       $osMdwHome    = "/opt/wls/Middleware11gR1"
#       $osWlHome     = "/opt/wls/Middleware11gR1/wlserver_10.3"
#       $oracleHome   = "/opt/wls/"
#       $user         = "oracle"
#       $group        = "dba"
#     }
#     windows: { 
#       $osMdwHome    = "c:/oracle/wls11g"
#       $osWlHome     = "c:/oracle/wls11g/wlserver_10.3"
#       $user         = "Administrator"
#       $group        = "Administrators"
#     }
#  }
#
#
#  Wls::Installsoa {
#    mdwHome      => $osMdwHome,
#    wlHome       => $osWlHome,
#    fullJDKName  => $jdkWls11gJDK,	
#    user         => $user,
#    group        => $group,    
#  }
#  
#
#  wls::installsoa{'soaPS5':
#    soaFile1      => 'ofm_soa_generic_11.1.1.6.0_disk1_1of2.zip',
#    soaFile2      => 'ofm_soa_generic_11.1.1.6.0_disk1_2of2.zip',
#  }
#
## 


define wls::installsoa($mdwHome         = undef,
                       $wlHome          = undef,
                       $oracleHome      = undef,
                       $fullJDKName     = undef,
                       $soaFile1        = undef,
                       $soaFile2        = undef,
                       $user            = 'oracle',
                       $group           = 'dba',
                       $downloadDir     = '/install/',
                       $puppetDownloadMntPoint  = undef,  
                    ) {

   case $operatingsystem {
     CentOS, RedHat, OracleLinux, Ubuntu, Debian: { 

        $execPath        = "/usr/java/${fullJDKName}/bin:/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin:"
        $path            = $downloadDir
        $soaOracleHome   = "${mdwHome}/Oracle_SOA1"
        $oraInstPath     = "/etc"
        $oraInventory    = "${oracleHome}/oraInventory"
        
        $soaInstallDir   = "linux64"
        $jreLocDir       = "/usr/java/${fullJDKName}"
        
        Exec { path      => $execPath,
               user      => $user,
               group     => $group,
               logoutput => true,
             }
        File {
               ensure  => present,
               mode    => 0775,
               owner   => $user,
               group   => $group,
             }        
     }
     Solaris: { 

        $execPath        = "/usr/jdk/${fullJDKName}/bin/amd64:/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin:"
        $path            = $downloadDir
        $soaOracleHome   = "${mdwHome}/Oracle_SOA1"
        $oraInstPath     = "/var/opt"
        $oraInventory    = "${oracleHome}/oraInventory"

        $soaInstallDir   = "intelsolaris"
        $jreLocDir       = "/usr/jdk/${fullJDKName}"
                
        Exec { path      => $execPath,
               user      => $user,
               group     => $group,
               logoutput => true,
             }
        File {
               ensure  => present,
               mode    => 0775,
               owner   => $user,
               group   => $group,
             }        
     }
     windows: { 

        $execPath         = "C:\\oracle\\${fullJDKName}\\bin;C:\\unxutils\\bin;C:\\unxutils\\usr\\local\\wbin;C:\\Windows\\system32;C:\\Windows"
        $checkCommand     = "C:\\Windows\\System32\\cmd.exe /c" 
        $path             = $downloadDir 
        $soaOracleHome    = "${mdwHome}/Oracle_SOA1"
        $oraInventory     = "C:\\Program Files\\Oracle\\Inventory"
        
        Exec { path      => $execPath,
             }
        File { ensure  => present,
               mode    => 0777,
             }   
     }
   }

     # check if the osb already exists
     $found = oracle_exists( $soaOracleHome )
     if $found == undef {
       $continue = true
     } else {
       if ( $found ) {
         notify {"wls::installsoa ${title} ${soaOracleHome} already exists":}
         $continue = false
       } else {
         notify {"wls::installsoa ${title} ${soaOracleHome} does not exists":}
         $continue = true 
       }
     }

if ( $continue ) {

   if $puppetDownloadMntPoint == undef {
     $mountPoint =  "puppet:///modules/wls/"    	
   } else {
     $mountPoint =	$puppetDownloadMntPoint
   }


   $soaTemplate =  "wls/silent_soa.xml.erb"

#   if ! defined(File["${path}/${title}silent_soa.xml"]) {
     file { "${path}/${title}silent_soa.xml":
       ensure  => present,
       content => template($soaTemplate),
     }
#   }

   # soa file 1 installer zip
   if ! defined(File["${path}/${soaFile1}"]) {
    file { "${path}/${soaFile1}":
     source  => "${mountPoint}/${soaFile1}",
     require => File ["${path}/${title}silent_soa.xml"],
    }
   }

   # soa file 2 installer zip
   if ! defined(File["${path}/${soaFile2}"]) {
    file { "${path}/${soaFile2}":
     source  => "${mountPoint}/${soaFile2}",
     require => [File ["${path}/${title}silent_soa.xml"],File["${path}/${soaFile1}"]],
    }
   }


   
   $command  = "-silent -response ${path}/${title}silent_soa.xml "
    
   case $operatingsystem {
     CentOS, RedHat, OracleLinux, Ubuntu, Debian: { 

        if ! defined(Exec["extract ${soaFile1}"]) {
         exec { "extract ${soaFile1}":
          command => "unzip ${path}/${soaFile1} -d ${path}/soa",
          creates => "${path}/soa/Disk1",
          require => [File ["${path}/${soaFile2}"],File ["${path}/${soaFile1}"]],
         }
        }

        if ! defined(Exec["extract ${soaFile2}"]) {
         exec { "extract ${soaFile2}":
          command => "unzip ${path}/${soaFile2} -d ${path}/soa",
          creates => "${path}/soa/Disk5",
          require => [File ["${path}/${soaFile2}"],Exec["extract ${soaFile1}"]],
         }
        }


        if ! defined(File["${oraInstPath}/oraInst.loc"]) {
         file { "${oraInstPath}/oraInst.loc":
           ensure  => present,
           content => template("wls/oraInst.loc.erb"),
#           require     => Exec["extract ${soaFile2}"],
         }
        }
        
        exec { "install soa ${title}":
          command     => "${path}/soa/Disk1/install/${soaInstallDir}/runInstaller ${command} -invPtrLoc ${oraInstPath}/oraInst.loc -ignoreSysPrereqs -jreLoc ${jreLocDir}",
          require     => [File ["${oraInstPath}/oraInst.loc"],File["${path}/${title}silent_soa.xml"],Exec["extract ${soaFile1}"],Exec["extract ${soaFile2}"]],
          creates     => $soaOracleHome,
          environment => ["CONFIG_JVM_ARGS=-Djava.security.egd=file:/dev/./urandom"],
        }    

        exec { "sleep 3 min for soa install ${title}":
          command     => "/bin/sleep 180",
          require     => Exec ["install soa ${title}"],
        }    

             
     }
     Solaris: { 

        if ! defined(Exec["extract ${soaFile1}"]) {
         exec { "extract ${soaFile1}":
          command => "unzip ${path}/${soaFile1} -d ${path}/soa",
          creates => "${path}/soa/Disk1",
          require => [File ["${path}/${soaFile2}"],File ["${path}/${soaFile1}"]],
         }
        }

        if ! defined(Exec["extract ${soaFile2}"]) {
         exec { "extract ${soaFile2}":
          command => "unzip ${path}/${soaFile2} -d ${path}/soa",
          creates => "${path}/soa/Disk5",
          require => [File ["${path}/${soaFile2}"],Exec["extract ${soaFile1}"]],
         }
        }

        exec { "add -d64 oraparam.ini soa":
          command => "sed -e's/JRE_MEMORY_OPTIONS=\" -Xverify:none\"/JRE_MEMORY_OPTIONS=\"-d64 -Xverify:none\"/g' ${path}/soa/Disk1/install/${soaInstallDir}/oraparam.ini > /tmp/soa.tmp && mv /tmp/soa.tmp ${path}/soa/Disk1/install/${soaInstallDir}/oraparam.ini",
          require => [Exec["extract ${soaFile1}"],Exec["extract ${soaFile2}"]],
        }


        if ! defined(File["${oraInstPath}/oraInst.loc"]) {
         file { "${oraInstPath}/oraInst.loc":
           ensure  => present,
           content => template("wls/oraInst.loc.erb"),
         }
        }
        
        exec { "install soa ${title}":
          command     => "${path}/soa/Disk1/install/${soaInstallDir}/runInstaller ${command} -invPtrLoc ${oraInstPath}/oraInst.loc -ignoreSysPrereqs -jreLoc ${jreLocDir}",
          require     => [File ["${oraInstPath}/oraInst.loc"],File["${path}/${title}silent_soa.xml"],Exec["extract ${soaFile1}"],Exec["extract ${soaFile2}"],Exec["add -d64 oraparam.ini soa"]],
          creates     => $soaOracleHome,
          environment => ["CONFIG_JVM_ARGS=-Djava.security.egd=file:/dev/./urandom"],
        }    

        exec { "sleep 3 min for soa install ${title}":
          command     => "/bin/sleep 180",
          require     => Exec ["install soa ${title}"],
        }    

             
     }

     windows: { 

        if ! defined(Registry_Key["HKEY_LOCAL_MACHINE\\SOFTWARE\\Oracle"]) { 
          registry_key { "HKEY_LOCAL_MACHINE\\SOFTWARE\\Oracle":
            ensure  => present,
            require => [File ["${path}/${soaFile1}"],File ["${path}/${soaFile2}"]],
          }
        }

        if ! defined(Registry_Value ["HKEY_LOCAL_MACHINE\\SOFTWARE\\Oracle\\inst_loc"]) {
          registry_value { "HKEY_LOCAL_MACHINE\\SOFTWARE\\Oracle\\inst_loc":
            type    => string,
            data    => $oraInventory,
            require => Registry_Key["HKEY_LOCAL_MACHINE\\SOFTWARE\\Oracle"],
          }
        }



        if ! defined(Exec["extract ${soaFile1}"]) {
         exec { "extract ${soaFile1}":
          command => "${checkCommand} unzip ${path}/${soaFile1} -d ${path}/soa",
          require => [Registry_Value ["HKEY_LOCAL_MACHINE\\SOFTWARE\\Oracle\\inst_loc"],File ["${path}/${soaFile1}"]],
          creates => "${path}/soa/Disk1",
         }
        }

        if ! defined(Exec["extract ${soaFile2}"]) {
         exec { "extract ${soaFile2}":
          command => "${checkCommand} unzip ${path}/${soaFile2} -d ${path}/soa",
          require => [Exec["extract ${soaFile1}"],File ["${path}/${soaFile2}"]],
          creates => "${path}/soa/Disk5",
         }
        }


        exec {"icacls soa disk ${title}": 
           command    => "${checkCommand} icacls ${path}\\soa\\* /T /C /grant Administrator:F Administrators:F",
           logoutput  => false,
           require    => [Exec["extract ${soaFile2}"],Exec["extract ${soaFile1}"]],
        } 

        exec { "install soa ${title}":
          command     => "${path}\\soa\\Disk1\\setup.exe ${command} -ignoreSysPrereqs -jreLoc C:\\oracle\\${fullJDKName}",
          logoutput   => true,
          require     => [Exec["icacls soa disk ${title}"],File["${path}/${title}silent_soa.xml"],Exec["extract ${soaFile2}"],Exec["extract ${soaFile1}"]],
          creates     => $soaOracleHome, 
        }    

        exec { "sleep 3 min for soa install ${title}":
          command     => "${checkCommand} sleep 180",
          require     => Exec ["install soa ${title}"],
        }    


     }
   }
}
}
