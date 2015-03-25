##
# This module requires Metasploit: http://metasploit.com/download
# Current source: https://github.com/rapid7/metasploit-framework
##

require 'msf/core'

class Metasploit3 < Msf::Auxiliary
  include Msf::Exploit::Remote::HttpClient
  include Msf::Auxiliary::Scanner

  def initialize(info = {})
    super(update_info(info,
      'Name'          => 'F5 Management Interface Scanner',
      'Description'   => %q{
        This module simply detects web management interface of the following F5 Networks devices: BigIP, BigIQ, Enterprise Manager, ARX, and FirePass.
      },
      'License'       => MSF_LICENSE,
      'Author'        =>
        [
          'Denis Kolegov <dnkolegov[at]gmail.com>',
          'Oleg Broslavsky <ovbroslavsky[at]gmail.com>',
          'Nikita Oleksov <neoleksov[at]gmail.com>'
        ],
      'DefaultOptions' =>
        {
          'SSL' => true,
          'SSLVersion' => 'TLS1',
          'RPORT' => 443
        }
    ))

    register_options(
        [
          OptInt.new('TIMEOUT', [true, "Timeout for the HTTPS probe in milliseconds", 1000])
        ], self.class)
  end

  def port_open?(to, verbose)
    begin
      ::Timeout.timeout(to) do
        begin
          res = send_request_raw('method' => 'GET', 'uri' => '/', 'rport' => rport)
          return true if res
        rescue ::Rex::ConnectionRefused
          print_status("#{peer} - TCP port closed") if verbose
          return false
        rescue ::Rex::ConnectionError
          print_error("#{peer} - Connection failed") if verbose
          return false
        rescue ::OpenSSL::SSL::SSLError
          print_error("#{peer} - SSL/TLS connection error") if verbose
          return false
        end
      end
    rescue Timeout::Error
      print_error("#{peer} - HTTP connection timed out") if verbose
      return false
    end
  end

  def run_host(ip)
    # Test if a RPORT on a remote host is reachable using HTTPClient
    to = (datastore['TIMEOUT'] || 500).to_f / 1000.0
    verbose = datastore['VERBOSE']
    return unless port_open?(to, verbose)

    res = send_request_raw('method' => 'GET', 'uri' => '/', 'rport' => rport)
    if res && res.code == 200

      # Detect BigIP management interface
      if res.body =~ /<title>BIG\-IP/
        print_status("#{peer} - F5 BigIP web management interface found")
        return
      end

      # Detect EM management interface
      if res.body =~ /<title>Enterprise Manager/
        print_status("#{peer} - F5 Enterprise Manager web management interface found")
        return
      end

      # Detect ARX management interface
      if res.body =~ /<title>F5 ARX Manager Login<\/title>/
        print_status("#{peer} - ARX web management interface found")
        return
      end
    end

    res = send_request_raw('method' => 'GET', 'uri' => '/ui/login/', 'rport' => rport)

    # Detect BigIQ management interface
    if res && res.code == 200 && res.body =~ /<title>BIG\-IQ/
      print_status("#{peer} - F5 BigIQ web management interface found")
      return
    end

    # Detect FirePass management interface
    res = send_request_raw('method' => 'GET', 'uri' => '/admin/', 'rport' => rport)
    if res && res.code == 200 && res.body =~ /<br><br><br><big><b>&nbsp;FirePass/
      print_status("#{peer} - F5 FirePass web management interface found")
      return
    end
  end
end
