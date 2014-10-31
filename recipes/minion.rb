#
# Cookbook Name:: chef-salt
# Recipe:: default
#
# Copyright (C) 2014 
#
# 
#

# TODO: call sync grains command in Salt periodically to ensure the autmatic
# grains stay in sync.

include_recipe "salt::_setup"

package node.salt['minion']['package'] do
  version node.salt['version'] if node.salt['version']
  options node.salt['minion']['install_opts'] unless node.salt['minion']['install_opts'].nil?
  action :install
end

service 'salt-minion' do 
  action :enable
end

unless node.salt['minion']['master']
  master_search = "role:#{node.salt['role']['master']}"
  if node.salt['minion']['master_environment'] and node.salt['minion']['master_environment'] != '_default'
    master_search += " AND chef_environment:#{node.salt['minion']['master_environment']}" 
  end

  master_nodes = search(:node, master_search)

  # TODO: Find best IP address
  master = master_nodes.collect { |n| n['ipaddress'] }
else
  master = [node.salt['minion']['master']]
end

unless master and master.length >= 1
  raise "No salt-master found"
end

template "/etc/salt/minion" do
  source node.salt['minion']['config_template'] || 'minion.erb'
  cookbook node.salt['minion']['config_cookbook'] || 'salt'
  owner "root"
  group "root"
  mode "0644"
  variables( 
            :master => master,
            :id     => node[:salt][:minion][:id]
           )
  notifies :restart, 'service[salt-minion]', :delayed
  notifies :run, 'execute[wait for salt-minion]', :delayed
end

# We need to wait for salt-minion to generate the key, so we can capture it
execute "wait for salt-minion" do
  command 'sleep 5'
  action :nothing
  notifies :reload, 'ohai[reload_salt]', :immediate
end


