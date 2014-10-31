
include_recipe "salt::_setup"

package node['salt']['master']['package'] do
  version node['salt']['version'] if node['salt']['version']
  options node['salt']['master']['install_opts'] unless node['salt']['master']['install_opts'].nil?
  action :install
end

service 'salt-master' do 
  action :enable
end

template "/etc/salt/master" do
  source node['salt']['master']['config_template'] || 'master.erb'
  cookbook node['salt']['master']['config_cookbook'] || 'salt'
  owner "root"
  group "root"
  mode "0644"
  notifies :restart, 'service[salt-master]', :delayed
  notifies :run, 'execute[wait for salt-master]', :delayed
end

execute "wait for salt-master" do
  command 'sleep 5'
  action :nothing
  notifies :reload, 'ohai[reload_salt]', :immediate
end

unless Chef::Config[:solo]
  
  minion_search = "role:#{node.salt['role']['minion']}"
  if node.salt['master']['environment']
    minion_search += " AND chef_environment:#{node.salt['master']['environment']}" 
  end

  minions = search(:node, minion_search)

  log "Synchronizing keys for #{minions.length} minions"

  # Add minion keys to master PKI
  minions.each do |minion|
    next unless minion.salt['public_key']

    file "/etc/salt/pki/master/minions/#{minion.salt['minion']['id']}" do
      action :create
      owner "root"
      group "root"
      mode "0644"
      content minion.salt['public_key']
    end
    file "/etc/salt/pki/master/minions_pre/#{minion.salt['minion']['id']}" do
      action :delete
    end
    
    
  end
else

  log "Salt key exchange not supported on Chef solo" do
    level :warn
  end

end