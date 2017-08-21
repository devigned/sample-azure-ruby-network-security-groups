require 'azure_mgmt_resources'
require 'azure_mgmt_network'

WEST_US = 'westus'
GROUP_NAME = 'azure-nsg-sample-group'


# This script expects that the following environment vars are set:
#
# AZURE_TENANT_ID: with your Azure Active Directory tenant id or domain
# AZURE_CLIENT_ID: with your Azure Active Directory Application Client ID
# AZURE_CLIENT_SECRET: with your Azure Active Directory Application Secret
# AZURE_SUBSCRIPTION_ID: with your Azure Subscription Id
#
def run_example
  #
  # Create the Resource Manager Client with an Application (service principal) token provider
  #
  subscription_id = ENV['AZURE_SUBSCRIPTION_ID'] || '11111111-1111-1111-1111-111111111111' # your Azure Subscription Id
  provider = MsRestAzure::ApplicationTokenProvider.new(
      ENV['AZURE_TENANT_ID'],
      ENV['AZURE_CLIENT_ID'],
      ENV['AZURE_CLIENT_SECRET'])
  credentials = MsRest::TokenCredentials.new(provider)
  rm = Azure::ARM::Resources::ResourceManagementClient.new(credentials)
  rm.subscription_id = subscription_id
  networking = Azure::ARM::Network::NetworkManagementClient.new(credentials)
  networking.subscription_id = subscription_id

  #
  # Managing resource groups
  #
  resource_group_params = Azure::ARM::Resources::Models::ResourceGroup.new.tap do |rg|
    rg.location = WEST_US
  end

  nsg_params = Azure::ARM::Network::Models::NetworkSecurityGroup.new.tap do |nsg|
    nsg.location = WEST_US
  end

  # Create Resource group
  puts "\nCreate Resource Group"
  print_item rm.resource_groups.create_or_update(GROUP_NAME, resource_group_params)

  puts "\nCreating NSG named 'sample-ruby-nsg'"
  print_item nsg = networking.network_security_groups.create_or_update(GROUP_NAME, 'sample-ruby-nsg', nsg_params)

  puts "\nCreating a virtual network"
  vnet_create_params = Azure::ARM::Network::Models::VirtualNetwork.new.tap do |vnet|
    vnet.location = WEST_US
    vnet.address_space = Azure::ARM::Network::Models::AddressSpace.new.tap do |addr_space|
      addr_space.address_prefixes = ['10.0.0.0/16']
    end
    vnet.dhcp_options = Azure::ARM::Network::Models::DhcpOptions.new.tap do |dhcp|
      dhcp.dns_servers = ['8.8.8.8']
    end
    vnet.subnets = [
        Azure::ARM::Network::Models::Subnet.new.tap do |subnet|
          subnet.name = 'rubySampleSubnet'
          subnet.address_prefix = '10.0.0.0/24'
          subnet.network_security_group = nsg
        end
    ]
  end
  print_item vnet = networking.virtual_networks.create_or_update(GROUP_NAME, 'sample-ruby-vnet', vnet_create_params)

  puts "\nList security rules: "
  puts networking.security_rules.list(GROUP_NAME, 'sample-ruby-nsg')

  rule1 = Azure::ARM::Network::Models::SecurityRule.new.tap do |rule|
    rule.description = 'Ruby sample rule'
    rule.protocol = Azure::ARM::Network::Models::Protocol::TCP
    rule.source_port_range = '8888'
    rule.destination_port_range = '8000'
    rule.priority = 1000
    rule.source_address_prefix = '*'
    rule.destination_address_prefix = '*'
    rule.access = Azure::ARM::Network::Models::SecurityRuleAccess::Allow
    rule.direction = Azure::ARM::Network::Models::Direction::Inbound
  end

  rule2 = Azure::ARM::Network::Models::SecurityRule.new.tap do |rule|
    rule.description = 'Ruby sample rule'
    rule.protocol = Azure::ARM::Network::Models::Protocol::UDP
    rule.source_port_range = '9000'
    rule.destination_port_range = '9000'
    rule.priority = 1001
    rule.source_address_prefix = '*'
    rule.destination_address_prefix = '*'
    rule.access = Azure::ARM::Network::Models::SecurityRuleAccess::Allow
    rule.direction = Azure::ARM::Network::Models::Direction::Inbound
  end

  puts "\nAdd securty group rule1: "
  puts rule = networking.security_rules.create_or_update(GROUP_NAME, 'sample-ruby-nsg', 'sample-ruby-rule1', rule1)

  puts "\nAdd securty group rule2: "
  puts rule = networking.security_rules.create_or_update(GROUP_NAME, 'sample-ruby-nsg', 'sample-ruby-rule2', rule2)

  puts "\nList security rules: "
  puts networking.security_rules.list(GROUP_NAME, 'sample-ruby-nsg')

  puts "\nShow Network Security Group: "
  puts networking.network_security_groups.get(GROUP_NAME, 'sample-ruby-nsg')

end

def print_item(group)
  puts "\tName: #{group.name}"
  puts "\tId: #{group.id}"
  puts "\tLocation: #{group.location}"
  puts "\tTags: #{group.tags}"
  puts group
end

def print_properties(props)
  puts "\tProperties:"
  props.instance_variables.sort.each do |ivar|
    str = ivar.to_s.gsub /^@/, ''
    if props.respond_to? str.to_sym
      puts "\t\t#{str}: #{props.send(str.to_sym)}"
    end
  end
  puts "\n\n"
end

if $0 == __FILE__
  run_example
end