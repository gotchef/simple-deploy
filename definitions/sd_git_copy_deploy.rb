
define :sd_git_copy_deploy do
	deploy = params[:deploy_data]
	deploy_key = params[:deploy_key]

	deploy_root = deploy[:deploy_root]
	new_release_dir = Time.now.strftime("%Y-%m-%dT%H%M-%S")
	releases_dir = "#{deploy_root}/releases"
	deploy_current = "#{releases_dir}/#{new_release_dir}"

	branch_name = deploy[:scm][:revision]

	#create go root
	directory "#{deploy_current}" do
		group deploy[:group]
		owner deploy[:user]
		mode "0775"
		action :create
		recursive true
	end

	ensure_scm_package_installed('git')

	ruby_block "change HOME to #{deploy[:home]} for source checkout" do
		block do
		ENV['HOME'] = "#{deploy[:home]}"
		end
	end

	#so we can checkout private repos
	execute 'git config --global url."git@github.com:".insteadOf "https://github.com/"' do
		user 'root'
		group 'root'
	end

	prepare_git_checkouts(
      :user => deploy[:user],
      :group => deploy[:group],
      :home => deploy[:home],
      :ssh_key => deploy_key
    ) 

	#go source
	directory "#{deploy_current}" do
		group deploy[:group]
		owner deploy[:user]
		mode "0775"
		action :create
		recursive true
	end
	
	git "#{deploy_current}"  do
		repository "#{deploy[:scm][:repository]}"	
		revision branch_name
		action :sync
		user deploy[:user]
		group deploy[:group]
	end

	#be good to also run ginkgo tests
	#coverage also
	#
	
	link "#{deploy_root}/current" do
		to "#{deploy_current}/"
		owner deploy[:user]
		group deploy[:group]
	end

	#delete previous releases
	sorted_dirs = ::Dir["#{releases_dir}/*"].sort.reverse
	max_index = sorted_dirs.length - 1
	for i in 5..max_index
		current = sorted_dirs[i]
		directory "#{current}" do
			action :delete
			recursive true
		end
	end

	ruby_block "change HOME back to /root after source checkout" do
		block do
		ENV['HOME'] = "/root"
		end
	end	
end

