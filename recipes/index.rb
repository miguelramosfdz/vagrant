#
# Cookbook Name:: pelias
# Recipe:: index
#

deploy "#{node[:pelias][:basedir]}/pelias-schema" do
  user        node[:pelias][:user][:name]
  repository  node[:pelias][:index][:repository]
  revision    node[:pelias][:index][:revision]
  migrate     false

  symlink_before_migrate.clear
  create_dirs_before_symlink %w(tmp public config deploy)

  notifies :run, 'execute[npm install pelias-schema]', :immediately
end

execute 'npm install pelias-schema' do
  action  :nothing
  user    node[:pelias][:user][:name]
  command 'npm install'
  cwd     "#{node[:pelias][:basedir]}/pelias-schema/current"
  environment('HOME' => node[:pelias][:user][:home])
end

execute 'node scripts/drop_index.js --force-yes' do
  user    node[:pelias][:user][:name]
  cwd     "#{node[:pelias][:basedir]}/pelias-schema/current"
  only_if { node[:pelias][:index][:drop_index] == true }
  environment('PELIAS_CONFIG' => "#{node[:pelias][:cfg_dir]}/#{node[:pelias][:cfg_file]}")
end

# ignore failure here so that we can reprovision without having to change settings
#   in the Vagrantfile. If the index creation really does fail, we'll just abort further
#   downstream anyway.
#
execute 'node scripts/create_index.js' do
  user            node[:pelias][:user][:name]
  cwd             "#{node[:pelias][:basedir]}/pelias-schema/current"
  retries         2
  retry_delay     15
  ignore_failure  true
  only_if { node[:pelias][:index][:create_index] == true }
  environment('PELIAS_CONFIG' => "#{node[:pelias][:cfg_dir]}/#{node[:pelias][:cfg_file]}")
end