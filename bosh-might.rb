#!/usr/bin/ruby

require 'rubygems'
#require 'aws-sdk'
require 'colored'

#AWS.config(:access_key_id     => ENV['AWS_ACCESS_KEY_ID'],
#           :secret_access_key => ENV['AWS_SECRET_ACCESS_KEY'])
#
#ec2                 = AWS::EC2.new
cf_release_version  = ARGV[0]
ip_address = ARGV[1]
##ami_name            = `curl -s https://bosh-lite-build-artifacts.s3.amazonaws.com/ami/bosh-lite-ami.list |tail -1`.chop
#ami_name            = 'ami-5692b93e' #boshlite-9000.11.0 https://github.com/cloudfoundry/bosh-lite/blob/master/Vagrantfile#L20
#instance_type       = 'm3.xlarge'
$ssh_username       = 'ubuntu'
$prefix              = "bosh-might".blue_on_black + ": ".yellow

class String
    def integer?
      [                          # In descending order of likeliness:
        /^[-+]?[1-9]([0-9]*)?$/, # decimal
        /^0[0-7]+$/,             # octal
        /^0x[0-9A-Fa-f]+$/,      # hexadecimal
        /^0b[01]+$/              # binary
      ].each do |match_pattern|
        return true if self =~ match_pattern
      end
      return false
    end
  end

def term_out(arg)
  puts $prefix + arg.white
end

if cf_release_version == nil
  puts "syntax: ruby bosh-might.rb <cf-release version number or branch name>"
  exit
end

#key_pair = ec2.key_pairs.find{|kp| kp.name == 'default' }
#if key_pair == nil
#  key_pair = ec2.key_pairs.import("default", File.read("#{ENV['HOME']}/.ssh/id_rsa.pub"))
#else
#  key_pair = ec2.key_pairs['default']
#end
#term_out "Using keypair #{key_pair.name}, fingerprint: #{key_pair.fingerprint}"

#security_group = ec2.security_groups.find{|sg| sg.name == 'bosh-lite' }

#if security_group == nil
#  secgroup = ec2.security_groups.create('bosh-lite')
#  secgroup.authorize_ingress(:tcp, 22, '0.0.0.0/0')
#else
#  secgroup = security_group
#  term_out "Using security group: #{security_group.name}"
#end

# create the instance (and launch it)
#instance = ec2.instances.create(:image_id        => ami_name,
#                                :instance_type   => instance_type,
#                                :count           => 1,
#                                :security_groups => secgroup,
#                                :key_pair        => key_pair,
#                                :block_device_mappings => [
#                                  {
#                                   :device_name => "/dev/sda1",
#                                   :ebs         => { :volume_size => 80, :delete_on_termination => true }
#                                  }
#                                ])
#term_out "Launching bosh-lite instance ..."

# wait until battle station is fully operational
#sleep 1 until instance.status != :pending
#term_out "Launched instance #{instance.id}, status: #{instance.status}, public dns: #{instance.dns_name}, public ip: #{instance.ip_address}"
#exit 1 unless instance.status == :running
#sleep 60 # yeah, running isn't really running
##omg what a hack
#$ip_address = ""

def local_command(arg, output=true)
  if output
    suffix = ""
  else
    suffix = "> /dev/null 2>&1"
  end
#  `ssh -o "StrictHostKeyChecking no" #{$ssh_username}@#{$ip_address} 'export DEBIAN_FRONTEND="noninteractive"; #{arg} #{suffix}'`
  `export DEBIAN_FRONTEND="noninteractive"; #{arg} #{suffix}`
end




term_out "Install Git, libmysql, libpq"
local_command "sudo apt-get -y update"
local_command "sudo apt-get -q -y install git libmysqlclient-dev libpq-dev"
term_out "Install Bundler"
local_command "sudo gem install bundler --no-rdoc --no-ri"
term_out "Install Bosh CLI"
local_command "sudo gem install bosh_cli --no-rdoc --no-ri"
term_out "Creating workspace directory"
local_command "mkdir workspace"
term_out "Installing unzip"
local_command "sudo apt-get -q -y install unzip"
term_out "Download Spiff"
local_command "wget https://github.com/cloudfoundry-incubator/spiff/releases/download/v1.0.3/spiff_linux_amd64.zip -P ~/workspace/"
term_out "Install Spiff"
local_command "sudo unzip -oq ~/workspace/spiff_linux_amd64.zip -d /usr/local/bin/"
term_out "Cloning into CF-Release"
local_command "git clone https://www.github.com/cloudfoundry/cf-release ~/workspace/cf-release"
term_out "Target local bosh-lite"
local_command "bosh -n target 127.0.0.1"
local_command "sudo chown ubuntu:ubuntu /home/ubuntu/.bosh_config"
local_command "sudo chown ubuntu:ubuntu /home/ubuntu/tmp"
local_command "bosh -n login admin admin"
term_out "Download bosh-lite stemcell"
#TODO: should have a way to get the latest bosh-lite stemcell and download it instead of hard coding it
local_command "curl -L https://bosh.io/d/stemcells/bosh-warden-boshlite-ubuntu-trusty-go_agent -o latest-bosh-lite-stemcell.tgz", true
term_out "Upload bosh-lite stemcell"
local_command "bosh upload stemcell latest-bosh-lite-stemcell.tgz"
term_out "Upload Bosh Release"
if cf_release_version.integer?
  local_command "cd ~/workspace/cf-release; git checkout v#{cf_release_version}"
  local_command "cd ~/workspace/cf-release/; ./update"
  local_command "cd ~/workspace/cf-release; bosh -n upload release ./releases/cf-#{cf_release_version}.yml"
else
  local_command "cd ~/workspace/cf-release; git checkout #{cf_release_version}"
  local_command "cd ~/workspace/cf-release/; ./update", true
  local_command "cd ~/workspace/cf-release; bosh -n create release", true
  local_command "cd ~/workspace/cf-release; bosh -n upload release", true
end
term_out "Spiff manifest"
local_command "cd ~/workspace/cf-release; ./bosh-lite/make_manifest", true

term_out "Fix IP address"
local_command "cd ~/workspace/cf-release; sed -i 's/10.244.0.34.xip.io/#{ip_address}.xip.io/g' ./bosh-lite/manifests/cf-manifest.yml"

term_out "Bosh Deploy"
local_command "bosh -n deploy", true


term_out "Launched: You can SSH to it with;"
#term_out "ssh #{$ssh_username}@#{instance.ip_address}"
term_out "Remember to terminate after you're done!"
