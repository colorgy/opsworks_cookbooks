node[:deploy].each do |application, _deploy|
  ruby_block "Read Procfile and set the worker" do
    block do
      procfile_path = "#{node[:deploy][application][:deploy_to]}/current/Procfile"

      worker_command = nil

      if File.exist?(procfile_path)
        # Read the CWM version from file.
        f = File.open(procfile_path)

        pattern = /^worker: (?<command>.+)$/

        f.each do |line|
          if match = line.match(pattern)
            worker_command = match['command']
            break
          end
        end

        f.close
      end

      if worker_command
        template "#{node[:monit][:conf_dir]}/worker_#{application}.monitrc" do
          owner 'root'
          group 'root'
          mode 0644
          source "monitrc.conf.erb"
          variables({
            command: worker_command,
            app_name: application,
            process_type: 'worker',
            process_count: 1
          })
        end

        execute "Reload monit" do
          command %Q{
            monit reload
          }
        end

        execute "Restart worker" do
          command %Q{
            echo "sleep 20 && monit -g worker_#{application} restart all" | at now
          }
        end

      else
        execute "Stop worker" do
          command %Q{
            monit -g worker_#{application} stop all
          }
        end

        file "#{node[:monit][:conf_dir]}/worker_#{application}.monitrc" do
          action :delete
        end
      end
    end
  end
end