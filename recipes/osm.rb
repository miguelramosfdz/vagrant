#
# Cookbook Name:: pelias
# Recipe:: osm
#

deploy "#{node[:pelias][:basedir]}/pelias-osm" do
  user        node[:pelias][:user][:name]
  repository  node[:pelias][:osm][:repository]
  revision    node[:pelias][:osm][:revision]
  migrate     false

  symlink_before_migrate.clear
  create_dirs_before_symlink %w(tmp public config deploy)

  notifies :run, 'execute[npm install pelias-osm]', :immediately
  only_if { node[:pelias][:osm][:index_data] == true }
end

execute 'npm install pelias-osm' do
  action  :nothing
  user    node[:pelias][:user][:name]
  command 'npm install'
  cwd     "#{node[:pelias][:basedir]}/pelias-osm/current"
  environment('HOME' => node[:pelias][:user][:home])
end

node[:pelias][:osm][:extracts].map do |name, url|
  data_file = url.split('/').last
  log "Data file is #{data_file}"

  # fail if someone tries to pull something other than
  #   a pbf data file
  fail if data_file !~ /\.pbf$/

  # unique templates for each file we need to load (ugh)
  template "#{node[:pelias][:cfg_dir]}/#{name}_#{node[:pelias][:cfg_file]}" do
    source  "#{node[:pelias][:cfg_file]}.erb"
    mode    0644
    variables(osm_data_file: data_file)
  end

  remote_file "#{node[:pelias][:osm][:data_dir]}/#{data_file}" do
    action    :create_if_missing
    source    url
    mode      0644
    backup    false
    notifies  :run, "execute[load osm #{name}]", :immediately
    only_if { node[:pelias][:osm][:index_data] == true }
  end

  # triggered by the data download
  execute "load osm #{name}" do
    action  :nothing
    user    node[:pelias][:user][:name]
    command "node index.js >#{node[:pelias][:basedir]}/logs/osm_#{name}.log 2>&1"
    cwd     "#{node[:pelias][:basedir]}/pelias-osm/current"
    timeout node[:pelias][:osm][:timeout]
    environment(
      'HOME' => node[:pelias][:user][:home],
      'PELIAS_CONFIG' => "#{node[:pelias][:cfg_dir]}/#{name}_#{node[:pelias][:cfg_file]}"
    )
  end
end
